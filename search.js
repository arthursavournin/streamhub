// Recherche plus tolérante et plus précise que celle de TMDB :
// - fautes de frappe : la recherche est comparée aux titres les plus populaires (data/search/titles.json, publié avec le
//   site par scripts/build_episode_index.py) pour proposer « Tu voulais dire « Harry Potter » ? » (« hary poter »)
// - numéro de film : « harry potter 1 » ne garde que le 1er film de la saga (et un éventuel 11e), pas « Les Reliques de
//   la Mort - 1re partie », qui est le 7e ; « harry potter 7 partie 2 » : le film en deux parties numéro 7, 2e partie
// - sagas : les films d'une même saga sont regroupés et rangés dans l'ordre (1, 2, 3)

// « Grey's Anatomy » → « greys anatomy » (même calcul que simple_title du script)
export const simplify = (text) =>
  String(text ?? '')
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .toLowerCase()
    .replace(/['’]/g, '')
    .match(/[a-z0-9]+/g)
    ?.join(' ') ?? '';

// Mots qui annoncent une partie (« 2e partie », « Part Two », « Vol. 2 », « Chapitre 2 ») et nombres écrits en lettres
const PART = '(?:partie|part|volume|vol|chapitre|chapter)';
const PART_AFTER = new RegExp(`(?:^| )${PART} (\\w+)`); // « partie 2 », « part two »
const PART_BEFORE = new RegExp(`(\\w+) ${PART}(?: |$)`); // « 2eme partie », « deuxieme partie »
const ROMAN = { i: 1, ii: 2, iii: 3, iv: 4, v: 5, vi: 6, vii: 7, viii: 8, ix: 9, x: 10 };
const WORDS = {
  un: 1, une: 1, one: 1, premier: 1, premiere: 1, first: 1,
  deux: 2, two: 2, deuxieme: 2, second: 2, seconde: 2,
  trois: 3, three: 3, troisieme: 3, third: 3, quatre: 4, four: 4, quatrieme: 4, fourth: 4,
};

// « 2 », « 2eme », « 2nd », « ii », « deux » → 2 ; sinon null
function toNumber(word) {
  if (!word) return null;
  const digits = /^(\d{1,3})(?:e|er|ere|eme|nd|st|rd|th)?$/.exec(word);
  return digits ? Number(digits[1]) : ROMAN[word] ?? WORDS[word] ?? null;
}

// Numéro de partie écrit dans un titre (« Les Reliques de la Mort - 2e partie » → 2), avec la position du mot de
// partie (pour comparer le début des titres) ; null sans partie
function partOf(title) {
  const s = simplify(title);
  for (const re of [PART_BEFORE, PART_AFTER]) {
    const m = re.exec(s);
    const n = m && toNumber(m[1]);
    if (n) return { n, prefix: s.slice(0, m.index).trim() };
  }
  return null;
}

// « harry potter 7 partie 2 » → { text: 'harry potter', number: '7', part: 2, rest: '7 partie 2' }.
// Le numéro du film est le premier nombre après le nom ; la suite peut préciser une partie.
export function parseQuery(query) {
  const words = simplify(query).split(' ').filter(Boolean);
  const i = words.findIndex((w, k) => k > 0 && /^\d{1,3}$/.test(w));
  if (i < 1 || words.slice(0, i).join(' ').length < 2) return { text: words.join(' '), number: '', part: null, rest: '' };
  const after = words.slice(i + 1).join(' ');
  const m = PART_AFTER.exec(after) ?? PART_BEFORE.exec(after);
  return { text: words.slice(0, i).join(' '), number: words[i], part: m ? toNumber(m[1]) : null, rest: words.slice(i).join(' ') };
}

// Ancienne forme, gardée pour app.js : { text, number }
export const splitNumber = (query) => parseQuery(query);

// ---------- Fautes de frappe ----------

let titles = null; // Promise : [{ words: ['harry', 'potter', …], shown: ['Harry', 'Potter', …], weight }]

// Liste des titres, chargée à la première recherche (environ 300 Ko compressés)
export function loadTitles() {
  titles ??= fetch('data/search/titles.json')
    .then((res) => (res.ok ? res.json() : []))
    .catch(() => [])
    .then((list) =>
      list.map(([title, weight]) => {
        const pairs = String(title).split(/[\s\-–]+/).map((w) => [simplify(w).replace(/ /g, ''), w.replace(/[:,;.!?]+$/, '')]).filter(([s]) => s);
        return { words: pairs.map(([s]) => s), shown: pairs.map(([, w]) => w), weight };
      }),
    );
  return titles;
}

// Distance de Damerau-Levenshtein (lettre en trop, en moins, remplacée ou inversée), au-delà de max : max + 1
function distance(a, b, max) {
  if (Math.abs(a.length - b.length) > max) return max + 1;
  let prev2 = null;
  let prev = Array.from({ length: b.length + 1 }, (_, j) => j);
  for (let i = 1; i <= a.length; i++) {
    const cur = [i];
    let best = i;
    for (let j = 1; j <= b.length; j++) {
      let v = Math.min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + (a[i - 1] === b[j - 1] ? 0 : 1));
      if (prev2 && i > 1 && j > 1 && a[i - 1] === b[j - 2] && a[i - 2] === b[j - 1]) v = Math.min(v, prev2[j - 2] + 1);
      cur.push(v);
      best = Math.min(best, v);
    }
    if (best > max) return max + 1;
    prev2 = prev;
    prev = cur;
  }
  return prev[b.length];
}

// Correction proposée (« Harry Potter 1 » pour « hary poter 1 »), ou null si la recherche correspond déjà à un titre.
// On compare la recherche à chaque suite de mots des titres (du même nombre de mots, ou d'un de plus : « starwars »),
// sans tenir compte des espaces. Le dernier mot peut être en cours de frappe : « harry pot » est le début d'un vrai titre,
// rien à corriger. Au plus une faute pour 4 lettres, 3 en tout ; à égalité, le titre le plus populaire.
export function suggest(query, list) {
  const { text, rest } = parseQuery(query);
  const words = text.split(' ').filter(Boolean);
  const joined = words.join(' ');
  const glued = words.join('');
  const max = Math.min(3, Math.floor(glued.length / 4));
  if (!words.length || !max) return null;
  const typed = words[words.length - 1];
  let best = null;
  for (const t of list) {
    for (const size of [words.length, words.length + 1]) {
      for (let i = 0; i + size <= t.words.length; i++) {
        const win = t.words.slice(i, i + size);
        const end = win[size - 1];
        // Début du dernier mot seulement (frappe en cours)
        const cutWords = end.length > typed.length ? [...win.slice(0, -1), end.slice(0, typed.length)] : win;
        if (size === words.length && cutWords.join(' ') === joined) return null; // un vrai titre (ou son début)
        const full = win.join('');
        const cut = cutWords.join('');
        if (Math.min(Math.abs(full.length - glued.length), Math.abs(cut.length - glued.length)) > max) continue;
        const limit = best ? Math.min(max, best.d) : max;
        const d = Math.min(distance(glued, full, limit), distance(glued, cut, limit));
        if (d <= max && (!best || d < best.d || (d === best.d && t.weight > best.weight))) {
          best = { d, weight: t.weight, shown: t.shown.slice(i, i + size).join(' ') };
        }
      }
    }
  }
  return best ? [best.shown, rest].filter(Boolean).join(' ') : null;
}

// ---------- Sagas et numéros ----------

// Numéro écrit juste après le nom dans le titre (« Toy Story 3 », « Rocky II »), sinon null
function numberInTitle(item, text) {
  for (const title of [item.title ?? item.name, item.original_title ?? item.original_name]) {
    const s = simplify(title);
    if (!`${s} `.startsWith(`${text} `)) continue; // mots entiers : « dune » n'est pas le début de « dunes »
    const next = s.slice(text.length).trim().split(' ')[0];
    if (/^\d+$/.test(next)) return Number(next);
    if (ROMAN[next]) return ROMAN[next];
  }
  return null;
}

// Partie d'un film : dans son titre français, sinon dans son titre original
const partOfItem = (m) => partOf(m.title ?? m.name) ?? partOf(m.original_title ?? m.original_name);

// Range les résultats : chaque saga regroupée à la place de son premier film, dans l'ordre de sortie.
// Avec un numéro (« harry potter 1 »), seuls les films dont le rang dans la saga commence par celui-ci (1, 10, 11…).
// Avec une partie (« harry potter 7 partie 2 ») : les films sortis en plusieurs parties partagent un numéro (Les
// Reliques de la Mort 1 et 2 = 7 ; Hunger Games La Révolte 1 et 2 = 3), on garde le numéro et la partie demandés.
// Sans film correspondant, tous les résultats restent. api : title(type, id), collection(id), searchCollections(query).
export async function arrangeSagas(found, query, api) {
  const { text, number, part } = parseQuery(query);
  const seen = new Set();
  const results = found.filter((m) => !seen.has(`${m.media_type}:${m.id}`) && seen.add(`${m.media_type}:${m.id}`));
  const movies = results.filter((m) => m.media_type === 'movie').slice(0, 20);
  const infos = await Promise.all(movies.map((m) => api.title('movie', m.id).catch(() => null)));
  const collectionIds = new Set(infos.map((d) => d?.belongs_to_collection?.id).filter(Boolean));
  // Avec un numéro, la saga peut manquer des résultats (« harry potter 1 » ne trouve pas le 1er film) : on la cherche
  if (number) {
    const found = await api.searchCollections(text).catch(() => []);
    for (const c of found.slice(0, 2)) if (simplify(c.name).startsWith(text)) collectionIds.add(c.id);
  }
  const collections = (await Promise.all([...collectionIds].map((id) => api.collection(id).catch(() => null)))).filter(Boolean);

  // Position de chaque film dans sa saga (films sortis, dans l'ordre de sortie), et son numéro « logique » : deux films
  // qui se suivent avec le même début de titre et un numéro de partie (« … 1re partie », « … 2e partie ») ont le même
  const place = new Map(); // id du film → { collection, index, logical, part }
  for (const c of collections) {
    const parts = (c.parts ?? []).filter((p) => p.release_date).sort((a, b) => a.release_date.localeCompare(b.release_date));
    let logical = 0;
    let previous = null;
    parts.forEach((p, index) => {
      const info = partOfItem(p);
      if (!(info && previous && previous.prefix === info.prefix && info.n > previous.n)) logical += 1;
      previous = info;
      place.set(p.id, { collection: c, index, logical, part: info?.n ?? null });
    });
  }

  let list = [...results];
  if (number) {
    // Films de la saga absents des résultats : ajoutés pour pouvoir garder le bon numéro
    for (const c of collections) {
      for (const p of c.parts ?? []) {
        if (!list.some((m) => m.media_type === 'movie' && m.id === p.id)) list.push({ ...p, media_type: 'movie' });
      }
    }
    // Saga du film, seulement si elle correspond au nom cherché (dans le nom de la saga ou le titre du film) : pour
    // « dune 2 », le 2e film d'une autre saga trouvée par TMDB (Millénium 2…) ne compte pas
    // (apostrophe = séparation de mots : « d'une » ne contient pas le mot « dune »)
    const words = (t) => ` ${simplify(String(t ?? '').replace(/['’]/g, ' '))} `;
    const named = (m, saga) =>
      [saga.collection.name, m.title ?? m.name, m.original_title ?? m.original_name].some((t) => words(t).includes(` ${text} `));
    const sagaOf = (m) => {
      const saga = m.media_type === 'movie' ? place.get(m.id) : null;
      return saga && named(m, saga) ? saga : null;
    };
    const numberOf = (m) => (sagaOf(m) ? sagaOf(m).index + 1 : numberInTitle(m, text));
    const starts = (n) => n != null && String(n).startsWith(number);
    // Avec une partie : numéro logique (ou numéro dans le titre) et partie ; sinon (ou si rien ne correspond) : le rang
    let matching = part
      ? list.filter((m) => (sagaOf(m) ? starts(sagaOf(m).logical) && sagaOf(m).part === part : starts(numberInTitle(m, text)) && partOfItem(m)?.n === part))
      : [];
    if (!matching.length) matching = list.filter((m) => starts(numberOf(m)));
    if (matching.length) list = matching.sort((a, b) => (numberOf(a) ?? 0) - (numberOf(b) ?? 0));
    else list = [...results];
  }

  // Regroupement des sagas, à la place du premier film de chacune
  const out = [];
  const done = new Set();
  for (const m of list) {
    const p = m.media_type === 'movie' ? place.get(m.id) : null;
    if (!p) {
      out.push(m);
      continue;
    }
    if (done.has(p.collection.id)) continue;
    done.add(p.collection.id);
    out.push(...list.filter((o) => o.media_type === 'movie' && place.get(o.id)?.collection.id === p.collection.id).sort((a, b) => place.get(a.id).index - place.get(b.id).index));
  }
  return out;
}
