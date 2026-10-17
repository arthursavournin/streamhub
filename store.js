// Réglages et cache persistés dans le navigateur (localStorage peut être indisponible : on ne plante jamais).
// Chaque modification des réglages ou de la bibliothèque est signalée (évènement « streamhub:changed »)
// pour que sync.js l'envoie aux autres appareils.
const SETTINGS_KEY = 'streamhub:settings';

// Relais StreamHub (relay/worker.js) : liens JustWatch et synchronisation. Modifiable dans les réglages.
export const DEFAULT_RELAY = 'https://streamhub-relay.arthursavournin.workers.dev';

const defaults = {
  tmdbKey: '',
  saKey: '',
  region: 'FR',
  language: 'fr-FR',
  type: 'all', // 'all' | 'movie' | 'tv'
  relay: '', // vide = DEFAULT_RELAY
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

export const relayUrl = (settings) => (settings.relay || DEFAULT_RELAY).replace(/\/+$/, '');

// État de la synchronisation sur cet appareil : { code, syncedAt, hashes, lastSyncAt, error }
const SYNC_KEY = 'streamhub:sync';

export function loadSyncMeta() {
  try {
    return JSON.parse(localStorage.getItem(SYNC_KEY) || '{}');
  } catch {
    return {};
  }
}

export function saveSyncMeta(meta) {
  try {
    if (meta.code) localStorage.setItem(SYNC_KEY, JSON.stringify(meta));
    else localStorage.removeItem(SYNC_KEY);
  } catch {
    /* stockage indisponible */
  }
}

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
    };
  } catch {
    return { likes: [], watchlist: [], history: [], downloads: [], pending: [], platformLikes: {} };
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
