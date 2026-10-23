// Service worker : rend l'appli installable et garde l'interface en cache (hors ligne).
// Les appels aux API passent toujours par le réseau (comptes Supabase compris : jamais mis en cache).
const SHELL_CACHE = 'streamhub-shell-v2.9.0';
const SHELL = ['./', 'index.html', 'styles.css', 'app.js', 'api.js', 'store.js', 'providers.js', 'nav.js', 'library.js', 'episodes.js', 'aliases.js', 'search.js', 'suggestions.js',
  'sync.js', 'account.js', 'account-ui.js', 'i18n.js', 'i18n-en.js', 'logos/hbo-max-amazon-channel.png', 'logos/hbo-max-canal-channel.png', 'logos/apple-tv-canal-channel.png',
  'logos/paramount-plus-canal-channel.png', 'icon.svg?v=3', 'icon-192.png?v=3', 'apple-touch-icon.png?v=3', 'manifest.webmanifest?v=3'];

self.addEventListener('install', (event) => {
  // cache: 'reload' : on prend la version du serveur, pas celle du cache du navigateur
  event.waitUntil(caches.open(SHELL_CACHE).then((cache) => cache.addAll(SHELL.map((u) => new Request(u, { cache: 'reload' })))));
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((keys) => Promise.all(keys.filter((k) => k !== SHELL_CACHE).map((k) => caches.delete(k)))),
  );
  self.clients.claim();
});

self.addEventListener('fetch', (event) => {
  const { request } = event;
  if (request.method !== 'GET') return;
  const url = new URL(request.url);
  // Retour de Google / GitHub ou d'un lien d'e-mail (?code=…) : toujours le réseau, jamais une copie en cache
  if (url.origin === self.location.origin && url.searchParams.has('code')) return;

  // Interface : réseau d'abord (pour recevoir les mises à jour), cache si hors ligne.
  // cache: 'no-cache' : le navigateur revérifie chaque fichier auprès du serveur. Sans ça, il peut garder
  // quelques minutes un ancien fichier à côté d'un nouveau après une mise à jour, et l'appli ne démarre plus.
  if (url.origin === self.location.origin) {
    event.respondWith(
      fetch(request, { cache: 'no-cache' })
        .then((res) => {
          const copy = res.clone();
          caches.open(SHELL_CACHE).then((cache) => cache.put(request, copy));
          return res;
        })
        .catch(() => caches.match(request)),
    );
  }
  // Affiches (image.tmdb.org) : le cache HTTP du navigateur suffit
});
