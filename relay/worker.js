// Relais StreamHub (Cloudflare Worker) : https://streamhub-relay.arthursavournin.workers.dev
//
// JustWatch connaît le lien direct d'un titre sur chaque plateforme (ex. Prime Video, chaînes Amazon
// comme France TV), mais son API refuse les appels venant d'autres sites. Ce relais l'interroge à la
// place du navigateur et renvoie ces liens à StreamHub.
//
//   GET /offers?tmdb=317555&type=tv&title=Michael%20Jackson&country=FR
//   → { found: true, offers: [{ provider, type, url, deeplink }] }
//
//   GET /country → { country: "FR" }
//   Pays de la connexion (wifi, réseau mobile ou VPN), tel que Cloudflare le voit : StreamHub choisit ainsi le catalogue
//   du pays où l'on se trouve (version 2.8.0). Rien n'est gardé.
//
// Il ne stocke rien. (Jusqu'à la version 2.3.3, il gardait aussi dans Workers KV les données de l'ancienne
// synchronisation par code, retirée en 2.1.0 : route /sync supprimée après l'audit de sécurité, car n'importe qui
// pouvait y écrire.)
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
    'Access-Control-Allow-Methods': 'GET, OPTIONS',
    'Access-Control-Allow-Headers': 'content-type',
    Vary: 'Origin',
  };
}

const json = (body, request, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...corsHeaders(request), 'content-type': 'application/json' } });

export default {
  async fetch(request, env, ctx) {
    if (request.method === 'OPTIONS') return new Response(null, { status: 204, headers: corsHeaders(request) });
    const url = new URL(request.url);
    if (url.pathname === '/country') {
      const country = request.cf?.country;
      return new Response(JSON.stringify({ country: /^[A-Z]{2}$/.test(country ?? '') ? country : null }), {
        headers: { ...corsHeaders(request), 'content-type': 'application/json', 'cache-control': 'no-store' },
      });
    }
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

    // Limite de débit par adresse IP (liaison LIMITER, voir scripts/deploy_relay.sh) : le relais ne sert pas de
    // passerelle JustWatch illimitée à n'importe qui (audit de sécurité, F3). Seules les vraies questions à JustWatch
    // comptent, pas les réponses en cache.
    if (env.LIMITER) {
      const { success } = await env.LIMITER.limit({ key: request.headers.get('cf-connecting-ip') ?? 'inconnu' });
      if (!success) return json({ error: 'Trop de demandes : réessaie dans une minute.' }, request, 429);
    }

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
    // Seule une réponse trouvée (même identifiant TMDB) est gardée : un titre faux ou absent ne doit pas cacher les
    // liens du film aux autres pendant 6 heures (audit de sécurité, F3)
    if (node) {
      ctx.waitUntil(
        caches.default.put(cacheKey, new Response(JSON.stringify(body), { headers: { 'cache-control': `public, max-age=${CACHE_SECONDS}` } })),
      );
    }
    return json(body, request);
  },
};
