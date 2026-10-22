// Réglages → Compte : connexion et création de compte (e-mail, Google, GitHub), invité, coffre à ouvrir, clé de
// secours, mot de passe, déconnexion, suppression. L'état vient d'account.js ; ici, seulement l'affichage et les
// boutons. Même dessin que l'appli iPhone (Views/AccountView.swift) : carte de connexion, carte de profil, actions en
// liste.
import {
  accountState, signUp, signIn, signInWith, resendConfirmation, cancelPending, unlockVault, createVaultWith,
  requestReset, resetWithRecovery, changePassword, newRecovery, recoveryNoted, signOut, deleteAccount, PROVIDERS,
  enabledProviders, MIN_PASSWORD,
} from './account.js';

const esc = (s) => String(s).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]);
const PROVIDER_NAMES = { email: 'e-mail', ...PROVIDERS };

let box;
let status;
// Ce qui est affiché : signin, signup, forgot (invité) ; unlock, recover (coffre fermé) ; open, password, recovery,
// delete
let ui = { mode: 'signin' };
let hooks = {};
let rememberedEmail = '';

// ---------- Logos (Google : logo officiel en couleurs ; GitHub : Octocat) ----------

const GOOGLE_LOGO = `<svg viewBox="0 0 48 48" aria-hidden="true"><path fill="#EA4335" d="M24 9.5c3.54 0 6.71 1.22 9.21 3.6l6.85-6.85C35.9 2.38 30.47 0 24 0 14.62 0 6.51 5.38 2.56 13.22l7.98 6.19C12.43 13.72 17.74 9.5 24 9.5z"/><path fill="#4285F4" d="M46.98 24.55c0-1.57-.15-3.09-.38-4.55H24v9.02h12.94c-.58 2.96-2.26 5.48-4.78 7.18l7.73 6c4.51-4.18 7.09-10.36 7.09-17.65z"/><path fill="#FBBC05" d="M10.53 28.59c-.48-1.45-.76-2.99-.76-4.59s.27-3.14.76-4.59l-7.98-6.19C.92 16.46 0 20.12 0 24c0 3.88.92 7.54 2.56 10.78l7.97-6.19z"/><path fill="#34A853" d="M24 48c6.48 0 11.93-2.13 15.89-5.81l-7.73-6c-2.15 1.45-4.92 2.3-8.16 2.3-6.26 0-11.57-4.22-13.47-9.91l-7.98 6.19C6.51 42.62 14.62 48 24 48z"/></svg>`;
const GITHUB_LOGO = `<svg viewBox="0 0 16 16" aria-hidden="true"><path fill="currentColor" d="M8 0C3.58 0 0 3.58 0 8c0 3.54 2.29 6.53 5.47 7.59.4.07.55-.17.55-.38 0-.19-.01-.82-.01-1.49-2.01.37-2.53-.49-2.69-.94-.09-.23-.48-.94-.82-1.13-.28-.15-.68-.52-.01-.53.63-.01 1.08.58 1.23.82.72 1.21 1.87.87 2.33.66.07-.52.28-.87.51-1.07-1.78-.2-3.64-.89-3.64-3.95 0-.87.31-1.59.82-2.15-.08-.2-.36-1.02.08-2.12 0 0 .67-.21 2.2.82.64-.18 1.32-.27 2-.27.68 0 1.36.09 2 .27 1.53-1.04 2.2-.82 2.2-.82.44 1.1.16 1.92.08 2.12.51.56.82 1.27.82 2.15 0 3.07-1.87 3.75-3.65 3.95.29.25.54.73.54 1.48 0 1.07-.01 1.93-.01 2.2 0 .21.15.46.55.38A8.013 8.013 0 0016 8c0-4.42-3.58-8-8-8z"/></svg>`;
const LOGOS = { google: GOOGLE_LOGO, github: GITHUB_LOGO };

// Icônes des actions (même trait que les icônes des sections)
const ICONS = {
  sync: '<path d="M20 12a8 8 0 0 1-14.3 4.9M4 12a8 8 0 0 1 14.3-4.9"/><path d="M18.5 3v4.2h-4.2M5.5 21v-4.2h4.2"/>',
  key: '<circle cx="8" cy="15" r="4"/><path d="m11 12 9-9M17 6l3 3M14.5 8.5l2 2"/>',
  shield: '<path d="M12 3 5 6v5c0 4.5 3 8.4 7 10 4-1.6 7-5.5 7-10V6Z"/><path d="m9 12 2 2 4-4"/>',
  out: '<path d="M14 4h4a2 2 0 0 1 2 2v12a2 2 0 0 1-2 2h-4M10 16l-4-4 4-4M6 12h10"/>',
  trash: '<path d="M4 7h16M10 11v6M14 11v6M6 7l1 12a2 2 0 0 0 2 2h6a2 2 0 0 0 2-2l1-12M9 7V4h6v3"/>',
  mail: '<rect x="3" y="5" width="18" height="14" rx="2"/><path d="m3 7 9 6 9-6"/>',
  lock: '<rect x="5" y="11" width="14" height="10" rx="2"/><path d="M8 11V7a4 4 0 0 1 8 0v4"/>',
};
const icon = (name) => `<svg class="action-icon" viewBox="0 0 24 24" aria-hidden="true">${ICONS[name]}</svg>`;

// ---------- Morceaux ----------

const field = (id, label, type = 'password', extra = '', aside = '') => `<div class="auth-field">
    <div class="auth-label"><label for="${id}">${label}</label>${aside}</div>
    <input id="${id}" type="${type}" ${extra}>
  </div>`;
const emailField = () => field('accEmail', 'Adresse e-mail', 'email', `autocomplete="username" spellcheck="false" placeholder="toi@exemple.fr" value="${esc(rememberedEmail)}"`);
const newPasswordFields = (label = 'Mot de passe') =>
  field('accPassword', label, 'password', `autocomplete="new-password" placeholder="${MIN_PASSWORD} caractères au moins"`) +
  field('accPassword2', 'Confirme le mot de passe', 'password', 'autocomplete="new-password"');
const submit = (action, text, kind = 'primary') => `<button type="button" class="btn ${kind} auth-submit" data-acc="${action}">${text}</button>`;
const link = (action, text) => `<button type="button" class="link-btn" data-acc="${action}">${text}</button>`;
const row = (action, iconName, text, { danger = false, chevron = false } = {}) =>
  `<li><button type="button" class="action-row${danger ? ' danger' : ''}" data-acc="${action}">${icon(iconName)}<span>${text}</span>${chevron ? '<span class="chevron" aria-hidden="true">›</span>' : ''}</button></li>`;

// Information au moment de la collecte (recommandation de la CNIL) : liens vers les conditions et la confidentialité
const LEGAL = `<p class="auth-legal">En créant un compte ou en te connectant, tu acceptes les
  <a href="conditions.html" target="_blank" rel="noopener">conditions d’utilisation</a> et la
  <a href="confidentialite.html" target="_blank" rel="noopener">politique de confidentialité</a>.</p>`;

// Boutons Google / GitHub, ajoutés quand Supabase a dit quels fournisseurs sont activés (rien s'il n'y en a aucun)
const providerSlot = () => '<div id="accProviders" class="auth-providers"></div>';
async function fillProviders() {
  const list = await enabledProviders();
  const slot = box.querySelector('#accProviders');
  if (!slot || !list.length) return;
  slot.innerHTML = `<div class="auth-divider"><span>ou</span></div>
    ${list.map((id) => `<button type="button" class="social-btn ${id}" data-provider="${id}">${LOGOS[id]}<span>Continuer avec ${PROVIDERS[id]}</span></button>`).join('')}`;
}

// Carte de profil : initiale (et logo du fournisseur), adresse, façon de se connecter
function profile(s, sync = '') {
  const via = s.provider === 'email' ? 'Compte e-mail' : `Connecté avec ${esc(PROVIDER_NAMES[s.provider] ?? s.provider)}`;
  const badge = LOGOS[s.provider] ? `<span class="avatar-badge ${s.provider}">${LOGOS[s.provider]}</span>` : '';
  return `<div class="profile-card">
    <div class="avatar">${esc((s.email[0] ?? '?').toUpperCase())}${badge}</div>
    <div class="profile-text"><strong>${esc(s.email)}</strong><span>${via}</span>${sync}</div>
  </div>`;
}

function recoveryPanel(key) {
  return `<div class="recovery-panel">
    <div class="recovery-head">${icon('shield')}<strong>Ta clé de secours</strong></div>
    <p>Note-la dans ton gestionnaire de mots de passe. Si tu oublies ton mot de passe, elle seule permet de retrouver
      tes données : personne, pas même StreamHub, ne peut les rouvrir sans elle.</p>
    <div class="key-row">
      <input id="accRecoveryShown" readonly value="${esc(key)}" aria-label="Ta clé de secours">
      <button type="button" class="btn" data-copy="#accRecoveryShown">Copier</button>
    </div>
    ${submit('noted', 'Je l’ai notée')}
  </div>`;
}

// ---------- États ----------

function render() {
  const s = accountState();
  setStatus('', '');
  if (s.open) return renderOpen(s);
  if (s.signedIn) return renderSignedIn(s);
  if (s.pending) {
    box.innerHTML = `<div class="auth-card">
      <div class="auth-icon">${icon('mail')}</div>
      <h3 class="auth-title">Vérifie ta boîte mail</h3>
      <p class="auth-text">Ouvre le lien envoyé à <strong>${esc(s.pending)}</strong> (regarde aussi dans les indésirables).
        Tu reviendras ici, connecté.</p>
      ${submit('resend', 'Renvoyer l’e-mail', '')}
      <p class="auth-switch">${link('cancel', 'Utiliser une autre adresse')}</p>
    </div>`;
    return;
  }
  renderGuest();
}

function renderGuest() {
  const onboarding = hooks.isOnboarding?.();
  const hero = onboarding
    ? `<div class="auth-hero"><img src="icon.svg?v=3" alt="" width="72" height="72">
        <h2>Bienvenue sur StreamHub</h2>
        <p>Tous tes films et séries, toutes tes plateformes, au même endroit.</p></div>`
    : `<p class="auth-note">Tu es en invité : tes données restent sur cet appareil. Connecte-toi pour les retrouver
        partout, chiffrées de bout en bout.</p>`;
  if (ui.mode === 'forgot') {
    box.innerHTML = `${hero}<div class="auth-card">
      <h3 class="auth-title">Mot de passe oublié</h3>
      <p class="auth-text">Tu recevras un lien pour choisir un nouveau mot de passe ; il faudra aussi ta clé de secours.</p>
      ${emailField()}
      ${submit('sendReset', 'Envoyer le lien')}
      <p class="auth-switch">${link('signinMode', '← Retour à la connexion')}</p>
    </div>`;
    return;
  }
  const signup = ui.mode === 'signup';
  box.innerHTML = `${hero}<div class="auth-card">
    <h3 class="auth-title">${signup ? 'Créer un compte' : 'Se connecter'}</h3>
    <p class="auth-text">${signup ? 'Tes réglages et tes listes, sur tous tes appareils.' : 'Retrouve tes réglages et tes listes.'}</p>
    ${emailField()}
    ${signup ? newPasswordFields() : field('accPassword', 'Mot de passe', 'password', 'autocomplete="current-password"', link('forgotMode', 'Oublié ?'))}
    ${submit(signup ? 'signup' : 'signin', signup ? 'Créer mon compte' : 'Se connecter')}
    ${providerSlot()}
    <p class="auth-switch">${signup ? `Déjà un compte ? ${link('signinMode', 'Se connecter')}` : `Pas encore de compte ? ${link('signupMode', 'Créer un compte')}`}</p>
    ${onboarding ? `<div class="auth-guest"><button type="button" class="btn ghost" data-acc="guest">Continuer sans compte</button>
      <small>Tes données resteront sur cet appareil. Tu pourras créer un compte plus tard dans les réglages.</small></div>` : ''}
    ${LEGAL}
  </div>`;
  fillProviders();
}

// Connecté mais coffre fermé sur cet appareil : mot de passe à entrer, coffre à créer, ou mot de passe à refaire
function renderSignedIn(s) {
  const vaultWord = s.vaultMode === 'vault' ? 'mot de passe du coffre' : 'mot de passe';
  let body;
  if (s.needs === 'reset' || ui.mode === 'recover') {
    body = `<h3 class="auth-title">Nouveau ${vaultWord}</h3>
      <p class="auth-text">Ta clé de secours rouvre tes données ; le nouveau ${vaultWord} les referme.</p>
      ${field('accRecovery', 'Clé de secours', 'text', 'autocomplete="off" autocapitalize="characters" spellcheck="false" placeholder="ABCD-EFGH-JKLM-NPQR-STUV"')}
      ${newPasswordFields(`Nouveau ${vaultWord}`)}
      ${submit('reset', 'Enregistrer')}
      ${s.needs === 'reset' ? '' : `<p class="auth-switch">${link('unlockMode', '← Retour')}</p>`}`;
  } else if (s.needs === 'create' && s.vaultMode === 'vault') {
    body = `<h3 class="auth-title">Choisis un mot de passe du coffre</h3>
      <p class="auth-text">Il chiffre tes données sur l’appareil, avant l’envoi. Tu le taperas une fois sur chaque nouvel
        appareil. Il ne sert qu’à StreamHub (rien à voir avec ${esc(PROVIDER_NAMES[s.provider] ?? s.provider)}).</p>
      ${newPasswordFields('Mot de passe du coffre')}
      ${submit('create', 'Créer mon coffre')}`;
  } else if (s.needs === 'create') {
    body = `<h3 class="auth-title">Adresse confirmée</h3>
      <p class="auth-text">Entre ton mot de passe pour terminer la création du compte.</p>
      ${field('accPassword', 'Mot de passe', 'password', 'autocomplete="current-password"')}
      ${submit('create', 'Continuer')}`;
  } else {
    body = `<div class="auth-icon">${icon('lock')}</div>
      <h3 class="auth-title">Ouvre tes données</h3>
      <p class="auth-text">Entre ton ${vaultWord} pour ouvrir tes données sur cet appareil.</p>
      ${field('accPassword', s.vaultMode === 'vault' ? 'Mot de passe du coffre' : 'Mot de passe', 'password', 'autocomplete="current-password"', link('recoverMode', 'Oublié ?'))}
      ${submit('unlock', 'Ouvrir')}`;
  }
  box.innerHTML = `${profile(s)}<div class="auth-card">${body}</div>
    <ul class="action-list">${row('signout', 'out', 'Se déconnecter')}</ul>`;
}

function renderOpen(s) {
  const vaultWord = s.vaultMode === 'vault' ? 'mot de passe du coffre' : 'mot de passe';
  let main;
  if (ui.mode === 'password') {
    main = `<div class="auth-card">
      <h3 class="auth-title">Changer de ${vaultWord}</h3>
      ${field('accCurrent', `${vaultWord[0].toUpperCase()}${vaultWord.slice(1)} actuel`, 'password', 'autocomplete="current-password"')}
      ${newPasswordFields(`Nouveau ${vaultWord}`)}
      ${submit('changePassword', 'Enregistrer')}
      <p class="auth-text small">Tes autres appareils seront déconnectés : reconnecte-les avec le nouveau mot de passe (leurs données restent).</p>
      <p class="auth-switch">${link('openMode', 'Annuler')}</p>
    </div>`;
  } else if (ui.mode === 'recovery') {
    // La clé du coffre de l'appareil ne peut pas être recopiée : le mot de passe rouvre le coffre (version 2.3.4)
    main = `<div class="auth-card">
      <h3 class="auth-title">Nouvelle clé de secours</h3>
      <p class="auth-text">L’ancienne clé ne marchera plus. Entre ton ${vaultWord} pour continuer.</p>
      ${field('accCurrent', `${vaultWord[0].toUpperCase()}${vaultWord.slice(1)}`, 'password', 'autocomplete="current-password"')}
      ${submit('newRecovery', 'Créer la clé')}
      <p class="auth-switch">${link('openMode', 'Annuler')}</p>
    </div>`;
  } else if (ui.mode === 'delete') {
    main = `<div class="auth-card danger-card">
      <h3 class="auth-title">Supprimer ton compte ?</h3>
      <p class="auth-text">Ton compte, ton coffre et tes données synchronisées seront effacés. Tes données restent sur cet
        appareil (en invité). Impossible d’annuler.</p>
      ${submit('delete', 'Supprimer définitivement', 'danger')}
      <p class="auth-switch">${link('openMode', 'Annuler')}</p>
    </div>`;
  } else {
    main = `<ul class="action-list">
        ${row('syncNow', 'sync', 'Synchroniser maintenant')}
        ${row('passwordMode', 'key', `Changer de ${vaultWord}`, { chevron: true })}
        ${row('recoveryMode', 'shield', 'Nouvelle clé de secours', { chevron: true })}
        ${row('signout', 'out', 'Se déconnecter')}
      </ul>
      <ul class="action-list">${row('deleteMode', 'trash', 'Supprimer mon compte', { danger: true, chevron: true })}</ul>`;
  }
  // État de la synchronisation dans la carte de profil
  const sync = s.error
    ? `<em class="sync-state bad">Synchronisation impossible : ${esc(s.error)}</em>`
    : `<em class="sync-state ok">${s.lastSyncAt ? `Synchronisé ${hooks.syncedWhen(s.lastSyncAt)}` : 'Synchronisation…'}</em>`;
  box.innerHTML = `${profile(s, sync)}${s.recoveryKey ? recoveryPanel(s.recoveryKey) : ''}${main}`;
}

function setStatus(kind, message) {
  status.className = `key-status account-status ${kind}`;
  status.textContent = message;
}

const value = (id) => box.querySelector(`#${id}`)?.value ?? '';
function newPassword() {
  const p = value('accPassword');
  if (p !== value('accPassword2')) throw new Error('Les deux mots de passe ne sont pas identiques.');
  return p;
}
function email() {
  const e = value('accEmail').trim();
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(e)) throw new Error('Adresse e-mail invalide.');
  rememberedEmail = e;
  return e;
}

// Chaque bouton : son action, puis le message à afficher (ou rien)
const ACTIONS = {
  signinMode: () => (ui.mode = 'signin'),
  signupMode: () => (ui.mode = 'signup'),
  forgotMode: () => (ui.mode = 'forgot'),
  recoverMode: () => (ui.mode = 'recover'),
  unlockMode: () => (ui.mode = 'unlock'),
  passwordMode: () => (ui.mode = 'password'),
  recoveryMode: () => (ui.mode = 'recovery'),
  deleteMode: () => (ui.mode = 'delete'),
  openMode: () => (ui.mode = 'open'),
  guest: () => hooks.onGuest?.(),
  async signup() {
    const result = await signUp(email(), newPassword());
    return result === 'open' ? 'Compte créé.' : '';
  },
  async signin() {
    await signIn(email(), value('accPassword'));
    return accountState().open ? 'Connecté.' : '';
  },
  async sendReset() {
    await requestReset(email());
    ui.mode = 'signin';
    return `Si un compte existe pour ${rememberedEmail}, un e-mail vient de partir. Ouvre son lien.`;
  },
  async resend() {
    await resendConfirmation();
    return 'E-mail renvoyé.';
  },
  cancel: () => cancelPending(),
  async unlock() {
    await unlockVault(value('accPassword'));
    return 'Coffre ouvert : synchronisation…';
  },
  async create() {
    const s = accountState();
    await createVaultWith(s.vaultMode === 'vault' ? newPassword() : value('accPassword'));
    return '';
  },
  async reset() {
    await resetWithRecovery(value('accRecovery'), newPassword());
    ui.mode = 'open';
    return 'Nouveau mot de passe enregistré.';
  },
  async changePassword() {
    await changePassword(value('accCurrent'), newPassword());
    ui.mode = 'open';
    return 'Mot de passe changé.';
  },
  async newRecovery() {
    await newRecovery(value('accCurrent'));
    ui.mode = 'open';
    return 'Nouvelle clé de secours : l’ancienne ne marche plus.';
  },
  noted: () => recoveryNoted(),
  async syncNow() {
    const { pulled } = await hooks.syncNow();
    if (pulled) hooks.onPulled();
    return '';
  },
  async signout() {
    await signOut();
    ui.mode = 'signin';
    return 'Déconnecté. Tes données restent sur cet appareil.';
  },
  async delete() {
    await deleteAccount();
    ui.mode = 'signin';
    return 'Compte supprimé. Tes données restent sur cet appareil.';
  },
};

async function run(name) {
  const buttons = box.querySelectorAll('button');
  buttons.forEach((b) => (b.disabled = true));
  setStatus('', ['signup', 'signin', 'unlock', 'create', 'reset', 'changePassword', 'newRecovery'].includes(name) ? 'Chiffrement…' : '');
  try {
    const message = await ACTIONS[name]();
    render();
    if (typeof message === 'string' && message) setStatus('ok', message);
    hooks.onChange();
    box.querySelector('input:not([readonly])')?.focus({ preventScroll: true });
  } catch (err) {
    render();
    setStatus('bad', err.message || String(err));
  }
}

export function initAccountUi(options) {
  hooks = options;
  box = document.querySelector('#accountBox');
  status = document.querySelector('#accountStatus');
  box.addEventListener('click', (e) => {
    const provider = e.target.closest('[data-provider]');
    if (provider) {
      setStatus('', `Ouverture de ${PROVIDERS[provider.dataset.provider]}…`);
      signInWith(provider.dataset.provider).catch((err) => setStatus('bad', err.message));
      return;
    }
    const action = e.target.closest('[data-acc]');
    if (action) run(action.dataset.acc);
  });
  // Entrée dans un champ : le bouton principal (pas l'envoi du formulaire des réglages)
  box.addEventListener('keydown', (e) => {
    if (e.key !== 'Enter' || e.target.tagName !== 'INPUT') return;
    e.preventDefault();
    box.querySelector('.auth-submit')?.click();
  });
  window.addEventListener('streamhub:account', () => {
    if (!box.contains(document.activeElement) || !box.querySelector('input:not([readonly])')) render();
  });
  render();
  return {
    render() {
      ui = { mode: accountState().open ? 'open' : 'signin' };
      render();
    },
    message: setStatus,
    focus: () => box.querySelector('input:not([readonly])')?.focus({ preventScroll: true }),
  };
}

// Résumé de la section (barre latérale des réglages)
export function accountSummary() {
  const s = accountState();
  if (s.open) return s.email;
  if (s.signedIn) return `${s.email} : coffre à ouvrir`;
  if (s.pending) return 'Adresse à confirmer';
  return 'Invité : données sur cet appareil';
}
