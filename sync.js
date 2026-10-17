// Synchronisation entre navigateurs et appareils : réglages (clés API comprises), J'aime, historique,
// likes sur les plateformes. Tout est chiffré ici, avec le code de synchronisation, avant d'être envoyé
// au relais StreamHub (relay/worker.js, stockage Cloudflare KV) : le relais ne voit qu'un contenu illisible,
// rangé sous une empreinte du code. Sans le code, personne ne peut lire ni retrouver les données.
//
// Règle de fusion : ce qui a changé depuis la dernière synchronisation gagne. Si les deux côtés ont
// changé (deux appareils modifiés hors ligne), les listes sont réunies et les réglages de cet appareil gardés.
import {
  loadSettings, saveSettings, loadLibrary, saveLibrary, loadSyncMeta, saveSyncMeta, relayUrl, HISTORY_MAX,
} from './store.js';

// Propres à chaque appareil : jamais synchronisés
// desktopApps (avant : primeApp) : les applis sont installées sur un ordinateur, pas un autre ; glass : réglé selon
// l'appareil
const DEVICE_SETTINGS = ['desktopApps', 'primeApp', 'glass'];
const SYNCED_LIBRARY = ['likes', 'watchlist', 'history', 'platformLikes']; // téléchargements et questions : sur l'appareil

const ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // sans 0/O ni 1/I, faciles à confondre
const CODE_LENGTH = 20; // 100 bits : impossible à deviner
const enc = new TextEncoder();

export const normalizeCode = (code) => String(code).toUpperCase().replace(/[^A-Z0-9]/g, '');
const formatCode = (code) => code.match(/.{1,4}/g).join('-');
const validCode = (code) => code.length === CODE_LENGTH && [...code].every((c) => ALPHABET.includes(c));

function newCode() {
  const bytes = crypto.getRandomValues(new Uint8Array(CODE_LENGTH));
  return [...bytes].map((b) => ALPHABET[b % ALPHABET.length]).join(''); // 256 = 8 × 32 : tirage uniforme
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

const derived = new Map();
// Du code : l'identifiant de rangement (empreinte) et la clé AES-GCM (PBKDF2), indépendants l'un de l'autre
async function secrets(code) {
  if (!derived.has(code)) {
    derived.set(code, (async () => {
      const id = toHex(await crypto.subtle.digest('SHA-256', enc.encode(`streamhub-sync:id:${code}`)));
      const base = await crypto.subtle.importKey('raw', enc.encode(code), 'PBKDF2', false, ['deriveKey']);
      const key = await crypto.subtle.deriveKey(
        { name: 'PBKDF2', salt: enc.encode('streamhub-sync:key'), iterations: 200000, hash: 'SHA-256' },
        base, { name: 'AES-GCM', length: 256 }, false, ['encrypt', 'decrypt'],
      );
      return { id, key };
    })());
  }
  return derived.get(code);
}

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

function merge(local, remote, changed) {
  return {
    settings: changed.settings ? local.settings : remote.settings,
    library: changed.library
      ? {
          likes: unionByKey(local.library.likes, remote.library?.likes),
          watchlist: unionByKey(local.library.watchlist, remote.library?.watchlist),
          history: unionByKey(local.library.history, remote.library?.history, HISTORY_MAX),
          platformLikes: mergePlatformLikes(local.library.platformLikes, remote.library?.platformLikes),
        }
      : remote.library,
  };
}

// ---------- Échanges avec le relais ----------

async function endpoint(code) {
  const { id, key } = await secrets(code);
  return { url: `${relayUrl(loadSettings())}/sync/${id}`, key };
}

async function fetchRemote(url) {
  const res = await fetch(url, { cache: 'no-store' }).catch(() => null);
  if (!res) throw new Error('Relais injoignable (hors ligne ?).');
  if (res.status === 404) return null;
  if (!res.ok) throw new Error(`Relais : erreur ${res.status}.`);
  return res.json();
}

async function push(url, key, payload) {
  const res = await fetch(url, {
    method: 'PUT',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify(await encrypt(payload, key)),
  }).catch(() => null);
  if (!res?.ok) throw new Error(res ? `Relais : erreur ${res.status}.` : 'Relais injoignable (hors ligne ?).');
  return (await res.json()).updatedAt;
}

// Une synchronisation : récupère les changements des autres appareils, envoie ceux d'ici.
// Renvoie { pulled } : true si des données sont arrivées (l'appli doit se redessiner).
async function run() {
  const meta = loadSyncMeta();
  if (!meta.code) return { pulled: false };
  const { url, key } = await endpoint(meta.code);
  const local = localPayload();
  const now = await hashes(local);
  const changed = { settings: now.settings !== meta.hashes?.settings, library: now.library !== meta.hashes?.library };
  const localChanged = changed.settings || changed.library;

  const remote = await fetchRemote(url);
  let pulled = false;
  let toPush = null;
  if (remote && remote.updatedAt !== meta.syncedAt) {
    const theirs = await decrypt(remote, key);
    const next = localChanged ? merge(local, theirs, changed) : theirs;
    applyPayload(next);
    pulled = true;
    meta.syncedAt = remote.updatedAt;
    if (localChanged) toPush = next;
  } else if (!remote || localChanged) {
    toPush = local;
  }
  if (toPush) meta.syncedAt = await push(url, key, toPush);
  meta.hashes = await hashes(localPayload());
  meta.lastSyncAt = Date.now();
  meta.error = null;
  saveSyncMeta(meta);
  return { pulled };
}

let running = null;
let again = false;
// Une seule synchronisation à la fois ; une demande pendant qu'une tourne en relance une juste après
export function syncNow() {
  if (running) {
    again = true;
    return running;
  }
  running = run()
    .catch((err) => {
      const meta = loadSyncMeta();
      if (meta.code) saveSyncMeta({ ...meta, error: err.message || String(err) });
      throw err;
    })
    .finally(() => {
      running = null;
      notify();
      if (again) {
        again = false;
        schedule(0);
      }
    });
  return running;
}

// ---------- API pour l'appli ----------

export const syncState = () => {
  const { code, lastSyncAt, error } = loadSyncMeta();
  return { code: code ? formatCode(code) : '', lastSyncAt, error };
};
const notify = () => window.dispatchEvent(new CustomEvent('streamhub:sync', { detail: syncState() }));

// Nouveau code pour cet appareil : ses données deviennent la référence
export async function createCode() {
  const code = newCode();
  saveSyncMeta({ code });
  await syncNow();
  return formatCode(code);
}

// Code créé sur un autre appareil : on récupère ses données. Si cet appareil a déjà des J'aime ou un
// historique, ils sont ajoutés ; ses réglages sont remplacés (sauf s'il n'y en a pas de l'autre côté).
export async function joinCode(input) {
  const code = normalizeCode(input);
  if (!validCode(code)) throw new Error(`Code invalide : ${CODE_LENGTH} lettres et chiffres (ex. ABCD-EFGH-JKLM-NPQR-STUV).`);
  const { url } = await endpoint(code);
  if (!(await fetchRemote(url))) throw new Error('Aucune donnée pour ce code. Vérifie-le, ou crée un nouveau code.');
  const local = localPayload();
  const now = await hashes(local);
  const hasLibrary = SYNCED_LIBRARY.some((k) => Object.keys(local.library[k] ?? {}).length);
  // Empreintes « déjà synchronisées » = ce côté n'a rien à imposer : les données distantes s'appliquent
  saveSyncMeta({ code, hashes: { settings: now.settings, library: hasLibrary ? null : now.library } });
  return syncNow();
}

export function leave() {
  saveSyncMeta({});
  notify();
}

// Synchronisation automatique : au démarrage, après chaque modification (regroupées), au retour sur l'onglet
let timer = null;
let lastRun = 0;
let onPulled = () => {};

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
  window.addEventListener('streamhub:changed', () => loadSyncMeta().code && schedule(2000));
  document.addEventListener('visibilitychange', () => {
    if (!loadSyncMeta().code) return;
    if (document.visibilityState === 'hidden' && timer) schedule(0); // on part : on envoie tout de suite
    else if (document.visibilityState === 'visible' && Date.now() - lastRun > 30000) schedule(0);
  });
  if (loadSyncMeta().code) schedule(0);
}
