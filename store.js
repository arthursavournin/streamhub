// Réglages et cache persistés dans le navigateur (localStorage peut être indisponible : on ne plante jamais).
// Chaque modification des réglages ou de la bibliothèque est signalée (évènement « streamhub:changed »)
// pour que sync.js l'envoie aux autres appareils (compte StreamHub).
const SETTINGS_KEY = 'streamhub:settings';

// Relais StreamHub (relay/worker.js) : liens JustWatch. Plus réglable depuis la version 2.3.4 : la page n'a le droit
// de contacter que ce relais (Content-Security-Policy d'index.html). Une copie de StreamHub change cette adresse ici.
export const DEFAULT_RELAY = 'https://streamhub-relay.arthursavournin.workers.dev';

const defaults = {
  tmdbKey: '',
  saKey: '',
  region: 'FR',
  language: 'fr-FR',
  type: 'all', // 'all' | 'movie' | 'tv'
  providers: [], // [{ id, name, logo }] — plateformes TMDB auxquelles l'utilisateur est abonné
};

export function loadSettings() {
  try {
    return { ...defaults, ...JSON.parse(localStorage.getItem(SETTINGS_KEY) || '{}') };
  } catch {
    return { ...defaults };
  }
}

const changed = (part, quiet) => quiet || window.dispatchEvent(new CustomEvent('streamhub:changed', { detail: part }));

// quiet : écriture venant de la synchronisation elle-même (pas besoin de la renvoyer)
export function saveSettings(settings, { quiet = false } = {}) {
  try {
    localStorage.setItem(SETTINGS_KEY, JSON.stringify(settings));
  } catch {
    /* stockage indisponible : les réglages ne vivront que le temps de la session */
  }
  changed('settings', quiet);
}

// (settings.relay, réglé avant la version 2.3.4 et encore présent dans certains comptes, est ignoré)
export const relayUrl = () => DEFAULT_RELAY;

export function cacheGet(key, maxAgeMs) {
  try {
    const raw = localStorage.getItem(`streamhub:cache:${key}`);
    if (!raw) return undefined;
    const { t, v } = JSON.parse(raw);
    return Date.now() - t < maxAgeMs ? v : undefined;
  } catch {
    return undefined;
  }
}

export function cacheSet(key, value) {
  const entry = JSON.stringify({ t: Date.now(), v: value });
  try {
    localStorage.setItem(`streamhub:cache:${key}`, entry);
  } catch {
    // Quota plein (les liens par épisode prennent de la place) : on vide le cache et on réessaie une fois
    try {
      Object.keys(localStorage)
        .filter((k) => k.startsWith('streamhub:cache:'))
        .forEach((k) => localStorage.removeItem(k));
      localStorage.setItem(`streamhub:cache:${key}`, entry);
    } catch {
      /* stockage bloqué : tant pis pour le cache */
    }
  }
}

// Bibliothèque personnelle : titres aimés, historique, téléchargements
const LIBRARY_KEY = 'streamhub:library';
export const HISTORY_MAX = 30;

export function loadLibrary() {
  try {
    const lib = JSON.parse(localStorage.getItem(LIBRARY_KEY) || '{}');
    return {
      likes: lib.likes ?? [],
      watchlist: lib.watchlist ?? [],
      history: lib.history ?? [],
      downloads: lib.downloads ?? [],
      pending: lib.pending ?? [],
      platformLikes: lib.platformLikes ?? {},
      removed: lib.removed ?? {},
    };
  } catch {
    return { likes: [], watchlist: [], history: [], downloads: [], pending: [], platformLikes: {}, removed: {} };
  }
}

export function saveLibrary(library, { quiet = false } = {}) {
  try {
    localStorage.setItem(LIBRARY_KEY, JSON.stringify(library));
  } catch {
    /* stockage indisponible : la bibliothèque ne vivra que le temps de la session */
  }
  changed('library', quiet);
}
