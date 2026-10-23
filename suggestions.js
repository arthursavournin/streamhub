// Onglet « Suggestions » de la fiche, dans cet ordre :
// - les autres films de la saga (Harry Potter : les 7 autres films, dans l'ordre de sortie) ;
// - les titres du même univers, films et séries : TMDB ne relie pas un film à une série (Harry Potter → la série HBO,
//   Naruto → Naruto Shippuden, Boruto et les films, Breaking Bad → El Camino et Better Call Saul). Voir universeTitles ;
// - des titres du même genre (conseillés par TMDB, puis proches), ceux de tes abonnements d'abord (choix dans app.js).
// Vérifié le 21 octobre 2026 sur Harry Potter, Naruto, Boruto, Breaking Bad, Star Wars, Le Seigneur des anneaux, Dune ;
// rien d'ajouté à tort pour des noms courants (Lupin, Lost, You, Friends, Inception).
import { simplify } from './search.js';

// Genres des séries → genres des films équivalents (TMDB n'a pas les mêmes)
const TV_TO_MOVIE = { 10759: [28, 12], 10765: [878, 14], 10768: [10752], 10762: [10751] };
const genreSet = (ids) => new Set((ids ?? []).flatMap((id) => TV_TO_MOVIE[id] ?? [id]));
// Documentaires, infos, téléréalité, talk-shows : « Harry Potter : Les Sorciers de la pâtisserie », « Retour à Poudlard »
const OFF_GENRES = [99, 10763, 10764, 10767];
// Mots-clés TMDB d'une suite ou d'une série dérivée (Better Call Saul : « prequel », « spin off »)
const SEQUEL = /sequel|prequel|spin.?off|based on (tv series|movie|film)/;
// Vérifications (fiche complète d'un titre) au plus par fiche ouverte : titres contenant le nom, titres conseillés
const MAX_CHECKS = { named: 12, recommended: 10 };

const titleOf = (m) => m.title ?? m.name ?? '';
const originalOf = (m) => m.original_title ?? m.original_name ?? '';
const dateOf = (m) => m.release_date ?? m.first_air_date ?? '';
const keyOf = (m) => `${m.media_type}:${m.id}`;
const latin = (text) => !/[^\P{L}\p{Script=Latin}]/u.test(text);

// Nom de la saga sans « - Saga » / « Collection » : « Harry Potter - Saga » → « Harry Potter »
const sagaName = (collection) =>
  String(collection?.name ?? '').replace(/^(la )?saga\s+/i, '').replace(/\s*[-–:]?\s*(la saga|saga|the collection|collection)$/i, '').trim();

// Le nom en mots entiers dans le titre (« Rogue One : A Star Wars Story » contient « Star Wars »)
const contains = (title, name) => ` ${simplify(title)} `.includes(` ${simplify(name)} `);

// Noms sous lesquels chercher l'univers : la saga, puis le titre et le titre d'origine avant « : »
// (« Boruto : Naruto Next Generations » → « Boruto »)
function universeNames(item) {
  const names = [sagaName(item.belongs_to_collection), titleOf(item), originalOf(item)]
    .filter((n) => n && latin(n))
    .map((n) => n.split(/\s*[:–]\s+|\s+-\s+/)[0].trim());
  // Sans les doublons, ni les noms qui contiennent un nom déjà retenu (« Harry Potter à l'école des sorciers »)
  return names.filter((n, i) => simplify(n).length > 1 && !names.slice(0, i).some((m) => contains(n, m)));
}

// Le titre commence par le nom suivi de rien, d'une ponctuation ou d'un numéro : « Harry Potter », « Star Wars : Andor »,
// « Naruto Shippuden : Les Liens » (et « 劇場版 NARUTO -ナルト- … » : les autres alphabets sont ignorés). Pas « Lost in
// Space » pour « Lost », ni « Star Wars Rebels » (vérifié autrement).
function namedAfter(title, name) {
  const text = String(title ?? '').normalize('NFD').replace(/[^\x20-\x7e]/g, '').toLowerCase();
  const words = simplify(name).split(' ').map((w) => w.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'));
  const m = new RegExp(`^[^a-z0-9]*${words.join("[^a-z0-9]+")}(.*)$`).exec(text);
  return Boolean(m) && (!m[1].trim() || /^\s*([:,(-]|\d|(i{1,3}|iv)\b)/.test(m[1]));
}

// Les autres films de la saga, dans l'ordre de sortie
export async function sagaTitles(api, item) {
  const id = item.belongs_to_collection?.id;
  if (!id) return { name: '', items: [] };
  const saga = await api.collection(id);
  const items = saga.parts
    .filter((p) => p.id !== item.id)
    .map((p) => ({ ...p, media_type: 'movie' }))
    .sort((a, b) => (dateOf(a) || '9999').localeCompare(dateOf(b) || '9999'));
  return { name: sagaName(saga) || sagaName(item.belongs_to_collection), items };
}

// Titres du même univers. Candidats : recherche TMDB par le nom de l'univers (films et séries, et autres sagas de ce nom)
// et titres conseillés par TMDB. Gardés seulement s'ils sont dans la même langue d'origine, pas documentaire ni
// téléréalité (sauf si le titre l'est), sortis (au moins 5 votes) ou annoncés / sortis depuis moins d'un an, et :
// - nommés d'après l'univers (« Star Wars : Andor », la série « Harry Potter »), avec un genre en commun ;
// - ou contenant le nom avec une société de production ou un créateur en commun (« El Camino : un film Breaking Bad »,
//   « Naruto Shippuden », « Rogue One : A Star Wars Story ») ;
// - ou conseillés par TMDB, avec au moins deux sociétés de production en commun et un mot-clé de suite ou de série
//   dérivée (Better Call Saul pour Breaking Bad). Sans ce mot-clé, Pluribus (même créateur, mêmes sociétés) passait.
// exclude : clés « type:id » déjà affichées (la saga)
export async function universeTitles(api, item, type, exclude = new Set()) {
  const names = universeNames(item);
  const base = {
    language: item.original_language,
    genres: genreSet((item.genres ?? []).map((g) => g.id)),
    companies: new Set((item.production_companies ?? []).map((c) => c.id)),
    creators: new Set((item.created_by ?? []).map((c) => c.id)),
  };
  const searches = names.flatMap((name) => [
    api.search('all', name, 1).then((r) => r.results).catch(() => []),
    api.searchCollections(name)
      .then((list) => list.filter((c) => contains(c.name, name) && c.id !== item.belongs_to_collection?.id).slice(0, 4))
      .then((list) => Promise.all(list.map((c) => api.collection(c.id).then((s) => s.parts.map((p) => ({ ...p, media_type: 'movie' }))).catch(() => []))))
      .then((lists) => lists.flat())
      .catch(() => []),
  ]);
  const [recommended, ...found] = await Promise.all([api.recommendations(type, item.id).then((r) => r.results).catch(() => []), ...searches]);

  const seen = new Set([...exclude, `${type}:${item.id}`]);
  const yearAgo = new Date(Date.now() - 365 * 864e5).toISOString().slice(0, 10);
  const offGenre = (genres) => OFF_GENRES.some((g) => genres.has(g)) && !OFF_GENRES.some((g) => base.genres.has(g));
  // Candidats : { m, names (noms de l'univers contenus dans le titre), recommended }
  const candidates = [
    ...found.flat().map((m) => ({ m, recommended: false })),
    ...recommended.map((m) => ({ m, recommended: true })),
  ].filter((c) => {
    const { m } = c;
    const genres = genreSet(m.genre_ids);
    if (seen.has(keyOf(m)) || m.original_language !== base.language || offGenre(genres)) return false;
    if ((m.vote_count ?? 0) < 5 && !(dateOf(m) >= yearAgo)) return false;
    c.names = names.filter((n) => contains(titleOf(m), n) || contains(originalOf(m), n));
    if (c.names.length && ![...genres].some((g) => base.genres.has(g))) return false;
    return c.names.length > 0 || c.recommended;
  });

  // Titres à vérifier sur leur fiche complète (mêmes choix et mêmes limites qu'avant), vérifiés tous en même temps
  // (avant : l'un après l'autre, jusqu'à 22 requêtes à la suite). Un titre trouvé deux fois (par son nom, puis dans les
  // recommandations) est revérifié avec l'autre règle, comme avant, sauf s'il est déjà gardé d'office par son nom.
  const checks = { named: 0, recommended: 0 };
  const plan = [];
  const sure = new Set(seen);
  for (const { m, names: inTitle } of candidates) {
    if (sure.has(keyOf(m))) continue;
    const ok = inTitle.some((n) => namedAfter(titleOf(m), n) || namedAfter(originalOf(m), n));
    if (ok) sure.add(keyOf(m));
    const kind = inTitle.length ? 'named' : 'recommended';
    const check = !ok && checks[kind] < MAX_CHECKS[kind];
    if (check) checks[kind]++;
    plan.push({ m, ok, check, named: inTitle.length > 0 });
  }
  const verdicts = await Promise.all(
    plan.map(async (p) => {
      if (p.ok || !p.check) return p.ok;
      const full = await api.withKeywords(p.m.media_type, p.m.id).catch(() => null);
      const shared = (full?.production_companies ?? []).filter((c) => base.companies.has(c.id)).length;
      const creator = (full?.created_by ?? []).some((c) => base.creators.has(c.id));
      const keywords = (full?.keywords?.keywords ?? full?.keywords?.results ?? []).map((k) => k.name);
      return p.named ? shared > 0 || creator : shared >= 2 && keywords.some((k) => SEQUEL.test(k));
    }),
  );
  const kept = plan.filter((p, i) => verdicts[i] && !seen.has(keyOf(p.m)) && seen.add(keyOf(p.m))).map((p) => p.m);
  // Les plus connus d'abord (Star Wars en a des dizaines : séries LEGO, parodies…)
  return kept.sort((a, b) => (b.vote_count ?? 0) - (a.vote_count ?? 0)).slice(0, 20);
}

// Titres du même genre : conseillés par TMDB, complétés par les titres proches s'il y en a peu
export async function genreTitles(api, item, type) {
  const recommended = await api.recommendations(type, item.id).then((r) => r.results).catch(() => []);
  const similar = recommended.length < 12 ? await api.similar(type, item.id).then((r) => r.results).catch(() => []) : [];
  const seen = new Set();
  return [...recommended, ...similar].filter((m) => !seen.has(keyOf(m)) && seen.add(keyOf(m)));
}
