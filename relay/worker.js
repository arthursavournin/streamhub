// Relais StreamHub (Cloudflare Worker) : https://streamhub-relay.arthursavournin.workers.dev
//
// JustWatch connaît le lien direct d'un titre sur chaque plateforme (ex. Prime Video, chaînes Amazon
// comme France TV), mais son API refuse les appels venant d'autres sites. Ce relais l'interroge à la
// place du navigateur et renvoie ces liens à StreamHub.
//
//   GET /offers?tmdb=317555&type=tv&title=Michael%20Jackson&country=FR
//   → { found: true, offers: [{ provider, type, url, deeplink }] }
//
// Il sert aussi à synchroniser StreamHub entre navigateurs et appareils (réglages, clés, listes) :
//   GET /sync/<id>   → { updatedAt, iv, data }   (404 si rien n'est encore enregistré)
//   PUT /sync/<id>   ← { iv, data }            → { ok, updatedAt }  (date fixée par le relais)
// Les données sont chiffrées dans le navigateur avec le code de synchronisation (AES-GCM) : le relais
// ne stocke que du contenu illisible, rangé sous <id> = empreinte SHA-256 du code. Stockage : Workers KV.
//
// Déploiement : scripts/deploy_relay.sh (jeton Cloudflare en variable d'environnement, jamais dans le code)

const JUSTWATCH = 'https://apis.justwatch.com/graphql';
const ALLOWED_ORIGINS = ['https://arthursavournin.github.io', 'http://localhost:8080', 'http://127.0.0.1:8080'];
const CACHE_SECONDS = 6 * 3600;

const query = (country) => `query Search($q: String!) {
  popularTitles(country: ${country}, first: 10, filter: { searchQuery: $q }) {
    edges { node {
      objectType
      content(country: ${country}, language: "fr") { externalIds { tmdbId } }
      offers(country: ${country}, platform: WEB) {
        monetizationType standardWebURL deeplinkURL(platform: WEB) package { clearName }
      }
    } }
  }
}`;

function corsHeaders(request) {
  const origin = request.headers.get('Origin') ?? '';
  return {
    'Access-Control-Allow-Origin': ALLOWED_ORIGINS.includes(origin) ? origin : ALLOWED_ORIGINS[0],
    'Access-Control-Allow-Methods': 'GET, PUT, OPTIONS',
    'Access-Control-Allow-Headers': 'content-type',
    Vary: 'Origin',
  };
}

const json = (body, request, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...corsHeaders(request), 'content-type': 'application/json' } });

const MAX_SYNC_BYTES = 512 * 1024;

async function handleSync(request, env, id) {
  if (request.method === 'GET') {
    const stored = await env.SYNC.get(id);
    return stored ? json(JSON.parse(stored), request) : json({ error: 'Rien d’enregistré pour ce code' }, request, 404);
  }
  if (request.method !== 'PUT') return json({ error: 'Méthode non prise en charge' }, request, 405);
  const text = await request.text();
  if (text.length > MAX_SYNC_BYTES) return json({ error: 'Données trop volumineuses' }, request, 413);
  let body;
  try {
    body = JSON.parse(text);
  } catch {
    return json({ error: 'JSON invalide' }, request, 400);
  }
  if (typeof body.iv !== 'string' || typeof body.data !== 'string') {
    return json({ error: 'Attendu : { iv, data }' }, request, 400);
  }
  // Date du relais, pas de l'appareil : les horloges des appareils peuvent être décalées
  const updatedAt = Date.now();
  await env.SYNC.put(id, JSON.stringify({ updatedAt, iv: body.iv, data: body.data }));
  return json({ ok: true, updatedAt }, request);
}

export default {
  async fetch(request, env, ctx) {
    if (request.method === 'OPTIONS') return new Response(null, { status: 204, headers: corsHeaders(request) });
    const url = new URL(request.url);
    const sync = /^\/sync\/([0-9a-f]{64})$/.exec(url.pathname);
    if (sync) return handleSync(request, env, sync[1]);
    if (url.pathname !== '/offers') return json({ service: 'StreamHub relay' }, request);

    const tmdb = url.searchParams.get('tmdb') ?? '';
    const type = url.searchParams.get('type');
    const title = (url.searchParams.get('title') ?? '').slice(0, 200);
    const country = (url.searchParams.get('country') ?? 'FR').toUpperCase();
    if (!/^\d+$/.test(tmdb) || !['movie', 'tv'].includes(type) || !title || !/^[A-Z]{2}$/.test(country)) {
      return json({ error: 'Paramètres attendus : tmdb, type (movie|tv), title, country' }, request, 400);
    }

    // Même titre demandé plusieurs fois : réponse en cache 6 heures
    const cacheKey = new Request(`https://cache.streamhub/${country}/${type}/${tmdb}`);
    const cached = await caches.default.match(cacheKey);
    if (cached) return json(await cached.json(), request);

    const res = await fetch(JUSTWATCH, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ query: query(country), variables: { q: title } }),
    });
    if (!res.ok) return json({ error: `JustWatch (${res.status})` }, request, 502);
    const data = await res.json();

    // Le bon titre parmi les résultats : même identifiant TMDB et même type
    const wanted = type === 'tv' ? 'SHOW' : 'MOVIE';
    const node = (data.data?.popularTitles?.edges ?? [])
      .map((e) => e.node)
      .find((n) => n.objectType === wanted && n.content?.externalIds?.tmdbId === tmdb);
    const seen = new Set();
    const offers = (node?.offers ?? [])
      .map((o) => ({ provider: o.package?.clearName, type: o.monetizationType, url: o.standardWebURL, deeplink: o.deeplinkURL }))
      .filter((o) => o.provider && o.url && !seen.has(`${o.provider}|${o.type}`) && seen.add(`${o.provider}|${o.type}`));

    const body = { found: Boolean(node), offers };
    ctx.waitUntil(
      caches.default.put(cacheKey, new Response(JSON.stringify(body), { headers: { 'cache-control': `public, max-age=${CACHE_SECONDS}` } })),
    );
    return json(body, request);
  },
};
