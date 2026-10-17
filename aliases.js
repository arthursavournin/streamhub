// Recherche par surnom ou sigle (« DNA » → Demain nous appartient), que TMDB ne connaît pas.
// Wikidata (la base de Wikipédia) recense ces alias et, pour chaque œuvre, son identifiant TMDB.
// Gratuit, sans clé, et autorisé depuis n'importe quel site (origin=*).
const API = 'https://www.wikidata.org/w/api.php';

async function wikidata(params) {
  const url = new URL(API);
  for (const [k, v] of Object.entries({ ...params, format: 'json', origin: '*' })) url.searchParams.set(k, v);
  const res = await fetch(url);
  if (!res.ok) throw new Error(`Wikidata (${res.status})`);
  return res.json();
}

// Sigles courants absents de Wikidata (ou mal reliés à TMDB), vérifiés à la main sur TMDB
const KNOWN = {
  pblv: [{ type: 'tv', id: 8590 }, { type: 'tv', id: 243117 }], // Plus belle la vie (+ encore plus belle)
  twd: [{ type: 'tv', id: 1402 }], // The Walking Dead
  tbbt: [{ type: 'tv', id: 1418 }], // The Big Bang Theory
  b99: [{ type: 'tv', id: 48891 }], // Brooklyn Nine-Nine
  oitnb: [{ type: 'tv', id: 1424 }], // Orange Is the New Black
  svu: [{ type: 'tv', id: 2734 }], // New York, unité spéciale
  hpi: [{ type: 'tv', id: 112738 }], // HPI : Haut Potentiel Intellectuel
  lcdp: [{ type: 'tv', id: 71446 }], // La casa de papel
  fpcfpc: [{ type: 'tv', id: 35690 }], // Fais pas ci, fais pas ça
  sdm: [{ type: 'tv', id: 55216 }], // Scènes de ménages
  itc: [{ type: 'tv', id: 112470 }], // Ici tout commence
  usgs: [{ type: 'tv', id: 81329 }], // Un si grand soleil
  hotd: [{ type: 'tv', id: 94997 }], // House of the Dragon
  got: [{ type: 'tv', id: 1399 }], // Game of Thrones
  himym: [{ type: 'tv', id: 1100 }], // How I Met Your Mother
  dna: [{ type: 'tv', id: 72879 }], // Demain nous appartient
};

// Titres correspondant à un surnom ou sigle : liste intégrée + Wikidata. Renvoie [{ type: 'tv' | 'movie', id }].
const cache = new Map(); // une même recherche (frappe après frappe) n'interroge Wikidata qu'une fois

export function aliasMatches(query) {
  const q = query.trim().replace(/["\\]/g, '');
  if (q.length < 2) return Promise.resolve([]);
  const key = q.toLowerCase();
  if (!cache.has(key)) {
    const known = KNOWN[key.replace(/[^a-z0-9]/g, '')] ?? [];
    cache.set(key, wikidataMatches(q).catch(() => []).then((found) => dedupe([...known, ...found])));
  }
  return cache.get(key);
}

const dedupe = (list) => list.filter((m, i) => list.findIndex((o) => o.type === m.type && o.id === m.id) === i);

// Œuvres dont le nom ou un alias en français est exactement la recherche, et qui ont un identifiant TMDB
// (P4983 : série, P4947 : film)
async function wikidataMatches(q) {
  const search = await wikidata({
    action: 'query',
    list: 'search',
    srsearch: `inlabel:"${q}"@fr haswbstatement:P4983|P4947`,
    srlimit: '5',
  });
  const ids = (search.query?.search ?? []).map((r) => r.title);
  if (!ids.length) return [];
  const { entities = {} } = await wikidata({ action: 'wbgetentities', ids: ids.join('|'), props: 'claims' });
  const matches = [];
  for (const id of ids) {
    const claims = entities[id]?.claims ?? {};
    for (const [prop, type] of [['P4983', 'tv'], ['P4947', 'movie']]) {
      const value = claims[prop]?.[0]?.mainsnak?.datavalue?.value;
      if (value && /^\d+$/.test(value)) matches.push({ type, id: Number(value) });
    }
  }
  return matches;
}
