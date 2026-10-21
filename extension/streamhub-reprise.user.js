// ==UserScript==
// @name         StreamHub – reprise après connexion
// @namespace    https://arthursavournin.github.io/streamhub/
// @version      3.1
// @description  Ouvre le titre lancé depuis StreamHub après la connexion ou le choix du profil, au lieu de laisser sur l'accueil.
// @author       StreamHub
// @match        *://*/*
// @run-at       document-start
// @grant        GM.getValue
// @grant        GM.setValue
// @grant        GM.deleteValue
// @downloadURL  https://arthursavournin.github.io/streamhub/streamhub-reprise.user.js
// @updateURL    https://arthursavournin.github.io/streamhub/streamhub-reprise.user.js
// ==/UserScript==

// Un seul fichier pour tous les navigateurs : Safari (appli « Userscripts », Mac, iPhone, iPad),
// Firefox / Chrome (Tampermonkey, Violentmonkey) et l'extension Chrome du dossier extension/.
//
// StreamHub ajoute à ses liens « #streamhub=<lien voulu> ». Ce fragment est conservé par le navigateur quand
// la plateforme redirige vers sa page de connexion. Le script mémorise le lien, puis, une fois connecté et le
// profil choisi, ouvre le titre au lieu de laisser sur l'accueil.
//
// Ailleurs, et sans lien « #streamhub= » récent (15 minutes), le script ne fait rien.
(() => {
  // StreamHub en ligne, ou lancé sur son ordinateur (python3 -m http.server)
  const onStreamHub =
    (location.hostname === 'arthursavournin.github.io' && location.pathname.startsWith('/streamhub')) ||
    /^(localhost|127\.0\.0\.1)$/.test(location.hostname);

  const KEY = 'streamhub-resume';
  const MAX_AGE = 15 * 60 * 1000;
  const STABLE_MS = 1500; // écran de connexion / profil disparu depuis… avant de rediriger
  const SETTLE_MS = 4000; // page du titre affichée sans écran bloquant depuis… : on y est
  const PLAY_MS = 3000; // lecture demandée (Prime Video, série Disney+) : fiche sans lecteur depuis… → bouton de lecture

  // Stockage partagé entre les sites (la connexion se fait parfois sur un autre site que la plateforme) :
  // GM.* pour les gestionnaires de scripts, chrome.storage pour l'extension Chrome.
  const store = {
    async get(key) {
      if (typeof GM !== 'undefined' && GM.getValue) return GM.getValue(key, null);
      if (globalThis.chrome?.storage?.local) return (await chrome.storage.local.get(key))[key] ?? null;
      try {
        return JSON.parse(localStorage.getItem(key) || 'null');
      } catch {
        return null;
      }
    },
    async set(key, value) {
      if (typeof GM !== 'undefined' && GM.setValue) return GM.setValue(key, value);
      if (globalThis.chrome?.storage?.local) return chrome.storage.local.set({ [key]: value });
      localStorage.setItem(key, JSON.stringify(value));
    },
    async del(key) {
      if (typeof GM !== 'undefined' && GM.deleteValue) return GM.deleteValue(key);
      if (globalThis.chrome?.storage?.local) return chrome.storage.local.remove(key);
      localStorage.removeItem(key);
    },
  };

  // ---------- Sur StreamHub : signaler le script ----------

  if (onStreamHub) {
    document.documentElement.dataset.streamhubExtension = '1';
    return;
  }

  // ---------- Outils ----------

  const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
  const squash = (s) => String(s).toLowerCase().replace(/[^a-z0-9]/g, '');
  // « www.canalplus.com » → « canalplus » : reconnaît aussi « pass.canal-plus.com » (même marque)
  const brandOf = (host) => squash(host.split('.').slice(-2, -1)[0] ?? host);
  const siteOf = (host) => host.split('.').slice(-2).join('.');
  const isVisible = (el) => el.getClientRects().length > 0 && getComputedStyle(el).visibility !== 'hidden';
  const visible = (selector, root = document) => {
    try {
      return [...root.querySelectorAll(selector)].some(isVisible);
    } catch {
      return false;
    }
  };
  // Écran bloquant : hors en-tête (le menu du profil de l'en-tête est sur toutes les pages)
  const outsideHeader = (el) => !el.closest('header, nav, [role="navigation"], [role="banner"]');
  const visibleGate = (selector) => {
    try {
      return [...document.querySelectorAll(selector)].some((el) => isVisible(el) && outsideHeader(el));
    } catch {
      return false;
    }
  };
  // Écran de profil reconnu à son titre
  const profileTitleShown = () =>
    [...document.querySelectorAll('h1, h2, h3, [role="heading"], [class*="title" i]')].some((el) => {
      const text = el.textContent.replace(/\s+/g, ' ').trim();
      return text.length <= 40 && GATE_TITLE.test(text) && isVisible(el) && outsideHeader(el);
    });
  // Identifiant d'un titre d'après son adresse, pour reconnaître le même titre sous plusieurs adresses
  function pageRef(href) {
    let u;
    try {
      u = new URL(href);
    } catch {
      return '';
    }
    const host = u.hostname.replace(/^www\./, '');
    if (/netflix\.com$/.test(host)) {
      const id = u.searchParams.get('jbv') ?? /\/(?:title|watch)\/(\d+)/.exec(u.pathname)?.[1];
      return id ? `netflix:${id}` : '';
    }
    if (/primevideo\.com$/.test(host)) {
      const gti = u.searchParams.get('gti');
      if (gti) return `prime:${gti}`;
      const asin = /\/detail\/(?:[^/]+\/)?([A-Z0-9]{10,})/i.exec(u.pathname)?.[1];
      return asin ? `prime:${asin.toUpperCase()}` : '';
    }
    return `${host}${u.pathname.replace(/\/+$/, '').toLowerCase()}`;
  }

  // ---------- Écrans de connexion / profil ----------

  // Plateformes au comportement connu : leur page d'accueil après connexion, et ce qui bloque encore
  const KNOWN = [
    {
      host: /netflix\.com$/,
      home: /^\/(?:[a-z]{2}(?:-[a-z]{2})?\/)?browse\/?$/,
      gate: '.profile-gate-container, .list-profiles, [data-uia*="profile-gate"], [data-uia*="profile-choices"], .pin-number-container, [data-uia*="pin"]',
      ready: '.lolomo, .lolomoRow, .billboard-row, [data-uia="row-container"], .mainView .slider',
    },
    { host: /disneyplus\.com$/, home: /^\/(?:[a-z]{2}-[a-z]{2}\/)?(?:home|browse)\/?$/, gate: '[data-testid*="profile"], [data-testid*="pin"]' },
    {
      host: /primevideo\.com$/,
      home: /^\/(?:-\/[a-z]{2}(?:_[a-z]{2})?\/)?(?:region\/[a-z]+\/)?(?:storefront|home)?(?:\/|$)/,
      gate: '[data-testid*="profile"], [class*="ProfileSelection"], [data-automation-id*="profile"]',
    },
    // M6+ : au premier lancement, le site peut perdre le titre demandé et afficher l'accueil (constaté par
    // l'utilisateur, sur Mac comme sur iPhone) : on rouvre le titre une fois
    { host: /(^|\.)m6\.fr$/, home: /^\/?$/ },
    // TF1+ : au premier lancement d'une vidéo, le site reste sur la fiche du programme (« /tf1/<programme> ») ;
    // relancée une deuxième fois, la vidéo démarre (constaté par l'utilisateur)
    { host: /(^|\.)tf1\.fr$/, home: /^\/(?:[a-z0-9-]+\/[a-z0-9-]+\/?)?$/ },
  ];
  // (Canal+ : écran « Qui regarde ? », composant WhoIsWatching, affiché par-dessus la page du titre)
  const GATE = 'input[type="password"], input[autocomplete="one-time-code"], [class*="profile" i][class*="select" i], [class*="profile" i][class*="picker" i], [class*="profile" i][class*="gate" i], [data-testid*="profile" i], [class*="pincode" i], [class*="pin-code" i], [data-testid*="pin" i], [class*="WhoIsWatching" i], [class*="who-is-watching" i], [class*="whoswatching" i]';
  // Titre d'un écran de choix du profil, quelle que soit la plateforme (« Qui regarde ? », « Qui est-ce ? »…)
  const GATE_TITLE =
    /^(?:qui regarde|qui est-ce|qui est-ce qui regarde|who['’]?s watching|who is watching|wer schaut zu|chi sta guardando|(?:choisi(?:s|ssez|r)|s[ée]lectionne(?:z|r)?) (?:ton|votre|un) profil|choose (?:a|your) profile|select (?:a|your) profile)\s*[?!.]*$/i;
  // Adresses de connexion / profil, par mots entiers (« pin » ne doit pas reconnaître « /shopping »)
  const GATE_URL = /(?:^|[/_.-])(?:log-?in|sign-?in|connexion|identification|auth|authenticate|account|compte|profiles?|profils?|profilesgate|select-profile|who-?s-?watching|pin)(?=[/_.-]|$)/i;

  // ---------- Lancer la lecture depuis la fiche (Prime Video, séries Disney+) ----------

  // Prime Video : sur le site, « …?deepLinkingRedirect=1&autoplay=1 » lance certains titres mais laisse d'autres sur
  // la fiche (Naruto, constaté par l'utilisateur). Disney+ : pour reprendre une série à l'épisode suivant, StreamHub
  // ouvre la page de la série (le lien de lecture serait l'épisode 1) et le signale par « &play=1 ». Dans les deux
  // cas, si le lecteur ne s'ouvre pas, on appuie une fois sur le bouton de la fiche (« Reprendre », « Lecture »…).
  const wantsPlay = (pending) =>
    pending.play || (/(^|\.)primevideo\.com$/.test(new URL(pending.target).hostname) && /[?&]autoplay=1\b/.test(pending.target));
  const playerOpen = () =>
    Boolean(document.fullscreenElement) ||
    /^\/(?:[a-z]{2}-[a-z]{2}\/)?play\//.test(location.pathname) || // lecteur Disney+
    [...document.querySelectorAll('#dv-web-player, .webPlayerSDKContainer, [class*="webPlayer" i]')].some(
      (el) => isVisible(el) && el.getBoundingClientRect().width > innerWidth * 0.8,
    );
  // Disney+ : « Continuer » (série en cours), « Lecture » ou « Commencer » (jamais regardée) ; Prime Video :
  // « Reprendre », « Lecture » ; « Recommencer » (revenir au début) n'est pas retenu
  const PLAY_TEXT = /^(?:continuer|reprendre|lecture|lire|commencer|regarder|play|resume|continue|start|watch)\b/i;
  const NOT_PLAY = /bande|trailer|plus tard|liste|later|list|épisodes|episodes|acheter|louer|buy|rent|essai|trial|s'abonner|subscribe/i;
  function playButton() {
    const candidates = [
      ...document.querySelectorAll('[data-automation-id*="play" i], [data-testid*="play" i]'),
      ...document.querySelectorAll('button, a[role="button"], a[href*="autoplay"]'),
    ].filter((el) => isVisible(el) && outsideHeader(el));
    return candidates.find((el) => {
      const text = (el.getAttribute('aria-label') || el.textContent).replace(/\s+/g, ' ').trim();
      return text.length <= 60 && PLAY_TEXT.test(text) && !NOT_PLAY.test(text);
    });
  }

  // ---------- Parcours ouvert depuis StreamHub ----------

  const samePage = (a, b) => {
    const norm = (href) => {
      const u = new URL(href);
      return u.hostname + u.pathname.replace(/^\/(?:[a-z]{2}(?:-[a-z]{2})?|-\/[a-z]{2})(?=\/)/, '').replace(/\/+$/, '');
    };
    try {
      if (norm(a) === norm(b)) return true;
    } catch {
      return false;
    }
    const ra = pageRef(a);
    return Boolean(ra) && ra === pageRef(b);
  };

  let settledSince = null;
  async function check() {
    const pending = await store.get(KEY);
    if (!pending || Date.now() - pending.at > MAX_AGE) {
      if (pending) await store.del(KEY);
      return false;
    }
    // Uniquement sur les sites de la plateforme (ou de sa connexion) : jamais sur un site sans rapport
    if (!squash(location.hostname).includes(pending.brand)) return true;

    const known = KNOWN.find((k) => k.host.test(location.hostname));
    // Écran de connexion / profil / code PIN, y compris affiché à l'adresse même du titre (Netflix, Prime)
    if (visibleGate(GATE) || (known && visibleGate(known.gate)) || profileTitleShown() || GATE_URL.test(location.pathname)) {
      if (!pending.sawGate || pending.reached) await store.set(KEY, { ...pending, sawGate: true, reached: false });
      settledSince = null;
      return true;
    }
    settledSince ??= Date.now();
    const settled = Date.now() - settledSince;

    // Sur la page du titre : c'est arrivé (on surveille encore un écran de profil tardif)
    if (samePage(location.href, pending.target) || (pending.landing && samePage(location.href, pending.landing))) {
      if (!pending.played && settled >= PLAY_MS && wantsPlay(pending) && !playerOpen()) {
        const button = playButton();
        if (button) {
          await store.set(KEY, { ...pending, played: true, reached: true }); // une seule fois, puis on s'arrête
          button.click();
          return true;
        }
      }
      if (!pending.reached && settled >= SETTLE_MS) await store.set(KEY, { ...pending, reached: true });
      return true;
    }
    // Ailleurs sur la plateforme, après être arrivé sur le titre : c'est toi qui navigues, on s'arrête
    if (pending.reached) {
      await store.del(KEY);
      return false;
    }
    // Ailleurs, sans être arrivé : écran de connexion passé (même site), ou page d'accueil d'une plateforme connue
    const target = new URL(pending.target);
    const ok =
      (pending.sawGate && location.hostname.endsWith(siteOf(target.hostname))) ||
      (known && known.home.test(location.pathname) && (!known.ready || visible(known.ready)));
    if (!ok) {
      settledSince = null;
      return true;
    }
    if (settled < STABLE_MS) return true;
    if (pending.redirected) {
      await store.del(KEY); // une seule tentative : pas de boucle si la plateforme refuse
      return false;
    }
    await store.set(KEY, { ...pending, sawGate: false, redirected: true });
    location.replace(pending.target);
    return false;
  }

  async function start() {
    // Arrivée depuis StreamHub : on mémorise le lien voulu et on retire le fragment de l'adresse
    const params = new URLSearchParams(location.hash.slice(1));
    const wanted = params.get('streamhub');
    if (wanted && /^https?:\/\//.test(wanted)) {
      history.replaceState(null, '', location.pathname + location.search);
      const known = KNOWN.find((k) => k.host.test(location.hostname));
      const gated = GATE_URL.test(location.pathname);
      await store.set(KEY, {
        target: wanted,
        play: params.get('play') === '1', // StreamHub demande la lecture depuis la fiche (série Disney+)
        at: Date.now(),
        brand: brandOf(new URL(wanted).hostname),
        sawGate: gated,
        // Page d'arrivée (la plateforme peut rediriger le lien vers une autre adresse du même titre)
        landing: gated || known?.home.test(location.pathname) ? null : location.href,
      });
    }
    if (!(await store.get(KEY))) return; // rien en attente : le script s'arrête ici
    while (await check()) await sleep(500);
  }

  start();

})();
