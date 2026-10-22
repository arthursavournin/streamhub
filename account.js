// Comptes StreamHub (version 2.0.0) : connexion Supabase (e-mail et mot de passe, Google, GitHub) et coffre chiffré.
//
// Chiffrement de bout en bout : une clé de coffre aléatoire (AES-GCM 256) chiffre les données synchronisées
// (sync.js). Supabase la garde deux fois, fermée à clé (table vaults) :
//   - password_lock : par une clé tirée du mot de passe (compte e-mail) ou du mot de passe du coffre (Google, GitHub)
//   - recovery_lock : par une clé tirée de la clé de secours (20 caractères tirés au hasard)
// Le vrai mot de passe ne quitte jamais l'appareil : il en sort deux secrets indépendants (PBKDF2 puis HKDF),
// un « mot de passe de connexion » envoyé à Supabase Auth et une clé qui ouvre le coffre, gardée ici.
//
// Appels HTTP directs (pas de bibliothèque : le site n'a pas d'étape de construction).
const SUPABASE_URL = 'https://bfcmqdvztmkpqwamwejp.supabase.co';
const SUPABASE_KEY = 'sb_publishable_RB_4r6Da9y2SLQPjavQXVA_w2Brn3LI'; // clé publique (faite pour être dans le code)
// Ce que l'adresse du site devient après la connexion Google / GitHub et les liens des e-mails (liste autorisée
// dans Supabase : Authentication → URL Configuration)
const SITE_URL = new URL('./', location.href).href;

// Tests en local (Supabase dans Docker) : serveur choisi dans localStorage, jamais sur le site en ligne
const LOCAL = ['localhost', '127.0.0.1'].includes(location.hostname);
const devServer = () => {
  try {
    return LOCAL ? JSON.parse(localStorage.getItem('streamhub:supabase-dev') || 'null') : null;
  } catch {
    return null;
  }
};
const server = () => devServer() ?? { url: SUPABASE_URL, key: SUPABASE_KEY };

export const PROVIDERS = { google: 'Google', github: 'GitHub' }; // Apple : demande l'Apple Developer Program payant

// Fournisseurs activés dans Supabase (Authentication → Sign In / Providers) : seuls leurs boutons s'affichent
let enabled = null;
export function enabledProviders() {
  enabled ??= call('/auth/v1/settings')
    .then((d) => Object.keys(PROVIDERS).filter((p) => d?.external?.[p]))
    .catch(() => {
      enabled = null; // hors ligne : on redemandera
      return [];
    });
  return enabled;
}

const KDF_ITERATIONS = 600000; // mot de passe (recommandation OWASP pour PBKDF2-SHA256)
const RECOVERY_ITERATIONS = 200000; // clé de secours : 100 bits au hasard, impossible à deviner
const ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // sans 0/O ni 1/I, faciles à confondre
const RECOVERY_LENGTH = 20;
const enc = new TextEncoder();

// ---------- Outils ----------

const toB64 = (bytes) => btoa(String.fromCharCode(...new Uint8Array(bytes)));
const fromB64 = (s) => Uint8Array.from(atob(s), (c) => c.charCodeAt(0));
const b64url = (bytes) => toB64(bytes).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
const normalizeEmail = (email) => String(email).trim().toLowerCase();
export const normalizeRecovery = (key) => String(key).toUpperCase().replace(/[^A-Z0-9]/g, '');
export const formatRecovery = (key) => key.match(/.{1,4}/g).join('-');

function newRecoveryKey() {
  const bytes = crypto.getRandomValues(new Uint8Array(RECOVERY_LENGTH));
  return [...bytes].map((b) => ALPHABET[b % ALPHABET.length]).join(''); // 256 = 8 × 32 : tirage uniforme
}

function checkRecovery(input) {
  const key = normalizeRecovery(input);
  if (key.length !== RECOVERY_LENGTH || ![...key].every((c) => ALPHABET.includes(c))) {
    throw new Error('Clé de secours invalide : 20 lettres et chiffres (ex. ABCD-EFGH-JKLM-NPQR-STUV).');
  }
  return key;
}

// Nouveau mot de passe (inscription, changement, oubli, mot de passe du coffre). Supabase ne reçoit qu'un secret qui en
// est tiré : ses propres règles (longueur, mots de passe divulgués) ne voient jamais le vrai. La vérification se fait
// donc ici, avant l'envoi (audit de sécurité, version 2.3.4 ; avant : 8 caractères, sans vérification des fuites).
export const MIN_PASSWORD = 12;
export async function checkPassword(password) {
  password = String(password);
  if (password.length < MIN_PASSWORD) throw new Error(`Mot de passe trop court : ${MIN_PASSWORD} caractères au moins.`);
  if (await leaked(password)) {
    throw new Error('Ce mot de passe figure dans des fuites de données connues : choisis-en un autre.');
  }
}

// Mots de passe divulgués (Have I Been Pwned, recherche par plage) : seuls les 5 premiers caractères de l'empreinte
// SHA-1 partent, jamais le mot de passe ; la réponse est complétée de fausses entrées (Add-Padding) pour ne rien
// laisser deviner. Service injoignable : on laisse passer (la longueur minimale reste vérifiée).
async function leaked(password) {
  try {
    const hash = [...new Uint8Array(await crypto.subtle.digest('SHA-1', enc.encode(password)))]
      .map((b) => b.toString(16).padStart(2, '0'))
      .join('')
      .toUpperCase();
    const res = await fetch(`https://api.pwnedpasswords.com/range/${hash.slice(0, 5)}`, { headers: { 'Add-Padding': 'true' }, cache: 'no-store' });
    if (!res.ok) return false;
    return (await res.text()).split('\n').some((line) => {
      const [suffix, count] = line.trim().split(':');
      return suffix === hash.slice(5) && Number(count) > 0;
    });
  } catch {
    return false;
  }
}

// ---------- Dérivation des clés ----------

// PBKDF2 (lent : 600 000 tours) puis HKDF : deux secrets indépendants tirés d'un même mot de passe
async function stretch(secret, salt, iterations) {
  const base = await crypto.subtle.importKey('raw', enc.encode(secret), 'PBKDF2', false, ['deriveBits']);
  const bits = await crypto.subtle.deriveBits({ name: 'PBKDF2', salt: enc.encode(salt), iterations, hash: 'SHA-256' }, base, 256);
  return crypto.subtle.importKey('raw', bits, 'HKDF', false, ['deriveBits']);
}

const expand = (master, info) =>
  crypto.subtle.deriveBits({ name: 'HKDF', hash: 'SHA-256', salt: new Uint8Array(32), info: enc.encode(info) }, master, 256);

// Clé AES non extractible (ou déjà importée : CryptoKey gardée dans IndexedDB)
const wrapKey = (raw) => (raw instanceof CryptoKey ? raw : crypto.subtle.importKey('raw', raw, 'AES-GCM', false, ['encrypt', 'decrypt']));

// Compte e-mail : sel = l'adresse (il faut pouvoir le calculer avant d'être connecté)
async function passwordSecrets(email, password) {
  const master = await stretch(password, `streamhub-account:${normalizeEmail(email)}`, KDF_ITERATIONS);
  return { login: b64url(await expand(master, 'streamhub:login')), unlock: await expand(master, 'streamhub:vault') };
}

// Mot de passe du coffre (Google, GitHub) : sel aléatoire gardé dans le coffre
async function vaultPasswordKey(password, salt) {
  return expand(await stretch(password, salt, KDF_ITERATIONS), 'streamhub:vault');
}

async function recoveryUnlock(key, salt) {
  return expand(await stretch(key, salt, RECOVERY_ITERATIONS), 'streamhub:recovery');
}

async function lock(vaultRaw, unlockRaw) {
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const data = await crypto.subtle.encrypt({ name: 'AES-GCM', iv }, await wrapKey(unlockRaw), vaultRaw);
  return { iv: toB64(iv), data: toB64(data) };
}

async function unlock(stored, unlockRaw) {
  try {
    return new Uint8Array(await crypto.subtle.decrypt({ name: 'AES-GCM', iv: fromB64(stored.iv) }, await wrapKey(unlockRaw), fromB64(stored.data)));
  } catch {
    return null; // mauvais mot de passe ou mauvaise clé
  }
}

const randomSalt = () => toB64(crypto.getRandomValues(new Uint8Array(16)));

// ---------- Clés gardées sur l'appareil ----------
// Clé du coffre et clé tirée du mot de passe pendant une inscription : CryptoKey non extractibles dans IndexedDB.
// StreamHub peut s'en servir, mais personne ne peut les copier, même un code injecté dans la page (audit de sécurité,
// version 2.3.4 ; avant : en base64 dans localStorage). IndexedDB indisponible : gardées en mémoire, le temps de la page.

const KEYS_DB = 'streamhub-keys';
const memoryKeys = new Map();

function keysStore(mode, action) {
  return new Promise((resolve, reject) => {
    const open = indexedDB.open(KEYS_DB, 1);
    open.onupgradeneeded = () => open.result.createObjectStore('keys');
    open.onerror = () => reject(open.error);
    open.onsuccess = () => {
      const db = open.result;
      const tx = db.transaction('keys', mode);
      const request = action(tx.objectStore('keys'));
      tx.oncomplete = () => (db.close(), resolve(request.result));
      tx.onerror = tx.onabort = () => (db.close(), reject(tx.error));
    };
  });
}

async function keepKey(name, key) {
  memoryKeys.set(name, key);
  await keysStore('readwrite', (store) => store.put(key, name)).catch(() => {});
}

async function readKey(name) {
  if (memoryKeys.has(name)) return memoryKeys.get(name);
  const key = await keysStore('readonly', (store) => store.get(name)).catch(() => undefined);
  if (key) memoryKeys.set(name, key);
  return key ?? null;
}

function dropKeys(...names) {
  for (const name of names) {
    memoryKeys.delete(name);
    keysStore('readwrite', (store) => store.delete(name)).catch(() => {});
  }
}

// ---------- État sur cet appareil ----------
// { email, userId, provider, via, session: { access, refresh, expiresAt }, vaultKey (true : clé dans IndexedDB ;
//   base64 avant la version 2.3.4, convertie au premier usage), syncedAt (version), hashes, lastSyncAt, error,
//   recoveryKey (à montrer une fois), pending: { email } (inscription à confirmer, clé tirée du mot de passe dans
//   IndexedDB ; avant 2.3.4 : pending.unlock en base64) }

const ACCOUNT_KEY = 'streamhub:account';
const FLOW_KEY = 'streamhub:auth-flow'; // connexion Google / GitHub en cours (vérificateur PKCE)
const RESET_KEY = 'streamhub:reset-asked'; // « mot de passe oublié » demandé ici : { email, at }
// Compte changé dans un autre onglet (déconnexion, autre compte) : les clés gardées en mémoire ici sont relues
window.addEventListener('storage', (e) => e.key === ACCOUNT_KEY && memoryKeys.clear());

export function loadAccount() {
  try {
    return JSON.parse(localStorage.getItem(ACCOUNT_KEY) || '{}');
  } catch {
    return {};
  }
}

export function saveAccount(account) {
  try {
    if (account.session || account.pending) localStorage.setItem(ACCOUNT_KEY, JSON.stringify(account));
    else localStorage.removeItem(ACCOUNT_KEY);
  } catch {
    /* stockage indisponible */
  }
  window.dispatchEvent(new CustomEvent('streamhub:account'));
}

const update = (changes) => saveAccount({ ...loadAccount(), ...changes });

// connecté : session ouverte ; open : coffre ouvert sur cet appareil (la synchro tourne)
export const accountState = () => {
  const a = loadAccount();
  return {
    email: a.email ?? '',
    provider: a.provider ?? 'email',
    signedIn: Boolean(a.session),
    open: Boolean(a.session && a.vaultKey),
    pending: a.pending?.email ?? '',
    recoveryKey: a.recoveryKey ? formatRecovery(a.recoveryKey) : '',
    needs: a.needs ?? null, // 'unlock' | 'create' | 'reset' : ce que l'utilisateur doit encore faire
    vaultMode: a.vaultMode ?? null, // 'login' (mot de passe du compte) | 'vault' (mot de passe du coffre)
    lastSyncAt: a.lastSyncAt,
    error: a.error,
  };
};

// ---------- Supabase : Auth ----------

class AuthError extends Error {
  constructor(message, code, status) {
    super(message);
    this.code = code;
    this.status = status;
  }
}

const MESSAGES = {
  invalid_credentials: 'E-mail ou mot de passe incorrect.',
  email_not_confirmed: 'Adresse pas encore confirmée : clique sur le lien de l’e-mail reçu.',
  user_already_exists: 'Un compte existe déjà avec cette adresse : connecte-toi.',
  email_exists: 'Un compte existe déjà avec cette adresse : connecte-toi.',
  over_email_send_rate_limit: 'Trop d’e-mails envoyés : réessaie dans quelques minutes.',
  over_request_rate_limit: 'Trop de tentatives : réessaie dans quelques minutes.',
  email_address_invalid: 'Adresse e-mail invalide.',
  validation_failed: 'Adresse e-mail invalide.',
  weak_password: 'Mot de passe trop faible.',
  same_password: 'Le nouveau mot de passe est identique à l’ancien.',
  refresh_token_not_found: 'Session expirée : reconnecte-toi.',
  refresh_token_already_used: 'Session expirée : reconnecte-toi.',
  session_not_found: 'Session fermée (mot de passe changé sur un autre appareil ?) : reconnecte-toi.',
  user_not_found: 'Compte introuvable (supprimé ?) : tu es déconnecté.',
  flow_state_not_found: 'Connexion expirée : recommence.',
  bad_code_verifier: 'Connexion expirée : recommence.',
};

const SESSION_GONE = ['session_not_found', 'user_not_found', 'bad_jwt'];

async function call(path, { method = 'GET', body, token, headers = {} } = {}) {
  const { url, key } = server();
  const res = await fetch(`${url}${path}`, {
    method,
    cache: 'no-store',
    headers: {
      apikey: key,
      ...(token ? { authorization: `Bearer ${token}` } : {}),
      ...(body !== undefined ? { 'content-type': 'application/json' } : {}),
      ...headers,
    },
    body: body !== undefined ? JSON.stringify(body) : undefined,
  }).catch(() => null);
  if (!res) throw new AuthError('Compte : serveur injoignable (hors ligne ?).', 'offline', 0);
  const text = await res.text();
  let data = null;
  try {
    data = text ? JSON.parse(text) : null;
  } catch {
    /* réponse vide ou pas en JSON */
  }
  if (!res.ok) {
    const code = data?.error_code ?? data?.code ?? data?.error ?? '';
    // Session fermée par le serveur (mot de passe changé sur un autre appareil, compte supprimé) : déconnecté ici,
    // les données restent sur l'appareil
    if (token && SESSION_GONE.includes(code)) forget();
    throw new AuthError(MESSAGES[code] ?? `Compte : erreur ${res.status}.`, code, res.status);
  }
  return data;
}

const authHeaders = { 'x-client-info': 'streamhub-web' };

function keepSession(data, extra = {}) {
  const user = data.user ?? {};
  update({
    email: user.email ?? loadAccount().email,
    userId: user.id,
    provider: user.app_metadata?.provider ?? 'email',
    session: {
      access: data.access_token,
      refresh: data.refresh_token,
      expiresAt: data.expires_at ? data.expires_at * 1000 : Date.now() + (data.expires_in ?? 3600) * 1000,
    },
    ...extra,
  });
}

let refreshing = null;
// Jeton d'accès valable (renouvelé une minute avant expiration) ; null si déconnecté
async function accessToken() {
  const { session } = loadAccount();
  if (!session) return null;
  if (Date.now() < session.expiresAt - 60000) return session.access;
  if (!refreshing) {
    refreshing = call('/auth/v1/token?grant_type=refresh_token', { method: 'POST', body: { refresh_token: session.refresh }, headers: authHeaders })
      .then((data) => {
        keepSession(data);
        return data.access_token;
      })
      .catch((err) => {
        // Session refusée par le serveur (pas une coupure réseau) : déconnecté, les données restent ici
        if (err.status >= 400 && err.status < 500 && err.status !== 429) forget();
        throw err;
      })
      .finally(() => (refreshing = null));
  }
  return refreshing;
}

function forget() {
  const { email } = loadAccount();
  saveAccount({});
  dropKeys('vault', 'pending');
  return email;
}

// ---------- Supabase : base (PostgREST) ----------

async function rest(path, options = {}) {
  const token = await accessToken();
  if (!token) throw new AuthError('Pas connecté.', 'signed_out', 401);
  return call(`/rest/v1/${path}`, { ...options, token });
}

const fetchVault = async () => (await rest('vaults?select=kdf,password_lock,recovery_lock'))?.[0] ?? null;

// ---------- Coffre ----------

// Clé du coffre (CryptoKey non extractible) ou null si le coffre est fermé sur cet appareil
export async function vaultKey() {
  const stored = loadAccount().vaultKey;
  if (!stored) return null;
  // Ancienne forme (base64 dans localStorage, avant 2.3.4) : rangée dans IndexedDB, puis effacée de localStorage
  if (typeof stored === 'string') {
    const key = await wrapKey(fromB64(stored));
    await keepKey('vault', key);
    update({ vaultKey: true });
    return key;
  }
  const key = await readKey('vault');
  // Données du site effacées (ou IndexedDB indisponible au rechargement) : il faut rouvrir le coffre
  if (!key) update({ vaultKey: null, needs: 'unlock' });
  return key;
}

// Ouvre le coffre avec le secret qui convient à son mode (mot de passe du compte ou du coffre)
async function openWith(vault, password) {
  const unlockRaw = vault.kdf.mode === 'vault'
    ? await vaultPasswordKey(password, vault.kdf.salt)
    : (await passwordSecrets(loadAccount().email, password)).unlock;
  return unlock(vault.password_lock, unlockRaw);
}

// joining : coffre d'un compte qui a peut-être déjà des données (sync.js applique alors ses réglages)
async function opened(raw, extra = {}) {
  await keepKey('vault', await wrapKey(raw));
  dropKeys('pending');
  update({ vaultKey: true, needs: null, error: null, joining: true, ...extra });
  window.dispatchEvent(new CustomEvent('streamhub:vault-open'));
}

// Crée le coffre, avec une nouvelle clé de secours (à montrer une seule fois)
async function createVault(mode, unlockRaw, salt) {
  const raw = crypto.getRandomValues(new Uint8Array(32));
  const recoveryKey = newRecoveryKey();
  const recoverySalt = randomSalt();
  await rest('vaults', {
    method: 'POST',
    headers: { prefer: 'return=minimal' },
    body: {
      user_id: loadAccount().userId,
      kdf: { v: 1, mode, iterations: KDF_ITERATIONS, ...(salt ? { salt } : {}) },
      password_lock: await lock(raw, unlockRaw),
      recovery_lock: { salt: recoverySalt, ...(await lock(raw, await recoveryUnlock(recoveryKey, recoverySalt))) },
    },
  });
  await opened(raw, { recoveryKey, syncedAt: null, hashes: null, vaultMode: mode, joining: false });
}

// Après la connexion : ouvrir le coffre si on a de quoi, sinon dire ce qui manque
async function afterSignIn({ unlockRaw = null } = {}) {
  const vault = await fetchVault();
  if (!vault) {
    // Premier passage : compte e-mail (mot de passe connu) → coffre créé tout de suite ; sinon on demande
    if (unlockRaw) return createVault('login', unlockRaw);
    // Session ouverte par Google / GitHub : pas de mot de passe StreamHub, on en choisit un pour le coffre
    return update({ needs: 'create', vaultMode: loadAccount().via === 'oauth' ? 'vault' : 'login' });
  }
  update({ vaultMode: vault.kdf.mode });
  if (unlockRaw && vault.kdf.mode === 'login') {
    const raw = await unlock(vault.password_lock, unlockRaw);
    if (raw) return opened(raw);
  }
  update({ needs: 'unlock' });
}

// ---------- Actions ----------

// Inscription par e-mail. Avec la confirmation d'adresse (réglage Supabase), pas de session tout de suite :
// la clé tirée du mot de passe attend ici le retour du lien, pour créer le coffre sans redemander le mot de passe.
export async function signUp(email, password) {
  await checkPassword(password);
  email = normalizeEmail(email);
  const secrets = await passwordSecrets(email, password);
  const data = await call(`/auth/v1/signup?redirect_to=${encodeURIComponent(SITE_URL)}`, {
    method: 'POST',
    body: { email, password: secrets.login },
    headers: authHeaders,
  });
  if (data?.access_token) {
    keepSession(data, { via: 'password' });
    await afterSignIn({ unlockRaw: secrets.unlock });
    return 'open';
  }
  // Adresse déjà inscrite et confirmée : Supabase répond comme si de rien n'était (pour ne pas révéler les comptes),
  // sans identité ; le lien n'est pas envoyé
  if (data && Array.isArray(data.identities) && !data.identities.length) throw new AuthError(MESSAGES.user_already_exists, 'user_already_exists', 400);
  await keepKey('pending', await wrapKey(secrets.unlock));
  saveAccount({ email, pending: { email } });
  return 'confirm';
}

export async function resendConfirmation() {
  const { pending } = loadAccount();
  if (!pending) return;
  await call(`/auth/v1/resend?redirect_to=${encodeURIComponent(SITE_URL)}`, { method: 'POST', body: { type: 'signup', email: pending.email }, headers: authHeaders });
}

export function cancelPending() {
  if (loadAccount().session) return;
  saveAccount({});
  dropKeys('pending');
}

export async function signIn(email, password) {
  email = normalizeEmail(email);
  const secrets = await passwordSecrets(email, password);
  const data = await call('/auth/v1/token?grant_type=password', { method: 'POST', body: { email, password: secrets.login }, headers: authHeaders });
  keepSession(data, { via: 'password', pending: null });
  await afterSignIn({ unlockRaw: secrets.unlock });
}

// Google, GitHub : départ vers le fournisseur (PKCE : le code reçu au retour ne sert qu'avec le vérificateur gardé ici)
export async function signInWith(provider) {
  const verifier = b64url(crypto.getRandomValues(new Uint8Array(32)));
  const challenge = b64url(await crypto.subtle.digest('SHA-256', enc.encode(verifier)));
  try {
    localStorage.setItem(FLOW_KEY, JSON.stringify({ verifier, provider, at: Date.now() }));
  } catch {
    throw new Error('Connexion impossible : le stockage du navigateur est bloqué.');
  }
  const params = new URLSearchParams({ provider, redirect_to: SITE_URL, code_challenge: challenge, code_challenge_method: 's256' });
  location.assign(`${server().url}/auth/v1/authorize?${params}`);
}

// Ouvre le coffre (nouvel appareil, ou session venue d'un lien / de Google) avec le mot de passe
export async function unlockVault(password) {
  const vault = await fetchVault();
  if (!vault) return update({ needs: 'create' });
  const raw = await openWith(vault, password);
  if (!raw) throw new Error(vault.kdf.mode === 'vault' ? 'Mot de passe du coffre incorrect.' : 'Mot de passe incorrect.');
  await opened(raw);
}

// Premier coffre d'un compte Google / GitHub (mot de passe du coffre choisi), ou d'un compte e-mail confirmé
// sur un autre appareil (mot de passe du compte, vérifié auprès de Supabase)
export async function createVaultWith(password) {
  const a = loadAccount();
  if (a.vaultMode === 'login') {
    const secrets = await passwordSecrets(a.email, password);
    await call('/auth/v1/token?grant_type=password', { method: 'POST', body: { email: a.email, password: secrets.login }, headers: authHeaders })
      .then((data) => keepSession(data))
      .catch((err) => {
        throw err.code === 'invalid_credentials' ? new Error('Mot de passe incorrect.') : err;
      });
    return afterSignIn({ unlockRaw: secrets.unlock });
  }
  await checkPassword(password);
  const salt = randomSalt();
  return createVault('vault', await vaultPasswordKey(password, salt), salt);
}

export async function requestReset(email) {
  // Lien classique (pas PKCE) : il marche aussi ouvert sur un autre appareil que celui de la demande. Demande notée
  // ici : le lien ouvert sur cet appareil n'aura pas besoin d'être confirmé (voir linkOffer)
  try {
    localStorage.setItem(RESET_KEY, JSON.stringify({ email: normalizeEmail(email), at: Date.now() }));
  } catch {
    /* stockage indisponible : le lien demandera une confirmation */
  }
  await call(`/auth/v1/recover?redirect_to=${encodeURIComponent(SITE_URL)}`, { method: 'POST', body: { email: normalizeEmail(email) }, headers: authHeaders });
}

// Mot de passe oublié (après le lien de l'e-mail) ou mot de passe du coffre oublié : la clé de secours rouvre le
// coffre, que le nouveau mot de passe referme
export async function resetWithRecovery(recoveryInput, newPassword) {
  const recoveryKey = checkRecovery(recoveryInput);
  await checkPassword(newPassword);
  const vault = await fetchVault();
  if (!vault) throw new Error('Aucun coffre pour ce compte.');
  const raw = await unlock(vault.recovery_lock, await recoveryUnlock(recoveryKey, vault.recovery_lock.salt));
  if (!raw) throw new Error('Clé de secours incorrecte.');
  await setPassword(vault, raw, newPassword);
  await opened(raw);
}

// Changer de mot de passe : l'ancien est vérifié en rouvrant le coffre
export async function changePassword(current, next) {
  await checkPassword(next);
  const vault = await fetchVault();
  const raw = vault && (await openWith(vault, current));
  if (!raw) throw new Error('Mot de passe actuel incorrect.');
  await setPassword(vault, raw, next);
}

// Mode « login » : le mot de passe de connexion change aussi chez Supabase (d'abord : si la suite échoue, le
// nouveau mot de passe permet de recommencer avec la clé de secours)
async function setPassword(vault, raw, password) {
  if (vault.kdf.mode === 'vault') {
    const salt = randomSalt();
    await patchVault({ kdf: { ...vault.kdf, salt }, password_lock: await lock(raw, await vaultPasswordKey(password, salt)) });
    return;
  }
  const secrets = await passwordSecrets(loadAccount().email, password);
  await call('/auth/v1/user', { method: 'PUT', token: await accessToken(), body: { password: secrets.login }, headers: authHeaders });
  await patchVault({ kdf: { ...vault.kdf, iterations: KDF_ITERATIONS }, password_lock: await lock(raw, secrets.unlock) });
}

const patchVault = (body) => rest(`vaults?user_id=eq.${loadAccount().userId}`, { method: 'PATCH', headers: { prefer: 'return=minimal' }, body });

// Nouvelle clé de secours (l'ancienne ne marche plus). La clé du coffre gardée sur l'appareil ne peut pas être
// recopiée (non extractible) : le mot de passe rouvre le coffre (et confirme que c'est bien toi)
export async function newRecovery(password) {
  const vault = await fetchVault();
  const raw = vault && (await openWith(vault, password));
  if (!raw) throw new Error(vault?.kdf.mode === 'vault' ? 'Mot de passe du coffre incorrect.' : 'Mot de passe incorrect.');
  const recoveryKey = newRecoveryKey();
  const salt = randomSalt();
  await patchVault({ recovery_lock: { salt, ...(await lock(raw, await recoveryUnlock(recoveryKey, salt))) } });
  update({ recoveryKey });
  return formatRecovery(recoveryKey);
}

export const recoveryNoted = () => update({ recoveryKey: null });

// Déconnexion : les données restent sur cet appareil, elles ne suivent simplement plus
export async function signOut() {
  const token = loadAccount().session?.access;
  forget();
  if (token) await call('/auth/v1/logout?scope=local', { method: 'POST', token, headers: authHeaders }).catch(() => {});
}

// Le mot de passe (ou mot de passe du coffre) est redemandé : un jeton de session volé ne suffit pas à tout effacer
// depuis StreamHub (audit de sécurité, F2)
export async function deleteAccount(password) {
  const vault = await fetchVault();
  if (vault && !(await openWith(vault, password))) {
    throw new Error(vault.kdf.mode === 'vault' ? 'Mot de passe du coffre incorrect.' : 'Mot de passe incorrect.');
  }
  await rest('rpc/delete_my_account', { method: 'POST', body: {} });
  await signOut();
}

// ---------- Retour sur le site (Google / GitHub, liens des e-mails) ----------

// Lien d'e-mail ouvert sans inscription ni « mot de passe oublié » en cours sur cet appareil : la session n'est gardée
// qu'après confirmation (l'adresse du compte est affichée). Sans ça, un lien piégé (jetons du compte de quelqu'un
// d'autre) connecterait StreamHub à ce compte sans que tu le voies (audit de sécurité, F8).
let offer = null; // { data, type, email }
export const linkOffer = () => (offer ? { email: offer.email, type: offer.type } : null);

async function useLink(data, type, unlockRaw) {
  keepSession(data, { via: 'link', pending: null, vaultKey: null, needs: null });
  dropKeys('vault');
  if (type === 'recovery') {
    update({ needs: 'reset' });
    return { kind: 'recovery' };
  }
  await afterSignIn({ unlockRaw });
  return { kind: 'confirmed' };
}

export async function acceptLink() {
  const o = offer;
  offer = null;
  if (o) return useLink(o.data, o.type, null);
}

export async function declineLink() {
  const o = offer;
  offer = null;
  // La session reçue est fermée tout de suite chez Supabase
  if (o) await call('/auth/v1/logout?scope=local', { method: 'POST', token: o.data.access_token, headers: authHeaders }).catch(() => {});
}

// À appeler au démarrage. Renvoie ce qui s'est passé ({ kind, message }) ou null, et nettoie l'adresse.
export async function handleAuthRedirect() {
  const query = new URLSearchParams(location.search);
  const hash = new URLSearchParams(location.hash.slice(1));
  const error = query.get('error_description') || hash.get('error_description');
  const code = query.get('code');
  const token = hash.get('access_token');
  if (!error && !code && !token) return null;
  const clean = new URL(location.href);
  for (const k of ['code', 'error', 'error_code', 'error_description', 'state']) clean.searchParams.delete(k);
  clean.hash = '';
  history.replaceState(null, '', clean.href);

  if (error) {
    const expired = /expired|invalid/i.test(query.get('error_code') || hash.get('error_code') || '');
    return { kind: 'error', message: expired ? 'Lien expiré ou déjà utilisé : recommence.' : `Connexion refusée : ${error}` };
  }
  try {
    if (code) {
      let flow = null;
      try {
        flow = JSON.parse(localStorage.getItem(FLOW_KEY) || 'null');
        localStorage.removeItem(FLOW_KEY);
      } catch {
        /* stockage indisponible */
      }
      if (!flow) return { kind: 'error', message: 'Connexion commencée dans un autre navigateur : recommence ici.' };
      const data = await call('/auth/v1/token?grant_type=pkce', { method: 'POST', body: { auth_code: code, code_verifier: flow.verifier }, headers: authHeaders });
      keepSession(data, { via: 'oauth', provider: flow.provider, pending: null, vaultKey: null, needs: null });
      await afterSignIn();
      return { kind: 'oauth', provider: flow.provider };
    }
    // Lien d'un e-mail (confirmation de l'adresse, mot de passe oublié) : jetons dans le fragment
    const type = hash.get('type');
    const data = {
      access_token: token,
      refresh_token: hash.get('refresh_token'),
      expires_at: Number(hash.get('expires_at')) || undefined,
      expires_in: Number(hash.get('expires_in')) || undefined,
    };
    data.user = await call('/auth/v1/user', { token, headers: authHeaders });
    const email = normalizeEmail(data.user.email);
    const { pending } = loadAccount();
    let reset = null;
    try {
      reset = JSON.parse(localStorage.getItem(RESET_KEY) || 'null');
      localStorage.removeItem(RESET_KEY);
    } catch {
      /* stockage indisponible */
    }
    // Lien demandé sur cet appareil : inscription en cours, ou « mot de passe oublié » (moins de 24 h)
    const sameDevice = pending && pending.email === email;
    const asked = type === 'recovery' ? reset?.email === email && Date.now() - reset.at < 24 * 3600 * 1000 : sameDevice;
    if (!asked) {
      offer = { data, type, email };
      return { kind: 'link-confirm', email };
    }
    // Confirmation sur l'appareil de l'inscription : la clé tirée du mot de passe est encore là
    // (avant 2.3.4 : pending.unlock en base64 ; depuis : CryptoKey dans IndexedDB)
    const pendingKey = sameDevice ? (pending.unlock ? fromB64(pending.unlock) : await readKey('pending')) : null;
    dropKeys('pending');
    return useLink(data, type, pendingKey);
  } catch (err) {
    return { kind: 'error', message: err.message };
  }
}

// ---------- Transport pour sync.js ----------

export class Conflict extends Error {}

// Données chiffrées du compte : { stamp (version), iv, data } ou null
export async function fetchData() {
  return (await rest('sync_data?select=iv,data,version'))?.[0] ?? null;
}

// Écrit seulement si la version lue est encore la dernière (sinon Conflict : relire, fusionner, renvoyer)
export async function pushData(encrypted, version) {
  if (version == null) {
    try {
      await rest('sync_data', { method: 'POST', headers: { prefer: 'return=minimal' }, body: { user_id: loadAccount().userId, ...encrypted, version: 1 } });
      return 1;
    } catch (err) {
      if (err.status === 409) throw new Conflict(); // un autre appareil a écrit le premier
      throw err;
    }
  }
  const rows = await rest(`sync_data?user_id=eq.${loadAccount().userId}&version=eq.${version}`, {
    method: 'PATCH',
    headers: { prefer: 'return=representation' },
    body: { ...encrypted, version: version + 1 },
  });
  if (!rows?.length) throw new Conflict();
  return version + 1;
}

// Petite vérification que le serveur répond (sans compte)
export async function ping() {
  return call('/rest/v1/rpc/keepalive', { method: 'POST', body: {} });
}
