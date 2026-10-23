// Synchronisation entre navigateurs et appareils par le compte StreamHub (account.js) : réglages (clés API comprises),
// J'aime, Ma liste, historique, likes sur les plateformes. Tout est chiffré ici avec la clé du coffre avant d'être
// envoyé : Supabase ne voit qu'un contenu illisible. (Avant la version 2.1.0, un code de synchronisation passait
// par le relais StreamHub : retiré à la demande de l'utilisateur, c'est le compte ou rien.)
//
// Règle de fusion : ce qui a changé depuis la dernière synchronisation gagne. Si les deux côtés ont
// changé (deux appareils modifiés hors ligne), les listes sont réunies et les réglages de cet appareil gardés.
import { loadSettings, saveSettings, loadLibrary, saveLibrary, HISTORY_MAX } from './store.js';
import { loadAccount, saveAccount, vaultKey, fetchData, pushData, Conflict } from './account.js';

// Propres à chaque appareil : jamais synchronisés
// desktopApps (avant : primeApp) : les applis sont installées sur un ordinateur, pas un autre ; glass : réglé selon
// l'appareil
const DEVICE_SETTINGS = ['desktopApps', 'primeApp', 'glass', 'uiLang', 'region'];
// téléchargements et questions : sur l'appareil ; removed : titres retirés (voir library.js), pour la fusion
const SYNCED_LIBRARY = ['likes', 'watchlist', 'history', 'platformLikes', 'removed'];

const enc = new TextEncoder();

// L'ancien code de synchronisation (avant 2.1.0) n'a plus rien à faire sur l'appareil
try {
  localStorage.removeItem('streamhub:sync');
} catch {
  /* stockage indisponible */
}

// ---------- Chiffrement ----------

const toB64 = (bytes) => {
  let s = '';
  for (let i = 0; i < bytes.length; i += 0x8000) s += String.fromCharCode(...bytes.subarray(i, i + 0x8000));
  return btoa(s);
};
const fromB64 = (s) => Uint8Array.from(atob(s), (c) => c.charCodeAt(0));
const toHex = (buf) => [...new Uint8Array(buf)].map((b) => b.toString(16).padStart(2, '0')).join('');
const digest = async (value) => toHex(await crypto.subtle.digest('SHA-256', enc.encode(JSON.stringify(value))));

async function encrypt(payload, key) {
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const data = await crypto.subtle.encrypt({ name: 'AES-GCM', iv }, key, enc.encode(JSON.stringify(payload)));
  return { iv: toB64(iv), data: toB64(new Uint8Array(data)) };
}

async function decrypt(stored, key) {
  const plain = await crypto.subtle.decrypt({ name: 'AES-GCM', iv: fromB64(stored.iv) }, key, fromB64(stored.data));
  return JSON.parse(new TextDecoder().decode(plain));
}

// ---------- Données synchronisées ----------

function localPayload() {
  const settings = { ...loadSettings() };
  for (const k of DEVICE_SETTINGS) delete settings[k];
  const lib = loadLibrary();
  return { settings, library: Object.fromEntries(SYNCED_LIBRARY.map((k) => [k, lib[k]])) };
}

function applyPayload(payload) {
  const local = loadSettings();
  const settings = { ...local, ...payload.settings };
  for (const k of DEVICE_SETTINGS) settings[k] = local[k];
  saveSettings(settings, { quiet: true });
  saveLibrary({ ...loadLibrary(), ...payload.library }, { quiet: true });
}

const hashes = async (payload) => ({ settings: await digest(payload.settings), library: await digest(payload.library) });

// Réunit deux listes d'entrées { key, at } : une entrée par titre, la plus récente, triées du plus récent
function unionByKey(a = [], b = [], max = Infinity) {
  const byKey = new Map();
  for (const e of [...a, ...b]) {
    const prev = byKey.get(e.key);
    if (!prev || (e.at ?? 0) > (prev.at ?? 0)) byKey.set(e.key, e);
  }
  return [...byKey.values()].sort((x, y) => (y.at ?? 0) - (x.at ?? 0)).slice(0, max);
}

function mergePlatformLikes(a = {}, b = {}) {
  const out = { ...b };
  for (const [key, list] of Object.entries(a)) {
    const seen = new Set((out[key] ?? []).map((p) => `${p.service}|${p.platform}`));
    out[key] = [...(out[key] ?? []), ...list.filter((p) => !seen.has(`${p.service}|${p.platform}`))];
  }
  return out;
}

// Retraits mémorisés des deux côtés : pour chaque titre, le plus récent. On n'en garde que 200 par liste (un appareil
// resté hors ligne plus longtemps pourrait faire revenir un vieux titre retiré : sans gravité).
const REMOVED_MAX = 200;
function mergeRemoved(a = {}, b = {}) {
  const out = {};
  for (const name of new Set([...Object.keys(a), ...Object.keys(b)])) {
    const merged = { ...a[name] };
    for (const [key, at] of Object.entries(b[name] ?? {})) merged[key] = Math.max(merged[key] ?? 0, at);
    // Liste vidée : les retraits plus anciens n'ont plus d'utilité
    const cleared = merged['*'];
    const kept = Object.entries(merged).filter(([key, at]) => key !== '*' && at > (cleared ?? 0));
    out[name] = Object.fromEntries(kept.sort((x, y) => y[1] - x[1]).slice(0, REMOVED_MAX));
    if (cleared) out[name]['*'] = cleared;
  }
  return out;
}

// Une entrée retirée (ou la liste vidée) après son ajout ne revient pas ; ajoutée de nouveau après, elle reste
function notRemoved(list, removed = {}) {
  return list.filter((e) => {
    const at = Math.max(removed[e.key] ?? 0, removed['*'] ?? 0);
    return !at || (e.at ?? 0) > at;
  });
}

function merge(local, remote, changed) {
  if (!changed.library) return { settings: changed.settings ? local.settings : remote.settings, library: remote.library };
  const removed = mergeRemoved(local.library.removed, remote.library?.removed);
  const lists = (name, max) => notRemoved(unionByKey(local.library[name], remote.library?.[name]), removed[name]).slice(0, max);
  return {
    settings: changed.settings ? local.settings : remote.settings,
    library: {
      likes: lists('likes'),
      watchlist: lists('watchlist'),
      history: lists('history', HISTORY_MAX),
      platformLikes: mergePlatformLikes(local.library.platformLikes, remote.library?.platformLikes),
      removed,
    },
  };
}

// ---------- Une synchronisation ----------
// État dans le compte (account.js) : syncedAt (version de sync_data reçue ou envoyée), hashes, lastSyncAt, error

// Récupère les changements des autres appareils, envoie ceux d'ici. Renvoie { pulled } : true si des données sont
// arrivées (l'appli doit se redessiner).
async function run() {
  const key = await vaultKey();
  if (!key) return { pulled: false };
  if (loadAccount().joining) {
    // Coffre ouvert sur cet appareil (compte existant) : les réglages du compte s'appliquent et les listes d'ici s'y
    // ajoutent
    const local = localPayload();
    const now = await hashes(local);
    const hasLibrary = SYNCED_LIBRARY.some((k) => Object.keys(local.library[k] ?? {}).length);
    saveAccount({ ...loadAccount(), joining: false, syncedAt: null, hashes: { settings: now.settings, library: hasLibrary ? null : now.library } });
  }
  let pulled = false;
  try {
    for (let attempt = 0; ; attempt++) {
      const meta = loadAccount();
      const remote = await fetchData();
      const theirs = remote && remote.version !== meta.syncedAt ? await decrypt(remote, key) : null;
      // Données d'ici lues après la réponse du serveur : une modification faite pendant l'échange n'est pas écrasée
      const local = localPayload();
      const now = await hashes(local);
      const changed = { settings: now.settings !== meta.hashes?.settings, library: now.library !== meta.hashes?.library };
      const localChanged = changed.settings || changed.library;

      let syncedAt = meta.syncedAt;
      let toPush = null;
      let server = local; // ce que le serveur a maintenant (ses empreintes sont gardées)
      if (theirs) {
        const next = localChanged ? merge(local, theirs, changed) : theirs;
        applyPayload(next);
        pulled = true;
        syncedAt = remote.version;
        server = next;
        if (localChanged) toPush = next;
      } else if (!remote || localChanged) {
        toPush = local;
      }
      try {
        if (toPush) {
          syncedAt = await pushData(await encrypt(toPush, key), remote?.version ?? null);
          server = toPush;
        }
      } catch (err) {
        // Un autre appareil a écrit entre la lecture et l'écriture : on relit et on fusionne (ce qui vient d'être
        // appliqué compte comme un changement d'ici, puisque les empreintes n'ont pas bougé)
        if (err instanceof Conflict && attempt < 4) {
          saveAccount({ ...loadAccount(), syncedAt });
          continue;
        }
        throw err;
      }
      // Empreintes de ce qui a été envoyé ou reçu, pas des données d'ici relues maintenant : une modification faite
      // pendant l'envoi reste « à envoyer » (avant, elle passait pour envoyée et ne partait jamais)
      saveAccount({ ...loadAccount(), syncedAt, hashes: await hashes(server), lastSyncAt: Date.now(), error: null });
      return { pulled };
    }
  } catch (err) {
    if (loadAccount().session) saveAccount({ ...loadAccount(), error: err.message || String(err) });
    if (pulled) onPulled(); // des données sont déjà arrivées : l'appli se redessine
    throw err;
  }
}

let running = null;
let again = false;
// Une seule synchronisation à la fois ; une demande pendant qu'une tourne en relance une juste après.
// Erreur gardée dans l'état du compte et affichée dans les réglages.
export function syncNow() {
  if (running) {
    again = true;
    return running;
  }
  running = run().finally(() => {
    running = null;
    if (again) {
      again = false;
      schedule(0);
    }
  });
  return running;
}

// Synchronisation automatique : au démarrage, après chaque modification (regroupées), au retour sur l'onglet
let timer = null;
let lastRun = 0;
let onPulled = () => {};
const active = () => Boolean(loadAccount().vaultKey);

function schedule(delay) {
  clearTimeout(timer);
  timer = setTimeout(() => {
    timer = null;
    lastRun = Date.now();
    syncNow()
      .then(({ pulled }) => pulled && onPulled())
      .catch(() => {}); // erreur gardée dans l'état et affichée dans les réglages
  }, delay);
}

export function startAutoSync(callback) {
  onPulled = callback;
  window.addEventListener('streamhub:changed', () => active() && schedule(2000));
  window.addEventListener('streamhub:vault-open', () => schedule(0)); // compte ouvert : première synchro
  document.addEventListener('visibilitychange', () => {
    if (!active()) return;
    if (document.visibilityState === 'hidden' && timer) schedule(0); // on part : on envoie tout de suite
    else if (document.visibilityState === 'visible' && Date.now() - lastRun > 30000) schedule(0);
  });
  if (active()) schedule(0);
}
