import { loadSettings, saveSettings, relayUrl, HISTORY_MAX } from './store.js';
import { makeApi, img, testTmdbKey, testSaKey, testRelay } from './api.js';
import { syncNow, startAutoSync } from './sync.js';
import { handleAuthRedirect, accountState } from './account.js';
import { initAccountUi, accountSummary } from './account-ui.js';
import { serviceFor, hostServiceFor, isChannel, fallbackLink, episodesLink, iosLink, iosAppLink, desktopAppLink, desktopWebLink, autoplayLink, seriesResumeLink, providerLogo, CANAL_CHANNELS, CANAL_CINE_SERIES, withVirtualChannels, withSaOffers, originalNetworks } from './providers.js';
import { INDEXED_PLATFORMS, platformEpisodeUrl, canalChannelPath } from './episodes.js';
import { aliasMatches } from './aliases.js';
import { loadTitles, suggest, splitNumber, arrangeSagas } from './search.js';
import { sagaTitles, universeTitles, genreTitles } from './suggestions.js';
import { initSpatialNav } from './nav.js';
import * as library from './library.js';

// À changer à chaque mise en ligne (avec le nom du cache dans sw.js) : affiché dans les réglages
const APP_VERSION = '2.2.0';

const $ = (sel, root = document) => root.querySelector(sel);
const esc = (s) =>
  String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]);

const el = {
  grid: $('#grid'),
  status: $('#status'),
  topbar: $('#topbar'),
  rowsPage: $('#rowsPage'),
  gridPage: $('#gridPage'),
  pageTitle: $('#pageTitle'),
  backBtn: $('#backBtn'),
  filters: $('#filters'),
  typeSwitch: $('#typeSwitch'),
  platform: $('#platformSelect'),
  genre: $('#genreSelect'),
  sort: $('#sortSelect'),
  search: $('#searchInput'),
  searchForm: $('#searchForm'),
  sentinel: $('#sentinel'),
  detail: $('#detail'),
  settings: $('#settings'),
  settingsForm: $('#settingsForm'),
  settingsError: $('#settingsError'),
  providerGrid: $('#providerGrid'),
  providerFilter: $('#providerFilter'),
  toast: $('#toast'),
};

let settings = loadSettings();
let api = makeApi(settings);
// Effet verre choisi pour cet appareil (voir styles.css, « Effet verre »)
const applyGlass = () => (document.documentElement.dataset.glass = settings.glass || 'auto');
applyGlass();

const state = {
  // Pages en rangées : 'home' | 'movies' | 'tv' | 'anime' | 'me' ; pages en grille : 'library' | 'likes' | 'history' | 'downloads'
  view: 'home',
  type: ['movie', 'tv', 'all'].includes(settings.type) ? settings.type : 'all', // films, séries ou les deux
  filter: settings.providers.length ? 'mine' : 'all', // 'mine' | 'all' | id d'une plateforme
  genre: '', // nom du genre (les identifiants diffèrent entre films et séries)
  genreIds: null, // { movie, tv } quand le genre vient d'une rangée de l'accueil
  genreExtra: null, // paramètres TMDB du genre venu d'une rangée (animés : pays d'origine)
  sort: 'popularity',
  query: '',
  page: 0,
  totalPages: 1,
  pagesByType: {}, // en mode « Tout », nombre de pages disponibles côté films et côté séries
  hidden: 0,
  suggestion: null, // « Tu voulais dire… ? » de la recherche en cours
  loading: false,
  token: 0,
};

// Genres proposés : [{ name, movie: id | undefined, tv: id | undefined, extra? }]
let genreOptions = [];

// Animation japonaise : TMDB n'a pas de genre « animé », c'est le genre Animation avec le Japon comme pays d'origine.
// Proposé comme un genre de la Bibliothèque, et page Animés (rangées) dans la navigation.
const ANIME = { name: 'Animés japonais', movie: 16, tv: 16, extra: { with_origin_country: 'JP' } };

// ---------- Utilitaires ----------

const streamable = (offers) => [...(offers?.flatrate ?? []), ...(offers?.free ?? []), ...(offers?.ads ?? [])];
const year = (date) => (date ? date.slice(0, 4) : '');
// TMDB nomme différemment les champs des films (title, release_date) et des séries (name, first_air_date)
const titleOf = (item) => item.title ?? item.name ?? '';
const originalTitleOf = (item) => item.original_title ?? item.original_name ?? '';
const dateOf = (item) => item.release_date ?? item.first_air_date ?? '';
// Date de sortie d'un film : « 9 oct. 2026 » (affiches), « 1er octobre 2026 » (fiche) ; année seule si le jour manque
function releaseDate(date, long = false) {
  if (!/^\d{4}-\d{2}-\d{2}/.test(date ?? '')) return year(date);
  const d = new Date(`${date.slice(0, 10)}T12:00:00`);
  const text = d.toLocaleDateString('fr-FR', { day: 'numeric', month: long ? 'long' : 'short', year: 'numeric' });
  return d.getDate() === 1 ? text.replace(/^1 /, '1er ') : text;
}
// Les plateformes ne permettent de télécharger que dans leurs applis pour téléphone et tablette
// (iPhone, iPad, Android) : ni sur ordinateur, ni sur TV.
const CAN_DOWNLOAD = (() => {
  const ua = navigator.userAgent;
  const apple = /iPhone|iPad|iPod/.test(ua) || (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1); // iPadOS se fait passer pour un Mac
  const android = /Android/.test(ua) && !/\bTV\b|AFT|GoogleTV|SmartTV|BRAVIA/i.test(ua); // sauf Android TV, Fire TV…
  return apple || android;
})();
const IOS = /iPhone|iPad|iPod/.test(navigator.userAgent) || (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);
// StreamHub ouvert depuis l'écran d'accueil de l'iPhone / iPad (et non dans Safari)
const IOS_WEB_APP = navigator.standalone === true;
// Moteur du navigateur, pour quelques ajustements propres à Chrome / Edge (Blink) et Firefox (Gecko), surtout sous
// Windows. Safari (Mac, iPhone, iPad) et tous les navigateurs d'iPhone (même moteur que Safari) n'ont pas d'attribut :
// rien de ce qui suit ne les concerne.
const ENGINE = (() => {
  const ua = navigator.userAgent;
  if (/CriOS|FxiOS|EdgiOS/.test(ua) || IOS) return '';
  if (/Firefox\//.test(ua)) return 'gecko';
  if (/Chrome\/|Edg\//.test(ua)) return 'blink';
  return '';
})();
if (ENGINE) document.documentElement.dataset.engine = ENGINE;
const MAC = /Mac/.test(navigator.platform) && !IOS;

const myIds = () => settings.providers.map((p) => p.id);
const myServices = () => new Set(settings.providers.map((p) => serviceFor(p.name)?.id).filter(Boolean));

const WORDS = {
  movie: { none: 'Aucun film', found: 'trouvé', this: 'Ce film', included: 'inclus' },
  tv: { none: 'Aucune série', found: 'trouvée', this: 'Cette série', included: 'incluse' },
  all: { none: 'Aucun titre', found: 'trouvé', this: 'Ce titre', included: 'inclus' },
};
const words = (type = state.type) => WORDS[type];
const typesShown = () => (state.type === 'all' ? ['movie', 'tv'] : [state.type]);

// Identifiant du genre choisi pour un type, ou undefined si ce genre n'existe pas pour ce type
// state.genreIds, s'il est défini (venu d'une rangée), donne directement les identifiants par type
// (« 16,28 » : animés d'action, les deux genres à la fois)
const genreIdFor = (type) =>
  state.genreIds ? state.genreIds[type] : genreOptions.find((g) => g.name === state.genre)?.[type];
// Paramètres TMDB en plus du genre (animés japonais : { with_origin_country: 'JP' })
const genreExtra = () =>
  (state.genreIds ? state.genreExtra : genreOptions.find((g) => g.name === state.genre)?.extra) ?? undefined;

// Recherche : le genre est vérifié sur chaque résultat (tous les genres de « 16,28 », et l'origine japonaise des animés)
function matchesGenre(m) {
  const ids = String(genreIdFor(m.media_type) ?? '').split(',').filter(Boolean).map(Number);
  if (!ids.length || !ids.every((id) => m.genre_ids?.includes(id))) return false;
  const country = genreExtra()?.with_origin_country;
  return !country || Boolean(m.origin_country?.includes(country)) || (country === 'JP' && m.original_language === 'ja');
}

// En mode « Tout », on mélange les deux listes selon le tri choisi
const SORT_KEYS = {
  popularity: (m) => m.popularity ?? 0,
  rating: (m) => m.vote_average ?? 0,
  // Une série récente compte à la date de son dernier épisode, pas à celle de sa création
  recent: (m) => Date.parse(m.latest_episode?.air_date ?? dateOf(m)) || 0,
};

// Une offre est « à moi » si c'est la même plateforme TMDB ou le même service (ex. Netflix / Netflix avec pub)
function isMine(provider) {
  if (myIds().includes(provider.provider_id)) return true;
  const service = serviceFor(provider.provider_name)?.id;
  return Boolean(service && myServices().has(service));
}

// Le titre est-il inclus (abonnement, gratuit) dans la sélection : mes abonnements ou une plateforme ?
function matchesFilter(offers, filter = state.filter) {
  const list = streamable(offers);
  if (filter === 'all') return true;
  if (filter === 'mine') return list.some(isMine);
  const id = Number(filter);
  const chosen = settings.providers.find((p) => p.id === id);
  const service = chosen && serviceFor(chosen.name)?.id;
  return list.some((p) => p.provider_id === id || (service && serviceFor(p.provider_name)?.id === service));
}

// Pour les recherches TMDB : les cases inventées par StreamHub correspondent à de vraies plateformes (chaîne de Canal+
// → catalogue de la plateforme ; Canal+ Ciné Séries → Canal+, ses autres plateformes étant cochées avec elle)
function activeProviderIds(filter = state.filter) {
  if (filter === 'all') return [];
  const ids = filter === 'mine' ? myIds() : [Number(filter)];
  const real = (id) => CANAL_CHANNELS.find((c) => c.id === id)?.tmdbIds ?? (id === CANAL_CINE_SERIES.id ? [381] : [id]);
  return [...new Set(ids.flatMap(real))];
}

// Sans abonnement choisi, on montre tout le catalogue
const defaultFilter = () => (settings.providers.length ? 'mine' : 'all');

// Message temporaire en haut de l'écran, avec éventuellement un bouton d'action { label, run }.
// C'est un popover (comme les barres du bas) pour rester visible quand une fiche est ouverte.
let toastTimer;
let toastAction = null;
// custom : contenu HTML complet à la place du message (notification des likes sur les plateformes)
function toast(message, action = null, { custom = '', duration = 0 } = {}) {
  el.toast.innerHTML = custom || `<span>${esc(message)}</span>${action ? `<button type="button" class="btn primary" data-toast-action>${esc(action.label)}</button>` : ''}`;
  el.toast.classList.toggle('custom', Boolean(custom));
  toastAction = action?.run ?? null;
  toastEntry = null;
  togglePopover(el.toast, true);
  requestAnimationFrame(() => el.toast.classList.add('show'));
  clearTimeout(toastTimer);
  toastTimer = setTimeout(hideToast, duration || (action ? 10000 : 4500));
}

function hideToast() {
  el.toast.classList.remove('show');
  toastTimer = setTimeout(() => togglePopover(el.toast, false), 250); // après le fondu
}

function setStatus(html) {
  el.status.innerHTML = html;
}

// ---------- Filtres ----------

function renderTypeSwitch() {
  for (const btn of el.typeSwitch.querySelectorAll('[data-type]')) {
    btn.setAttribute('aria-pressed', btn.dataset.type === state.type);
  }
}

// Les abonnements se gèrent dans les réglages ; ici, un simple menu pour restreindre la Bibliothèque
function renderPlatformSelect() {
  const options = [];
  if (settings.providers.length) {
    options.push({ value: 'mine', label: 'Mes plateformes' });
    for (const p of settings.providers) options.push({ value: String(p.id), label: p.name });
  }
  options.push({ value: 'all', label: 'Tout le catalogue' });
  el.platform.innerHTML = options.map((o) => `<option value="${esc(o.value)}">${esc(o.label)}</option>`).join('');
  el.platform.value = String(state.filter);
}

async function loadGenres() {
  const type = state.type;
  try {
    if (!settings.tmdbKey) return;
    const lists = await Promise.all(typesShown().map((t) => api.genres(t).then((genres) => ({ t, genres }))));
    if (type !== state.type) return;
    // Fusion par nom : « Drame » existe pour les deux, « Action & Adventure » seulement pour les séries
    const byName = new Map();
    for (const { t, genres } of lists) {
      for (const g of genres) byName.set(g.name, { ...byName.get(g.name), name: g.name, [t]: g.id });
    }
    genreOptions = [...byName.values(), ANIME].sort((a, b) => a.name.localeCompare(b.name, 'fr'));
    el.genre.innerHTML =
      '<option value="">Tous les genres</option>' +
      genreOptions.map((g) => `<option value="${esc(g.name)}">${esc(g.name)}</option>`).join('');
    // Genre d'une rangée qui n'existe pas tel quel dans la liste (ex. « Action & aventure ») : on l'ajoute
    if (state.genre && !genreOptions.some((g) => g.name === state.genre)) {
      el.genre.insertAdjacentHTML('beforeend', `<option value="${esc(state.genre)}">${esc(state.genre)}</option>`);
    }
    el.genre.value = state.genre;
  } catch {
    /* le message d'erreur s'affiche déjà via le chargement du catalogue */
  }
}

function setType(type) {
  if (type === state.type) return;
  state.type = type;
  state.genre = ''; // la liste des genres change avec le type
  settings = { ...settings, type };
  saveSettings(settings);
  renderTypeSwitch();
  loadGenres();
  reload();
}

// ---------- Catalogue ----------

function reload() {
  state.token++;
  state.page = 0;
  state.totalPages = 1;
  state.pagesByType = {};
  state.hidden = 0;
  state.suggestion = null;
  state.loading = false;
  el.grid.innerHTML = '';
  el.sort.disabled = Boolean(state.query);
  window.scrollTo({ top: 0 });
  return loadMore();
}

async function loadMore() {
  if (state.view !== 'library' || state.loading || state.page >= state.totalPages) return;
  if (!settings.tmdbKey) {
    setStatus(`<div class="empty"><p>Pour afficher les films et les séries, ajoute ta clé TMDB.</p>
      <button type="button" class="btn primary" data-open-settings>Ouvrir les réglages</button></div>`);
    return;
  }

  state.loading = true;
  const token = state.token;
  const page = state.page + 1;
  if (page === 1) {
    setStatus('');
    el.grid.innerHTML = Array.from({ length: 12 }, () => '<div class="card skeleton" aria-hidden="true"></div>').join('');
  }

  try {
    let results;
    let totalPages;
    if (state.query) {
      // Première page : on cherche aussi la correction proposée (« hary poter » → « Harry Potter ») et, pour
      // « harry potter 1 », le nom sans le numéro ; puis les sagas sont rangées dans l'ordre (voir search.js)
      const { text, number } = splitNumber(state.query);
      const suggestion = page === 1 ? suggest(state.query, await loadTitles()) : null;
      if (page === 1) state.suggestion = suggestion;
      const extra = page === 1 ? [suggestion, number && text].filter(Boolean) : [];
      const [res, aliases, ...more] = await Promise.all([
        api.search(state.type, state.query, page),
        page === 1 ? aliasMatches(state.query).catch(() => []) : [],
        ...extra.map((q) => api.search(state.type, q, 1).catch(() => ({ results: [] }))),
      ]);
      totalPages = res.total_pages;
      // Correction en tête : la recherche telle quelle contient une faute
      const found = suggestion ? [...more.flatMap((r) => r.results), ...res.results] : [...res.results, ...more.flatMap((r) => r.results)];
      results = [...(await aliasResults(aliases, found)), ...found];
      if (page === 1) results = await arrangeSagas(results, suggestion ?? state.query, api).catch(() => results);
      if (state.genre) results = results.filter(matchesGenre);
    } else {
      // Un type est ignoré si le genre choisi n'existe pas pour lui, ou s'il n'a plus de pages
      const types = typesShown().filter(
        (t) => (!state.genre || genreIdFor(t)) && page <= (state.pagesByType[t] ?? 1),
      );
      const responses = await Promise.all(
        types.map((t) =>
          api
            .discover(t, { page, genre: genreIdFor(t), sort: state.sort, providers: activeProviderIds(), extra: genreExtra() })
            .then((res) => ({ t, res })),
        ),
      );
      results = [];
      for (const { t, res } of responses) {
        state.pagesByType[t] = Math.min(res.total_pages, 500); // TMDB plafonne à 500 pages
        results.push(...res.results.map((m) => ({ ...m, media_type: t })));
      }
      if (types.length > 1) results.sort((a, b) => SORT_KEYS[state.sort](b) - SORT_KEYS[state.sort](a));
      totalPages = Math.max(0, ...Object.values(state.pagesByType));
    }
    if (state.filter !== 'all') {
      // La recherche ne filtre pas par plateforme, et l'index de « discover » peut être en retard
      // sur les offres réelles : on vérifie chaque titre avec les mêmes données que sa fiche.
      const offers = await Promise.all(results.map((m) => api.offers(m.media_type, m.id).catch(() => null)));
      const kept = results.filter((m, i) => matchesFilter(offers[i]));
      if (state.query) state.hidden += results.length - kept.length;
      results = kept;
    }
    if (token !== state.token) return;

    if (page === 1) el.grid.innerHTML = '';
    state.page = page;
    state.totalPages = Math.min(totalPages, 500);
    appendCards(results);
    updateStatus();
    state.loading = false;
    requestAnimationFrame(fillViewport);
  } catch (err) {
    if (token !== state.token) return;
    state.loading = false;
    if (page === 1) el.grid.innerHTML = '';
    setStatus(`<div class="empty"><p>${esc(err.message)}</p>
      ${err.status === 401 ? '<button type="button" class="btn primary" data-open-settings>Ouvrir les réglages</button>' : '<button type="button" class="btn" data-retry>Réessayer</button>'}</div>`);
  }
}

// Titres trouvés par surnom ou sigle (« DNA ») et absents de la recherche TMDB : placés en tête
async function aliasResults(aliases, tmdbResults) {
  const wanted = aliases.filter(
    (a) => (state.type === 'all' || a.type === state.type) && !tmdbResults.some((r) => r.id === a.id && r.media_type === a.type),
  );
  const items = await Promise.all(
    wanted.map((a) =>
      api
        .details(a.type, a.id)
        .then((d) => ({ ...d, media_type: a.type, genre_ids: (d.genres ?? []).map((g) => g.id) }))
        .catch(() => null),
    ),
  );
  return items.filter(Boolean);
}

// Si l'écran n'est pas rempli (ou si une page filtrée était vide), on charge la suivante
function fillViewport() {
  const rect = el.sentinel.getBoundingClientRect();
  if (rect.top < window.innerHeight + 600) loadMore();
}

function updateStatus() {
  const count = el.grid.children.length;
  if (state.query) {
    const hidden = state.hidden
      ? ` <button type="button" class="link" data-filter="all">${state.hidden} autre${state.hidden > 1 ? 's' : ''} hors de tes abonnements — tout afficher</button>`
      : '';
    const didYouMean = state.suggestion
      ? ` <button type="button" class="link" data-suggestion>Tu voulais dire « ${esc(state.suggestion)} » ?</button>`
      : '';
    setStatus(
      count
        ? `<p>Résultats pour « ${esc(state.query)} ».${didYouMean}${hidden}</p>`
        : `<div class="empty"><p>${words().none} ${words().found} pour « ${esc(state.query)} »${state.hidden ? ' sur tes abonnements' : ''}.${didYouMean}</p>${hidden}</div>`,
    );
  } else if (!count) {
    setStatus(`<div class="empty"><p>${words().none} ne correspond à ces filtres.</p></div>`);
  } else {
    setStatus('');
  }
}

// Carte d'affiche. Options : meta (ligne sous le titre), href (la carte ouvre ce lien au lieu de la fiche),
// typeTag (étiquette « Série » sur l'affiche)
function buildCard(m, { meta, href, target, typeTag = state.type === 'all', rank = null } = {}) {
  const type = m.media_type;
  const title = titleOf(m);
  const date = dateOf(m);
  const card = document.createElement(href ? 'a' : 'button');
  if (href) {
    card.href = href;
    card.target = target ?? '_blank';
  } else {
    card.type = 'button';
  }
  card.className = 'card';
  card.dataset.id = m.id;
  card.dataset.type = type;
  const rating = m.vote_count ? `★ ${m.vote_average.toFixed(1)}` : '';
  card.innerHTML = `
    <div class="poster">
      ${m.poster_path ? `<img src="${img(m.poster_path)}" alt="" loading="lazy">` : `<span class="no-poster">${esc(title)}</span>`}
      ${typeTag ? `<span class="card-tag">${type === 'tv' ? 'Série' : 'Film'}</span>` : ''}
      ${rank ? `<span class="card-rank" aria-label="Numéro ${rank}">${rank}</span>` : ''}
      <div class="card-providers"></div>
    </div>
    <span class="card-title">${esc(title)}</span>
    <span class="card-meta">${meta ?? esc([type === 'movie' ? releaseDate(date) : year(date), rating].filter(Boolean).join(' · '))}</span>`;
  card.setAttribute('aria-label', `${title}${date ? `, ${year(date)}` : ''}`);
  return card;
}

function appendCards(items) {
  // Un film et une série peuvent avoir le même identifiant TMDB : la clé inclut le type
  const existing = new Set([...el.grid.querySelectorAll('.card[data-id]')].map((c) => `${c.dataset.type}:${c.dataset.id}`));
  const frag = document.createDocumentFragment();
  for (const m of items) {
    if (existing.has(`${m.media_type}:${m.id}`)) continue;
    existing.add(`${m.media_type}:${m.id}`);
    const card = buildCard(m);
    frag.append(card);
    logoObserver.observe(card);
  }
  el.grid.append(frag);
}

// ---------- Bibliothèque : J'aime, Historique, Téléchargements ----------

// Pages personnelles (en grille, retour vers « Mon espace »)
const PERSONAL_VIEWS = ['watchlist', 'likes', 'history', 'downloads'];

const LIBRARY_TEXT = {
  watchlist: {
    intro: 'Les films et séries que tu as mis de côté pour plus tard.',
    empty: 'Ta liste est vide. Appuie sur « + Ma liste » dans la fiche d’un film ou d’une série pour le garder ici.',
    remove: 'Retirer de ma liste',
  },
  likes: {
    intro: 'Les films et séries que tu as aimés.',
    empty: 'Aucun titre aimé pour l’instant. Appuie sur « ♡ J’aime » dans la fiche d’un film ou d’une série.',
    remove: 'Retirer des titres aimés',
  },
  history: {
    intro: `Les ${HISTORY_MAX} derniers titres regardés depuis StreamHub.`,
    empty: 'Ton historique est vide. Les films et épisodes que tu lances depuis StreamHub s’ajoutent ici.',
    remove: 'Retirer de l’historique',
  },
  downloads: {
    intro: 'Ce que tu as téléchargé dans les applis des plateformes. Un clic ouvre le titre dans la bonne appli, où se trouve ton téléchargement.',
    empty: CAN_DOWNLOAD
      ? 'Aucun téléchargement. Dans la fiche d’un film ou d’un épisode, appuie sur « ⬇ Télécharger » : StreamHub ouvre l’appli de la plateforme pour lancer le téléchargement et le note ici.'
      : 'Les téléchargements se font depuis ton téléphone ou ta tablette : les plateformes ne permettent pas de télécharger sur ordinateur ni sur TV. Ouvre StreamHub sur ton téléphone et appuie sur « ⬇ Télécharger » dans la fiche d’un film ou d’un épisode. Ils seront listés là-bas, car cette liste est propre à chaque appareil.',
    remove: 'Retirer des téléchargements',
  },
};

const episodeLabel = (e) => (e.season != null && e.episode != null ? `S${e.season} E${e.episode}` : '');

const relativeTime = new Intl.RelativeTimeFormat('fr', { numeric: 'auto' });
function ago(timestamp) {
  const minutes = Math.round((timestamp - Date.now()) / 60000);
  if (minutes === 0) return 'à l’instant';
  if (minutes > -60) return relativeTime.format(minutes, 'minute');
  if (minutes > -1440) return relativeTime.format(Math.round(minutes / 60), 'hour');
  return relativeTime.format(Math.round(minutes / 1440), 'day');
}

function libraryMeta(entry, name) {
  if (name === 'likes') {
    const on = library.likedOn(entry.type, entry.id).map((p) => `✓ ${shortPlatformName(p.platform)}`);
    return esc([entry.type === 'movie' ? releaseDate(entry.date) : year(entry.date), entry.type === 'tv' ? 'Série' : 'Film', ...on].filter(Boolean).join(' · '));
  }
  const parts = [episodeLabel(entry), shortPlatformName(entry.platform), name === 'history' ? ago(entry.at) : ''].filter(Boolean);
  return `${name === 'downloads' ? '⬇ ' : ''}${esc(parts.join(' · '))}`;
}

function libraryCard(entry, name, { removable = true } = {}) {
  const m = { media_type: entry.type, id: entry.id, title: entry.title, poster_path: entry.poster, release_date: entry.date };
  // Un téléchargement s'ouvre directement dans l'appli de la plateforme
  const card =
    name === 'downloads' && entry.href
      ? buildCard(m, { meta: libraryMeta(entry, name), href: entry.href, target: platformTarget(entry.service || entry.platform), typeTag: true })
      : buildCard(m, { meta: libraryMeta(entry, name), typeTag: true });
  if (name === 'downloads') card.dataset.platform = entry.platform;
  card.dataset.libraryKey = entry.key;
  const wrap = document.createElement('div');
  wrap.className = 'card-wrap';
  wrap.append(card);
  if (!removable) return wrap;
  wrap.insertAdjacentHTML(
    'beforeend',
    `<button type="button" class="card-remove" data-remove="${name}" data-key="${esc(entry.key)}"
      aria-label="${esc(`${LIBRARY_TEXT[name].remove} : ${entry.title} ${episodeLabel(entry)}`.trim())}" title="${LIBRARY_TEXT[name].remove}">✕</button>`,
  );
  return wrap;
}

function renderLibrary() {
  const name = state.view;
  if (!LIBRARY_TEXT[name]) return;
  const entries = library.list(name);
  el.grid.innerHTML = '';
  el.grid.append(...entries.map((e) => libraryCard(e, name)));
  setStatus(entries.length ? `<p>${LIBRARY_TEXT[name].intro}</p>` : `<div class="empty"><p>${LIBRARY_TEXT[name].empty}</p></div>`);
}

// J'aime, Historique, Téléchargements ont changé : on redessine ce qui les affiche
function updateCounts() {
  if (state.view === 'me' || state.view === 'home') refreshLocalRows();
  refreshHeroLike();
}

const PAGE_TITLES = { library: 'Bibliothèque', watchlist: 'Ma liste', likes: 'J’aime', history: 'Historique', downloads: 'Téléchargements' };
const GRID_VIEWS = Object.keys(PAGE_TITLES);

// Changement de page. options.library : filtres à appliquer en ouvrant la Bibliothèque (depuis « Tout voir »)
async function showView(view, { library: filters } = {}) {
  state.view = view;
  const navKey = PERSONAL_VIEWS.includes(view) ? 'me' : view;
  for (const btn of document.querySelectorAll('[data-nav]')) {
    if (btn.classList.contains('brand') || btn === el.backBtn) continue;
    btn.setAttribute('aria-current', btn.dataset.nav === navKey ? 'page' : 'false');
  }
  const grid = GRID_VIEWS.includes(view);
  el.rowsPage.hidden = grid;
  el.gridPage.hidden = !grid;
  el.filters.hidden = view !== 'library';
  el.backBtn.hidden = !PERSONAL_VIEWS.includes(view);
  el.pageTitle.textContent = state.query && view === 'library' ? `Résultats pour « ${state.query} »` : PAGE_TITLES[view] ?? '';
  document.body.dataset.view = view;
  state.token++; // abandonne un chargement en cours
  state.loading = false;
  rowsToken++;
  window.scrollTo({ top: 0 });
  updateTopbar();

  if (view === 'library') {
    if (filters) {
      Object.assign(state, { genre: '', genreIds: null, genreExtra: null, query: '', ...filters });
      el.search.value = state.query;
      el.pageTitle.textContent = PAGE_TITLES.library;
    }
    renderTypeSwitch();
    renderPlatformSelect();
    el.sort.value = state.sort;
    await loadGenres(); // avant de charger : un genre venu de « Tout voir » doit être connu
    if (state.view === 'library') reload();
  } else if (grid) {
    renderLibrary();
  } else {
    renderRowsPage(view);
  }
}

// En haut d'une page avec affiche, la barre est transparente ; elle devient opaque en défilant
function updateTopbar() {
  el.topbar.classList.toggle('solid', window.scrollY > 40 || !$('.hero', el.rowsPage) || el.rowsPage.hidden);
}
window.addEventListener('scroll', updateTopbar, { passive: true });

// Le titre de la fiche ouverte, au format des entrées de la bibliothèque
function currentEntry() {
  const item = current.item;
  return { type: current.type, id: current.id, title: titleOf(item), poster: item.poster_path, date: dateOf(item) };
}

// Saison / épisode du bouton cliqué, s'il est dans la liste des épisodes
function episodeInfo(node) {
  const ep = node.closest('.episode');
  if (!ep) return {};
  return {
    season: Number(node.closest('.season').dataset.season),
    episode: Number(ep.dataset.episode),
    episodeName: $('strong', ep).textContent.replace(/^\d+\.\s*/, ''),
  };
}

// Logos des plateformes sur les affiches, chargés seulement quand la carte devient visible
const logoObserver = new IntersectionObserver(
  (entries) => {
    for (const entry of entries) {
      if (!entry.isIntersecting) continue;
      logoObserver.unobserve(entry.target);
      showCardProviders(entry.target);
    }
  },
  { rootMargin: '200px' },
);

async function showCardProviders(card) {
  try {
    const offers = streamable(await api.offers(card.dataset.type, card.dataset.id));
    const mine = offers.filter(isMine);
    // Hors « Tout le catalogue », on ne montre jamais une plateforme à laquelle tu n'es pas abonné
    const list = (mine.length || state.filter !== 'all' ? mine : offers).filter(
      (p, i, all) => all.findIndex((q) => (serviceFor(q.provider_name)?.id ?? q.provider_id) === (serviceFor(p.provider_name)?.id ?? p.provider_id)) === i,
    );
    const box = card.querySelector('.card-providers');
    box.classList.toggle('mine', mine.length > 0);
    box.innerHTML = list
      .slice(0, 3)
      .map((p) => `<img src="${img(p.logo_path, 'w92')}" alt="${esc(p.provider_name)}" title="${esc(p.provider_name)}">`)
      .join('');
  } catch {
    /* pas de logos : pas grave */
  }
}

new IntersectionObserver((entries) => entries[0].isIntersecting && loadMore(), { rootMargin: '600px' }).observe(el.sentinel);

// ---------- Pages en rangées : Accueil, Films, Séries, Mon espace ----------

let rowsToken = 0;
let heroItem = null;

// Rangées par genre de l'accueil, films et séries mélangés. TMDB n'a pas les mêmes genres pour les
// deux : un genre sans identifiant pour un type (ex. Horreur pour les séries) n'affiche que l'autre.
const HOME_GENRES = [
  { key: 'action', title: 'Action & aventure', genres: { movie: 28, tv: 10759 } },
  { key: 'comedy', title: 'Comédie', genres: { movie: 35, tv: 35 } },
  { key: 'horror', title: 'Horreur', genres: { movie: 27 } },
  { key: 'scifi', title: 'Science-fiction & fantastique', genres: { movie: 878, tv: 10765 } },
  { key: 'thriller', title: 'Thriller & policier', genres: { movie: 53, tv: 80 } },
  { key: 'drama', title: 'Drame', genres: { movie: 18, tv: 18 } },
  { key: 'animation', title: 'Animation', genres: { movie: 16, tv: 16 } },
  { key: 'anime', title: 'Animés japonais', genres: { movie: ANIME.movie, tv: ANIME.tv }, extra: ANIME.extra, section: 'anime' },
  { key: 'romance', title: 'Romance', genres: { movie: 10749 } },
  { key: 'family', title: 'Famille', genres: { movie: 10751, tv: 10751 } },
  { key: 'documentary', title: 'Documentaires', genres: { movie: 99, tv: 99 } },
];

// Rangées de l'accueil, dans l'ordre par défaut. Réglages → Accueil : l'utilisateur choisit celles qu'il affiche et leur
// ordre (settings.home.rows : [{ key, on }]), et le titre à l'affiche (settings.home.hero, sinon le n° 1 du Top 50).
// Clés communes avec l'appli iPhone (réglages synchronisés).
// Top 50 : classement « populaire » de JustWatch dans ton pays (activité récente, publié avec le site toutes les 6 heures),
// limité à tes plateformes. Avant : popularité TMDB, qui mettait en tête de vieilles séries très consultées (New York
// Police Judiciaire, Les Simpson), signalé par l'utilisateur. Sans classement : popularité TMDB.
const HOME_ROWS = [
  { key: 'top', top: true, title: 'Top 50 du moment', type: 'all', sort: 'popularity', pages: 2, limit: 50, ranked: true },
  { key: 'history', title: 'Reprendre', local: 'history' },
  { key: 'watchlist', title: 'Ma liste', local: 'watchlist' },
  { key: 'recent', title: 'Nouveautés', type: 'all', sort: 'recent', pages: 2, limit: 30 },
  { key: 'new-episodes', title: 'Nouveaux épisodes', type: 'tv', sort: 'recent', pages: 2, limit: 40 },
  { key: 'new-movies', title: 'Nouveaux films', type: 'movie', sort: 'recent' },
  { key: 'rating', title: 'Les mieux notés', type: 'all', sort: 'rating' },
  ...HOME_GENRES.map((g) => ({ ...g, type: 'all', sort: 'popularity' })),
];

// Ordre et choix des rangées : ceux enregistrés, puis les rangées inconnues de l'enregistrement (ajoutées depuis), affichées
function homeLayout(home = settings.home) {
  const known = new Set(HOME_ROWS.map((r) => r.key));
  const saved = (home?.rows ?? []).filter((r) => known.has(r.key));
  const seen = new Set(saved.map((r) => r.key));
  return [...saved.map((r) => ({ key: r.key, on: r.on !== false })), ...HOME_ROWS.filter((r) => !seen.has(r.key)).map((r) => ({ key: r.key, on: true }))];
}

// Genres de la page Animés, croisés avec Animation (identifiants TMDB films / séries)
const ANIME_GENRES = [
  { title: 'Action & aventure', movie: 28, tv: 10759 },
  { title: 'Science-fiction & fantastique', movie: 878, tv: 10765 },
  { title: 'Comédie', movie: 35, tv: 35 },
  { title: 'Drame', movie: 18, tv: 18 },
  { title: 'Mystère', movie: 9648, tv: 9648 },
  { title: 'Famille', movie: 10751, tv: 10751 },
];

// Genres mis en avant dans les pages Films et Séries (identifiants TMDB, dans cet ordre)
const ROW_GENRES = {
  movie: [28, 35, 18, 16, 878, 53, 12, 80, 27, 10749, 10751, 99],
  tv: [10759, 35, 18, 16, 10765, 80, 9648, 10751, 99, 10764],
};

// Une rangée « catalogue » : { title, type: 'movie' | 'tv' | 'all' | 'trending', sort, genre?, filter, hero? }
// Une rangée « perso » : { title, local: 'watchlist' | 'likes' | 'history' | 'downloads', always? (affichée même vide) }
async function rowsFor(view) {
  const filter = defaultFilter();
  if (view === 'home') {
    // L'affiche vient du Top 50 (son n° 1), sauf si un titre a été choisi
    const chosenHero = Boolean(settings.home?.hero);
    return homeLayout()
      .filter((r) => r.on)
      .map((r) => HOME_ROWS.find((d) => d.key === r.key))
      .map((d) => ({ ...d, filter, hero: Boolean(d.top) && !chosenHero }));
  }
  if (view === 'movies' || view === 'tv') {
    const type = view === 'movies' ? 'movie' : 'tv';
    const genres = await api.genres(type).catch(() => []);
    return [
      { hero: true, title: type === 'movie' ? 'Films populaires' : 'Séries populaires', type, sort: 'popularity', filter },
      { title: type === 'tv' ? 'Nouveaux épisodes' : 'Nouveautés', type, sort: 'recent', filter, ...(type === 'tv' ? { pages: 2, limit: 40 } : {}) },
      { title: type === 'movie' ? 'Les mieux notés' : 'Les mieux notées', type, sort: 'rating', filter },
      ...ROW_GENRES[type]
        .map((id) => genres.find((g) => g.id === id))
        .filter(Boolean)
        .map((genre) => ({ title: genre.name, type, sort: 'popularity', filter, genre })),
    ];
  }
  if (view === 'anime') {
    // Toutes les rangées sont des animés japonais ; « Tout voir » ouvre la Bibliothèque sur ce genre
    const anime = (title, more) => ({
      title, type: 'all', sort: 'popularity', filter,
      genres: { movie: ANIME.movie, tv: ANIME.tv }, extra: ANIME.extra, genreName: ANIME.name, ...more,
    });
    return [
      anime('Animés populaires', { hero: true }),
      anime('Nouveaux épisodes', { type: 'tv', sort: 'recent', pages: 2, limit: 40 }),
      anime('Séries animées', { type: 'tv' }),
      anime('Films d’animation', { type: 'movie' }),
      anime('Les mieux notés', { sort: 'rating' }),
      ...ANIME_GENRES.map((g) =>
        anime(g.title, { genres: { movie: `${ANIME.movie},${g.movie}`, tv: `${ANIME.tv},${g.tv}` }, genreName: `${ANIME.name} : ${g.title}` }),
      ),
    ];
  }
  return [
    { title: 'Ma liste', local: 'watchlist', always: true },
    { title: 'J’aime', local: 'likes', always: true },
    { title: 'Historique', local: 'history', always: true },
    { title: 'Téléchargements', local: 'downloads', always: true },
  ];
}

// Classement du moment (data/top/<pays>.json, voir scripts/build_episode_index.py), null s'il manque
const topFiles = new Map();
function topRanking(region) {
  if (!topFiles.has(region)) {
    topFiles.set(region, fetch(`data/top/${region}.json`).then((res) => (res.ok ? res.json() : null)).catch(() => null));
  }
  return topFiles.get(region);
}

// Les premiers titres du classement disponibles dans la sélection (tes abonnements, une plateforme ou tout)
async function fetchTop(row) {
  const ranking = await topRanking(settings.region);
  if (!ranking?.titles?.length) return null;
  const offersOf = (t) =>
    withVirtualChannels({ flatrate: t.p.map((id) => ({ provider_id: id, provider_name: ranking.names[id] ?? '' })) }, settings.region);
  const picked = ranking.titles.filter((t) => matchesFilter(offersOf(t), row.filter)).slice(0, row.limit);
  if (!picked.length) return null;
  const items = await Promise.all(
    picked.map((t) => api.title(t.t, t.id).then((m) => ({ ...m, media_type: t.t })).catch(() => null)),
  );
  return items.filter(Boolean);
}

// Les titres d'une rangée, vérifiés comme dans la Bibliothèque (vraiment inclus dans la plateforme choisie)
async function fetchRow(row) {
  if (row.top) {
    const top = await fetchTop(row);
    if (top?.length) return top;
  }
  let items;
  if (row.type === 'trending') {
    items = (await api.trending()).results;
  } else {
    const types = (row.type === 'all' ? ['movie', 'tv'] : [row.type]).filter((t) => !row.genres || row.genres[t] != null);
    const pages = Array.from({ length: row.pages ?? 1 }, (_, i) => i + 1);
    const lists = await Promise.all(
      types.flatMap((t) =>
        pages.map((page) =>
          api
            .discover(t, { page, genre: row.genres?.[t] ?? row.genre?.id, sort: row.sort, providers: activeProviderIds(row.filter), extra: row.extra })
            .then((res) => res.results.map((m) => ({ ...m, media_type: t })))
            .catch((err) => (page > 1 ? [] : Promise.reject(err))), // une page en trop n'est pas une erreur
        ),
      ),
    );
    const seen = new Set();
    items = lists.flat().filter((m) => !seen.has(`${m.media_type}:${m.id}`) && seen.add(`${m.media_type}:${m.id}`));
    const unlisted = (await fetchUnlisted(row, types)).filter((m) => !seen.has(`tv:${m.id}`));
    items.push(...unlisted);
    // Séries récentes : leur dernier épisode (pour les classer parmi les films, et affiché sur l'affiche à la place de
    // l'année de création)
    if (row.sort === 'recent') {
      const latest = await Promise.all(items.map((m) => (m.media_type === 'tv' ? api.title('tv', m.id).catch(() => null) : null)));
      items = items.map((m, i) => (latest[i]?.last_episode_to_air ? { ...m, latest_episode: latest[i].last_episode_to_air } : m));
    }
    if (types.length > 1 || unlisted.length) items.sort((a, b) => SORT_KEYS[row.sort ?? 'popularity'](b) - SORT_KEYS[row.sort ?? 'popularity'](a));
  }
  if (row.filter !== 'all') {
    const offers = await Promise.all(items.map((m) => api.offers(m.media_type, m.id).catch(() => null)));
    items = items.filter((m, i) => matchesFilter(offers[i], row.filter));
  }
  return row.limit ? items.slice(0, row.limit) : items;
}

// Séries de la rangée que JustWatch n'a pas encore dans le pays : créations de tes plateformes (VisionQuest sur Disney+)
// absentes de la recherche TMDB par plateforme, qui ne connaît que les offres JustWatch. Même recherche que la rangée,
// par diffuseur ; on ne garde que celles que withOriginals ajoute à une de tes plateformes.
async function fetchUnlisted(row, types) {
  const networks = originalNetworks(activeProviderIds(row.filter));
  if (!types.includes('tv') || !networks.length) return [];
  const res = await api.discover('tv', { page: 1, genre: row.genres?.tv ?? row.genre?.id, sort: row.sort, networks, extra: row.extra }).catch(() => null);
  const found = (res?.results ?? []).map((m) => ({ ...m, media_type: 'tv' }));
  const offers = await Promise.all(found.map((m) => api.offers('tv', m.id).catch(() => null)));
  return found.filter((m, i) => streamable(offers[i]).some((p) => p.unlisted) && matchesFilter(offers[i], row.filter));
}

// « S1 E31 · 16 oct. » : dernier épisode d'une série récente
function latestEpisodeMeta(m) {
  const e = m.latest_episode;
  if (!e?.air_date) return undefined;
  const day = new Date(`${e.air_date}T12:00:00`).toLocaleDateString('fr-FR', { day: 'numeric', month: 'short' });
  return esc(`S${e.season_number} E${e.episode_number} · ${day}`);
}

function meHeader() {
  const logos = settings.providers
    .map((p) => `<img src="${img(providerLogo(p.name, p.logo), 'w92')}" alt="${esc(p.name)}" title="${esc(p.name)}">`)
    .join('');
  return `<div class="me-head">
    <h1>Mon espace</h1>
    <div class="me-platforms">
      ${logos ? `<span class="muted">Tes plateformes</span><div class="me-logos">${logos}</div>` : '<span class="muted">Aucune plateforme choisie</span>'}
      <button type="button" class="btn" data-open-settings>Réglages et abonnements</button>
    </div>
  </div>`;
}

const rowObserver = new IntersectionObserver(
  (entries) => {
    for (const entry of entries) {
      if (!entry.isIntersecting) continue;
      rowObserver.unobserve(entry.target);
      loadRow(entry.target);
    }
  },
  { rootMargin: '300px 0px' },
);

async function renderRowsPage(view) {
  const token = ++rowsToken;
  heroItem = null;
  if (!settings.tmdbKey && view !== 'me') {
    el.rowsPage.innerHTML = `<div class="empty page-empty"><p>Pour afficher les films et les séries, ajoute ta clé TMDB.</p>
      <button type="button" class="btn primary" data-open-settings>Ouvrir les réglages</button></div>`;
    updateTopbar();
    return;
  }
  el.rowsPage.innerHTML = view === 'me' ? meHeader() : '<section class="hero hero-loading" aria-label="À la une"></section>';
  const rows = await rowsFor(view);
  if (token !== rowsToken) return;
  for (const row of rows) {
    const section = document.createElement('section');
    section.className = 'row';
    section.rowDef = row;
    section.innerHTML = `
      <div class="row-head">
        <h2>${esc(row.title)}${row.local ? ' <span class="count"></span>' : ''}</h2>
        <button type="button" class="see-all" data-see-all>Tout voir <span aria-hidden="true">›</span></button>
      </div>
      <div class="row-body">
        <button type="button" class="row-arrow prev" data-row-scroll="-1" tabindex="-1" aria-label="Défiler vers la gauche">‹</button>
        <div class="row-track">${'<div class="card skeleton" aria-hidden="true"></div>'.repeat(8)}</div>
        <button type="button" class="row-arrow next" data-row-scroll="1" tabindex="-1" aria-label="Défiler vers la droite">›</button>
      </div>`;
    el.rowsPage.append(section);
    if (row.local) fillLocalRow(section);
    else if (row.hero) loadRow(section); // tout de suite : elle fournit l'affiche
    else rowObserver.observe(section);
  }
  if (view === 'home' && !rows.some((r) => r.hero)) loadHomeHero(token);
  updateTopbar();
}

// Affiche de l'accueil quand elle ne vient pas de la rangée Top 50 : le titre choisi (Réglages → Accueil, ou « ☆ À
// l'affiche » dans sa fiche), sinon le n° 1 du Top 50 (rangée masquée)
async function loadHomeHero(token) {
  try {
    const chosen = settings.home?.hero;
    const item = chosen
      ? { ...(await api.title(chosen.type, chosen.id)), media_type: chosen.type }
      : (await fetchTop({ filter: defaultFilter(), limit: 1 }))?.[0];
    if (token !== rowsToken) return;
    if (item) renderHero(item);
    else $('.hero', el.rowsPage)?.remove();
  } catch {
    if (token === rowsToken) $('.hero', el.rowsPage)?.remove();
  }
  updateTopbar();
}

async function loadRow(section) {
  const token = rowsToken;
  const row = section.rowDef;
  try {
    const items = await fetchRow(row);
    if (token !== rowsToken) return;
    if (!items.length) {
      section.remove();
      if (row.hero) $('.hero', el.rowsPage)?.remove();
      updateTopbar();
      return;
    }
    const track = $('.row-track', section);
    track.innerHTML = '';
    for (const [i, m] of items.entries()) {
      const card = buildCard(m, { typeTag: true, rank: row.ranked ? i + 1 : null, meta: latestEpisodeMeta(m) });
      track.append(card);
      logoObserver.observe(card);
    }
    if (row.hero) renderHero(items.find((m) => m.backdrop_path) ?? items[0]);
  } catch (err) {
    if (token !== rowsToken) return;
    $('.row-track', section).innerHTML = `<p class="muted row-message">${esc(err.message)}</p>`;
    if (row.hero) $('.hero', el.rowsPage)?.remove();
    updateTopbar();
  }
}

function fillLocalRow(section) {
  const row = section.rowDef;
  const entries = library.list(row.local);
  $('.count', section).textContent = entries.length || '';
  $('[data-see-all]', section).hidden = !entries.length;
  section.hidden = !entries.length && !row.always;
  const track = $('.row-track', section);
  track.innerHTML = entries.length ? '' : `<p class="muted row-message">${LIBRARY_TEXT[row.local].empty}</p>`;
  for (const entry of entries.slice(0, 20)) track.append(libraryCard(entry, row.local, { removable: false }));
}

// J'aime, Historique, Téléchargements ont changé : on met à jour leurs rangées
function refreshLocalRows() {
  for (const section of el.rowsPage.querySelectorAll('.row')) if (section.rowDef?.local) fillLocalRow(section);
}

// « Tout voir » : la page perso correspondante, la page de la rangée (Animés japonais de l'accueil → page Animés), ou
// la Bibliothèque avec les filtres de la rangée
function seeAllRow(btn) {
  const row = btn.closest('.row')?.rowDef;
  if (!row) return;
  if (row.local) return showView(row.local);
  if (row.section) return showView(row.section);
  return showView('library', {
    library: {
      type: row.type === 'trending' ? 'all' : row.type,
      sort: row.sort,
      genre: row.genres ? (row.genreName ?? row.title) : (row.genre?.name ?? ''),
      genreIds: row.genres ?? null,
      genreExtra: row.extra ?? null,
      filter: row.filter,
    },
  });
}

function scrollRow(arrow) {
  const track = $('.row-track', arrow.closest('.row-body'));
  track.scrollBy({ left: Number(arrow.dataset.rowScroll) * track.clientWidth * 0.85, behavior: 'smooth' });
}

// ---------- Affiche mise en avant ----------

function renderHero(m) {
  const hero = $('.hero', el.rowsPage);
  if (!hero || !m) return;
  heroItem = m;
  hero.classList.remove('hero-loading');
  hero.style.backgroundImage = m.backdrop_path ? `url('${img(m.backdrop_path, 'w1280')}')` : '';
  const meta = [year(dateOf(m)), m.vote_count ? `★ ${m.vote_average.toFixed(1)}` : ''].filter(Boolean).join(' · ');
  hero.innerHTML = `
    <div class="hero-content">
      <span class="type-badge">${m.media_type === 'tv' ? 'Série' : 'Film'}</span>
      <h1>${esc(titleOf(m))}</h1>
      ${meta ? `<p class="hero-meta">${esc(meta)}</p>` : ''}
      ${m.overview ? `<p class="hero-overview">${esc(m.overview)}</p>` : ''}
      <div class="hero-actions">
        <button type="button" class="btn primary" data-hero="open">▶ Regarder</button>
        <button type="button" class="btn hero-list" data-hero="list" aria-pressed="false"></button>
        <button type="button" class="btn hero-like" data-hero="like" aria-pressed="false"></button>
      </div>
    </div>`;
  refreshHeroLike();
  updateTopbar();
}

function refreshHeroLike() {
  const btn = $('[data-hero="like"]', el.rowsPage);
  if (!btn || !heroItem) return;
  const liked = library.has('likes', library.titleKey(heroItem.media_type, heroItem.id));
  btn.setAttribute('aria-pressed', liked);
  btn.textContent = liked ? '♥ Aimé' : '♡ J’aime';
  const list = $('[data-hero="list"]', el.rowsPage);
  const inList = library.has('watchlist', library.titleKey(heroItem.media_type, heroItem.id));
  list.setAttribute('aria-pressed', inList);
  list.textContent = inList ? '✓ Ma liste' : '+ Ma liste';
}

function onHeroAction(btn) {
  if (!heroItem) return;
  if (btn.dataset.hero === 'open') return openDetail(heroItem.media_type, heroItem.id, btn);
  const entry = { type: heroItem.media_type, id: heroItem.id, title: titleOf(heroItem), poster: heroItem.poster_path, date: dateOf(heroItem) };
  if (btn.dataset.hero === 'list') {
    toast(library.toggleList(entry) ? 'Ajouté à ma liste.' : 'Retiré de ma liste.');
    refreshHeroLike();
    refreshLocalRows();
    return;
  }
  const liked = library.toggleLike(entry);
  refreshHeroLike();
  refreshLocalRows();
  if (liked) toast('Ajouté à J’aime.');
  else if (!remindPlatformLikes(entry)) toast('Retiré de J’aime.');
}

// ---------- Fiche film / série ----------

// Fiche ouverte : { key, type, id, entries, links, linksState: 'none' | 'loading' | 'ready' | 'error' }
let current = null;


async function openDetail(type, id, opener) {
  const key = `${type}:${id}`;
  current = { key, type, id, entries: [], links: null, linksState: settings.saKey ? 'loading' : 'none' };
  el.detail.dataset.key = key;
  setDetailHtml('<div class="detail-loading">Chargement…</div>');
  // Depuis une suggestion, la fiche est déjà ouverte : le focus reviendra sur la carte qui l'avait ouverte
  if (!el.detail.open) {
    el.detail.returnFocus = opener;
    el.detail.showModal();
  }
  rehostBars();
  try {
    const item = await api.details(type, id);
    if (current?.key !== key) return;
    current.item = item;
    if (type === 'tv') current.seasons = tmdbSeasons(item);
    renderDetail(item, type);
    applyCanalChannels(); // index des chaînes de Canal+ (fichiers publiés avec StreamHub, sans attendre les liens directs)
    if (type === 'tv') loadEpisodeGroups(item, key); // en parallèle des liens directs
    // Liens directs : Streaming Availability et JustWatch (relais) interrogés en même temps. Pour une série,
    // Streaming Availability peut mettre plusieurs secondes ; un clic pendant ce temps attend le lien (onLaunch).
    const loading = linksLoading(current);
    const relay = api.relayOffers(type, id, titleOf(item)).catch(() => []);
    const links = await api.streamingOptions(type, id).catch((err) => {
      toast(err.message);
      return null;
    });
    if (current?.key !== key) return loading.done();
    current.links = links;
    current.linksState = links ? 'ready' : settings.saKey ? 'error' : 'none';
    if (links) addSaOffers(links.options);
    if (links) applyDirectLinks(links.options);
    if (type === 'tv') applySeasonLinks();
    // Boutons encore sans lien direct (plateforme ou titre inconnu de Streaming Availability) : JustWatch
    if (el.detail.querySelector('a.watch:not([data-direct])')) {
      const offers = await relay;
      if (current?.key === key && offers.length) applyRelayLinks(offers, type);
    }
    loading.done();
  } catch (err) {
    setDetailHtml(`<div class="detail-loading"><p>${esc(err.message)}</p>
      <button type="button" class="btn" data-close>Fermer</button></div>`);
  }
}

// Construit la liste des boutons « Regarder sur… » à partir des offres TMDB
function watchEntries(item, type) {
  const offers = item['watch/providers']?.results?.[settings.region];
  const tmdbLink = offers?.link ?? `https://www.themoviedb.org/${type}/${item.id}/watch?locale=${settings.region}`;
  const seen = new Set();
  const entries = [];
  const add = (p, kind) => {
    const key = `${kind === 'rent' || kind === 'buy' ? 'paid' : 'stream'}:${serviceFor(p.provider_name)?.id ?? p.provider_id}`;
    if (seen.has(key)) return;
    seen.add(key);
    const fallback = fallbackLink(p.provider_name, titleOf(item), tmdbLink);
    entries.push({
      name: p.provider_name,
      logo: p.logo_path,
      kind,
      mine: kind !== 'rent' && kind !== 'buy' && isMine(p),
      service: hostServiceFor(p.provider_name)?.id ?? null, // pour les liens ; une chaîne Amazon → Prime Video
      href: fallback.href,
      hint: fallback.hint,
      unlisted: p.unlisted ?? null, // pas encore référencée dans le pays : 'network' (diffuseur) ou 'sa'
    });
  };
  for (const kind of ['flatrate', 'free', 'ads', 'rent', 'buy']) for (const p of offers?.[kind] ?? []) add(p, kind);
  return { entries, tmdbLink };
}

// « Netflix », « Netflix ou Disney Plus », « Netflix, Canal+ ou Disney Plus »
function platformList(entries) {
  const names = [...new Set(entries.map((e) => e.name))];
  return names.length > 1 ? `${names.slice(0, -1).join(', ')} ou ${names.at(-1)}` : names[0];
}

const KIND_LABEL = { flatrate: 'Abonnement', free: 'Gratuit', ads: 'Gratuit avec pub', rent: 'Location', buy: 'Achat' };

// Un onglet dédié par plateforme (pas de rel="noopener", sinon le navigateur ne le retrouve pas) :
// un nouveau clic réutilise l'onglet Netflix déjà ouvert au lieu d'en ouvrir un autre.
const platformTarget = (serviceOrName) => `streamhub-${String(serviceOrName).toLowerCase().replace(/[^a-z0-9]+/g, '-')}`;

// Bouton « Télécharger » : ouvre le titre dans l'appli de la plateforme et le note dans Téléchargements.
// href vide = on prend le lien de la fiche du bouton « Regarder » voisin.
function downloadButton({ platform, service, href = '', compact = false }) {
  return `<button type="button" class="download-btn ${compact ? 'compact' : ''}" data-download
      data-platform="${esc(platform)}" data-service="${esc(service ?? '')}" data-href="${esc(href)}"
      aria-label="Télécharger sur ${esc(shortPlatformName(platform))}" title="Télécharger dans l’appli ${esc(shortPlatformName(platform))}"
      >⬇<span class="download-label">${compact ? '' : ' Télécharger'}</span></button>`;
}

function watchButton(e, { download = false } = {}) {
  const link = `<a class="watch ${e.mine ? 'mine' : ''}" href="${esc(e.href)}" target="${platformTarget(e.service ?? e.name)}"
      data-service="${esc(e.service ?? '')}" data-kind="${e.kind}" data-platform="${esc(e.name)}">
      ${e.logo ? `<img src="${img(e.logo, 'w92')}" alt="">` : '<span class="logo-placeholder"></span>'}
      <span class="watch-text">
        <strong>${e.kind === 'rent' || e.kind === 'buy' ? esc(shortPlatformName(e.name)) : `Regarder sur ${esc(shortPlatformName(e.name))}`}</strong>
        <small><span class="watch-kind">${KIND_LABEL[e.kind]}</span> · <span class="watch-hint">${esc(e.hint)}</span></small>
      </span>
      <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M7 17 17 7M8 7h9v9"/></svg>
    </a>`;
  return download && CAN_DOWNLOAD ? `<div class="watch-row">${link}${downloadButton({ platform: e.name, service: e.service })}</div>` : link;
}

// Marque « ✓ Téléchargé » les boutons des titres / épisodes déjà notés
function refreshDownloadButtons() {
  if (!current) return;
  for (const btn of el.detail.querySelectorAll('[data-download]')) {
    const { season, episode } = episodeInfo(btn);
    const done = library.has('downloads', library.downloadKey(current.type, current.id, season, episode));
    btn.classList.toggle('done', done);
    $('.download-label', btn).textContent = btn.classList.contains('compact') ? '' : done ? ' Téléchargé' : ' Télécharger';
    btn.firstChild.textContent = done ? '✓' : '⬇';
  }
}

function refreshListButton() {
  const btn = $('[data-list]', el.detail);
  if (!btn || !current) return;
  const inList = library.has('watchlist', library.titleKey(current.type, current.id));
  btn.setAttribute('aria-pressed', inList);
  btn.textContent = inList ? '✓ Ma liste' : '+ Ma liste';
}

function refreshHeroPick() {
  const btn = $('[data-hero-pick]', el.detail);
  if (!btn || !current) return;
  const chosen = settings.home?.hero;
  const on = chosen?.type === current.type && chosen?.id === current.id;
  btn.setAttribute('aria-pressed', on);
  btn.textContent = on ? '★ À l’affiche' : '☆ À l’affiche';
}

function refreshLikeButton() {
  refreshListButton();
  const btn = $('[data-like]', el.detail);
  if (!btn || !current) return;
  const liked = library.has('likes', library.titleKey(current.type, current.id));
  btn.setAttribute('aria-pressed', liked);
  btn.textContent = liked ? '♥ Aimé' : '♡ J’aime';
}

// Après un J'aime : notification temporaire avec un bouton par plateforme de tes abonnements où le titre n'est
// pas encore liké (la page du titre s'ouvre, où est son pouce). Rien ne reste affiché dans la fiche.
let toastEntry = null;
function likeToast(entry, targets) {
  const seen = new Set();
  const chips = targets
    .filter((t) => t.platform && t.href && !library.isLikedOn(entry.type, entry.id, t.service, t.platform))
    .filter((t) => !seen.has(t.service || t.platform) && seen.add(t.service || t.platform))
    .map(
      (t) => `<button type="button" class="like-chip" data-platform-like data-platform="${esc(t.platform)}"
        data-service="${esc(t.service ?? '')}" data-href="${esc(t.href)}">${t.logo ? `<img src="${esc(t.logo)}" alt="">` : ''}${esc(shortPlatformName(t.platform))}</button>`,
    )
    .join('');
  if (!chips) return toast('Ajouté à J’aime.');
  toast('', null, {
    duration: 9000,
    custom: `<div class="like-pop">
      <div class="like-pop-head"><strong>♥ Ajouté à J’aime</strong>
        <button type="button" class="like-pop-close" data-toast-close aria-label="Fermer">✕</button></div>
      <p>Liker aussi sur</p>
      <div class="like-chips">${chips}</div>
    </div>`,
  });
  toastEntry = entry;
}

// Plateformes de tes abonnements où se trouve le titre de la fiche, avec la page du titre
const likeTargets = () =>
  [...el.detail.querySelectorAll('a.watch.mine')].map((a) => ({
    platform: a.dataset.platform,
    service: a.dataset.service,
    logo: $('img', a)?.getAttribute('src') ?? '',
    href: a.dataset.page || a.href.split('#')[0],
  }));

// « Liker aussi sur… » de la question « Tu as regardé… ? » : aucune plateforme ne permet de liker à distance, on
// ouvre la page du titre. Mêmes pastilles (logo + nom court) que la notification « Liker aussi sur ».
// Partout où un nom de plateforme s'affiche (les données gardent le nom TMDB, qui sert à reconnaître tes abonnements)
const SHORT_PLATFORM_NAMES = {
  amazonprimevideo: 'Prime Video',
  amazonprimevideowithads: 'Prime Video avec pub',
  disneyplus: 'Disney+',
  netflixbasicwithads: 'Netflix avec pub',
  netflixstandardwithads: 'Netflix avec pub',
  appletvplus: 'Apple TV+',
  paramountplus: 'Paramount+',
};
// Chaînes vendues sur une autre plateforme : « HBO Max Amazon Channel » → « HBO Max (Prime Video) »,
// « HBO Max Canal+ Channel » → « HBO Max (Canal+) »
const CHANNEL_HOSTS = { amazon: 'Prime Video', 'apple tv': 'Apple TV', 'canal+': 'Canal+' };
const channelName = (name) => {
  const m = /^(.*?)\s+(Amazon|Apple TV|Canal\+)\s+Channels?$/i.exec(String(name ?? ''));
  return m ? `${SHORT_PLATFORM_NAMES[squash(m[1])] ?? m[1]} (${CHANNEL_HOSTS[m[2].toLowerCase()]})` : null;
};
const shortPlatformName = (name) => SHORT_PLATFORM_NAMES[squash(name)] ?? channelName(name) ?? name;
// Logo d'une plateforme : celui de tes abonnements (Réglages), sinon celui du bouton de la fiche ouverte
function platformLogo(platform, service) {
  const p = settings.providers.find((x) => squash(x.name) === squash(platform) || (service && serviceFor(x.name)?.id === service));
  if (p?.logo) return img(providerLogo(p.name, p.logo), 'w92');
  const a = [...el.detail.querySelectorAll('a.watch')].find((x) => x.dataset.platform === platform);
  return a ? ($('img', a)?.getAttribute('src') ?? '') : '';
}
function platformLikeButtons(type, id, targets) {
  const seen = new Set();
  const chips = targets
    .filter((t) => t.platform && t.href && !seen.has(t.service || t.platform) && seen.add(t.service || t.platform))
    .map((t) => {
      const done = library.isLikedOn(type, id, t.service, t.platform);
      const logo = platformLogo(t.platform, t.service);
      return `<button type="button" class="like-chip ${done ? 'done' : ''}" data-platform-like
        data-platform="${esc(t.platform)}" data-service="${esc(t.service ?? '')}" data-href="${esc(t.href)}"
        aria-label="${done ? `Liké sur ${esc(t.platform)}` : `Liker aussi sur ${esc(t.platform)}`}"
        >${logo ? `<img src="${esc(logo)}" alt="">` : ''}${done ? '✓ ' : ''}${esc(shortPlatformName(t.platform))}</button>`;
    })
    .join('');
  return chips && `<span class="platform-likes-label">Liker aussi sur</span>${chips}`;
}

const plural = (n, one, many) => `${n} ${n > 1 ? many : one}`;

// Ligne d'infos sous le titre : année(s), durée ou nombre de saisons, genres
function metaLine(item, type) {
  const genres = item.genres?.map((g) => g.name).join(', ');
  if (type === 'tv') {
    const start = year(item.first_air_date);
    const end = item.in_production ? 'en cours' : year(item.last_air_date);
    const years = start && end && end !== start ? `${start} – ${end}` : start;
    return [
      years,
      item.number_of_seasons ? plural(item.number_of_seasons, 'saison', 'saisons') : '',
      item.number_of_episodes ? plural(item.number_of_episodes, 'épisode', 'épisodes') : '',
      genres,
    ].filter(Boolean);
  }
  const runtime = item.runtime ? `${Math.floor(item.runtime / 60)} h ${String(item.runtime % 60).padStart(2, '0')}` : '';
  return [releaseDate(item.release_date, true), runtime, genres].filter(Boolean);
}

// Une saison affichée : { number, name, count, airDate, poster, origSeason, episodes? }
// - number : numéro affiché (celui de la plateforme quand on suit un groupe d'épisodes)
// - origSeason : saison TMDB d'origine, qui sert à retrouver les liens Streaming Availability
// - episodes : déjà connus pour un groupe d'épisodes ; sinon chargés à l'ouverture de la saison

// Le découpage par défaut de TMDB : saisons régulières d'abord, épisodes spéciaux (saison 0) à la fin
function tmdbSeasons(item) {
  return [...(item.seasons ?? [])]
    .filter((s) => s.episode_count > 0)
    .sort((a, b) => (a.season_number || 999) - (b.season_number || 999))
    .map((s) => ({ number: s.season_number, name: s.name, count: s.episode_count, airDate: s.air_date, poster: s.poster_path, origSeason: s.season_number }));
}

// Un groupe d'épisodes TMDB (ex. « TF1+ » pour Demain nous appartient : 10 saisons au lieu de 3)
function groupSeasons(group, item) {
  return [...group.groups]
    .sort((a, b) => a.order - b.order)
    .filter((g) => g.episodes?.length)
    .map((g, i) => {
      const episodes = [...g.episodes].sort((a, b) => a.order - b.order).map((e, j) => ({ ...e, display_number: j + 1 }));
      return {
        number: i + 1,
        name: /^(season|saison) \d+$/i.test(g.name.trim()) ? `Saison ${i + 1}` : g.name,
        count: episodes.length,
        airDate: episodes[0].air_date,
        poster: seasonImage(episodes, item),
        origSeason: episodes[0].season_number,
        episodes,
      };
    });
}

// Image d'une saison d'un groupe : une affiche (format portrait), jamais une image d'épisode (paysage,
// illisible une fois recadrée). Celle de la saison TMDB d'origine, sinon celle de la série.
function seasonImage(episodes, item) {
  const tmdb = item.seasons?.find((s) => s.season_number === episodes[0].season_number);
  return tmdb?.poster_path ?? item.poster_path ?? null;
}

// Un groupe d'épisodes n'est pas toujours à jour (ex. saison 10 de Demain nous appartient : 2 épisodes
// dans le groupe, 40 chez TMDB). On ajoute les épisodes TMDB manquants à la saison qui les précède.
async function completeGroupSeasons(seasons, item) {
  const covered = new Set(seasons.flatMap((s) => s.episodes.map((e) => `${e.season_number}:${e.episode_number}`)));
  for (const tmdbSeason of item.seasons ?? []) {
    const n = tmdbSeason.season_number;
    if (!n) continue; // épisodes spéciaux
    const known = seasons.flatMap((s) => s.episodes).filter((e) => e.season_number === n).length;
    if (known >= tmdbSeason.episode_count) continue;
    const full = await api.season(item.id, n).catch(() => null);
    const missing = (full?.episodes ?? []).filter((e) => !covered.has(`${n}:${e.episode_number}`));
    if (!missing.length) continue;
    const target = [...seasons].reverse().find((s) => s.episodes.some((e) => e.season_number === n)) ?? seasons.at(-1);
    for (const e of missing) target.episodes.push({ ...e, display_number: target.episodes.length + 1 });
    target.count = target.episodes.length;
  }
  return seasons;
}

function seasonsHtml() {
  const seasons = current?.seasons ?? [];
  if (!seasons.length) return '<section class="seasons" hidden></section>';
  const choices = current.groupChoices ?? [];
  const picker = choices.length
    ? `<select class="season-source" data-episode-group aria-label="Découpage des saisons">
        <option value="tmdb">Découpage TMDB</option>
        ${choices.map((g) => `<option value="${esc(g.id)}">Découpage ${esc(g.name)} · ${plural(g.group_count, 'saison', 'saisons')}</option>`).join('')}
      </select>`
    : '';
  return `<section class="seasons" aria-label="Saisons">
    ${picker ? `<div class="seasons-head">${picker}</div>` : ''}
    <ol class="season-list">
      ${seasons
        .map(
          (s) => `<li class="season${s.fillers && s.fillers === s.count ? ' filler' : ''}" data-season="${s.number}" data-orig-season="${s.origSeason}">
            <button type="button" class="season-head" data-season-toggle="${s.number}" aria-expanded="false">
              ${s.poster ? `<img src="${img(s.poster, 'w92')}" alt="" loading="lazy">` : '<span class="season-placeholder"></span>'}
              <span class="season-text">
                <strong>${esc(s.name)}</strong>
                <small>${[plural(s.count, 'épisode', 'épisodes'), year(s.airDate)].filter(Boolean).join(' · ')}</small>
                ${s.fillers ? `<small class="season-fillers">${s.fillers === s.count ? 'Que des fillers' : plural(s.fillers, 'filler', 'fillers')}</small>` : ''}
                <small class="season-platforms"></small>
              </span>
              <svg class="chevron" viewBox="0 0 24 24" aria-hidden="true"><path d="m6 9 6 6 6-6"/></svg>
            </button>
            <div class="episodes" hidden></div>
          </li>`,
        )
        .join('')}
    </ol>
    ${settings.saKey ? '' : '<p class="hint">Avec une clé Streaming Availability, chaque épisode a son bouton pour le lancer directement.</p>'}
  </section>`;
}

const frDate = (date) =>
  date ? new Date(`${date}T12:00:00`).toLocaleDateString('fr-FR', { day: 'numeric', month: 'long', year: 'numeric' }) : '';

function episodeHtml(ep) {
  const upcoming = ep.air_date && ep.air_date > new Date().toISOString().slice(0, 10);
  const number = ep.display_number ?? ep.episode_number;
  return `<li class="episode${ep.filler ? ' filler' : ''}" data-episode="${number}" data-orig-season="${ep.season_number}" data-orig-episode="${ep.episode_number}" data-air="${esc(ep.air_date ?? '')}">
    ${ep.still_path ? `<img src="${img(ep.still_path, 'w300')}" alt="" loading="lazy">` : '<span class="episode-placeholder"></span>'}
    <div class="episode-text">
      <strong>${number}. ${esc(ep.name)}${ep.filler ? '<span class="filler-tag">Filler</span>' : ''}</strong>
      <small>${[ep.filler != null ? `épisode ${ep.episode_number}` : '', upcoming ? `Diffusion le ${frDate(ep.air_date)}` : frDate(ep.air_date), ep.runtime ? `${ep.runtime} min` : ''].filter(Boolean).join(' · ')}</small>
      <p class="episode-overview">${esc(ep.overview || 'Pas encore de résumé en français.')}</p>
      <div class="episode-links"></div>
    </div>
  </li>`;
}

// Découpage « Netflix - Sans filler » (Naruto, Naruto Shippuden ; demande de l'utilisateur) : saisons et épisodes
// hors-série d'après la liste d'animotaku.fr, dans fillers.json (numérotation absolue, la même que TMDB)
const FILLER_GROUP = 'fillers';
let fillersData;
let fillersLoaded = null; // la même liste, une fois arrivée (pour les liens d'épisodes)
const loadFillers = () =>
  (fillersData ??= fetch('fillers.json')
    .then((res) => (res.ok ? res.json() : null))
    .then((data) => (fillersLoaded = data))
    .catch(() => null));
// Liens Netflix de chaque épisode (netflix-episodes.json : Naruto, Shippuden, Boruto). Streaming Availability et
// JustWatch ne connaissent que les 15 premiers épisodes de Boruto sur Netflix, qui les a tous (signalé par
// l'utilisateur) ; identifiants relevés depuis sa session Netflix
let netflixData;
let netflixLoaded = null;
const loadNetflixEpisodes = () =>
  (netflixData ??= fetch('netflix-episodes.json')
    .then((res) => (res.ok ? res.json() : null))
    .then((data) => (netflixLoaded = data))
    .catch(() => null));
const netflixEpisodeId = (epEl) =>
  netflixLoaded?.shows?.[current?.id]?.episodes?.[`${epEl.dataset.origSeason}:${epEl.dataset.origEpisode}`] ?? null;

// Le bouton Netflix de l'épisode, avec son lien de lecture, à la place de celui de Streaming Availability
function withNetflixEpisode(options, epEl) {
  const id = netflixEpisodeId(epEl);
  if (!id || !myServices().has('netflix')) return options;
  const isNetflix = (o) => o.service === 'netflix' && !o.addon;
  const base = options.find(isNetflix) ?? (current.links?.options ?? []).find(isNetflix);
  const page = `https://www.netflix.com/title/${netflixLoaded.shows[current.id].netflix}`;
  const netflix = { service: 'netflix', name: base?.name ?? 'Netflix', type: 'subscription', addon: null, link: page, videoLink: `https://www.netflix.com/watch/${id}` };
  return [netflix, ...options.filter((o) => !isNetflix(o))];
}

// Épisode absent d'une plateforme alors que Streaming Availability en donne un lien (Boruto 11 à 15 sur Netflix,
// signalé par l'utilisateur : Netflix relançait le dernier épisode regardé à la place)
const unavailableOn = (service, episode) =>
  inRanges(episode, fillersLoaded?.shows?.[current?.id]?.unavailable?.[service] ?? []);
const inRanges = (n, ranges) => ranges.some(([first, last]) => n >= first && n <= last);

async function fillerSeasons(item, def) {
  const numbers = (item.seasons ?? []).map((s) => s.season_number).filter((n) => n > 0);
  const all = (await Promise.all(numbers.map((n) => api.season(item.id, n).catch(() => null)))).flatMap((s) => s?.episodes ?? []);
  return def.seasons
    .map(([number, first, last]) => {
      const episodes = all
        .filter((e) => e.episode_number >= first && e.episode_number <= last)
        .sort((a, b) => a.episode_number - b.episode_number)
        .map((e, j) => ({ ...e, display_number: j + 1, filler: inRanges(e.episode_number, def.fillers) }));
      // Titre de la saison sur Netflix quand il y en a un (Boruto : « Saison 1 · Débuts à l'académie ninja »)
      const title = def.seasonNames?.[number];
      return { number, name: title ? `Saison ${number} · ${title}` : `Saison ${number}`, episodes, fillers: episodes.filter((e) => e.filler).length };
    })
    .filter((s) => s.episodes.length)
    .map((s) => ({ ...s, count: s.episodes.length, airDate: s.episodes[0].air_date, poster: seasonImage(s.episodes, item), origSeason: s.episodes[0].season_number }));
}

// Autres découpages proposés sur TMDB. Si l'un porte le nom d'une plateforme où la série est disponible
// (ex. « TF1+ »), on l'utilise d'office : ce sont les saisons que tu verras sur cette plateforme. Le découpage
// « Sans filler » passe avant, quand la série en a un.
async function loadEpisodeGroups(item, key) {
  const [found, fillers] = await Promise.all([api.episodeGroups(item.id).catch(() => []), loadFillers(), loadNetflixEpisodes()]);
  const def = fillers?.shows?.[item.id];
  const groups = def ? [{ id: FILLER_GROUP, name: def.name, group_count: def.seasons.length }, ...found] : found;
  if (current?.key !== key || !groups.length) return;
  current.groupChoices = groups;
  if (def) return selectEpisodeGroup(FILLER_GROUP, key);
  const platforms = streamable(item['watch/providers']?.results?.[settings.region]).map((p) => p.provider_name.toLowerCase());
  const matches = (g) => platforms.some((p) => p === g.name.trim().toLowerCase() || p.startsWith(`${g.name.trim().toLowerCase()} `));
  const preferred = groups.find(matches);
  if (preferred) await selectEpisodeGroup(preferred.id, key);
  else renderSeasons();
}

async function selectEpisodeGroup(id, key = current?.key) {
  try {
    current.seasons =
      id === 'tmdb'
        ? tmdbSeasons(current.item)
        : id === FILLER_GROUP
          ? await fillerSeasons(current.item, (await loadFillers()).shows[current.id])
          : await completeGroupSeasons(groupSeasons(await api.episodeGroup(id), current.item), current.item);
    current.groupId = id;
  } catch (err) {
    toast(err.message);
  }
  if (current?.key === key) renderSeasons();
}

// Redessine la liste des saisons (après un changement de découpage)
function renderSeasons() {
  const section = $('.seasons', el.detail);
  if (!section) return;
  section.outerHTML = seasonsHtml();
  const picker = $('[data-episode-group]', el.detail);
  if (picker) picker.value = current.groupId ?? 'tmdb';
  if (current.links || current.linksState !== 'loading') applySeasonLinks();
}

el.detail.addEventListener('change', (e) => {
  const picker = e.target.closest('[data-episode-group]');
  if (picker) selectEpisodeGroup(picker.value);
});

// Clic sur une saison : ouvre / ferme sa liste d'épisodes (chargée la première fois)
async function toggleSeason(btn) {
  const number = Number(btn.dataset.seasonToggle);
  const box = btn.nextElementSibling;
  const open = btn.getAttribute('aria-expanded') !== 'true';
  btn.setAttribute('aria-expanded', open);
  box.hidden = !open;
  if (!open || box.dataset.loaded) return;
  box.dataset.loaded = 'true';
  box.innerHTML = '<p class="muted">Chargement des épisodes…</p>';
  const key = current?.key;
  try {
    const def = current.seasons.find((s) => s.number === number);
    const season = def?.episodes ? { episodes: def.episodes } : await api.season(current.id, def?.origSeason ?? number);
    if (current?.key !== key) return;
    if (!season.episodes?.length) {
      box.innerHTML = '<p class="muted">Pas encore d’épisodes annoncés.</p>';
      return;
    }
    box.episodes = season.episodes;
    box.innerHTML = '<ol class="episode-list"></ol>';
    showMoreEpisodes(box);
  } catch (err) {
    delete box.dataset.loaded;
    box.innerHTML = `<p class="muted">${esc(err.message)}</p>`;
  }
}

// Certaines séries quotidiennes ont des saisons de plusieurs milliers d'épisodes chez TMDB
// (ex. Demain nous appartient : 2 020 dans la « Saison 1 ») : on les affiche par paquets.
const EPISODES_PER_BATCH = 50;

function showMoreEpisodes(box) {
  const list = $('.episode-list', box);
  const shown = list.children.length;
  const next = box.episodes.slice(shown, shown + EPISODES_PER_BATCH);
  list.insertAdjacentHTML('beforeend', next.map(episodeHtml).join(''));
  $('.more-episodes', box)?.remove();
  const left = box.episodes.length - list.children.length;
  if (left > 0) {
    box.insertAdjacentHTML(
      'beforeend',
      `<button type="button" class="btn more-episodes" data-more-episodes>Afficher ${Math.min(left, EPISODES_PER_BATCH)} épisodes de plus <span class="muted">(${left} restants)</span></button>`,
    );
  }
  fillEpisodeLinks(Number(box.closest('.season').dataset.season));
}

// Numéro d'épisode depuis le début de la série (saisons dans l'ordre, sans les épisodes spéciaux)
function absoluteEpisode(season, episode) {
  let before = 0;
  for (const s of current.seasons ?? []) {
    if (!s.number) continue;
    if (s.number === season) return before + episode;
    before += s.count;
  }
  return null;
}

// Lien direct vers l'épisode sur la plateforme, quand on sait le retrouver (TF1+, M6+ : grâce à l'index)
function directEpisodeLink(entry, seasonEl, epEl, number) {
  const platform = hostServiceFor(entry.name)?.id;
  if (!INDEXED_PLATFORMS.has(platform)) return null;
  const key = current.key;
  const season = Number(seasonEl.dataset.season);
  const episode = Number(epEl.dataset.episode);
  const titles = [titleOf(current.item), originalTitleOf(current.item)];
  const redraw = () => current?.key === key && fillEpisodeLinks(number); // une fois l'index chargé
  return platformEpisodeUrl(platform, titles, {
    season,
    episode,
    origSeason: Number(epEl.dataset.origSeason),
    origEpisode: Number(epEl.dataset.origEpisode),
    airDate: epEl.dataset.air,
    absolute: absoluteEpisode(season, episode),
  }, redraw) ?? null;
}

// Une option Streaming Availability est-elle dans tes abonnements ? Une option « addon » (une chaîne
// vendue en plus, ex. Crunchyroll sur Prime Video) ne l'est que si tu as coché cette chaîne.
// « France.tv » → « francetv » : pour comparer des noms de plateformes écrits différemment
const squash = (name) => String(name ?? '').toLowerCase().replace(/[^a-z0-9]/g, '');

function isMineOption(o) {
  if (o.type === 'addon') {
    const addon = squash(o.addon);
    return Boolean(addon) && settings.providers.some((p) => squash(p.name).includes(addon));
  }
  return myServices().has(o.service);
}

// Options de streaming par abonnement, une par plateforme (ou chaîne), tes abonnements en premier
function streamOptions(options) {
  const seen = new Set();
  const key = (o) => `${o.service}:${o.addon ?? ''}`;
  return options
    .filter((o) => STREAM_TYPES.has(o.type) && !seen.has(key(o)) && seen.add(key(o)))
    .sort((a, b) => Number(isMineOption(b)) - Number(isMineOption(a)));
}

function playLink(o, label, { download = false } = {}) {
  const mine = isMineOption(o);
  return `<a class="episode-play ${mine ? 'mine' : ''}" href="${esc(o.videoLink ?? autoplayLink(o.link) ?? o.link)}" target="${platformTarget(o.service ?? o.name)}"
    data-platform="${esc(o.name)}" data-service="${esc(o.service ?? '')}" data-page="${esc(o.link ?? '')}">▶ ${esc(label ?? o.name)}${o.addon ? ` <span>(${esc(o.addon)})</span>` : ''}</a>${
    download && mine && CAN_DOWNLOAD ? downloadButton({ platform: o.name, service: o.service, href: o.link, compact: true }) : ''
  }`;
}

// Boutons de lecture sous chaque épisode d'une saison ouverte
function fillEpisodeLinks(number) {
  const seasonEl = el.detail.querySelector(`.season[data-season="${number}"]`);
  if (!seasonEl || !current) return;
  const saSeasonOf = (n) => current.links?.seasons.find((s) => s.number === n);
  const seasonOptions = streamOptions(saSeasonOf(Number(seasonEl.dataset.origSeason))?.options ?? []);
  for (const epEl of seasonEl.querySelectorAll('.episode')) {
    const box = epEl.querySelector('.episode-links');
    const saEpisode = saSeasonOf(Number(epEl.dataset.origSeason))?.episodes.find((e) => e.number === Number(epEl.dataset.origEpisode));
    const options = withNetflixEpisode(
      streamOptions(saEpisode?.options ?? []).filter((o) => !unavailableOn(o.service, Number(epEl.dataset.origEpisode))),
      epEl,
    );
    if (options.length) {
      // Tes plateformes qui ont la série mais pas de lien pour cet épisode (Streaming Availability ne connaît que les
      // 15 premiers épisodes de Boruto sur Netflix, qui les a tous) : bouton vers la page de la série
      const same = (a, b) => a.service === b.service && (a.addon ?? '') === (b.addon ?? '');
      const missing = streamOptions(current.links?.options ?? []).filter((o) => isMineOption(o) && o.link && !options.some((x) => same(x, o)));
      box.innerHTML =
        options.map((o) => playLink(o, undefined, { download: true })).join('') +
        missing.map((o) => playLink({ ...o, videoLink: o.link }, `${shortPlatformName(o.name)} · page de la série`)).join('');
    } else if (seasonOptions.length) {
      // Pas de lien pour cet épisode précis : on propose au moins la saison
      box.innerHTML = seasonOptions.map((o) => playLink(o, `La saison sur ${shortPlatformName(o.name)}`)).join('');
    } else if (current.linksState === 'loading') {
      box.innerHTML = '<span class="muted">Recherche des liens…</span>';
    } else if (!current.entries.length) {
      box.innerHTML = '<span class="muted">Pas disponible en streaming par abonnement</span>';
    } else {
      // Pas de lien par épisode (pas de clé Streaming Availability, ou série qu'elle ne connaît pas, comme
      // beaucoup de programmes de TF1+ ou M6+) : on renvoie vers la série sur tes plateformes
      box.innerHTML = current.entries
        .map((e) => {
          const direct = directEpisodeLink(e, seasonEl, epEl, number);
          const list = episodesLink(e.name, titleOf(current.item));
          const href = direct ?? list ?? e.href;
          const name = shortPlatformName(e.name);
          const label = direct ? `▶ ${name}` : list ? `Voir les épisodes sur ${name}` : `Ouvrir la série sur ${name}`;
          return `<a class="episode-play mine" href="${esc(href)}" target="${platformTarget(e.service ?? e.name)}" data-platform="${esc(e.name)}">${esc(label)}</a>${CAN_DOWNLOAD ? downloadButton({ platform: e.name, service: e.service, href, compact: true }) : ''}`;
        })
        .join('');
    }
  }
  refreshDownloadButtons();
}

// Section « Où regarder » de la fiche : boutons des plateformes, rangés par abonnement
function watchSectionHtml(item, type) {
  const w = words(type);
  const { entries, tmdbLink } = watchEntries(item, type);
  const mine = entries.filter((e) => e.mine);
  if (current) current.entries = mine;
  const others = entries.filter((e) => !e.mine && e.kind !== 'rent' && e.kind !== 'buy');
  const paid = entries.filter((e) => e.kind === 'rent' || e.kind === 'buy');
  const unlisted = entries.filter((e) => e.unlisted);

  let watchHtml;
  if (!entries.length) {
    watchHtml = `<p class="muted">${w.this} n’est disponible sur aucune plateforme de streaming dans ce pays pour le moment.
      <a href="${esc(tmdbLink)}" target="_blank" rel="noopener">Vérifier sur TMDB</a></p>`;
  } else {
    watchHtml = `
      ${mine.length ? `<h3>Dans tes abonnements</h3><div class="watch-list" data-section="mine">${mine.map((e) => watchButton(e, { download: type === 'movie' })).join('')}</div>` : ''}
      ${mine.length && !CAN_DOWNLOAD ? `<p class="hint download-hint">⬇ Pour ${type === 'tv' ? 'télécharger ses épisodes' : 'le télécharger'}, passe par l’appli ${esc(platformList(mine))} sur ton téléphone ou ta tablette, si le titre le permet.</p>` : ''}
      ${!mine.length && settings.providers.length ? `<p class="muted">${w.this} n’est ${w.included} dans aucun de tes abonnements.</p>` : ''}
      ${others.length && mine.length ? `<details class="paid"><summary>Aussi disponible sur (${others.length})</summary><div class="watch-list" data-section="others">${others.map(watchButton).join('')}</div></details>` : ''}
      ${others.length && !mine.length ? `<h3>Disponible sur</h3><div class="watch-list" data-section="others">${others.map(watchButton).join('')}</div>` : ''}
      ${paid.length ? `<details class="paid"><summary>Location et achat (${paid.length})</summary><div class="watch-list">${paid.map(watchButton).join('')}</div></details>` : ''}`;
  }
  // Offre ajoutée par StreamHub (JustWatch ne la référence pas encore dans le pays) : on le dit
  const names = esc(platformList(unlisted.map((e) => ({ name: shortPlatformName(e.name) }))) ?? '');
  const unlistedHint = !unlisted.length
    ? ''
    : unlisted.every((e) => e.unlisted === 'network')
      ? `<p class="hint">Pas encore référencé${type === 'tv' ? 'e' : ''} dans ce pays par JustWatch : ${names} ajouté d’après son diffuseur, en attendant.</p>`
      : `<p class="hint">Pas encore référencé${type === 'tv' ? 'e' : ''} dans ce pays par JustWatch : ${names} ajouté d’après Streaming Availability.</p>`;
  return `<section class="watch-section" aria-label="Où regarder">
        ${watchHtml}
        ${unlistedHint}
        ${entries.length && !settings.saKey ? `<p class="hint">Astuce : ajoute une clé Streaming Availability dans les réglages pour ouvrir directement ${type === 'tv' ? 'la série' : 'le film'} au lieu d’une recherche.</p>` : ''}
      </section>`;
}

// Plateformes que Streaming Availability donne dans le pays mais que TMDB (JustWatch) n'a pas encore : ajoutées à la
// fiche, puis la section « Où regarder » est redessinée (les liens directs sont posés juste après)
function addSaOffers(options) {
  const results = current?.item?.['watch/providers']?.results ?? {};
  const before = results[settings.region] ?? null;
  const after = withSaOffers(before, options);
  if (after === before) return;
  (current.item['watch/providers'] ??= { results }).results[settings.region] = withVirtualChannels(after, settings.region);
  $('.watch-section', el.detail).outerHTML = watchSectionHtml(current.item, current.type);
  applyCanalChannels();
  refreshLikeButton();
  refreshDownloadButtons();
}

function renderDetail(item, type) {
  const title = titleOf(item);
  const originalTitle = originalTitleOf(item);
  const trailer = item.videos?.results?.find((v) => v.site === 'YouTube' && v.type === 'Trailer');
  const makers =
    type === 'tv'
      ? (item.created_by ?? []).map((c) => c.name)
      : (item.credits?.crew ?? []).filter((c) => c.job === 'Director').map((c) => c.name);
  const cast = item.credits?.cast?.slice(0, 5).map((c) => c.name) ?? [];
  const meta = metaLine(item, type);

  setDetailHtml(`
    <div class="detail-hero" style="${item.backdrop_path ? `background-image:url('${img(item.backdrop_path, 'w1280')}')` : ''}"></div>
    <div class="detail-body">
      <div class="detail-head">
        ${item.poster_path ? `<img class="detail-poster" src="${img(item.poster_path)}" alt="">` : ''}
        <div>
          <span class="type-badge">${type === 'tv' ? 'Série' : 'Film'}</span>
          <h2>${esc(title)}</h2>
          ${originalTitle && originalTitle !== title ? `<p class="muted">${esc(originalTitle)}</p>` : ''}
          <p class="detail-meta">${meta.map(esc).join(' · ')}${item.vote_count ? ` · <span class="rating">★ ${item.vote_average.toFixed(1)}</span>` : ''}</p>
          <div class="detail-actions">
            <button type="button" class="btn list-btn" data-list aria-pressed="false">+ Ma liste</button>
            <button type="button" class="btn like-btn" data-like aria-pressed="false">♡ J’aime</button>
            <button type="button" class="btn hero-pick" data-hero-pick aria-pressed="false" title="Mettre ce titre en grand en haut de l’accueil">☆ À l’affiche</button>
            ${trailer ? `<a class="btn" href="https://www.youtube.com/watch?v=${esc(trailer.key)}" target="_blank" rel="noopener">▶ Bande-annonce</a>` : ''}
          </div>
        </div>
      </div>
      ${watchSectionHtml(item, type)}
      ${item.tagline ? `<p class="tagline">${esc(item.tagline)}</p>` : ''}
      ${item.overview ? `<p class="overview">${esc(item.overview)}</p>` : ''}
      ${makers.length || cast.length ? `<dl class="credits">
        ${makers.length ? `<dt>${type === 'tv' ? 'Création' : 'Réalisation'}</dt><dd>${makers.map(esc).join(', ')}</dd>` : ''}
        ${cast.length ? `<dt>Avec</dt><dd>${cast.map(esc).join(', ')}</dd>` : ''}</dl>` : ''}
      ${detailTabsHtml(type)}
    </div>`);
  if (!$('#panel-suggestions', el.detail).hidden) loadSuggestions();
  refreshLikeButton();
  refreshHeroPick();
  refreshDownloadButtons();
  $('.watch', el.detail)?.focus({ preventScroll: true });
  if (!$('.watch', el.detail)) el.detail.focus({ preventScroll: true });
}

// Onglets sous la description : « Épisodes » (séries, ouvert d'abord) et « Suggestions » (seul onglet d'un film).
// Les suggestions d'une série sont cherchées à la première ouverture de leur onglet.
function detailTabsHtml(type) {
  const episodes = type === 'tv' && current?.seasons?.length > 0;
  const tabs = [episodes && ['episodes', 'Épisodes'], ['suggestions', 'Suggestions']].filter(Boolean);
  return `<div class="detail-tabs" role="tablist" aria-label="Plus sur ce titre">
      ${tabs.map(([key, label], i) => `<button type="button" role="tab" id="tab-${key}" aria-controls="panel-${key}" aria-selected="${i === 0}" data-detail-tab="${key}">${label}</button>`).join('')}
    </div>
    ${type === 'tv' ? `<div class="tab-panel" role="tabpanel" id="panel-episodes" aria-labelledby="tab-episodes" ${episodes ? '' : 'hidden'}>${seasonsHtml()}</div>` : ''}
    <div class="tab-panel" role="tabpanel" id="panel-suggestions" aria-labelledby="tab-suggestions" ${episodes ? 'hidden' : ''}></div>`;
}

function selectDetailTab(key) {
  for (const tab of el.detail.querySelectorAll('[data-detail-tab]')) {
    const on = tab.dataset.detailTab === key;
    tab.setAttribute('aria-selected', on);
    $(`#panel-${tab.dataset.detailTab}`, el.detail).hidden = !on;
  }
  if (key === 'suggestions') loadSuggestions();
}

// Rangées de l'onglet Suggestions : la saga, le même univers, puis le même genre (voir suggestions.js). Cherchées en même
// temps, affichées dans cet ordre dès qu'elles arrivent, sans doublons.
async function loadSuggestions() {
  const panel = $('#panel-suggestions', el.detail);
  if (!panel || panel.dataset.loaded) return;
  panel.dataset.loaded = 'true';
  panel.innerHTML = '<p class="muted suggest-status">Recherche des suggestions…</p>';
  const { key, item, type } = current;
  const saga = sagaTitles(api, item).catch(() => ({ items: [] }));
  const universe = saga.then((s) => universeTitles(api, item, type, new Set(s.items.map((m) => `movie:${m.id}`)))).catch(() => []);
  const genre = genreTitles(api, item, type).then(availableFirst).catch(() => []);
  const shown = new Set([key]);
  const add = (title, items) => {
    if (current?.key !== key) return;
    const fresh = items.filter((m) => !shown.has(`${m.media_type}:${m.id}`));
    if (!fresh.length) return;
    fresh.forEach((m) => shown.add(`${m.media_type}:${m.id}`));
    $('.suggest-status', panel)?.before(suggestionRow(title, fresh));
  };
  const s = await saga;
  add(s.name ? `La saga ${s.name}` : 'La saga', s.items);
  add('Dans le même univers', await universe);
  add('Dans le même genre', (await genre).slice(0, 20));
  if (current?.key !== key) return;
  const status = $('.suggest-status', panel);
  if (panel.querySelector('.row')) status?.remove();
  else if (status) status.textContent = 'Pas de suggestion pour ce titre.';
}

// Titres du même genre : ceux de tes abonnements d'abord (mêmes offres que les rangées et les affiches)
async function availableFirst(items) {
  const filter = defaultFilter();
  if (filter === 'all') return items;
  const offers = await Promise.all(items.map((m) => api.offers(m.media_type, m.id).catch(() => null)));
  const mine = items.filter((m, i) => matchesFilter(offers[i], filter));
  return [...mine, ...items.filter((m) => !mine.includes(m))];
}

function suggestionRow(title, items) {
  const section = document.createElement('section');
  section.className = 'row suggest-row';
  section.innerHTML = `
    <div class="row-head"><h3>${esc(title)}</h3></div>
    <div class="row-body">
      <button type="button" class="row-arrow prev" data-row-scroll="-1" tabindex="-1" aria-label="Défiler vers la gauche">‹</button>
      <div class="row-track"></div>
      <button type="button" class="row-arrow next" data-row-scroll="1" tabindex="-1" aria-label="Défiler vers la droite">›</button>
    </div>`;
  const track = $('.row-track', section);
  for (const m of items) {
    const card = buildCard(m, { typeTag: true });
    track.append(card);
    logoObserver.observe(card);
  }
  return section;
}

// ---------- Lancement sur une plateforme ----------

const relaunchShown = new Set(); // plateformes déjà proposées pendant cette visite

// Au premier lancement sur une plateforme, elle peut demander de choisir un profil ou de se connecter
// et oublier le titre demandé. La barre « Relancer » renvoie l'onglet de la plateforme directement dessus.
function offerRelaunch(link, platform, label) {
  if (hasResumeExtension()) return; // l'extension reprend le titre toute seule après la connexion
  const key = link.target;
  if (relaunchShown.has(key)) return;
  relaunchShown.add(key);
  const bar = $('#relaunch');
  bar.innerHTML = `
    <p><strong>${esc(shortPlatformName(platform))}</strong> t’a demandé de choisir un profil ou de te connecter ? Une fois fait :</p>
    <a class="btn primary" href="${esc(link.href)}" target="${esc(link.target)}" data-relaunch>▶ Relancer ${esc(label)}</a>
    <button type="button" class="icon-btn" data-relaunch-close aria-label="Fermer">✕</button>`;
  showRelaunch(true);
  clearTimeout(offerRelaunch.timer);
  offerRelaunch.timer = setTimeout(() => showRelaunch(false), 3 * 60 * 1000);
}

// Les barres du bas (« Relancer », « Tu as regardé… ? ») sont des « popovers », affichés au premier plan.
// Une fenêtre modale (fiche, réglages) rend inactif tout ce qui est en dehors d'elle : une barre est donc
// placée dans la fenêtre ouverte, et revient dans la page quand celle-ci se ferme.
const BARS = ['#relaunch', '#confirm', '#toast'];
const isShown = (node) => (node.matches?.(':popover-open') ?? false) || (!('showPopover' in node) && !node.hidden);

function togglePopover(node, visible) {
  if (!('showPopover' in node)) {
    if (visible) (document.querySelector('dialog[open]') ?? document.body).append(node);
    node.hidden = !visible;
    return;
  }
  node.hidden = false;
  if (node.matches(':popover-open')) node.hidePopover(); // remis au premier plan si on le réaffiche
  if (!visible) return;
  const host = document.querySelector('dialog[open]') ?? document.body;
  if (node.parentElement !== host) host.append(node);
  node.showPopover();
}

// À l'ouverture ou la fermeture d'une fenêtre : les barres affichées suivent
// La fiche se redessine en remplaçant son contenu : les barres qu'elle héberge sont mises de côté puis remises
function setDetailHtml(html) {
  const body = $('#detailBody');
  const hosted = BARS.map((sel) => $(sel)).filter((node) => body.contains(node));
  const shown = hosted.filter(isShown);
  body.innerHTML = html;
  body.scrollTop = 0;
  for (const node of hosted) {
    if (shown.includes(node)) togglePopover(node, true);
    else document.body.append(node);
  }
}

function rehostBars() {
  for (const sel of BARS) {
    const node = $(sel);
    if (isShown(node)) togglePopover(node, true);
  }
}

const showRelaunch = (visible) => togglePopover($('#relaunch'), visible);

// Ordinateur : réglage « Ouvrir les titres » (Prime Video pour l'instant). Dans l'appli : le lien web est remplacé par
// l'adresse de l'appli (voir desktopAppLink). Sur le site : par une adresse que l'appli ne revendique pas, sinon
// Safari l'ouvrirait quand même dans l'appli (voir desktopWebLink). « primeApp » : nom du réglage avant la version 42.
const wantsDesktopApps = () => !CAN_DOWNLOAD && Boolean(settings.desktopApps ?? settings.primeApp);
function toDesktopApp(link) {
  if (CAN_DOWNLOAD) return;
  if (!wantsDesktopApps()) {
    link.href = desktopWebLink(link.href, { play: true }) ?? link.href;
    return;
  }
  const app = desktopAppLink(link.href);
  if (!app) return;
  link.href = app;
  link.target = '_self'; // ouvre l'appli sans laisser d'onglet vide
}

// Extension « reprise après connexion » (dossier extension/) : on joint au lien l'adresse voulue,
// dans le fragment « #streamhub=… » que le navigateur conserve pendant la redirection vers la page de
// connexion. Une fois connecté et le profil choisi, l'extension ouvre le titre au lieu de l'accueil.
const hasResumeExtension = () => document.documentElement.dataset.streamhubExtension === '1';

// play : la page s'ouvre sans lancer la lecture (Disney+, série) ; le script appuiera sur « Reprendre » / « Lecture »
function withResume(url, { play = false } = {}) {
  if (!/^https:\/\//.test(url) || url.includes('#streamhub=')) return url;
  return `${url.split('#')[0]}#streamhub=${encodeURIComponent(url.split('#')[0])}${play ? '&play=1' : ''}`;
}

// Appli web de l'écran d'accueil (iPhone, iPad) : on ouvre le lien du titre directement, sans page
// intermédiaire. Vérifié sur le simulateur iOS : depuis l'appli web, un lien universel (apple.news, plans)
// ouvre l'appli correspondante, que ce soit un lien simple, target=_blank ou location.href. Si l'appli de la
// plateforme n'est pas installée, iOS ouvre son site. Renvoie false hors de ce mode.
// Appli de l'écran d'accueil (iPhone, iPad) : les liens des plateformes sont mis tout de suite sous la forme
// qu'iOS reconnaît comme lien de l'appli (voir iosLink). C'est l'adresse affichée dans la page qui compte, aussi
// pour l'appui long (« Ouvrir dans Netflix »…) : on la corrige dès que la fiche l'affiche ou la change.
function fixIosLinks(root) {
  for (const a of root.querySelectorAll('a.watch, a.episode-play, a.card[data-library-key]')) {
    if (!/^https:\/\//.test(a.href)) continue;
    const href = iosLink(a.href).href;
    if (a.href !== href) a.href = href;
    if (a.hasAttribute('target')) a.removeAttribute('target');
  }
}
if (IOS_WEB_APP) {
  const fix = () => fixIosLinks(el.detail);
  new MutationObserver(fix).observe(el.detail, { subtree: true, childList: true, attributes: true, attributeFilter: ['href'] });
  new MutationObserver(() => fixIosLinks(document.body)).observe(el.grid, { childList: true });
}

function openInIosApp(href) {
  if (!IOS_WEB_APP || !/^https:\/\//.test(href)) return false;
  location.href = iosLink(href).href;
  return true;
}

// Adresse propre à l'appli (voir iosAppLink) : si l'appli s'ouvre, StreamHub passe en arrière-plan ; sinon
// (appli absente, adresse refusée), on ouvre le lien web au bout de 1,5 s
function openAppOrWeb(appHref, webHref) {
  const fallback = setTimeout(() => {
    if (!document.hidden) location.href = webHref;
  }, 1500);
  document.addEventListener('visibilitychange', () => clearTimeout(fallback), { once: true });
  location.href = appHref;
}

// Ouverture d'une plateforme depuis un bouton (Télécharger, Liker sur…) : même règle que les liens
function openPlatform(href, service, platform) {
  const url = withResume(CAN_DOWNLOAD || wantsDesktopApps() ? href : desktopWebLink(href) ?? href);
  if (!openInIosApp(url)) window.open(url, platformTarget(service || platform));
}

// Liens directs en cours de recherche pour la fiche ouverte : promesse résolue quand ils sont arrivés
function linksLoading(detail) {
  let done;
  detail.linksReady = new Promise((resolve) => (done = resolve));
  return { done: () => (detail.linksReady = null, done()) };
}

// Clic sur « Regarder sur… » avant l'arrivée du lien direct : le bouton n'a encore que son lien de secours (page du
// programme TF1+, recherche…). On attend le lien (4 s au plus) puis on relance le clic. Sur ordinateur, l'onglet de
// la plateforme est ouvert tout de suite (vide), pendant le clic : sinon le navigateur bloquerait son ouverture.
// Constaté : TF1+ restait sur la fiche au premier lancement d'un titre, et lançait la vidéo une fois le lien en
// mémoire (titre déjà ouvert).
function waitForDirectLink(link, event) {
  const ready = current?.linksReady;
  if (!ready || link.dataset.direct || link.dataset.waited || !link.matches('a.watch')) return false;
  event?.preventDefault();
  link.dataset.waited = '1';
  const tab = !IOS_WEB_APP && link.target && link.target !== '_self' ? window.open('', link.target) : null;
  Promise.race([ready, new Promise((resolve) => setTimeout(resolve, 4000))]).then(() => {
    if (!link.isConnected) return tab?.close();
    link.click();
    if (tab && !/^https?:/.test(link.href)) tab.close(); // ouvert dans une appli (aiv://…) : onglet inutile
    delete link.dataset.waited;
  });
  return true;
}

// Clic sur un lien de lecture : on demandera au retour s'il a bien été regardé (le lien s'ouvre normalement)
function onLaunch(link, event) {
  if (waitForDirectLink(link, event)) return;
  toDesktopApp(link);
  if (!IOS_WEB_APP) link.href = withResume(link.href, { play: link.dataset.resume === 'click' }); // le script ne tourne pas dans les applis
  const platform = link.dataset.platform ?? '';
  let entry;
  if (link.dataset.libraryKey) {
    entry = library.list('downloads').find((e) => e.key === link.dataset.libraryKey);
  } else if (current?.item) {
    const service = link.dataset.service || null;
    const titlePage = service && $(`a.watch[data-service="${service}"]`, el.detail)?.dataset.page;
    entry = { ...currentEntry(), platform, service, page: link.dataset.page || titlePage || link.href, ...episodeInfo(link) };
  }
  // Lancé = regardé : dans l'historique tout de suite, sans « Tu as regardé… ? » au retour (demande de l'utilisateur)
  if (entry) {
    library.recordWatch({ ...entry, platform, page: entry.page ?? entry.href });
    // Série : on enchaîne souvent plusieurs épisodes sur la plateforme ; au retour, « Où en es-tu ? » note le
    // dernier épisode vraiment regardé (et propose J'aime)
    if (entry.type === 'tv') library.addPending('progress', { ...entry, platform, page: entry.page ?? entry.href });
    updateCounts();
  }
  if (IOS_WEB_APP && /^https:\/\//.test(link.href)) {
    // Appli de l'écran d'accueil : le lien est suivi tel quel, comme un lien touché dans Safari (c'est ce cas
    // qu'iOS reconnaît pour ouvrir l'appli de la plateforme), dans la même fenêtre et sans « #streamhub= ».
    // Exception : les épisodes M6+, ouverts par l'adresse de l'appli (voir iosAppLink).
    link.href = iosLink(link.href).href;
    link.removeAttribute('target');
    const app = iosAppLink(link.href);
    if (app) {
      event?.preventDefault();
      openAppOrWeb(app, link.href);
    }
    return;
  }
  if (entry) offerRelaunch(link, platform, `« ${entry.title} »${episodeLabel(entry) ? ` ${episodeLabel(entry)}` : ''}`);
}

// ---------- Questions au retour dans StreamHub ----------

// Questions posées au retour : téléchargement, like sur la plateforme (un titre lancé entre directement dans
// l'historique depuis la version 1.9.2). watch : anciennes questions, vidées au démarrage (flushWatchPending).
// « Où en es-tu ? » n'est posé qu'après 3 minutes : un retour plus rapide, c'est souvent juste pour relancer après le
// choix du profil
const PENDING_DELAYS = { progress: 3 * 60 * 1000, download: 3 * 1000, platformLike: 3 * 1000, platformUnlike: 3 * 1000 };
let promptedId = null;

function checkPending() {
  if (document.hidden) return;
  const item = library.nextPending(PENDING_DELAYS);
  if (!item) {
    promptedId = null;
    togglePopover($('#confirm'), false);
    return;
  }
  if (item.id === promptedId) return; // déjà affichée
  promptedId = item.id;
  const e = item.entry;
  const what = `<strong>« ${esc(e.title)} »</strong>${episodeLabel(e) ? ` ${episodeLabel(e)}` : ''}`;
  const where = e.platform ? ` sur ${esc(shortPlatformName(e.platform))}` : '';
  const question = {
    progress: `Où en es-tu de <strong>« ${esc(e.title)} »</strong>${where} ?`,
    watch: `Tu as regardé ${what}${where} ?`,
    download: `Le téléchargement de ${what} a bien démarré${where} ?`,
    platformLike: `Tu as liké <strong>« ${esc(e.title)} »</strong>${where} ?`,
    platformUnlike: `Tu as retiré ton like de <strong>« ${esc(e.title)} »</strong>${where} ?`,
  }[item.kind];
  const bar = $('#confirm');
  bar.dataset.pendingId = item.id;
  const progress = item.kind === 'progress';
  bar.innerHTML = `
    <p>${question}</p>
    ${progress ? `<div class="progress-pick">
      <label><span>Dernier épisode regardé</span>
        <span class="progress-selects">
          <select data-progress-season aria-label="Saison"></select>
          <select data-progress-episode aria-label="Épisode"></select>
        </span></label>
    </div>` : ''}
    <div class="confirm-actions">
      <button type="button" class="btn primary" data-confirm="yes">${progress ? 'Enregistrer' : 'Oui'}</button>
      <button type="button" class="btn" data-confirm="no">${progress ? 'Ignorer' : 'Non'}</button>
      ${progress || item.kind === 'watch' ? '<button type="button" class="btn like-btn" data-confirm-like aria-pressed="false"></button><span class="platform-likes" data-platform-likes></span>' : ''}
    </div>`;
  if (progress) fillProgressPick(item);
  refreshConfirmLike();
  showRelaunch(false);
  togglePopover(bar, true);
  $('[data-confirm="yes"]', bar).focus({ preventScroll: true });
}

// Choix du dernier épisode regardé : saisons de la série, puis épisodes de la saison choisie (titres TMDB) ; au départ,
// l'épisode lancé (numérotation TMDB)
async function fillProgressPick(item, season = item.entry.season) {
  const bar = $('#confirm');
  const seasonSel = $('[data-progress-season]', bar);
  const episodeSel = $('[data-progress-episode]', bar);
  if (!seasonSel || bar.dataset.pendingId !== item.id) return;
  const show = await api.title('tv', item.entry.id).catch(() => null);
  const seasons = (show?.seasons ?? []).filter((s) => s.season_number > 0 && s.episode_count > 0);
  if (bar.dataset.pendingId !== item.id) return;
  if (!seasons.length) {
    $('.progress-pick', bar).hidden = true;
    return;
  }
  const chosen = seasons.find((s) => s.season_number === season) ?? seasons[0];
  seasonSel.innerHTML = seasons.map((s) => `<option value="${s.season_number}">Saison ${s.season_number}</option>`).join('');
  seasonSel.value = chosen.season_number;
  const details = await api.season(item.entry.id, chosen.season_number).catch(() => null);
  if (bar.dataset.pendingId !== item.id || Number(seasonSel.value) !== chosen.season_number) return;
  const episodes = details?.episodes?.length
    ? details.episodes.map((ep) => ({ number: ep.episode_number, name: ep.name }))
    : Array.from({ length: chosen.episode_count }, (_, i) => ({ number: i + 1, name: '' }));
  episodeSel.innerHTML = episodes
    .map((ep) => `<option value="${ep.number}" data-name="${esc(ep.name ?? '')}">${esc(`Épisode ${ep.number}${ep.name && !/^(Épisode|Episode) \d+$/i.test(ep.name) ? ` · ${ep.name}` : ''}`)}</option>`)
    .join('');
  const start = season === chosen.season_number ? item.entry.episode : null;
  episodeSel.value = episodes.some((ep) => ep.number === start) ? start : episodes[0].number;
}

// Le « J'aime » de la question porte sur le film ou la série entière, jamais sur un épisode
function confirmLikeEntry() {
  const id = $('#confirm').dataset.pendingId;
  const e = library.list('pending').find((p) => p.id === id)?.entry;
  return e && { type: e.type, id: e.id, title: e.title, poster: e.poster, date: e.date };
}

function refreshConfirmLike() {
  const btn = $('#confirm [data-confirm-like]');
  const e = btn && confirmLikeEntry();
  if (!e) return;
  const liked = library.has('likes', library.titleKey(e.type, e.id));
  btn.setAttribute('aria-pressed', liked);
  btn.textContent = `${liked ? '♥ Tu aimes' : '♡ J’aime'}${e.type === 'tv' ? ' la série' : ''}`;
  const pending = library.list('pending').find((p) => p.id === $('#confirm').dataset.pendingId)?.entry;
  const targets = liked && pending ? [{ platform: pending.platform, service: pending.service, href: pending.page }] : [];
  $('#confirm [data-platform-likes]').innerHTML = platformLikeButtons(e.type, e.id, targets);
}

// Retirer un like dans StreamHub ne le retire pas sur la plateforme : on le rappelle, avec un bouton
// qui ouvre la page du titre sur la plateforme (puis « Tu as retiré ton like… ? » au retour)
function remindPlatformLikes(entry) {
  const platforms = library.likedOn(entry.type, entry.id);
  if (!platforms.length) return false;
  const names = platforms.map((p) => shortPlatformName(p.platform)).join(' et ');
  // Les likes notés avant qu'on retienne la page du titre : on la reprend dans la fiche ouverte
  const pageOf = (p) => p.href || (current && p.service && $(`a.watch[data-service="${p.service}"]`, el.detail)?.dataset.page);
  const first = platforms.map((p) => ({ ...p, href: pageOf(p) })).find((p) => p.href);
  const title = { type: entry.type, id: entry.id, title: entry.title, poster: entry.poster, date: entry.date };
  toast(
    `Retiré de J’aime. Ton like sur ${names} est toujours là.`,
    first && {
      label: `Retirer aussi sur ${shortPlatformName(first.platform)}`,
      run() {
        library.addPending('platformUnlike', { ...title, platform: first.platform, service: first.service });
        openPlatform(first.href, first.service, first.platform);
      },
    },
  );
  return true;
}

function answerPending(yes) {
  const bar = $('#confirm');
  const episodeSel = $('[data-progress-episode]', bar);
  // Dernier épisode choisi (seulement si la liste a été remplie)
  const changes = episodeSel?.value
    ? {
        season: Number($('[data-progress-season]', bar).value),
        episode: Number(episodeSel.value),
        episodeName: episodeSel.selectedOptions[0]?.dataset.name ?? '',
      }
    : {};
  library.resolvePending(bar.dataset.pendingId, yes, changes);
  promptedId = null;
  updateCounts();
  refreshDownloadButtons();
  refreshLikeButton();
  if (PERSONAL_VIEWS.includes(state.view)) renderLibrary();
  checkPending(); // question suivante, s'il y en a une
}

// « Où en es-tu ? » : autre saison choisie → ses épisodes
document.addEventListener('change', (e) => {
  if (!e.target.matches?.('#confirm [data-progress-season]')) return;
  const item = library.list('pending').find((p) => p.id === $('#confirm').dataset.pendingId);
  if (item) fillProgressPick(item, Number(e.target.value));
});

document.addEventListener('visibilitychange', checkPending);
window.addEventListener('focus', checkPending);

const STREAM_TYPES = new Set(['subscription', 'free', 'addon']);

// Remplace les liens de secours par les liens directs de Streaming Availability
// L'offre qui correspond à un bouton « Regarder sur… ». Une même plateforme peut en avoir plusieurs :
// pour Naruto, Prime Video propose l'abonnement Prime (sans pub) ET la chaîne M6+ (avec pub, vendue
// en option). Le bouton « Prime Video » doit mener à l'offre Prime, jamais à une chaîne ; le bouton
// d'une chaîne (« Crunchyroll Amazon Channel ») mène à cette chaîne.
function pickOption(options, service, kind, platformName) {
  const candidates = options.filter((o) => o.service === service);
  if (kind === 'rent' || kind === 'buy') return candidates.find((o) => o.type === kind) ?? null;
  if (isChannel(platformName)) {
    // « France TV Amazon Channel » (TMDB) ↔ « France.tv » (Streaming Availability) : on compare les noms simplifiés
    const name = squash(platformName);
    return candidates.find((o) => o.type === 'addon' && o.addon && name.includes(squash(o.addon))) ?? null;
  }
  return candidates.find((o) => o.type === 'subscription') ?? candidates.find((o) => o.type === 'free') ?? null;
}

function applyDirectLinks(options) {
  for (const a of el.detail.querySelectorAll('.watch[data-service]')) {
    const service = a.dataset.service;
    if (!service) continue;
    const option = pickOption(options, service, a.dataset.kind, a.dataset.platform);
    if (!option) continue;
    // Lien de lecture recalculé ici aussi : les réponses en mémoire peuvent dater d'avant autoplayLink (Prime)
    const play = option.videoLink ?? autoplayLink(option.link);
    a.href = play ?? option.link;
    a.dataset.page = option.link; // la fiche du titre : c'est là que se trouvent les boutons télécharger et liker
    a.dataset.direct = 'sa';
    $('.watch-hint', a).textContent = play ? 'Lecture directe' : 'Fiche du titre';
  }
  applyCanalChannels();
  applySeriesResume();
  refreshLikeButton(); // les boutons « Liker aussi » pointent maintenant vers la page du titre
}

// Chaînes de Canal+ (HBO Max, Apple TV, Paramount+) : la fiche du titre sur la chaîne, d'après l'index publié avec
// StreamHub (la fiche Canal VOD qu'on trouve ailleurs est une autre offre, payante à l'unité : constaté par
// l'utilisateur avec Harry Potter). Titre absent de l'index : la page de la chaîne sur Canal+. Sur iPhone, l'appli
// Canal+ s'ouvre sur la fiche.
function applyCanalChannels() {
  if (!current?.item) return;
  const key = current.key;
  const titles = [titleOf(current.item), originalTitleOf(current.item)];
  for (const channel of CANAL_CHANNELS) {
    const a = el.detail.querySelector(`a.watch[data-platform="${channel.name}"]`);
    if (!a) continue;
    const path = canalChannelPath(channel.key, current.type, titles, () => current?.key === key && (applyCanalChannels(), applySeriesResume()));
    if (path === undefined) continue; // index en cours de chargement
    const page = `https://www.canalplus.com${path ?? channel.hub}`;
    a.href = (path && autoplayLink(page)) || page; // lecture automatique, comme pour Canal+
    a.dataset.page = page;
    a.dataset.direct = 'canal-channel';
    $('.watch-hint', a).textContent = path ? 'Lecture directe' : `Page ${channel.label} de Canal+`;
  }
}

// Séries : « Regarder sur… » reprend où tu t'es arrêté, ou commence à l'épisode 1 si tu n'as jamais regardé la série.
// Netflix, Disney+, Prime Video, Canal+ gardent la progression : on leur envoie le lien qu'elles savent reprendre
// (voir seriesResumeLink). TF1+ et M6+ n'en ont pas : on lance l'épisode qui suit le dernier épisode regardé depuis
// StreamHub (historique), retrouvé grâce à l'index des épisodes.
function applySeriesResume() {
  if (current?.type !== 'tv') return;
  const key = current.key;
  const last = library.list('history').find((e) => e.key === library.titleKey('tv', current.id));
  for (const a of el.detail.querySelectorAll('a.watch[data-service]')) {
    if (a.dataset.kind === 'rent' || a.dataset.kind === 'buy') continue;
    const resume = seriesResumeLink(a.href, a.dataset.page);
    if (resume) {
      a.href = resume.href;
      if (resume.click) a.dataset.resume = 'click';
      // Disney+ sur ordinateur, avec le script : il appuie sur « Reprendre » à ta place
      $('.watch-hint', a).textContent = resume.click && !CAN_DOWNLOAD && hasResumeExtension() ? 'Reprise de la série' : resume.hint;
      continue;
    }
    const platform = hostServiceFor(a.dataset.platform)?.id;
    if (!INDEXED_PLATFORMS.has(platform) || !last?.episode || hostServiceFor(last.platform)?.id !== platform) continue;
    const titles = [titleOf(current.item), originalTitleOf(current.item)];
    const redraw = () => current?.key === key && applySeriesResume(); // une fois l'index chargé
    const next =
      [{ season: last.season, episode: last.episode + 1 }, { season: last.season + 1, episode: 1 }]
        .map((keys) => ({ keys, href: platformEpisodeUrl(platform, titles, keys, redraw) }))
        .find((n) => n.href);
    if (!next) continue;
    a.href = next.href;
    $('.watch-hint', a).textContent = `Épisode suivant : S${next.keys.season} E${next.keys.episode}`;
  }
}

// Liens JustWatch (via le relais) pour les boutons restés sans lien direct
const JW_KIND = { flatrate: 'FLATRATE', free: 'FREE', ads: 'ADS', rent: 'RENT', buy: 'BUY' };

function applyRelayLinks(offers, type) {
  for (const a of el.detail.querySelectorAll('a.watch:not([data-direct])')) {
    const same = offers.filter((o) => squash(o.provider) === squash(a.dataset.platform));
    const offer = same.find((o) => o.type === JW_KIND[a.dataset.kind]) ?? same[0];
    if (!offer) continue;
    const play = offer.deeplink && offer.deeplink !== offer.url ? offer.deeplink : autoplayLink(offer.url);
    a.href = play ?? offer.url;
    a.dataset.page = offer.url;
    a.dataset.direct = 'jw';
    $('.watch-hint', a).textContent = play ? 'Lecture directe' : 'Fiche du titre';
    // Les épisodes sans lien propre renverront vers la fiche du titre sur la plateforme
    const entry = current.entries.find((e) => e.name === a.dataset.platform);
    if (entry) entry.href = offer.url;
  }
  applyCanalChannels();
  applySeriesResume();
  refreshLikeButton();
  if (type === 'tv') applySeasonLinks();
}

// Une fois les liens reçus : plateformes de chaque saison, et boutons des épisodes déjà affichés
function applySeasonLinks() {
  for (const seasonEl of el.detail.querySelectorAll('.season[data-season]')) {
    const number = Number(seasonEl.dataset.season);
    const saSeason = current.links?.seasons.find((s) => s.number === Number(seasonEl.dataset.origSeason));
    const names = streamOptions(saSeason?.options ?? []).map((o) => {
      const name = o.addon ? `${o.addon} (${shortPlatformName(o.name)})` : shortPlatformName(o.name);
      return isMineOption(o) ? `✓ ${name}` : name;
    });
    $('.season-platforms', seasonEl).textContent = names.length ? `Sur ${names.join(' · ')}` : '';
    if ($('.episode', seasonEl)) fillEpisodeLinks(number);
  }
}

el.settings.addEventListener('close', () => {
  rehostBars();
  applyGlass(); // aperçu de l'effet verre annulé si les réglages sont fermés sans enregistrer
});
// Résumés des sections, et aperçu immédiat de l'effet verre
el.settingsForm.addEventListener('input', (e) => {
  const row = e.target.closest?.('[data-home-row]');
  if (row) {
    draftHome.rows = draftHome.rows.map((r) => (r.key === row.dataset.homeRow ? { ...r, on: row.checked } : r));
    row.closest('li').classList.toggle('off', !row.checked);
  }
  if (e.target.name === 'glass') document.documentElement.dataset.glass = e.target.value;
  renderSettingsSummaries();
});

el.detail.addEventListener('close', () => {
  rehostBars();
  const closed = current;
  current = null;
  el.detail.dataset.key = '';
  if (PERSONAL_VIEWS.includes(state.view) && closed) {
    // Un « J'aime » retiré depuis la fiche doit disparaître de la liste : on la redessine
    renderLibrary();
    $(`.card[data-type="${closed.type}"][data-id="${closed.id}"]`, el.grid)?.focus({ preventScroll: true });
    return;
  }
  if (closed) {
    refreshLocalRows();
    refreshHeroLike();
  }
  el.detail.returnFocus?.focus({ preventScroll: true });
});

// ---------- Réglages ----------

let draftProviders = new Map();
let providerChoices = [];

// Remplit le formulaire avec les réglages enregistrés (à l'ouverture, ou quand la synchronisation en apporte)
function fillSettings() {
  const f = el.settingsForm;
  f.tmdbKey.value = settings.tmdbKey;
  f.saKey.value = settings.saKey;
  f.relay.value = settings.relay || '';
  f.region.value = settings.region;
  f.openIn.value = settings.desktopApps ?? settings.primeApp ? 'app' : 'web';
  f.glass.value = settings.glass || 'auto';
  for (const status of el.settings.querySelectorAll('[data-key-status]')) {
    status.className = 'key-status';
    status.innerHTML = status.dataset.default;
  }
  draftProviders = new Map(settings.providers.map((p) => [p.id, p]));
  draftHome = { rows: homeLayout(), hero: settings.home?.hero ?? null };
  renderHomeSettings();
  loadProviderChoices();
  renderSettingsSummaries();
}

// ---------- Réglages : accueil ----------

let draftHome = { rows: [], hero: null };

function renderHomeSettings() {
  $('#homeHero').textContent = draftHome.hero ? `« ${draftHome.hero.title} »` : 'Automatique (n° 1 du Top 50)';
  $('[data-home-hero-auto]').hidden = !draftHome.hero;
  const last = draftHome.rows.length - 1;
  $('#homeRows').innerHTML = draftHome.rows
    .map((r, i) => {
      const def = HOME_ROWS.find((d) => d.key === r.key);
      return `<li class="home-row ${r.on ? '' : 'off'}">
        <label><input type="checkbox" data-home-row="${r.key}" ${r.on ? 'checked' : ''}> ${esc(def.title)}</label>
        <button type="button" class="icon-btn" data-home-move="${i}" data-dir="-1" ${i === 0 ? 'disabled' : ''} aria-label="Monter ${esc(def.title)}">↑</button>
        <button type="button" class="icon-btn" data-home-move="${i}" data-dir="1" ${i === last ? 'disabled' : ''} aria-label="Descendre ${esc(def.title)}">↓</button>
      </li>`;
    })
    .join('');
}

// Résumé affiché sous le titre de chaque section repliée des réglages
const GLASS_NAMES = { auto: 'Effet verre automatique', clear: 'Effet verre transparent', tinted: 'Effet verre teinté' };
function renderSettingsSummaries() {
  const f = el.settingsForm;
  const summary = (name, text) => ($(`[data-summary="${name}"]`, f).textContent = text);
  const n = draftProviders.size;
  summary('providers', n ? `${n} plateforme${n > 1 ? 's' : ''} : ${[...draftProviders.values()].map((p) => p.name).join(', ')}` : 'Aucune plateforme cochée');
  summary('account', accountSummary());
  const keys = [f.tmdbKey.value.trim() ? 'TMDB ✓' : 'TMDB manquante', f.saKey.value.trim() ? 'Streaming Availability ✓' : 'Streaming Availability —'];
  summary('keys', keys.join(' · '));
  summary('look', GLASS_NAMES[f.glass.value] ?? GLASS_NAMES.auto);
  const shown = draftHome.rows.filter((r) => r.on).length;
  summary('home', `${shown} rangée${shown > 1 ? 's' : ''} sur ${draftHome.rows.length} · ${draftHome.hero ? `à l’affiche : ${draftHome.hero.title}` : 'affiche automatique'}`);
  const openIn = !CAN_DOWNLOAD && f.openIn.value === 'app' ? ' · titres dans l’appli' : '';
  summary('device', `${f.region.selectedOptions[0]?.textContent ?? f.region.value}${openIn}${hasResumeExtension() ? ' · script de reprise installé' : ''}`);
}

// Ouvre la section des réglages qui contient un champ (erreur à corriger, premier lancement…)
function revealSetting(node) {
  const group = node.closest('details');
  if (group) group.open = true;
  node.focus();
  node.scrollIntoView({ block: 'center', behavior: 'smooth' });
}

function openSettings(first = false) {
  const f = el.settingsForm;
  $('#extensionStatus').innerHTML = hasResumeExtension()
    ? '✓ Script « reprise après connexion » installé : après la connexion ou le choix du profil, le titre s’ouvre tout seul.'
    : `Pour que le titre s’ouvre tout seul après la connexion ou le choix du profil sur la plateforme :
       <strong>Safari</strong> (Mac, iPhone, iPad) : installe l’appli gratuite
       <a href="https://apps.apple.com/app/userscripts/id1463298887" target="_blank" rel="noopener">Userscripts</a>,
       active-la dans Safari, puis <a href="streamhub-reprise.user.js" target="_blank" rel="noopener">installe ce script</a>.
       <strong>Firefox, Chrome, Edge</strong> : module Violentmonkey ou Tampermonkey, puis
       <a href="streamhub-reprise.user.js" target="_blank" rel="noopener">ce script</a>
       (<a href="https://github.com/arthursavournin/streamhub/tree/main/extension#readme" target="_blank" rel="noopener">détails</a>).`;
  if (IOS_WEB_APP) {
    $('#extensionStatus').innerHTML = `Appli de l’écran d’accueil : les titres s’ouvrent dans l’appli de la plateforme si elle est
      installée, sinon sur son site.`;
  } else if (IOS) {
    $('#extensionStatus').insertAdjacentHTML('afterbegin', `<strong>Installer StreamHub</strong> : bouton Partager →
      « Sur l’écran d’accueil ». Dans Safari, les titres s’ouvrent déjà dans l’appli de la plateforme si elle est installée.<br>`);
  }
  $('#desktopAppsField').hidden = CAN_DOWNLOAD; // téléphone / tablette : les liens ouvrent déjà l'appli
  // Même phrase sur Mac et sur PC, seule la partie propre au système change (texte du Mac dans index.html)
  if (!MAC && $('#desktopAppsHint')) {
    const pc = /Win/.test(navigator.platform);
    $('#desktopAppsHint').textContent = `Quand elle est installée sur ${pc ? 'ce PC' : 'cet ordinateur'} : Prime Video pour l’instant${
      pc ? ' (les applis Windows des autres plateformes ne sont pas encore prises en charge)' : ''
    }. Le navigateur peut demander l’autorisation la première fois.`;
  }
  el.providerFilter.value = '';
  el.settingsError.textContent = '';
  $('#settingsIntro').hidden = !first;
  $('#appVersion').textContent = `StreamHub · version ${APP_VERSION}`;
  fillSettings();
  accountUi.render();
  el.settings.showModal();
  rehostBars();
  // Toutes les sections repliées (demande de l'utilisateur) ; au premier lancement, celles à remplir sont dépliées
  for (const group of el.settings.querySelectorAll('details.settings-group')) {
    group.open = first && ['providers', 'account', 'keys'].includes(group.dataset.group);
  }
  $('#settingsBody').scrollTop = 0;
  // La fenêtre elle-même, pas la croix : sur iPhone, la croix prendrait un anneau de focus à chaque ouverture
  if (first && !accountState().signedIn) accountUi.focus();
  else (first ? f.tmdbKey : el.settings).focus({ preventScroll: true });
}

// ---------- Clés API : tester, copier ----------

for (const status of el.settings.querySelectorAll('[data-key-status]')) status.dataset.default = status.innerHTML;

const KEY_TESTS = {
  tmdb: (f) => testTmdbKey(f.tmdbKey.value.trim()),
  sa: (f) => testSaKey(f.saKey.value.trim(), f.region.value),
  relay: (f) => testRelay(relayUrl({ relay: f.relay.value.trim() })),
};

function setKeyStatus(status, kind, message) {
  status.className = `key-status ${kind}`;
  status.textContent = message;
}

el.settingsForm.addEventListener('click', async (e) => {
  // Accueil : monter / descendre une rangée, affiche automatique
  const move = e.target.closest('[data-home-move]');
  if (move) {
    const i = Number(move.dataset.homeMove);
    const j = i + Number(move.dataset.dir);
    [draftHome.rows[i], draftHome.rows[j]] = [draftHome.rows[j], draftHome.rows[i]];
    renderHomeSettings();
    renderSettingsSummaries();
    $(`[data-home-move="${j}"][data-dir="${move.dataset.dir}"]`)?.focus() ?? $(`[data-home-move="${j}"]`)?.focus();
    return;
  }
  if (e.target.closest('[data-home-hero-auto]')) {
    draftHome.hero = null;
    renderHomeSettings();
    renderSettingsSummaries();
    return;
  }
  const test = e.target.closest('[data-test-key]');
  if (test) {
    const name = test.dataset.testKey;
    const status = $(`[data-key-status="${name}"]`, el.settings);
    const field = { tmdb: 'tmdbKey', sa: 'saKey' }[name];
    if (field && !el.settingsForm[field].value.trim()) return setKeyStatus(status, 'bad', 'Colle d’abord la clé.');
    setKeyStatus(status, '', 'Vérification…');
    test.disabled = true;
    try {
      setKeyStatus(status, 'ok', await KEY_TESTS[name](el.settingsForm));
    } catch (err) {
      setKeyStatus(status, 'bad', err.message);
    } finally {
      test.disabled = false;
    }
    return;
  }
  const copy = e.target.closest('[data-copy]');
  if (copy) {
    const input = $(copy.dataset.copy, el.settings);
    try {
      await navigator.clipboard.writeText(input.value);
      toast('Copié dans le presse-papiers.');
    } catch {
      input.select(); // presse-papiers refusé : le texte est sélectionné, à copier soi-même
    }
  }
});

// ---------- Synchronisation (compte) ----------

function syncedWhen(t) {
  const minutes = Math.round((Date.now() - t) / 60000);
  if (minutes < 1) return 'à l’instant';
  if (minutes < 60) return `il y a ${minutes} min`;
  return `le ${new Date(t).toLocaleString('fr-FR', { dateStyle: 'short', timeStyle: 'short' })}`;
}

// Des données sont arrivées d'un autre appareil : on repart des réglages et de la bibliothèque à jour
function applySynced() {
  settings = loadSettings();
  api = makeApi(settings);
  library.reload();
  state.filter = defaultFilter();
  if (el.settings.open) fillSettings();
  if (!el.detail.open) showView(state.view);
}

// ---------- Compte ----------

const accountUi = initAccountUi({
  syncNow,
  syncedWhen,
  onPulled: applySynced,
  onChange: renderSettingsSummaries,
});
window.addEventListener('streamhub:account', () => el.settings.open && renderSettingsSummaries());

let providerLoad = 0;
async function loadProviderChoices() {
  const f = el.settingsForm;
  const key = f.tmdbKey.value.trim();
  const load = ++providerLoad;
  if (!key) {
    el.providerGrid.innerHTML = '<p class="muted">Ajoute ta clé TMDB pour voir les plateformes.</p>';
    return;
  }
  el.providerGrid.innerHTML = '<p class="muted">Chargement des plateformes…</p>';
  try {
    const list = await makeApi({ ...settings, tmdbKey: key, region: f.region.value }).providers();
    if (load !== providerLoad) return;
    providerChoices = list;
    renderProviderChoices();
  } catch (err) {
    if (load === providerLoad) el.providerGrid.innerHTML = `<p class="muted">${esc(err.message)}</p>`;
  }
}

function renderProviderChoices() {
  const q = el.providerFilter.value.trim().toLowerCase();
  const list = providerChoices.filter((p) => !q || p.name.toLowerCase().includes(q));
  el.providerGrid.innerHTML = list.length
    ? list
        .map(
          (p) => `<button type="button" class="provider" data-provider="${p.id}" aria-pressed="${draftProviders.has(p.id)}">
            <img src="${img(p.logo, 'w92')}" alt="" loading="lazy"><span>${esc(p.name)}</span></button>`,
        )
        .join('')
    : '<p class="muted">Aucune plateforme ne correspond.</p>';
}

// Chaînes Amazon incluses sans supplément avec l'abonnement Prime Video (France) : cochées avec lui.
// Les autres chaînes (Crunchyroll, Paramount+, HBO Max…) sont payantes en plus.
const PRIME = 119;
const INCLUDED_WITH_PRIME = [2100, 2535, 2672]; // Prime Video avec pub, France TV, M6+

el.providerGrid.addEventListener('click', (e) => {
  const btn = e.target.closest('[data-provider]');
  if (!btn) return;
  const id = Number(btn.dataset.provider);
  const select = (pid, on) => {
    const p = providerChoices.find((c) => c.id === pid);
    if (on && p) draftProviders.set(pid, { id: pid, name: p.name, logo: p.logo });
    if (!on) draftProviders.delete(pid);
    renderSettingsSummaries();
  };
  const on = !draftProviders.has(id);
  select(id, on);
  if (id === CANAL_CINE_SERIES.id) {
    // Cochée : les plateformes incluses le sont aussi. Décochée : seule l'offre l'est (Netflix ou Apple TV+ peuvent
    // être des abonnements à part)
    if (!on) return btn.setAttribute('aria-pressed', 'false');
    for (const pid of CANAL_CINE_SERIES.includes) select(pid, true);
    renderProviderChoices();
    const names = CANAL_CINE_SERIES.includes.map((pid) => providerChoices.find((c) => c.id === pid)?.name).filter(Boolean);
    if (names.length) {
      el.settingsError.textContent = `Inclus avec Canal+ Ciné Séries, ajoutés aussi : ${names.join(', ')}.`;
      el.settingsError.classList.add('info');
    }
  } else if (id === PRIME) {
    for (const pid of INCLUDED_WITH_PRIME) select(pid, on);
    renderProviderChoices();
    const names = INCLUDED_WITH_PRIME.map((pid) => providerChoices.find((c) => c.id === pid)?.name).filter(Boolean);
    if (on && names.length) {
      el.settingsError.textContent = `Inclus avec Prime, ajoutés aussi : ${names.join(', ')}.`;
      el.settingsError.classList.add('info'); // message d'information, pas d'erreur
    }
  } else {
    btn.setAttribute('aria-pressed', draftProviders.has(id));
  }
});

el.providerFilter.addEventListener('input', renderProviderChoices);
el.settingsForm.tmdbKey.addEventListener('change', loadProviderChoices);
el.settingsForm.region.addEventListener('change', () => {
  draftProviders.clear(); // les identifiants de plateformes changent d'un pays à l'autre
  loadProviderChoices();
});

el.settingsForm.addEventListener('submit', (e) => {
  const f = el.settingsForm;
  const tmdbKey = f.tmdbKey.value.trim();
  if (!tmdbKey) {
    e.preventDefault();
    el.settingsError.classList.remove('info');
    el.settingsError.textContent = 'La clé TMDB est nécessaire pour charger le catalogue.';
    revealSetting(f.tmdbKey);
    return;
  }
  const relay = f.relay.value.trim().replace(/\/+$/, '');
  if (relay && !/^https:\/\/[^\s/]+/.test(relay)) {
    e.preventDefault();
    el.settingsError.classList.remove('info');
    el.settingsError.textContent = 'L’adresse du relais doit commencer par https://';
    revealSetting(f.relay);
    return;
  }
  settings = {
    ...settings,
    tmdbKey,
    saKey: f.saKey.value.trim(),
    relay,
    region: f.region.value,
    desktopApps: f.openIn.value === 'app',
    glass: f.glass.value,
    providers: [...draftProviders.values()],
    home: { rows: draftHome.rows, hero: draftHome.hero },
  };
  saveSettings(settings);
  applyGlass();
  api = makeApi(settings);
  state.filter = defaultFilter();
  showView(state.view);
});

// ---------- Événements ----------

document.addEventListener('click', (e) => {
  const target = e.target;

  // Liens vers une plateforme : on laisse le lien s'ouvrir, on note juste le lancement
  const launch = target.closest('a.watch, a.episode-play, a.card[data-library-key]');
  if (launch) return onLaunch(launch, e);
  const relaunch = target.closest('[data-relaunch]');
  if (relaunch) return toDesktopApp(relaunch);
  if (target.closest('[data-relaunch-close]')) return showRelaunch(false);
  const answer = target.closest('[data-confirm]');
  if (answer) return answerPending(answer.dataset.confirm === 'yes');
  const platformLike = target.closest('[data-platform-like]');
  if (platformLike) {
    const entry = platformLike.closest('#confirm') ? confirmLikeEntry() : platformLike.closest('#toast') ? toastEntry : current?.item && currentEntry();
    if (platformLike.closest('#toast')) hideToast();
    if (!entry) return;
    const { platform, service, href } = platformLike.dataset;
    library.addPending('platformLike', { ...entry, platform, service: service || null, href });
    openPlatform(href, service, platform);
    toast(`Sur ${shortPlatformName(platform)}, appuie sur le pouce ou le bouton « J’aime ».`);
    return;
  }
  if (target.closest('[data-confirm-like]')) {
    const entry = confirmLikeEntry();
    if (entry && !library.toggleLike(entry)) remindPlatformLikes(entry);
    refreshConfirmLike();
    refreshLikeButton();
    updateCounts();
    if (state.view === 'likes') renderLibrary();
    return;
  }

  const card = target.closest('button.card[data-id]');
  if (card) return openDetail(card.dataset.type, Number(card.dataset.id), card);

  const nav = target.closest('[data-nav]');
  if (nav) {
    if (nav.dataset.nav === 'library' && !el.gridPage.contains(nav)) {
      // Depuis le menu : la Bibliothèque complète, sans la recherche ni le genre d'avant
      el.search.value = '';
      return showView('library', { library: { query: '', genre: '', filter: defaultFilter() } });
    }
    return showView(nav.dataset.nav);
  }
  const seeAll = target.closest('[data-see-all]');
  if (seeAll) return seeAllRow(seeAll);
  const arrow = target.closest('[data-row-scroll]');
  if (arrow) return scrollRow(arrow);
  const heroAction = target.closest('[data-hero]');
  if (heroAction) return onHeroAction(heroAction);

  const remove = target.closest('[data-remove]');
  if (remove) {
    const entry = library.list(remove.dataset.remove).find((e) => e.key === remove.dataset.key);
    library.remove(remove.dataset.remove, remove.dataset.key);
    renderLibrary();
    if (remove.dataset.remove === 'likes' && entry) remindPlatformLikes(entry);
    return;
  }
  if (target.closest('[data-toast-close]')) return hideToast();
  if (target.closest('[data-toast-action]')) {
    toastAction?.();
    hideToast();
    return;
  }

  // « ☆ À l'affiche » : ce titre en grand en haut de l'accueil (un second appui revient au n° 1 du Top 50)
  if (target.closest('[data-hero-pick]') && current?.item) {
    const { type, id, title, poster } = currentEntry();
    const chosen = settings.home?.hero;
    const same = chosen?.type === type && chosen?.id === id;
    settings = { ...settings, home: { rows: homeLayout(), hero: same ? null : { type, id, title, poster } } };
    saveSettings(settings);
    refreshHeroPick();
    toast(same ? 'L’accueil affiche à nouveau le n° 1 du Top 50.' : `« ${title} » est à l’affiche de l’accueil.`, null, { duration: 4000 });
    if (state.view === 'home') renderRowsPage('home');
    return;
  }

  if (target.closest('[data-list]') && current?.item) {
    toast(library.toggleList(currentEntry()) ? 'Ajouté à ma liste.' : 'Retiré de ma liste.');
    refreshListButton();
    updateCounts();
    if (state.view === 'watchlist') renderLibrary();
    return;
  }

  if (target.closest('[data-like]') && current?.item) {
    const liked = library.toggleLike(currentEntry());
    refreshLikeButton();
    updateCounts();
    if (liked) likeToast(currentEntry(), likeTargets());
    else if (!remindPlatformLikes(currentEntry())) toast('Retiré de J’aime.');
    return;
  }

  const download = target.closest('[data-download]');
  if (download && current?.item) {
    const watch = download.closest('.watch-row')?.querySelector('a.watch');
    const href = download.dataset.href || watch?.dataset.page || watch?.href;
    const platform = download.dataset.platform;
    const service = download.dataset.service;
    library.addPending('download', { ...currentEntry(), platform, service, href, ...episodeInfo(download) });
    openPlatform(href, service, platform);
    toast(`Dans l’appli ${shortPlatformName(platform)}, appuie sur son bouton de téléchargement.`);
    return;
  }

  const detailTab = target.closest('[data-detail-tab]');
  if (detailTab) return selectDetailTab(detailTab.dataset.detailTab);
  const seasonBtn = target.closest('[data-season-toggle]');
  if (seasonBtn) return toggleSeason(seasonBtn);
  const moreEpisodes = target.closest('[data-more-episodes]');
  if (moreEpisodes) return showMoreEpisodes(moreEpisodes.closest('.episodes'));

  const typeBtn = target.closest('[data-type]');
  if (typeBtn && el.typeSwitch.contains(typeBtn)) return setType(typeBtn.dataset.type);

  // « Tu voulais dire… ? » : la recherche est corrigée et relancée
  if (target.closest('[data-suggestion]') && state.suggestion) {
    el.search.value = state.suggestion;
    state.query = state.suggestion;
    showView('library');
    return;
  }

  const filter = target.closest('[data-filter]');
  if (filter) {
    state.filter = filter.dataset.filter;
    renderPlatformSelect();
    reload();
    return;
  }
  if (target.closest('[data-close]')) return target.closest('dialog')?.close();
  if (target.closest('[data-open-settings]')) return openSettings(!settings.tmdbKey);
  if (target.closest('[data-retry]')) return reload();

  // Clic en dehors du contenu d'une fenêtre = fermeture
  if (target.tagName === 'DIALOG') target.close();
});

$('#settingsBtn').addEventListener('click', () => openSettings(!settings.tmdbKey));

el.platform.addEventListener('change', () => {
  state.filter = el.platform.value;
  reload();
});

el.genre.addEventListener('change', () => {
  state.genre = el.genre.value;
  state.genreIds = null;
  state.genreExtra = null;
  reload();
});
el.sort.addEventListener('change', () => {
  state.sort = el.sort.value;
  reload();
});

let searchTimer;
el.search.addEventListener('input', () => {
  clearTimeout(searchTimer);
  searchTimer = setTimeout(() => {
    const q = el.search.value.trim();
    if (q === state.query && state.view === 'library') return;
    state.query = q;
    showView('library'); // une recherche se fait dans la Bibliothèque
  }, 400);
});
el.searchForm.addEventListener('submit', (e) => {
  e.preventDefault();
  clearTimeout(searchTimer);
  state.query = el.search.value.trim();
  el.search.blur();
  showView('library');
});

initSpatialNav({
  onBack() {
    const open = document.querySelector('dialog[open]');
    if (open) {
      open.close();
      return true;
    }
    if (state.query) {
      el.search.value = '';
      state.query = '';
      showView('library');
      return true;
    }
    if (PERSONAL_VIEWS.includes(state.view)) {
      showView('me');
      return true;
    }
    if (state.view !== 'home') {
      showView('home');
      return true;
    }
    return false;
  },
});

// ---------- Démarrage ----------

library.flushWatchPending();
checkPending(); // l'appli a pu être fermée pendant le téléchargement
showView('home');
if (!settings.tmdbKey) openSettings(true);
startAutoSync(applySynced); // réglages et listes des autres appareils
// Retour de Google / GitHub ou d'un lien d'e-mail (confirmation, mot de passe oublié) : Réglages → Compte
handleAuthRedirect().then((result) => {
  if (!result) return;
  if (!el.settings.open) openSettings();
  const group = $('[data-group="account"]');
  group.open = true;
  group.scrollIntoView({ block: 'start' });
  const messages = {
    oauth: accountState().open ? `Connecté avec ${{ google: 'Google', github: 'GitHub' }[result.provider] ?? result.provider}.` : '',
    confirmed: accountState().open ? 'Adresse confirmée : compte créé.' : 'Adresse confirmée.',
    recovery: '',
  };
  if (result.kind === 'error') accountUi.message('bad', result.message);
  else if (messages[result.kind]) accountUi.message('ok', messages[result.kind]);
  accountUi.focus();
});

if ('serviceWorker' in navigator && location.protocol.startsWith('http')) {
  // Quand une nouvelle version est installée, elle prend la main : on recharge une fois pour l'utiliser
  // tout de suite, au lieu de garder l'ancien code jusqu'au prochain rechargement manuel. Fiche ou réglages
  // ouverts : on attend leur fermeture (avant la version 49, le rechargement était alors oublié).
  const updating = Boolean(navigator.serviceWorker.controller);
  let reloaded = false;
  const reload = () => {
    if (reloaded) return;
    if (document.querySelector('dialog[open]')) {
      // « close » ne remonte pas jusqu'au document : on l'écoute pendant la descente (capture)
      document.addEventListener('close', () => setTimeout(reload), { capture: true, once: true });
      return;
    }
    reloaded = true;
    location.reload();
  };
  navigator.serviceWorker.addEventListener('controllerchange', () => {
    if (updating) reload();
  });
  // updateViaCache: 'none' : le navigateur vérifie toujours sw.js sur le serveur, jamais dans son cache
  navigator.serviceWorker
    .register('sw.js', { updateViaCache: 'none' })
    .then((registration) => {
      // Onglet resté ouvert (Mac) ou appli gardée en mémoire (iPhone) : la page n'est pas rechargée, donc on
      // revérifie la version à chaque retour sur StreamHub, et toutes les 30 minutes
      const check = () => {
        if (!document.hidden) registration.update().catch(() => {});
      };
      document.addEventListener('visibilitychange', check);
      setInterval(check, 30 * 60 * 1000);
    })
    .catch(() => {});
}
