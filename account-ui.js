// Réglages → Compte : invité, inscription, connexion (e-mail, Google, GitHub), coffre à ouvrir, clé de secours,
// mot de passe, déconnexion, suppression. L'état vient d'account.js ; ici, seulement l'affichage et les boutons.
import {
  accountState, signUp, signIn, signInWith, resendConfirmation, cancelPending, unlockVault, createVaultWith,
  requestReset, resetWithRecovery, changePassword, newRecovery, recoveryNoted, signOut, deleteAccount, PROVIDERS,
  enabledProviders,
} from './account.js';

const esc = (s) => String(s).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]);
const PROVIDER_NAMES = { email: 'e-mail', ...PROVIDERS };

let box;
let status;
let ui = { mode: 'signin' }; // ce qui est affiché : signin, signup, forgot (invité) ; unlock, recover ; password, delete (connecté)
let hooks = {};
let rememberedEmail = '';

const field = (id, label, type = 'password', extra = '') => `<div class="field">
    <label for="${id}">${label}</label>
    <input id="${id}" type="${type}" ${extra}>
  </div>`;
const emailField = () => field('accEmail', 'Adresse e-mail', 'email', `autocomplete="username" spellcheck="false" value="${esc(rememberedEmail)}"`);
const newPasswordFields = (label = 'Mot de passe') =>
  field('accPassword', `${label} <em>8 caractères au moins</em>`, 'password', 'autocomplete="new-password"') +
  field('accPassword2', 'Encore une fois', 'password', 'autocomplete="new-password"');
const actions = (...buttons) => `<div class="key-actions">${buttons.join('')}</div>`;
const button = (action, text, kind = '') => `<button type="button" class="btn ${kind}" data-acc="${action}">${text}</button>`;
const link = (action, text) => `<button type="button" class="link-btn" data-acc="${action}">${text}</button>`;

// Rempli quand Supabase a dit quels fournisseurs sont activés (rien s'il n'y en a aucun)
const providerSlot = () => '<div id="accProviders"></div>';
async function fillProviders() {
  const list = await enabledProviders();
  const slot = box.querySelector('#accProviders');
  if (!slot || !list.length) return;
  slot.innerHTML = `<p class="sync-or">ou</p>
    <div class="account-providers">${list
      .map((id) => `<button type="button" class="btn provider-btn" data-provider="${id}">Continuer avec ${PROVIDERS[id]}</button>`)
      .join('')}</div>`;
}

function recoveryPanel(key) {
  return `<div class="recovery-panel">
    <p><strong>Ta clé de secours</strong></p>
    <div class="key-row">
      <input id="accRecoveryShown" readonly value="${esc(key)}" aria-label="Ta clé de secours">
      <button type="button" class="btn" data-copy="#accRecoveryShown">Copier</button>
    </div>
    <p class="hint">Note-la dans ton gestionnaire de mots de passe. Si tu oublies ton mot de passe, elle seule permet de
      retrouver tes données : personne, pas même StreamHub, ne peut les rouvrir sans elle.</p>
    ${actions(button('noted', 'Je l’ai notée', 'primary'))}
  </div>`;
}

function render() {
  const s = accountState();
  setStatus('', '');
  if (s.open) return renderOpen(s);
  if (s.signedIn) return renderSignedIn(s);
  if (s.pending) {
    box.innerHTML = `<p class="hint">Dernière étape : ouvre le lien envoyé à <strong>${esc(s.pending)}</strong> (regarde aussi
      dans les indésirables). Tu reviendras ici, connecté.</p>
      ${actions(button('resend', 'Renvoyer l’e-mail'), button('cancel', 'Annuler', 'ghost'))}`;
    return;
  }
  renderGuest();
}

function renderGuest() {
  const intro = `<p class="hint">Avec un compte, tes réglages, clés, abonnements, J’aime, Ma liste et historique te suivent
    sur tous tes appareils. Tout est chiffré sur l’appareil avant l’envoi : personne d’autre que toi ne peut les lire.
    Sans compte, tu restes en invité : tout reste sur cet appareil seulement.</p>`;
  if (ui.mode === 'forgot') {
    box.innerHTML = `${intro}${emailField()}
      <p class="hint">Tu recevras un lien pour choisir un nouveau mot de passe ; il faudra aussi ta clé de secours.</p>
      ${actions(button('sendReset', 'Envoyer le lien', 'primary'), button('signinMode', 'Retour', 'ghost'))}`;
    return;
  }
  const signup = ui.mode === 'signup';
  box.innerHTML = `${intro}
    <div class="account-tabs" role="tablist">
      <button type="button" role="tab" data-acc="signinMode" aria-selected="${!signup}">Se connecter</button>
      <button type="button" role="tab" data-acc="signupMode" aria-selected="${signup}">Créer un compte</button>
    </div>
    ${emailField()}
    ${signup ? newPasswordFields() : field('accPassword', 'Mot de passe', 'password', 'autocomplete="current-password"')}
    ${actions(button(signup ? 'signup' : 'signin', signup ? 'Créer mon compte' : 'Se connecter', 'primary'), signup ? '' : link('forgotMode', 'Mot de passe oublié ?'))}
    ${providerSlot()}`;
  fillProviders();
}

// Connecté mais coffre fermé sur cet appareil : mot de passe à entrer, coffre à créer, ou mot de passe à refaire
function renderSignedIn(s) {
  const who = `<p class="hint">Connecté : <strong>${esc(s.email)}</strong>${s.provider !== 'email' ? ` (${esc(PROVIDER_NAMES[s.provider] ?? s.provider)})` : ''}.</p>`;
  const vaultWord = s.vaultMode === 'vault' ? 'mot de passe du coffre' : 'mot de passe';
  let body;
  if (s.needs === 'reset' || ui.mode === 'recover') {
    body = `<p class="hint">Choisis un nouveau ${vaultWord} et entre ta clé de secours : elle rouvre tes données.</p>
      ${field('accRecovery', 'Clé de secours', 'text', 'autocomplete="off" autocapitalize="characters" spellcheck="false" placeholder="ABCD-EFGH-JKLM-NPQR-STUV"')}
      ${newPasswordFields(`Nouveau ${vaultWord}`)}
      ${actions(button('reset', 'Enregistrer', 'primary'), s.needs === 'reset' ? '' : button('unlockMode', 'Retour', 'ghost'))}`;
  } else if (s.needs === 'create' && s.vaultMode === 'vault') {
    body = `<p class="hint">Choisis un mot de passe du coffre : il chiffre tes données sur l’appareil, avant l’envoi.
      Tu le taperas une fois sur chaque nouvel appareil. Il ne sert qu’à StreamHub (rien à voir avec ${esc(PROVIDER_NAMES[s.provider] ?? s.provider)}).</p>
      ${newPasswordFields('Mot de passe du coffre')}
      ${actions(button('create', 'Créer mon coffre', 'primary'))}`;
  } else if (s.needs === 'create') {
    body = `<p class="hint">Adresse confirmée. Entre ton mot de passe pour terminer la création du compte.</p>
      ${field('accPassword', 'Mot de passe', 'password', 'autocomplete="current-password"')}
      ${actions(button('create', 'Continuer', 'primary'))}`;
  } else {
    body = `<p class="hint">Entre ton ${vaultWord} pour ouvrir tes données sur cet appareil.</p>
      ${field('accPassword', s.vaultMode === 'vault' ? 'Mot de passe du coffre' : 'Mot de passe', 'password', 'autocomplete="current-password"')}
      ${actions(button('unlock', 'Ouvrir', 'primary'), link('recoverMode', `${s.vaultMode === 'vault' ? 'Mot de passe du coffre oublié' : 'Mot de passe oublié'} ?`))}`;
  }
  box.innerHTML = `${who}${body}${actions(button('signout', 'Se déconnecter', 'ghost'))}`;
}

function renderOpen(s) {
  const via = s.provider !== 'email' ? ` (${esc(PROVIDER_NAMES[s.provider] ?? s.provider)})` : '';
  const vaultWord = s.vaultMode === 'vault' ? 'mot de passe du coffre' : 'mot de passe';
  let extra = '';
  if (ui.mode === 'password') {
    extra = `${field('accCurrent', `${vaultWord[0].toUpperCase()}${vaultWord.slice(1)} actuel`, 'password', 'autocomplete="current-password"')}
      ${newPasswordFields(`Nouveau ${vaultWord}`)}
      ${actions(button('changePassword', 'Enregistrer', 'primary'), button('openMode', 'Annuler', 'ghost'))}`;
  } else if (ui.mode === 'delete') {
    extra = `<p class="hint danger-text">Ton compte, ton coffre et tes données synchronisées seront effacés chez Supabase.
      Tes données restent sur cet appareil (en invité). Impossible d’annuler.</p>
      ${actions(button('delete', 'Supprimer définitivement', 'danger'), button('openMode', 'Annuler', 'ghost'))}`;
  } else {
    extra = actions(
      button('syncNow', 'Synchroniser maintenant'),
      button('passwordMode', `Changer de ${vaultWord}`),
      button('newRecovery', 'Nouvelle clé de secours'),
      button('signout', 'Se déconnecter', 'ghost'),
      button('deleteMode', 'Supprimer mon compte', 'ghost danger-text'),
    );
  }
  box.innerHTML = `${s.recoveryKey ? recoveryPanel(s.recoveryKey) : ''}
    <p class="hint">Connecté : <strong>${esc(s.email)}</strong>${via}. Tes réglages, clés, abonnements, J’aime, Ma liste et
      historique sont chiffrés ici puis synchronisés.</p>
    ${extra}`;
  if (s.error) setStatus('bad', `Dernière synchronisation impossible : ${s.error}`);
  else if (s.lastSyncAt) setStatus('ok', `Synchronisé ${hooks.syncedWhen(s.lastSyncAt)}.`);
  else setStatus('', 'Synchronisation…');
}

function setStatus(kind, message) {
  status.className = `key-status ${kind}`;
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
  deleteMode: () => (ui.mode = 'delete'),
  openMode: () => (ui.mode = 'open'),
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
    await newRecovery();
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
  setStatus('', ['signup', 'signin', 'unlock', 'create', 'reset', 'changePassword'].includes(name) ? 'Chiffrement…' : '');
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
    box.querySelector('.btn.primary, .btn.danger')?.click();
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

// Résumé de la section (réglages repliés)
export function accountSummary() {
  const s = accountState();
  if (s.open) return `Connecté : ${s.email}`;
  if (s.signedIn) return `${s.email} : coffre à ouvrir`;
  if (s.pending) return 'Adresse à confirmer';
  return 'Invité : données sur cet appareil seulement';
}
