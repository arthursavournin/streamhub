// Recherche plus tolérante et plus précise que celle de TMDB :
// - fautes de frappe : la recherche est comparée aux titres les plus populaires (data/search/titles.json, publié avec le
//   site par scripts/build_episode_index.py) pour proposer « Tu voulais dire « Harry Potter » ? » (« hary poter »)
// - numéro de film : « harry potter 1 » ne garde que le 1er film de la saga (et un éventuel 11e), pas « Les Reliques de
//   la Mort - 1re partie », qui est le 7e
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

// « harry potter 12 » → { text: 'harry potter', number: '12' } ; number vide sans numéro à la fin
export function splitNumber(query) {
  const m = /^(.*\D)\s*(\d{1,3})$/.exec(simplify(query));
  return m && m[1].trim().length >= 2 ? { text: m[1].trim(), number: m[2] } : { text: simplify(query), number: '' };
}

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
  const { text, number } = splitNumber(query);
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
  return best ? [best.shown, number].filter(Boolean).join(' ') : null;
}

// ---------- Sagas et numéros ----------

const ROMAN = { i: 1, ii: 2, iii: 3, iv: 4, v: 5, vi: 6, vii: 7, viii: 8, ix: 9, x: 10 };

// Numéro écrit juste après le nom dans le titre (« Toy Story 3 », « Rocky II »), sinon null
function numberInTitle(item, text) {
  for (const title of [item.title ?? item.name, item.original_title ?? item.original_name]) {
    const s = simplify(title);
    if (!s.startsWith(text)) continue;
    const next = s.slice(text.length).trim().split(' ')[0];
    if (/^\d+$/.test(next)) return Number(next);
    if (ROMAN[next]) return ROMAN[next];
  }
  return null;
}

// Range les résultats : chaque saga regroupée à la place de son premier film, dans l'ordre de sortie ; avec un numéro
// (« harry potter 1 »), seuls les films dont le numéro commence par celui-ci (1, 10, 11…). Sans film correspondant au
// numéro, tous les résultats restent. api : title(type, id), collection(id), searchCollections(query).
export async function arrangeSagas(results, query, api) {
  const { text, number } = splitNumber(query);
  const movies = results.filter((m) => m.media_type === 'movie').slice(0, 20);
  const infos = await Promise.all(movies.map((m) => api.title('movie', m.id).catch(() => null)));
  const collectionIds = new Set(infos.map((d) => d?.belongs_to_collection?.id).filter(Boolean));
  // Avec un numéro, la saga peut manquer des résultats (« harry potter 1 » ne trouve pas le 1er film) : on la cherche
  if (number) {
    const found = await api.searchCollections(text).catch(() => []);
    for (const c of found.slice(0, 2)) if (simplify(c.name).startsWith(text)) collectionIds.add(c.id);
  }
  const collections = (await Promise.all([...collectionIds].map((id) => api.collection(id).catch(() => null)))).filter(Boolean);

  // Position de chaque film dans sa saga (films sortis, dans l'ordre de sortie)
  const place = new Map(); // id du film → { collection, index }
  for (const c of collections) {
    const parts = (c.parts ?? []).filter((p) => p.release_date).sort((a, b) => a.release_date.localeCompare(b.release_date));
    parts.forEach((p, index) => place.set(p.id, { collection: c, index, parts }));
  }

  let list = [...results];
  if (number) {
    // Films de la saga absents des résultats : ajoutés pour pouvoir garder le bon numéro
    for (const c of collections) {
      for (const p of c.parts ?? []) {
        if (!list.some((m) => m.media_type === 'movie' && m.id === p.id)) list.push({ ...p, media_type: 'movie' });
      }
    }
    const numberOf = (m) => (m.media_type === 'movie' && place.has(m.id) ? place.get(m.id).index + 1 : numberInTitle(m, text));
    const matching = list.filter((m) => {
      const n = numberOf(m);
      return n != null && String(n).startsWith(number);
    });
    if (matching.length) list = matching.sort((a, b) => numberOf(a) - numberOf(b));
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
