// ==UserScript==
// @name         StreamHub – reprise après connexion
// @namespace    https://arthursavournin.github.io/streamhub/
// @version      2.9
// @description  Ouvre le titre lancé depuis StreamHub après la connexion ou le choix du profil, au lieu de laisser sur l'accueil. Signale les épisodes hors-série (fillers) de Naruto, Naruto Shippuden et Boruto sur Netflix et Prime Video.
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
//
// Sur Netflix et Prime Video, il signale aussi les épisodes hors-série (fillers) de Naruto, Naruto Shippuden et
// Boruto : cadre rouge « Filler » dans la liste des épisodes, bandeau au lancement d'un épisode filler.
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

  // ---------- Épisodes hors-série (fillers) sur Netflix et Prime Video ----------

  // Naruto, Naruto Shippuden et Boruto (demande de l'utilisateur) : la liste des fillers est celle de StreamHub
  // (fillers.json, d'après animotaku.fr). Un épisode est reconnu à son titre (titres français de TMDB, les mêmes
  // que ceux des plateformes la plupart du temps), sinon à son numéro et à sa saison. Netflix numérote les
  // épisodes de Shippuden de 1 à 500, ceux de Naruto à partir de 1 dans chaque saison : on accepte les deux.
  // Les pages de Netflix et Prime Video connectées n'ont pas pu être vues en écrivant ce code : les éléments
  // cherchés (classes, data-uia, data-testid) sont ceux connus de ces sites, à vérifier sur place.
  const fillerSite = /(^|\.)netflix\.com$/.test(location.hostname)
    ? 'netflix'
    : /(^|\.)primevideo\.com$/.test(location.hostname)
      ? 'prime'
      : document.documentElement.dataset.streamhubFillerTest || null; // pages de test de StreamHub (mobiletest/)
  if (fillerSite) setTimeout(() => fillerWatch(fillerSite), 0);

  function fillerWatch(site) {
    const shows = fillerData();
    const norm = (text) =>
      String(text ?? '').normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase().replace(/[^a-z0-9]/g, '');
    const textOf = (el) => (el?.textContent ?? '').replace(/\s+/g, ' ').trim();
    const shown = (el) => el.getClientRects().length > 0;
    const isFiller = (show, n) => show.fillers.some(([a, b]) => n >= a && n <= b);

    // Liste à jour publiée avec StreamHub (sinon celle du script)
    fetch('https://arthursavournin.github.io/streamhub/fillers.json')
      .then((res) => (res.ok ? res.json() : null))
      .then((data) => {
        for (const show of Object.values(shows)) if (data?.shows?.[show.tmdb]?.fillers) show.fillers = data.shows[show.tmdb].fillers;
      })
      .catch(() => {});

    const showOfText = (text) => {
      const t = norm(text);
      if (t.includes('boruto')) return shows.boruto;
      if (t.includes('shippuden') || t.includes('shippuuden')) return shows.shippuden;
      if (t.includes('naruto')) return shows.naruto;
      return null;
    };
    // La série affichée : identifiant Netflix de l'adresse, sinon les titres de la page (fiche, lecteur, onglet)
    function pageShow() {
      if (site === 'netflix') {
        const u = new URL(location.href);
        const id = u.searchParams.get('jbv') ?? /\/title\/(\d+)/.exec(u.pathname)?.[1];
        const byId = id && Object.values(shows).find((s) => s.netflix.includes(id));
        if (byId) return byId;
      }
      const sources = [
        ...document.querySelectorAll(
          '.previewModal--player-titleTreatment-logo, [data-uia*="titleTreatment"] img, [data-uia="video-title"] h4, h1, [data-automation-id="title"], .atvwebplayersdk-title-text',
        ),
      ];
      for (const el of sources) {
        const show = showOfText(el.getAttribute('alt') || el.getAttribute('aria-label') || textOf(el));
        if (show && shown(el)) return show;
      }
      return showOfText(document.title);
    }
    // Saison choisie dans la liste des épisodes (« Saison 2 »)
    function pageSeason() {
      const els = document.querySelectorAll(
        '.episodeSelector-dropdown .dropdown-toggle, [data-uia="dropdown-toggle"], .episodeSelector-label, [data-testid*="season" i], [data-automation-id*="season" i], select, label, button',
      );
      for (const el of els) {
        const value = el.tagName === 'SELECT' ? el.selectedOptions[0]?.textContent : textOf(el);
        const m = /^(?:saison|season)\s*(\d+)\b/i.exec(value ?? '');
        if (m && shown(el)) return Number(m[1]);
      }
      return null;
    }
    // Numéro de l'épisode depuis le début de la série
    function absolute(show, season, number, title) {
      const byTitle = show.titles[norm(title)];
      if (byTitle) return byTitle;
      if (!number) return null;
      if (!season || season === 1) return number;
      if (!show.netflixSeasons) return null;
      const start = show.netflixSeasons.slice(0, season - 1).reduce((a, b) => a + b, 1);
      if (number >= start) return number; // numéroté depuis le début de la série
      // Numéroté dans la saison : seulement sur Netflix, dont on connaît les saisons (celles de Prime peuvent différer)
      return site === 'netflix' ? start + number - 1 : null;
    }
    // « 5 », « É5 », « Épisode 5 », « 5. Titre », « É5 - Titre »…
    const parseEpisode = (text) => {
      const m = /^(?:[ÉE]p(?:isode)?\.?|[ÉE])?\s*(\d+)\s*[.:\-–]?\s*(.*)$/i.exec(text);
      return m ? { number: Number(m[1]), title: m[2] } : { number: null, title: text };
    };

    function markRow(row, filler) {
      if (row.dataset.streamhubFiller === String(filler)) return;
      row.dataset.streamhubFiller = String(filler);
      row.querySelector('.streamhub-filler-tag')?.remove();
      row.style.outline = filler ? '3px solid #ff453a' : '';
      row.style.outlineOffset = filler ? '-3px' : '';
      row.style.backgroundColor = filler ? 'rgba(255, 69, 58, 0.16)' : '';
      if (!filler) return;
      const tag = document.createElement('span');
      tag.className = 'streamhub-filler-tag';
      tag.textContent = 'FILLER';
      Object.assign(tag.style, {
        display: 'inline-block', margin: '0 8px', padding: '1px 8px', borderRadius: '999px', background: '#ff453a',
        color: '#fff', font: '700 11px/18px -apple-system, Helvetica, Arial, sans-serif', verticalAlign: 'middle',
      });
      const anchor = row.querySelector('.titleCard-title_text, .titleCardList-title-text, [data-uia="titleCard-title"], [data-automation-id^="ep-title"], [data-testid="episode-title"], h3, h4') ?? row;
      anchor.append(tag);
    }

    // Liste des épisodes (fiche du titre)
    function scanList(show) {
      const rows =
        site === 'netflix'
          ? document.querySelectorAll('.titleCardList--container, .episode-item, [data-uia="titleCard--container"]')
          : document.querySelectorAll('[data-testid="episode-list-item"], li[id^="av-ep-episodes-"], [data-automation-id^="ep-list-item"], [data-automation-id="episode"]');
      const season = pageSeason();
      let known = 0;
      let fillers = 0;
      for (const row of rows) {
        if (!shown(row)) continue;
        let number = null;
        let title = '';
        const index = row.querySelector('.titleCard-title_index');
        const name = row.querySelector('.titleCard-title_text, .titleCardList-title-text, [data-uia="titleCard-title"], [data-automation-id^="ep-title"], [data-testid="episode-title"], h3, h4');
        if (index) {
          number = Number(textOf(index)) || null;
          title = textOf(name);
        } else {
          ({ number, title } = parseEpisode(textOf(name).replace(/\s*FILLER$/, '')));
        }
        const n = absolute(show, season, number, title);
        if (!n) continue;
        known++;
        const filler = isFiller(show, n);
        if (filler) fillers++;
        markRow(row, filler);
      }
      return { rows: rows.length, known, fillers, season };
    }

    // Lecteur : épisode en cours (« S2:É5 », « É33 », « Saison 2, Ép. 5 ») → bandeau s'il est filler
    function currentEpisode(show) {
      const box = document.querySelector('[data-uia="video-title"], .atvwebplayersdk-subtitle-text');
      if (!box) return null;
      const text = textOf(box);
      const m = /(?:S(?:aison)?\s*(\d+)\s*[:,]\s*)?[ÉE]p?(?:isode)?\.?\s*(\d+)\s*(.*)$/i.exec(text);
      if (!m) return null;
      const spans = [...box.querySelectorAll('span')].map(textOf).filter(Boolean);
      const title = spans.length > 1 ? spans.at(-1) : m[3];
      return absolute(show, m[1] ? Number(m[1]) : null, Number(m[2]), title);
    }

    function banner(text, color) {
      let el = document.getElementById('streamhub-filler-banner');
      if (!el) {
        el = document.createElement('div');
        el.id = 'streamhub-filler-banner';
        Object.assign(el.style, {
          position: 'fixed', top: '16px', left: '50%', transform: 'translateX(-50%)', zIndex: '2147483647',
          padding: '10px 18px', borderRadius: '12px', color: '#fff', boxShadow: '0 6px 24px rgba(0,0,0,.45)',
          font: '600 15px/1.35 -apple-system, Helvetica, Arial, sans-serif', pointerEvents: 'none', maxWidth: '90vw',
          textAlign: 'center',
        });
        (document.body ?? document.documentElement).append(el);
      }
      el.textContent = text;
      el.style.background = color;
      el.hidden = false;
      clearTimeout(banner.timer);
      banner.timer = setTimeout(() => (el.hidden = true), 9000);
    }

    let lastReport = '';
    let lastEpisode = null;
    function tick() {
      const show = pageShow();
      if (!show) return;
      const list = scanList(show);
      // Petit message une fois par liste : sert aussi à vérifier que le script reconnaît la page
      const report = `${show.name}|${list.season}|${list.rows}|${list.known}`;
      if (list.rows && report !== lastReport) {
        lastReport = report;
        banner(
          list.known
            ? `StreamHub · ${show.name} : ${list.fillers} filler${list.fillers > 1 ? 's' : ''} sur ${list.known} épisode${list.known > 1 ? 's' : ''} affiché${list.known > 1 ? 's' : ''}`
            : `StreamHub · ${show.name} : épisodes affichés, mais pas reconnus`,
          'rgba(20, 20, 20, 0.92)',
        );
      }
      const n = currentEpisode(show);
      if (n && n !== lastEpisode) {
        lastEpisode = n;
        if (isFiller(show, n)) banner(`⚠️ ${show.name}, épisode ${n} : filler (hors-série)`, 'rgba(200, 30, 30, 0.95)');
      }
    }
    setInterval(tick, 1500);
  }

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

  // Données des fillers (générées depuis fillers.json et les titres français de TMDB) : saisons de Netflix (nombre
  // d'épisodes), épisodes hors-série (plages), titres simplifiés → numéro de l'épisode depuis le début de la série
  function fillerData() {
    return {"naruto":{"tmdb":"46260","name":"Naruto","netflix":["70205012"],"netflixSeasons":[26,26,28,26,29,25,26,26,8],"fillers":[[26,26],[97,97],[99,99],[101,106],[136,220]],"titles":{"etvoicinarutouzumaki":1,"jemappellekonohamaru":2,"sasukeetsakuraamisouennemis":3,"lepreuvedesurvie":4,"recales":5,"aupaysdesvagues":6,"lassassindanslabrume":7,"lapromessedusang":8,"kakashileninjacopieur":9,"lechakra":10,"iletaitunefoisunheros":11,"bataillesurlepontleretourdezabuza":12,"lesmiroirsdeglacedehaku":13,"imprevisiblenaruto":14,"batailledanslabrume":15,"lesceaubrise":16,"lepasseoublie":17,"unninjaunearme":18,"laneigerecouvrezabuza":19,"lexamendeschunin":20,"demysterieuxetpuissantsadversaires":21,"sasukecontrelee":22,"lesrivaux":23,"lapremiereepreuve":24,"ladixiemequestion":25,"lejournaldelecoledekonoha":26,"lasecondeepreuvetoutlemondeestunennemi":27,"mangerouetremangenarutojouelesappats":28,"narutocontreattaque":29,"lefeududragon":30,"lecombatpourlamour":31,"lereveildesakuraplusdefiguration":32,"uneformationimbattablesangliercerfpapillon":33,"letalentexceptionneldegaara":34,"interditderegarder":35,"combatdeclones":36,"lesuccesdesneufgenins":37,"leseliminatoirescommencent":38,"shishirendanlafureurdulion":39,"uneconfrontationexplosive":40,"lecombatdesrivales":41,"quelemeilleurcombatsoit":42,"shikamarulestratege":43,"akamaruparticipeaucombat":44,"lincroyableatoutdenaruto":45,"lepouvoirdubyakugan":46,"souslesyeuxdeceluiquejadmire":47,"lepouvoirdelee":48,"latechniqueinterdite":49,"lejeudelamort":50,"sasukeendanger":51,"leretourdebisu":52,"lermiteestderetour":53,"latechniquedinvocation":54,"unvufaitaunefleur":55,"unequestiondevieoudemort":56,"maitrecrapaudentreenscene":57,"lhistoiredegaara":58,"lepreuvefinalecommence":59,"byakugancontremulticlonage":60,"ladefenseabsolue":61,"lepouvoircachedurate":62,"disqualifieattentionlegrandtournoiestperturbe":63,"unpeudenerfshikamaru":64,"maisouestilsasukesefaitattendre":65,"celuiquideclencheunetempete":66,"lesleconsdumaitre":67,"offensivesurkonoha":68,"enfinunemissionderanga":69,"lembuscadedeshikamaru":70,"lecombatdeshokage":71,"lerreurduhokage":72,"lesceaududemon":73,"lavraienaturedegaara":74,"ladeterminationdesasuke":75,"lassassinduclairdelune":76,"sonnomestgaara":77,"narutosortlegrandjeu":78,"lecoupfinal":79,"konohapleurele3emehokage":80,"retouraupays":81,"sharingancontresharingan":82,"narutoetjirayasourcesdeproblemes":83,"lecridesmilleoiseaux":84,"lamaledictionduclanuchiwa":85,"lentrainementcommence":86,"narutoetleballondeau":87,"verslaconcentrationultime":88,"ondulation":89,"explosiondecolere":90,"lependentifmaudit":91,"lareponsedetsunade":92,"lesnegociationssontinterrompues":93,"rasengan":94,"le5ehokage":95,"bataillesur3fronts":96,"narutoauxsourcesthermales":97,"lediagnosticdetsunade":98,"lheritier":99,"ladeterminationdelee":100,"baslemasquekakashisensei":101,"missionaupaysduthe":102,"lagrandecoursedetodoroki":103,"oragessurnagi":104,"justeavantlarriveelabataillefaitrage":105,"ladernierelignedroitepouridate":106,"sasukecontrenaruto":107,"unecassureinvisible":108,"linvitationduson":109,"lescinqdekonohaun":110,"lepouvoirdesquatreninjasdoto":111,"latensionmontedanslequipedeshikamaru":112,"chojisedechaine":113,"adieulamijenetoublieraijamais":114,"cestmoitonadversaire":115,"langlemortdubyakugan":116,"nejisaraisondenepasperdre":117,"recupererletonneau":118,"unnouvelennemi":119,"hurlezaboyezlequipeultime":120,"chacunsoncombat":121,"shikamarujoueletoutpourletout":122,"arriveedufauvedejadedekonoha":123,"lexplosiondufauvedejade":124,"lesninjasdesuna":125,"gaaracontrekimimaro":126,"uneattaqueimplacable":127,"uncriegare":128,"itachietsasukeledestindesdeuxfreres":129,"pereetfilsleblasonbrise":130,"lesecretdukaleidoscopehypnotiquedusharingan":131,"monami":132,"lecrideslarmestuesmonami":133,"conclusionsousunepluiedelarmes":134,"unepromessenontenue":135,"enfinunemissionderangs":136,"lombreduclanfuma":137,"pureteettrahisonunreveephemere":138,"horreurlepalaisdorochimaru":139,"lepiegedekabuto":140,"ladecisiondesakura":141,"untriodiabolique":142,"jecomptesurtongroin":143,"lenouveautrio":144,"inoshikacholanouvelleformation":145,"desambitionsbrisees":146,"duelfatidique":147,"alarecherchedesinsectesflaireurs":148,"touslesinsectesseressemblent":149,"lagrandebatailledesinsectes":150,"enflammetoibyakugan":151,"requiempourlesvivants":152,"quelespoingsdelamouratteignenttoncur":153,"lenneminatureldubyakugan":154,"desnuagesnoirsenapproche":155,"lavengeancederaiga":156,"courscestlecurrydelavie":157,"lespritdequipe":158,"amiouennemilechasseurdeprimedudesert":159,"labatailledutempledokay":160,"detrangesvisiteurs":161,"leguerriermauditblanc":162,"lesarrangementsdekomeilestratege":163,"lesrenfortsarriventtroptard":164,"lamortdenaruto":165,"lamontrearretee":166,"letempsduvoldesoiseauxblancs":167,"brulonslesgraissesmelangeonsetironsetalacuisson":168,"lapageperdue":169,"lemysteredukaima":170,"intrusionlepiegesereferme":171,"desespoirlecurlacere":172,"batailleenmerlepouvoirlibere":173,"narutomoiaussijesuisunninja":174,"creusebaissetoiettrouveletresor":175,"unegrandepartiedechassealhomme":176,"ohsilvousplaitmonsieurlefacteur":177,"legarconaunomdetoile":178,"etoiledetesouvenirduneberceuse":179,"ladressedupaondedommage":180,"hoshikagelaveritecachee":181,"lesretrouvailles":182,"leclatdeletoile":183,"unelonguejourneepourkibainuzuka":184,"onboolenouveaucompagnondenaruto":185,"shinodelire":186,"lesdemenageursdekonoha":187,"lesmarchandsambulantspoursuivis":188,"combatsimpitoyables":189,"lepointfaibledelhommemagnetique":190,"lagrandefuitedenaruto":191,"leparadisdesjoufflus":192,"onrechercheecumeursdedojo":193,"lechateaufantome":194,"latroisiemegrandebetelultimerival":195,"leslarmesducombat":196,"rassemblementdesonzedekonoha":197,"lamemoiredenaruto":198,"loupelacibleapparaitdanslalignedemire":199,"enserviceactif":200,"piegesenseriecompteareboursverslaneantissement":201,"letop5desduelslespluspopulaires":202,"ladecisiondekurenai":203,"yakumopoursuivie":204,"lamissionsecretedekurenai":205,"uneillusionoularealite":206,"lepouvoirsupposerenferme":207,"lobjetdartrare":208,"lesennemissontlesshinobazu":209,"laforetdelillusion":210,"souvenirsdanslefeu":211,"chacunsonchemin":212,"lamemoireperdue":213,"laveriteretrouvee":214,"unememoirerejetee":215,"lemaitredisparu":216,"lallianceavecsuna":217,"lacontreattaquedesuiko":218,"larmeultimeressuscitee":219,"departenvoyage":220}},"shippuden":{"tmdb":"31910","name":"Naruto Shippuden","netflix":["80000603"],"netflixSeasons":[32,21,18,17,24,31,8,24,21,25,21,33,20,25,28,13,11,21,20,66,21],"fillers":[[28,28],[57,71],[90,112],[144,151],[170,171],[176,196],[223,242],[257,260],[271,271],[279,281],[284,295],[303,320],[347,356],[376,377],[389,390],[394,413],[416,417],[422,423],[427,450],[460,462],[464,468],[480,493]],"titles":{"retouraupays":1,"lakatsukientreenaction":2,"lesfruitsdelentrainement":3,"lhotedesuna":4,"entantquekazekage":5,"missionaccomplie":6,"courskankuro":7,"lequipedekakashipassealattaque":8,"leslarmesdelhote":9,"artsdessceauxlesneufdragonsfantomes":10,"ladiscipledumedecin":11,"ladecisiondelagrandmere":12,"unedestineeentrevue":13,"lesprogresdenaruto":14,"lorbetourbillonnantgeant":15,"lesecretdelhote":16,"gaarasuccombe":17,"infiltration":18,"lequipedegaicontrelequipedegai":19,"hirukocontrelesdeuxfemmesninjas":20,"levraivisagedesasori":21,"chiyojouesonatout":22,"papaetmaman":23,"lekazekagetroisiemedunom":24,"troisminutespourvivreoumourir":25,"dixcontrecent":26,"unreveinacheve":27,"laresurrectiondesfauves":28,"kakashiouvrelesyeux":29,"labeautedelinstant":30,"lareleve":31,"leretourdukazekage":32,"unnouveaubut":33,"lanouvelleequipedekakashi":34,"unmembredetrop":35,"souriremensonger":36,"lelivresecret":37,"simulation":38,"rencontreinattendue":39,"kyubilache":40,"ledebutdelamissionsecrete":41,"orochimarucontrelhote":42,"leslarmesdesakura":43,"lesdetailsducombat":44,"leslimitesdelatrahison":45,"lapageinachevee":46,"lerepaireduserpentvenimeux":47,"unliensacre":48,"unechoseprecieuse":49,"lhistoiredulivredimages":50,"retrouvailles":51,"lapuissancedesuchiwa":52,"findemission":53,"cauchemar":54,"levent":55,"fourmillements":56,"unreposeterneltrouble":57,"lasolitude":58,"unnouvelennemi":59,"hautsetbas":60,"prisedecontact":61,"coequipier":62,"deuxrois":63,"lesignaldebene":64,"labarrieredestenebres":65,"lesamesressuscitees":66,"chacunsoncombat":67,"lheuredureveil":68,"desespoir":69,"resonance":70,"monami":71,"unemenacequisapproche":72,"lakatsukiattaque":73,"souslecieletoile":74,"laprieredunvieuxmoine":75,"letapesuivante":76,"unestrategiepayante":77,"jugementsacre":78,"mauvaiseposture":79,"lesdernieresparoles":80,"tristenouvelle":81,"lequipenumero10":82,"cibleverrouillee":83,"lepouvoirdekakuzu":84,"unterriblesecret":85,"letalentdeshikamaru":86,"quandonmauditsonprochain":87,"futonleshurikentourbillonnan":88,"leprixdelapuissance":89,"ladeterminationdunninja":90,"lerepairedorochimaru":91,"larencontre":92,"attaquecombinee":93,"unenuitpluvieuse":94,"deuxtalismans":95,"unennemiinvisible":96,"lelabyrinthedesmiroirs":97,"cibleenvue":98,"ledemonenrage":99,"danslebrouillard":100,"chacunsessentiments":101,"reorganisation":102,"labarriereaquatrefaces":103,"ladestructionducristal":104,"batailleauxfrontieres":105,"lecameliarouge":106,"uneetrangealliance":107,"lavoieducamelia":108,"nouvelletentativedescellement":109,"obscursouvenir":110,"lapromesserompue":111,"unendroitourentrer":112,"lediscipleduserpent":113,"danslildufaucon":114,"lepeedezabuza":115,"karindurepairedusud":116,"jugodurepairedunord":117,"lequipeaucomplet":118,"chroniquesdekakashi1repartie":119,"chroniquesdekakashi2epartie":120,"ceuxquichangentleschoses":121,"alarechercheditachi":122,"laconfrontation":123,"lartestuneexplosion":124,"surlestracesdesasuke":125,"rencontreavecitachi":126,"lesaventuresdejiraya1repartie":127,"lesaventuresdejiraya2epartie":128,"linfiltrationdejiraya":129,"ameresretrouvailles":130,"modeermite":131,"rencontreavecpain":132,"histoiredelheroiquejiraya":133,"invitationaubanquet":134,"lemomenttantattendu":135,"lombreetlalumieredusharingan":136,"lalumiereceleste":137,"conclusion":138,"lemysteredetobi":139,"fatalite":140,"verite":141,"labatailledunraikyo":142,"hachibicontresasuke":143,"levagabond":144,"lheritiere":145,"lavolontedelheritiere":146,"lepassedudeserteur":147,"lheritagedestenebres":148,"latechniqueinterdite":150,"maitreeteleve":151,"unesombrenouvelle":152,"danslombredumaitre":153,"decryptage":154,"lapremiereepreuve":155,"lelevesurpasselemaitre":156,"attaquesurkonoha":157,"lepouvoirdelaconfiance":158,"paincontrekakashi":159,"lemysteredepain":160,"monprenomestsarutobimonnomkonohamaru":161,"lemondeconnaitralasouffrance":162,"explosionlemodeermite":163,"dangerlemodeermitesesteteint":164,"capturedekyubimissionaccomplie":165,"confessions":166,"naissancedelastredivin":167,"lehokagequatriemedunom":168,"deuxeleves":169,"lheritageduquatriemedunom1repartie":170,"lheritageduquatriemedunom2epartie":171,"rencontres":172,"lanaissancedepain":173,"lalegendedenaruto":174,"leherosdekonoha":175,"chapitredekonohairukaprofesseurnovice":176,"chapitredekonohalepreuvediruka":177,"chapitredekonohaladecisiondiruka":178,"kakashihatakejoninenchef":179,"inarilecouragemisalepreuve":180,"nostalgienarutocoachenvengeance":181,"nostalgiegaaralesliens":182,"lepidemie":183,"enavantlequipedetenten":184,"lemondedesanimaux":185,"nostalgielelixirdejeunesse":186,"nostalgiebornestelmaitreteldisciple":187,"nostalgiechroniquesdunninjacourageux":188,"sasukeetlencyclopediedespattes":189,"narutoetlevieuxsoldat":190,"lachansondamourdekakashi":191,"leschroniquesdeneji":192,"lefantomedekonoha":193,"courseatroisjambes":194,"nostalgieenformationequipe10":195,"nostalgieplongeedanslestenebres":196,"hokagelesixiemedanzo":197,"lanuitavantleconseildescinqkage":198,"lescinqkageentrentenscene":199,"lasuppliquedenaruto":200,"ameredecision":201,"courseeclair":202,"lavoiedesasuke":203,"laforcedescinqkage":204,"declarationdeguerre":205,"laconfessiondesakura":206,"demonaqueuecontredemonsansqueue":207,"entantquami":208,"lebrasdroitdedanzo":209,"latechniqueoculaireinterdite":210,"danzoshimura":211,"laresolutiondesakura":212,"lesliensperdus":213,"unfardeauaassumer":214,"deuxdestinees":215,"lesgrandsninjas":216,"lataupe":217,"lesnationssemobilisent":218,"hatakekakashihokage":219,"laprophetiedugrandermiteogama":220,"miseaudepot":221,"ladecisiondescinqkage":222,"lejeunehommeetlamer":223,"lesninjasdebenisu":224,"lebateaufantomemaudit":225,"lilecuirassee":226,"liledeloubli":227,"batstoirocklee":228,"mangerouetremangelenferdeschampignonsdansants":229,"lacontreattaquedesclones":230,"labaieinfernale":231,"soireeentrefillesdekonoha":232,"unfauxnaruto":233,"lelevepreferedenaruto":234,"lafemmeninjadenadeshiko":235,"couvrirsesamis":236,"maitretsunademonidole":237,"ledessindesai":238,"inochikacho":239,"ladecisiondekiba":240,"kakashimoneternelrival":241,"levudenaruto":242,"debarquementileparadisiaque":243,"killerbeeetmotoi":244,"nouvelleetapenarutocontrekyubi":245,"leclatorange":246,"kyubiconvoite":247,"lederniercombatduquatriemedunom":248,"merci":249,"lemonstrecontrelabeteunebatailleauparadis":250,"unhommeappelekisame":251,"langedelamort":252,"unpontpourlapaix":253,"missiontopsecretederangs":254,"leretourdelartiste":255,"rassemblementlarmeedelallianceshinobi":256,"rencontre":257,"rivaux":258,"fissures":259,"pourunami":261,"laguerre":262,"saietshin":263,"lesecretdelareincarnationdesames":264,"retrouvaillesavecunvieilennemi":265,"lepremierennemiledernierennemi":266,"lefinstrategedekonoha":267,"achacunsoncombat":268,"lesmotstabous":269,"desliensenor":270,"roadtosakura":271,"mifunecontrehanzo":272,"laveritablegentillesse":273,"laformationinoshikachoparfaite":274,"unmessagequivientducur":275,"lastatuegedopassealattaque":276,"lesignedereconciliation":277,"ninjasmedecinsprispourcible":278,"lepiegedeszetsublancs":279,"lesthetiquedelartiste":280,"lalliancearmeedesmeres":281,"histoiresecretelequipelaplusforte":282,"lesdeuxsoleils":283,"fendeusedeheaumesakebinojinin":284,"lutilisatricedeshakutonpakuraduvillagecachedusable":285,"cequelonnepeutretrouver":286,"celuisurquiilfautparier":287,"menacetandemjinpachikushimaru":288,"lesepeesdetonnerreameyuriringo":289,"puissancepremierepartie":290,"puissancedeuxiemepartie":291,"puissancetroisiemepartie":292,"puissancequatriemepartie":293,"puissancecinquiemepartie":294,"puissanceepisodefinal":295,"narutopartaufront":296,"lessentimentsdemonperelamourdemamere":297,"rencontretantattenduenarutocontreitachi":298,"estime":299,"mizukagepalourdeetmirages":300,"contradiction":301,"peurtyrandevapeur":302,"fantomesdupasse":303,"teleportationinfernale":304,"vengeurs":305,"lesyeuxducur":306,"disparitiondegekko":307,"nuitdenouvellelune":308,"missionderangadueldevantlempereur":309,"lachuteduchateau":310,"prologueofroadtoninja":311,"lesageetloeildudragon":312,"laneigeapreslapluieetparfoislorage":313,"tristepluiedebeautemps":314,"neigepersistante":315,"larmeedeninjasreincarnes":316,"shinocontretorune":317,"levideducurlautrehote":318,"lamedesmarionnettes":319,"coursomoi":320,"arriveedesrenforts":321,"madarauchiwa":322,"lerassemblementdescinqkage":323,"unmasqueincassableetdesbulles":324,"hotescontrehotes":325,"yonbileroidessinges":326,"kyubi":327,"kurama":328,"equipesdedeux":329,"presagedelavictoire":330,"loeilrivesurlestenebres":331,"volontedepierre":332,"lerisquedelareincarnationdesames":333,"freresunisdanslecombat":334,"chacunsonkonoha":335,"kabutoyakushi":336,"lactivationdelizanami":337,"izanagietizanami":338,"jetaimeraitoujours":339,"edotenseirupture":340,"orochimaruressuscite":341,"lesarcanesduninjutsuspatiotemporel":342,"quiestualafin":343,"obitoetmadara":344,"jesuisenenfer":345,"mondeonirique":346,"uneombrefurtive":347,"renaissanceakatsuki":348,"lemasquequicachelecur":349,"lamortdeminato":350,"lescellulesdhashirama":351,"orochimaruledeserteur":352,"lecobayedorochimaru":353,"lesdifferentschemins":354,"lesharinganconvoite":355,"shinobidekonoha":356,"lesuchiwadanslesservices":357,"coupdetat":358,"nuittragique":359,"ninjadelite":360,"lequipe7":361,"ladecisiondekakashi":362,"lartdelallianceshinobi":363,"relies":364,"ladansedesshinobis":365,"letempsdesreponses":366,"hashiramaetmadara":367,"lepoquedespaysenguerre":368,"leveritablereve":369,"lareponsedesasuke":370,"troubeant":371,"panserlesplaies":372,"lequipe7reunie":373,"protectionmutuelle":374,"kakashivsobito":375,"stormingkyubipartie1":376,"stormingkyubipartie2":377,"lereceptacledejubi":378,"labreche":379,"lejourounarutoestne":380,"larbredivin":381,"lerevedesshinobis":382,"lespoir":383,"combles":384,"obitouchiwa":385,"jeveillesurtoi":386,"promessetenue":387,"monpremierami":388,"lesdeuxsurs":389,"lessurshyugaouledestinimmuable":390,"madarauchiwaseleve":391,"lecuralinterieur":392,"lavraiefin":393,"lexamenpourdevenirdenouveauxchunin":394,"lexamendeschunincommence":395,"lestroisproblemes":396,"celuiquiestdignedetreunleader":397,"laveilleausoiravantlesecondexamen":398,"epreuvedesurviedansledesertdudemon":399,"entantquadeptedutaijutsu":400,"celuiquivajusquaubout":401,"fuitecontrepoursuite":402,"lecouragedenepasabandonner":403,"lespreoccupationsdetenten":404,"deuxkunoichiemprisonnees":405,"sonproprefoyer":406,"latechniquesecreteduclanyamanaka":407,"lamarionnettevaudou":408,"assurerleursarrieres":409,"laconspirationsemetenbranle":410,"ledemonaqueuesestprispourcible":411,"ladecisiondeneji":412,"confiersesespoirsalavenir":413,"auseuildelamort":414,"deuxkaleidoscopeshypnotiques":415,"laformationdelequipeminato":416,"tuesmonsoutien":417,"lapantheredejadecontrelessixcheminsdemadara":418,"lajeunessedepapa":419,"laformationdelouverturedeshuitportescelestes":420,"lesagedessixchemins":421,"cequiestherite":422,"lerivaldenaruto":423,"semettredebout":424,"unrevesansfin":425,"arcaneslunairesinfinis":426,"versunmondedereves":427,"lefoyerdetenten":428,"chroniquesdurapdekillerbeeleparcheminduciel":429,"chroniquesdurapdekillerbeeleparchemindelaterre":430,"revoircesourireunedernierefois":431,"carnetsninjasdejirayalegendesduherosnarutoleninjaproscrit":432,"carnetsninjasdejirayalegendesduherosnarutosortiemissiondinvestigation":433,"carnetsninjasdejirayalegendesduherosnarutolequipedejiraya":434,"carnetsninjasdejirayalegendesduherosnarutopriorites":435,"carnetsninjasdejirayalegendesduherosnarutolhommemasque":436,"carnetsninjasdejirayalegendesduherosnarutolapuissancescellee":437,"carnetsninjasdejirayalegendesduherosnarutolereglementoulescamarades":438,"carnetsninjasdejirayalegendesduherosnarutolenfantdelaprophetie":439,"carnetsninjasdejirayalegendesduherosnarutoloiseauencage":440,"carnetsninjasdejirayalegendesduherosnarutoretour":441,"carnetsninjasdejirayalegendesduherosnarutonoscheminsserejoignent":442,"carnetsninjasdejirayalegendesduherosnarutoladifferencedepuissance":443,"carnetsninjasdejirayalegendesduherosnarutodeserteur":444,"carnetsninjasdejirayalegendesduherosnarutopoursuivants":445,"carnetsninjasdejirayalegendesduherosnarutocollision":446,"carnetsninjasdejirayalegendesduherosnarutonouvellelune":447,"carnetsninjasdejirayalegendesduherosnarutocamarade":448,"carnetsninjasdejirayalegendesduherosnarutolactionconjointedesninjas":449,"carnetsninjasdejirayalegendesduherosnarutorival":450,"laveritablelegendeditachilumieresettenebresnaissanceetmort":451,"laveritablelegendeditachilumieresettenebreslegenie":452,"laveritablelegendeditachilumieresettenebreslasouffrancedevivre":453,"laveritablelegendeditachilumieresettenebreslademandedeshisui":454,"laveritablelegendeditachilumieresettenebresnuitdepleinelune":455,"laveritablelegendeditachilumieresettenebreslestenebresdelakatsuki":456,"laveritablelegendeditachilumieresettenebrespartenaires":457,"laveritablelegendeditachilumieresettenebreslaverite":458,"cequiestaucommencement":459,"otsutsukikaguya":460,"hagoromoethamura":461,"unpassefalsifie":462,"letonnantnumero1":463,"principesninja":464,"ashuraetindora":465,"voyageinitiatique":466,"ladeterminationdashura":467,"lheritier":468,"unemissionspeciale":469,"lefildespensees":470,"cesdeuxlapourtoujours":471,"tuasintereta":472,"lesharinganunedernierefois":473,"felicitations":474,"lavalleedelafin":475,"laffrontementfinal":476,"narutoetsasuke":477,"lesceaudelareconciliation":478,"narutouzumaki":479,"narutoethinata":480,"sasukeetsakura":481,"gaaraetshikamaru":482,"jiraiyaetkakashi":483,"lhommeexplosif":484,"colosseum":485,"fuushin":486,"leketsuryugan":487,"ledernierhomme":488,"etatdeslieux":489,"nuagesnoir":490,"imprudence":491,"unnuagedesuspicions":492,"aube":493,"lemariagedenaruto":494,"uncadeaudemariagepleindenergie":495,"sourceschaudesetcomplementsalimentaires":496,"lecadeaudemariagedukazekage":497,"ladernieremission":498,"lesresultatsdelamissionsecrete":499,"vuxdenoces":500}},"boruto":{"tmdb":"70881","name":"Boruto","netflix":["81080523"],"netflixSeasons":[15,9,8,7,11,20,22,13,10,21,20,20,16,13,15,12,28,13,8,5,7],"fillers":[[2,18],[25,38],[40,52],[60,60],[67,105],[107,127],[137,147],[152,180],[190,191],[209,210],[221,286]],"titles":{"borutouzumaki":1,"lefilsduhokage":2,"metalleesedechaine":3,"batailledeninjutsumixte":4,"lemysterieuxnouveau":5,"lederniercours":6,"amouretchips":7,"lemessagedureve":8,"lapreuveparsoimeme":9,"alarecherchedesspectres":10,"lombreducerveau":11,"borutoetmitsuki":12,"labeteapparait":13,"lecheminquevoitboruto":14,"nouvellevoie":15,"alerteauredoublement":16,"ellecourtsarada":17,"durejourneechezlesuzumaki":18,"saradauchiwa":19,"legarconauxsharingans":20,"sasukeetsarada":21,"lesliensducur":22,"lesformesdeliens":23,"borutoetsarada":24,"unvoyagescolaireagite":25,"lesuccesseurdumizukage":26,"labatailleshinobidelamitie":27,"declarationdeguerre":28,"lesseptnouveauxninjasspadassins":29,"sharingansvskibasabresfulgurants":30,"borutoetkagura":31,"enquetedegateaux":32,"monstresfantomatiquesenperil":33,"unenuitparsemeedetoiles":34,"entrevueavecleprof":35,"debutdelexamen":36,"laresolutiondushinobi":37,"formationdestrios":38,"uncheminauclairdelune":39,"equipe7premieremission":40,"laforcecollective":41,"letravaildesninjas":42,"lesnuitsblanchessurgissent":43,"shikadaihesite":44,"souvenirsdunjourdeneige":45,"operationnuitpolaire":46,"cequetuveuxetre":47,"docusurlesaspirants":48,"wasabifaitpleurernamida":49,"reuniondeselectiondescandidats":50,"lanniversairedeboruto":51,"lombredesasuke":52,"lanniversairedehimawari":53,"sasukeetboruto":54,"larmescientifiqueninja":55,"rassemblementderivaux":56,"pourquoionnepeutpasperdre":57,"letournoicommence":58,"borutovsshikadai":59,"konohavssuna":60,"shinkilemanieurdelimaille":61,"lesotsutsukiattaquent":62,"latoutdesasuke":63,"ramenernaruto":64,"pereetfils":65,"monhistoire":66,"lesupermodepapillondechocho":67,"lesupermodebaiserdechocho":68,"lesamourssupertumultueusesdechocho":69,"audeladustress":70,"lapierrelaplusduredumonde":71,"lavolontedemitsuki":72,"lafacecacheedelalune":73,"bataillecontreinoshikacho":74,"lesepreuvesdelagrotteryuchi":75,"lecaillearapporter":76,"lafurieuseattaquedegaraga":77,"intentionscroisees":78,"retrouvaillesavecmitsuki":79,"lamidemitsuki":80,"lesouhaitdeboruto":81,"infiltrationaiwa":82,"lebienselononoki":83,"lesaspirationsdonokietdeku":84,"lapierreducur":85,"lavolontedekozuchi":86,"lasensationdevivre":87,"lechocfaceakokuyo":88,"lenviedallerjusquaubout":89,"mitsukietsekiei":90,"lavolontedonoki":91,"unnouveauquotidien":92,"lafetedelafamille":93,"leconcoursdesplusgrosmangeurs":94,"operationpereetfille":95,"dusangdelasueuretnamida":96,"ladecisiondeshikadai":97,"laforetmaudite":98,"jugoetlamarquemaudite":99,"lavoietracee":100,"lesrenfortsdejugo":101,"duchaosdanslabataille":102,"periodedemigration":103,"unpetitpensionnaire":104,"lesplaiesducur":105,"chroniquesvaporeusesmissionderangs":106,"chroniquesvaporeuseschienscontrechats":107,"chroniquesvaporeuseslaubergehantee":108,"chroniquesvaporeusesleschipsetlerocher":109,"chroniquesvaporeusesleseauxdelaresurrection":110,"chroniquesvaporeuseslareponsedemirai":111,"unpromuadesigner":112,"letoffedunchef":113,"laguerreparprocurationdegemaki":114,"lequipe25":115,"konohamaruetlemon":116,"lesecretdelemon":117,"ledevoreurdememoire":118,"lenindodekonohamaru":119,"alarecherchedesasuke":120,"missiondeconfianceprotegerichibi":121,"batailledemarionnettes":122,"leretourdurashiki":123,"lheuredeladecision":124,"borutoetshinki":125,"lestratagemedeshukaku":126,"tactiquesdebatifolage":127,"lobjectifdurashiki":128,"levillagecachedekonoha":129,"rassemblementdesaspirants":130,"lepouvoirdekyubi":131,"ledefidejiraya":132,"levillagesanssasuke":133,"lepouvoirdeprediction":134,"lecombatfinalcontreurashiki":135,"audeladutemps":136,"letudiantedupaysdessamourais":137,"lanniversairedehiashi":138,"enkoonikumauneterreuravaincre":139,"quandlatranspositionnepeutrienfaceauxchips":140,"hozukilaprisondesninjas":141,"lecouragealepreuve":142,"lagresseurdekokuri":143,"lesecretdekokuri":144,"plandevasionahozuki":145,"fuiroumourir":146,"combatfinalcontretsukiyo":147,"unenouvellemission":148,"amis":149,"lavaleurdelatout":150,"borutoettento":151,"eveilauninjutsumedical":152,"uneharmonieenor":153,"himawarininjaenherbe":154,"mitsukiunjourdepluie":155,"jenepeuxpasrestermince":156,"lestracesdekara":157,"ledisparu":158,"lescellulesdehashirama":159,"lepaysdusilence":160,"lechateaudescauchemars":161,"sortirdelanasse":162,"lespoursuivants":163,"latechniqueinterditemortelle":164,"ledevoirdesquadruples":165,"combatamort":166,"leurdeterminationatouslesdeux":167,"lentrainementcommence":168,"missionconjointeavecsuna":169,"unnouvelorbetourbillonnant":170,"lesresultatsdelentrainement":171,"lautographedelapeur":172,"lesecretdusoussol":173,"renaissancedelarbredivin":174,"audeladeslimites":175,"fermezlesportesan":176,"linfailliblesystemededetection":177,"ledosdupere":178,"lamachinationdevictor":179,"muginolassasin":180,"lereceptacle":181,"ao":182,"lebras":183,"lesmarionnettes":184,"loutil":185,"lusage":186,"kama":187,"lereveil":188,"resonance":189,"levasion":190,"lechienerrant":191,"lepasse":192,"souslememetoit":193,"lafamilleuzumaki":194,"levase":195,"unpouvoirquirelie":196,"delta":197,"monstres":198,"surcharge":199,"nouveaudisciple":200,"leslarmesvides":201,"lasecte":202,"attaquesurprise":203,"letypequicraint":204,"lapreuve":205,"lanouvelleequipe7":206,"regeneration":207,"lapparitiondemomoshiki":208,"leparia":209,"surlapistedekara":210,"latraque":211,"lafuitedamado":212,"lavraieidentite":213,"ladestinee":214,"laresolution":215,"sacrifice":216,"decision":217,"compagnon":218,"retour":219,"letempsquireste":220,"unnouvelexamendeschunins":221,"veilledefinale":222,"inojinvshoki":223,"lalegendedumonstrechat":224,"dueldamies":225,"samouraivsscience":226,"ladernieremissiondelequipe7":227,"kawakisurlavoiedesninjas":228,"contrelesordres":229,"unvu":230,"lesabrerouille":231,"denkifaitsesdebutsdechef":232,"lanouvelleequipe7enaction":233,"lavermineestlachee":234,"infiltressurlilededoto":235,"lafuite":236,"laforteresseambulante":237,"untueurabord":238,"legarcondeliledelaconstructionnavale":239,"lerevedikada":240,"lesecretdikada":241,"seiren":242,"lieudattache":243,"fissures":244,"lahargnedefunamushi":245,"coupdur":246,"pourkagura":247,"unnouveaucombatamort":248,"lesgermesdelahaine":249,"lesangdesfunato":250,"deuxgarconsdetermines":251,"lenviedecroire":252,"dessentimentsinconciliables":253,"letourbillondelavengeance":254,"unpenibledevoir":255,"larecetteultime":256,"konohamarudevienthokage":257,"lesuzumakiensejourthermal":258,"blessuresinguerissables":259,"lesfeuxdartificedelamour":260,"kawakientrealacademie":261,"authedelaprincesse":262,"untalentdeprofpretaeclore":263,"aladecouvertedesseptmysteres":264,"exercicespratiquesparequipes":265,"lenlevementdehimawari":266,"kawakidemasque":267,"menacesurlafetedelacademie":268,"lombrerampante":269,"pileetface":270,"liledelatrahison":271,"leselevesfontbloc":272,"adieulacademie":273,"lefauconquinesavaitpasvoler":274,"retourversleciel":275,"bienvenuedanslelabyrinthe":276,"laviequiseteint":277,"leschaisesmusicales":278,"lemurdessept":279,"labreche":280,"laveriteduhuitieme":281,"leromandesasukeinfiltration":282,"leromandesasukealignementdetoiles":283,"leromandesasukelesecretdusoussol":284,"leromandesasukelecieltombesurterre":285,"leromandesasukelanneau":286,"lesmarquesdegriffes":287,"captif":288,"lestatut":289,"lapresence":290,"controle":291,"convoitise":292,"adieu":293}}};
  }
})();
