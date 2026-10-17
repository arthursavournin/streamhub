// Liens directs vers les épisodes TF1+ et M6+.
// Leurs adresses contiennent un identifiant interne impossible à deviner, et ces plateformes interdisent
// aux autres sites de lire leurs pages : un script GitHub (scripts/build_episode_index.py, toutes les
// 6 heures) lit leurs plans de site publics et publie avec StreamHub un index par programme :
//   data/<plateforme>/_programs.json : nom simplifié → programme
//   data/<plateforme>/<programme>.json : { base, e: numéro absolu, s: « saison-épisode », d: date }
export const INDEXED_PLATFORMS = new Set(['tf1', 'm6']);

const files = new Map(); // adresse → contenu (objet), null (absent) ou Promise en cours

// Le fichier s'il est déjà chargé (objet ou null), undefined sinon (et on lance le chargement)
function load(url, onLoaded) {
  const value = files.get(url);
  if (value instanceof Promise) return undefined;
  if (value !== undefined) return value;
  const loading = fetch(url)
    .then((res) => (res.ok ? res.json() : null))
    .catch(() => null)
    .then((data) => {
      files.set(url, data);
      onLoaded?.();
      return data;
    });
  files.set(url, loading);
  return undefined;
}

// « NCIS : Enquêtes spéciales » → « ncisenquetesspeciales » (comme les noms simplifiés de l'index)
const simplify = (title) =>
  String(title ?? '')
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .toLowerCase()
    .replace(/[^a-z0-9]/g, '');

// Lien direct de l'épisode, null si introuvable, undefined pendant le chargement de l'index
// (onLoaded est appelé une fois chargé). Recherche dans l'ordre : saison-épisode (affichés, puis
// TMDB), date de diffusion, numéro absolu (feuilletons quotidiens : « épisode 2299 »).
export function platformEpisodeUrl(platform, titles, keys, onLoaded) {
  const programs = load(`data/${platform}/_programs.json`, onLoaded);
  if (!programs) return programs;
  const program = titles.map(simplify).map((t) => programs[t]).find(Boolean);
  if (!program) return null;
  const index = load(`data/${platform}/${program}.json`, onLoaded);
  if (!index) return index;
  const { season, episode, origSeason, origEpisode, airDate, absolute } = keys;
  const file =
    index.s?.[`${season}-${episode}`] ??
    index.s?.[`${origSeason}-${origEpisode}`] ??
    (airDate ? index.d?.[airDate] : undefined) ??
    (absolute ? index.e?.[absolute] : undefined);
  return file ? index.base + file : null;
}

// Fiche d'un titre sur une chaîne de Canal+ (HBO Max, Apple TV, Paramount+), d'après l'index data/canal/<key>.json
// publié avec StreamHub (scripts/build_episode_index.py) : chemin (« /cinema/…/h/40438941_50889 »), null si le titre
// n'y est pas, undefined pendant le chargement (onLoaded est appelé une fois chargé). La fiche Canal VOD du même titre
// a une autre adresse, sans rapport.
export function canalChannelPath(key, type, titles, onLoaded) {
  const index = load(`data/canal/${key}.json`, onLoaded);
  if (!index) return index;
  const list = index[type === 'movie' ? 'movie' : 'tv'] ?? {};
  return titles.map(simplify).map((t) => list[t]).find(Boolean) ?? null;
}
