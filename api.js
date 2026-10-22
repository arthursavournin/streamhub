// Accès aux deux API :
// - TMDB : catalogue, fiches, et « où regarder » par pays (données JustWatch)
// - Streaming Availability (RapidAPI) : liens directs vers le film ou la série sur chaque plateforme
// `type` vaut 'movie' (film) ou 'tv' (série), comme dans les URL de TMDB.
import { cacheGet, cacheSet, relayUrl } from './store.js';
import { autoplayLink, providerLogo, webLink, withLogos, withOriginals, withVirtualChannels, withVirtualProviders } from './providers.js';

const TMDB = 'https://api.themoviedb.org/3';
const SA_HOST = 'streaming-availability.p.rapidapi.com';
const SA_CACHE_MS = 3 * 24 * 3600 * 1000; // l'offre gratuite est limitée : on garde les liens 3 jours
// Relais StreamHub (relay/worker.js) : interroge JustWatch, qui refuse les appels directs des autres sites
const RELAY_CACHE_MS = 24 * 3600 * 1000;

// Les chemins TMDB commencent par « / » ; les autres sont des images de StreamHub (logos/)
export const img = (path, size = 'w342') => (!path ? '' : path.startsWith('/') ? `https://image.tmdb.org/t/p/${size}${path}` : path);

export class ApiError extends Error {
  constructor(message, status) {
    super(message);
    this.status = status;
  }
}

// Tris proposés dans l'interface → paramètres TMDB (les champs de date diffèrent entre films et séries)
const SORTS = {
  popularity: { movie: 'popularity.desc', tv: 'popularity.desc' },
  rating: { movie: 'vote_average.desc', tv: 'vote_average.desc' },
  recent: { movie: 'primary_release_date.desc', tv: 'first_air_date.desc' },
};

// Un mot écrit dans un autre alphabet que le latin (devanagari, cyrillique, coréen…)
const foreignScript = (text) => /[^\P{L}\p{Script=Latin}]/u.test(text);

// Partagé entre instances : une même URL n'est demandée qu'une fois par session.
const memo = new Map();

export function makeApi(settings) {
  const region = settings.region;
  const language = settings.language;

  function tmdb(path, params = {}) {
    const key = settings.tmdbKey.trim();
    if (!key) return Promise.reject(new ApiError('Ajoute ta clé TMDB dans les réglages.', 401));
    const url = new URL(TMDB + path);
    const headers = { accept: 'application/json' };
    // Jeton v4 (JWT, commence par « eyJ ») ou clé v3 classique
    if (key.startsWith('eyJ')) headers.Authorization = `Bearer ${key}`;
    else url.searchParams.set('api_key', key);
    for (const [k, v] of Object.entries(params)) {
      if (v !== undefined && v !== null && v !== '') url.searchParams.set(k, v);
    }
    const id = `${key}|${url}`;
    if (memo.has(id)) return memo.get(id);
    const request = fetch(url, { headers }).then(async (res) => {
      if (res.ok) return res.json();
      if (res.status === 401) throw new ApiError('Clé TMDB invalide. Vérifie-la dans les réglages.', 401);
      if (res.status === 429) throw new ApiError('TMDB reçoit trop de requêtes, réessaie dans un instant.', 429);
      throw new ApiError(`TMDB : erreur ${res.status}.`, res.status);
    });
    memo.set(id, request);
    request.catch(() => memo.delete(id));
    return request;
  }

  // Identifiants des plateformes du pays (même requête que la liste des réglages)
  async function regionProviderIds() {
    const lists = await Promise.all(['movie', 'tv'].map((type) => tmdb(`/watch/providers/${type}`, { watch_region: region, language })));
    return new Set(lists.flatMap((l) => l.results).map((p) => p.provider_id));
  }

  // Offres du pays d'une fiche TMDB : logos, créations d'une plateforme pas encore référencées dans le pays,
  // chaînes de Canal+
  async function regionOffers(data) {
    const offers = withLogos(data['watch/providers']?.results?.[region] ?? null);
    const available = data.networks?.length ? await regionProviderIds().catch(() => new Set()) : new Set();
    return withVirtualChannels(withOriginals(offers, data, available), region);
  }

  // Titre sans traduction dans la langue choisie : TMDB renvoie le titre d'origine, parfois dans un autre alphabet
  // (« रिपोर्टिंग लाइव », film indien de Netflix, signalé par l'utilisateur ; « Reporting Live » sur Netflix France),
  // avec une affiche d'un autre pays (brésilienne). On prend alors le titre, le résumé manquant et l'affiche de la
  // version anglaise. Un titre d'origine en alphabet latin (espagnol, italien…) est gardé : c'est souvent celui
  // qu'utilisent les plateformes françaises.
  async function localized(item, type = item?.media_type) {
    const name = item?.title ?? item?.name;
    if (!name || !foreignScript(name) || language.startsWith('en') || (type !== 'movie' && type !== 'tv')) return item;
    const en = await tmdb(`/${type}/${item.id}`, { language: 'en-US' }).catch(() => null);
    const enName = en?.title ?? en?.name;
    if (!enName || foreignScript(enName)) return item;
    return { ...item, [item.title != null ? 'title' : 'name']: enName, overview: item.overview || en.overview, poster_path: en.poster_path ?? item.poster_path };
  }
  const localizedList = async (res, type) => ({ ...res, results: await Promise.all(res.results.map((m) => localized(m, type ?? m.media_type))) });

  return {
    // Plateformes du pays, films et séries confondus (certaines ne proposent que des séries)
    async providers() {
      const lists = await Promise.all(
        ['movie', 'tv'].map((type) => tmdb(`/watch/providers/${type}`, { watch_region: region, language })),
      );
      const byId = new Map();
      for (const p of lists.flatMap((l) => l.results)) {
        if (byId.has(p.provider_id)) continue;
        byId.set(p.provider_id, {
          id: p.provider_id,
          name: p.provider_name,
          logo: providerLogo(p.provider_name, p.logo_path),
          priority: p.display_priorities?.[region] ?? p.display_priority ?? 999,
        });
      }
      return withVirtualProviders([...byId.values()].sort((a, b) => a.priority - b.priority), region);
    },

    // Fiche courte d'un titre (affiche, titre, date) : pour les titres venus du classement du moment
    async title(type, id) {
      return localized(await tmdb(`/${type}/${id}`, { language }), type);
    },

    // Sagas (« Harry Potter - Saga ») : recherche par nom, et films d'une saga
    async searchCollections(query) {
      return (await tmdb('/search/collection', { query, language })).results ?? [];
    },

    async collection(id) {
      const data = await tmdb(`/collection/${id}`, { language });
      return { ...data, parts: await Promise.all((data.parts ?? []).map((m) => localized(m, 'movie'))) };
    },

    // Suggestions de la fiche (voir suggestions.js) : titres conseillés par TMDB (vus par les mêmes spectateurs), titres
    // proches (genres, mots-clés), et fiche avec ses mots-clés pour reconnaître une suite ou une série dérivée
    async recommendations(type, id) {
      const res = await tmdb(`/${type}/${id}/recommendations`, { language });
      return localizedList({ ...res, results: res.results.map((m) => ({ ...m, media_type: m.media_type ?? type })) });
    },

    async similar(type, id) {
      const res = await tmdb(`/${type}/${id}/similar`, { language });
      return localizedList({ ...res, results: res.results.map((m) => ({ ...m, media_type: type })) });
    },

    withKeywords(type, id) {
      return tmdb(`/${type}/${id}`, { language, append_to_response: 'keywords' });
    },

    async genres(type) {
      const data = await tmdb(`/genre/${type}/list`, { language });
      return data.genres;
    },

    // extra : paramètres TMDB supplémentaires (ex. { with_origin_country: 'JP' })
    // networks : séries de ces diffuseurs (créations des plateformes) diffusées ces 60 derniers jours, sans filtre de
    // plateforme (pour celles que JustWatch n'a pas encore dans le pays, voir withOriginals)
    async discover(type, options) {
      return localizedList(await this.discoverRaw(type, options), type);
    },

    discoverRaw(type, { page, genre, sort, providers, networks, extra = {} }) {
      if (type === 'tv' && networks?.length) {
        const recentFrom = new Date(Date.now() - (sort === 'recent' ? 7 : 60) * 864e5).toISOString().slice(0, 10);
        return this.discoverRaw('tv', { page, genre, sort, providers: [], extra: { with_networks: networks.join('|'), 'air_date.gte': recentFrom, ...extra } });
      }
      const today = new Date().toISOString().slice(0, 10);
      // Séries les plus récentes : celles qui ont eu un épisode ces 7 derniers jours (nouvelle saison ou épisode de la
      // semaine), les plus populaires d'abord, sans talk-shows, infos, feuilletons quotidiens ni téléréalité. La date de
      // première diffusion ne dit rien des nouveaux épisodes : Les Carnets de l'apothicaire (2023) en a chaque semaine.
      if (type === 'tv' && sort === 'recent') {
        return tmdb('/discover/tv', {
          language,
          page,
          watch_region: region,
          with_watch_providers: providers.length ? providers.join('|') : undefined,
          with_watch_monetization_types: providers.length ? 'flatrate|free|ads' : undefined,
          with_genres: genre,
          without_genres: '10763,10764,10766,10767',
          'air_date.gte': new Date(Date.now() - 7 * 864e5).toISOString().slice(0, 10),
          'air_date.lte': today,
          sort_by: 'popularity.desc',
          include_adult: false,
          ...extra,
        });
      }
      const sortBy = (SORTS[sort] ?? SORTS.popularity)[type];
      const dateField = type === 'tv' ? 'first_air_date' : 'primary_release_date';
      return tmdb(`/discover/${type}`, {
        language,
        page,
        region: type === 'movie' ? region : undefined,
        watch_region: region,
        with_watch_providers: providers.length ? providers.join('|') : undefined,
        with_watch_monetization_types: providers.length ? 'flatrate|free|ads' : undefined,
        with_genres: genre,
        sort_by: sortBy,
        'vote_count.gte': sort === 'rating' ? (type === 'tv' ? 150 : 300) : sort === 'recent' ? 10 : undefined,
        [`${dateField}.lte`]: sort === 'recent' ? today : undefined,
        include_adult: false,
        ...extra,
      });
    },

    // Chaque résultat porte son media_type ('movie' ou 'tv'). type 'all' = films et séries mélangés.
    async search(type, query, page) {
      const res = await tmdb(`/search/${type === 'all' ? 'multi' : type}`, { query, page, language, include_adult: false });
      const results =
        type === 'all'
          ? res.results.filter((r) => r.media_type === 'movie' || r.media_type === 'tv') // pas les personnes
          : res.results.map((r) => ({ ...r, media_type: type }));
      return localizedList({ ...res, results });
    },

    // Films et séries les plus vus de la semaine (sans les personnes)
    async trending() {
      const res = await tmdb('/trending/all/week', { language });
      return localizedList({ ...res, results: res.results.filter((r) => r.media_type === 'movie' || r.media_type === 'tv') });
    },

    // Autres découpages d'une série proposés sur TMDB (ex. « TF1+ » : les saisons telles que la plateforme les présente)
    async episodeGroups(tvId) {
      const data = await tmdb(`/tv/${tvId}/episode_groups`);
      return data.results ?? [];
    },

    episodeGroup(groupId) {
      return tmdb(`/tv/episode_group/${groupId}`, { language });
    },

    // Détail d'une saison : liste des épisodes avec résumé, image, date, durée
    season(tvId, number) {
      return tmdb(`/tv/${tvId}/season/${number}`, { language });
    },

    async details(type, id) {
      const data = await tmdb(`/${type}/${id}`, {
        language,
        append_to_response: 'watch/providers,videos,credits',
        include_video_language: `${language.slice(0, 2)},en,null`,
      });
      const offers = await regionOffers(data);
      if (offers) (data['watch/providers'] ??= { results: {} }).results[region] = offers;
      return localized(data, type);
    },

    // Offres pour le pays choisi : { link, flatrate, free, ads, rent, buy } ou null. Pour une série, la fiche
    // entière (ses diffuseurs et ses dates servent à regionOffers)
    async offers(type, id) {
      if (type === 'tv') return regionOffers(await tmdb(`/tv/${id}`, { language, append_to_response: 'watch/providers' }));
      const data = await tmdb(`/${type}/${id}/watch/providers`);
      return withVirtualChannels(withLogos(data.results?.[region] ?? null), region);
    },

    // Liens directs d'après JustWatch (via le relais) : [{ provider, type: FLATRATE | FREE | ADS | RENT | BUY, url, deeplink }]
    async relayOffers(type, tmdbId, title) {
      const cacheKey = `jw:${type}:${region}:${tmdbId}`;
      // Liens web seulement (voir webLink), aussi pour les réponses déjà en mémoire
      const safe = (offers) =>
        offers.map((o) => ({ ...o, url: webLink(o.url), deeplink: webLink(o.deeplink) })).filter((o) => o.url);
      const cached = cacheGet(cacheKey, RELAY_CACHE_MS);
      if (cached) return safe(cached);
      const params = new URLSearchParams({ tmdb: tmdbId, type, title, country: region });
      const res = await fetch(`${relayUrl(settings)}/offers?${params}`);
      if (!res.ok) throw new ApiError(`Relais : erreur ${res.status}.`, res.status);
      const { offers = [] } = await res.json();
      cacheSet(cacheKey, offers);
      return safe(offers);
    },

    // Liens directs (fiche ou lecture) par plateforme, via Streaming Availability v4.
    // Pour une série, on récupère aussi les liens de chaque saison et de chaque épisode.
    // Renvoie { options, seasons: [{ number, options, episodes: [{ number, options }] }] } ou null sans clé.
    async streamingOptions(type, tmdbId) {
      if (!settings.saKey.trim()) return null;
      const country = region.toLowerCase();
      const cacheKey = `sa4:${type}:${country}:${tmdbId}`;
      const cached = cacheGet(cacheKey, SA_CACHE_MS);
      if (cached) return cached;

      const params = new URLSearchParams({ country });
      if (type === 'tv') params.set('series_granularity', 'episode');
      const res = await fetch(`https://${SA_HOST}/shows/${type}/${tmdbId}?${params}`, {
        headers: { 'X-RapidAPI-Key': settings.saKey.trim(), 'X-RapidAPI-Host': SA_HOST },
      });
      if (res.status === 404) {
        const empty = { options: [], seasons: [] };
        cacheSet(cacheKey, empty);
        return empty;
      }
      if (!res.ok) {
        if (res.status === 401 || res.status === 403) throw new ApiError('Clé Streaming Availability invalide ou non abonnée.', res.status);
        if (res.status === 429) throw new ApiError('Quota Streaming Availability atteint pour aujourd’hui.', 429);
        throw new ApiError(`Streaming Availability : erreur ${res.status}.`, res.status);
      }
      const data = await res.json();
      const pick = (streamingOptions) =>
        (streamingOptions?.[country] ?? [])
          .map((o) => ({
            service: o.service?.id,
            name: o.service?.name,
            type: o.type, // subscription | free | addon | rent | buy
            link: webLink(o.link), // liens web seulement (voir webLink)
            videoLink: webLink(o.videoLink) ?? autoplayLink(webLink(o.link)),
            addon: o.addon?.name ?? null,
          }))
          .filter((o) => o.link);
      const result = {
        options: pick(data.streamingOptions),
        seasons: (data.seasons ?? []).map((s, i) => ({
          // Le numéro n'est pas un champ documenté : on le lit dans le titre (« Season 2 »), sinon l'ordre
          number: Number(String(s.title ?? '').match(/\d+/)?.[0] ?? i + 1),
          options: pick(s.streamingOptions),
          episodes: (s.episodes ?? []).map((e, j) => ({
            number: e.episodeNumber ?? j + 1,
            options: pick(e.streamingOptions),
          })),
        })),
      };
      cacheSet(cacheKey, result);
      return result;
    },
  };
}

// ---------- Vérification des clés (bouton « Tester » des réglages) ----------
// Chaque test renvoie un message à afficher ; il lève une ApiError si la clé ne marche pas.

export async function testTmdbKey(key) {
  const url = new URL(`${TMDB}/configuration`);
  const headers = { accept: 'application/json' };
  if (key.startsWith('eyJ')) headers.Authorization = `Bearer ${key}`;
  else url.searchParams.set('api_key', key);
  const res = await fetch(url, { headers, cache: 'no-store' });
  if (res.ok) return 'Clé TMDB valide.';
  throw new ApiError(res.status === 401 ? 'Clé TMDB refusée.' : `TMDB répond ${res.status}.`, res.status);
}

// Une requête du quota Streaming Availability
export async function testSaKey(key, region) {
  const res = await fetch(`https://${SA_HOST}/countries/${region.toLowerCase()}`, {
    headers: { 'X-RapidAPI-Key': key, 'X-RapidAPI-Host': SA_HOST },
    cache: 'no-store',
  });
  const left = res.headers.get('x-ratelimit-requests-remaining');
  if (res.ok) return `Clé Streaming Availability valide${left ? ` (${left} requêtes restantes sur ton forfait)` : ''}.`;
  if (res.status === 401 || res.status === 403) throw new ApiError('Clé refusée, ou pas abonnée à Streaming Availability sur RapidAPI.', res.status);
  if (res.status === 429) throw new ApiError('Clé valide, mais quota épuisé pour le moment.', 429);
  throw new ApiError(`Streaming Availability : erreur ${res.status}.`, res.status);
}

export async function testRelay(url) {
  const res = await fetch(`${url}/`, { cache: 'no-store' }).catch(() => null);
  const data = res?.ok ? await res.json().catch(() => null) : null;
  if (data?.service === 'StreamHub relay') return 'Relais joignable.';
  throw new ApiError('Relais injoignable à cette adresse (ou il refuse ce site).', res?.status ?? 0);
}
