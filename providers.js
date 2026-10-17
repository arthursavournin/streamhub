// Correspondance entre les plateformes TMDB (noms variables : « Netflix Standard with Ads »,
// « Canal+ Ciné Séries »…) et les identifiants Streaming Availability, avec un lien de secours
// quand on n'a pas de lien direct vers le film.
const SERVICES = [
  { id: 'netflix', match: /netflix/, search: (q) => `https://www.netflix.com/search?q=${q}` },
  { id: 'disney', match: /disney/, search: (q) => `https://www.disneyplus.com/search?q=${q}` },
  { id: 'apple', match: /apple tv/, search: (q) => `https://tv.apple.com/search?term=${q}` },
  { id: 'hbo', match: /^(hbo )?max\b|hbo max/, home: 'https://www.hbomax.com/' },
  { id: 'prime', match: /amazon|prime video/, search: (q) => `https://www.primevideo.com/search?phrase=${q}` },
  { id: 'canal', match: /canal\+|canal plus/, home: 'https://www.canalplus.com/' },
  { id: 'paramount', match: /paramount/, home: 'https://www.paramountplus.com/' },
  { id: 'mubi', match: /mubi/, search: (q) => `https://mubi.com/search/films?query=${q}` },
  // Plateformes gratuites françaises. TF1+ n'a pas de page de recherche accessible par un lien, mais ses
  // pages de programme suivent tf1.fr/<chaîne>/<titre> et redirigent vers la bonne chaîne
  // Les liens d'épisode TF1+ contiennent un identifiant interne impossible à deviner : on renvoie vers
  // la page Replay de la série, qui liste tous les épisodes
  {
    id: 'tf1',
    match: /^tf1/,
    page: (title) => `https://www.tf1.fr/tf1/${slug(title)}`,
    episodes: (title) => `https://www.tf1.fr/tf1/${slug(title)}/videos/replay`,
  },
  { id: 'm6', match: /^m6/, search: (q) => `https://www.m6.fr/recherche?q=${q}` },
  { id: 'francetv', match: /^france\.?tv|^france tv/, search: (q) => `https://www.france.tv/recherche/?q=${q}` },
  { id: 'arte', match: /^arte\b/, search: (q) => `https://www.arte.tv/fr/search/?q=${q}` },
];

// « Demain nous appartient » → « demain-nous-appartient »
export const slug = (title) =>
  String(title)
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-|-$/g, '');

// Les « chaînes » vendues en option sur une autre plateforme (« Crunchyroll Amazon Channel »,
// « MGM+ Apple TV Channel »…) demandent leur propre abonnement : elles ne comptent jamais comme
// la plateforme qui les héberge (avoir Prime Video ne donne pas accès à Crunchyroll).
export const isChannel = (providerName) => /\bchannels?\b/i.test(String(providerName));

// Le service d'une plateforme, pour reconnaître tes abonnements. Une chaîne n'en a pas :
// elle n'est à toi que si tu l'as cochée elle-même dans les réglages.
export function serviceFor(providerName) {
  if (isChannel(providerName)) return null;
  const name = String(providerName).toLowerCase();
  return SERVICES.find((s) => s.match.test(name)) ?? null;
}

// La plateforme où l'on regarde, pour les liens : une chaîne Amazon se regarde dans Prime Video
export function hostServiceFor(providerName) {
  if (!isChannel(providerName)) return serviceFor(providerName);
  const name = String(providerName).toLowerCase();
  if (/canal/.test(name)) return SERVICES.find((s) => s.id === 'canal'); // avant Apple : « Apple TV Canal+ Channel »
  if (/amazon/.test(name)) return SERVICES.find((s) => s.id === 'prime');
  if (/apple/.test(name)) return SERVICES.find((s) => s.id === 'apple');
  return null;
}

// Offres que TMDB et JustWatch ne référencent pas : les chaînes que Canal+ propose dans son abonnement (France).
// Avec elles, le catalogue de HBO Max, Apple TV ou Paramount+ se regarde sur Canal+, souvent sans compte chez la
// plateforme elle-même (signalé par l'utilisateur : Harry Potter, présent sur « HBO Max » et « HBO Max Amazon
// Channel », mais pas sur Canal+ dans les données). Chacune est ajoutée comme une chaîne de Canal+, à côté de la
// plateforme, pour chaque titre disponible sur celle-ci : abonnements, filtres, affiches et fiche la traitent comme
// les chaînes Prime. Identifiants inventés (pas des identifiants TMDB) ; tmdbIds sert aux recherches TMDB, key à
// l'index de la chaîne publié avec StreamHub (data/canal/<key>.json), hub à sa page sur Canal+.
export const CANAL_CHANNELS = [
  { key: 'hbo', id: 99001899, name: 'HBO Max Canal+ Channel', service: 'hbo', tmdbIds: [1899], hub: '/chaines/hbo-max/', label: 'HBO Max' },
  { key: 'appletv', id: 99000350, name: 'Apple TV Canal+ Channel', service: 'apple', tmdbIds: [350], hub: '/chaines/apple-tv/', label: 'Apple TV' },
  { key: 'paramount', id: 99000531, name: 'Paramount Plus Canal+ Channel', service: 'paramount', tmdbIds: [531], hub: '/chaines/paramount-plus/', label: 'Paramount+' },
];
// La plateforme d'origine : même service (« HBO Max », « Paramount Plus Premium »…), jamais une chaîne (« HBO Max
// Amazon Channel »), ni la boutique « Apple TV Store »
const isBaseOf = (channel, id, name) =>
  channel.tmdbIds.includes(id) || (channel.service !== 'apple' && serviceFor(name)?.id === channel.service);
// Offre Canal+ Ciné Séries (France) : le socle Canal+ avec Netflix, Apple TV, HBO Max, Paramount+ et Ciné+ OCS
// (référencé sous Canal+ dans les données). Case des réglages, juste après Canal+ : la cocher coche ces plateformes.
// Netflix y est un vrai compte (appli Netflix) ; Apple TV, HBO Max et Paramount+ se regardent sur Canal+.
// Identifiants TMDB (= JustWatch) : Canal+ 381, Canal+ Séries 345, Netflix 8.
export const CANAL_CINE_SERIES = { id: 99000381, name: 'Canal+ Ciné Séries', includes: [381, 345, 8, ...CANAL_CHANNELS.map((c) => c.id)] };

// Logos remplacés (dossier logos/) : celui de TMDB pour « HBO Max Amazon Channel » est un montage « HBO max on
// prime video », pas le logo de la plateforme avec l'étiquette « prime video | channels » des autres chaînes Prime
const LOGOS = { hbomaxamazonchannel: 'logos/hbo-max-amazon-channel.png' };
export const providerLogo = (name, path) => LOGOS[String(name ?? '').toLowerCase().replace(/[^a-z0-9]/g, '')] ?? path;
export function withLogos(offers) {
  if (!offers) return offers;
  const fix = (list) => (Array.isArray(list) ? list.map((p) => ({ ...p, logo_path: providerLogo(p.provider_name, p.logo_path) })) : list);
  return Object.fromEntries(Object.entries(offers).map(([k, v]) => [k, fix(v)]));
}

export function withVirtualChannels(offers, region) {
  if (region !== 'FR' || !offers?.flatrate) return offers;
  let flatrate = offers.flatrate;
  for (const channel of CANAL_CHANNELS) {
    const base = flatrate.find((p) => isBaseOf(channel, p.provider_id, p.provider_name));
    if (!base || flatrate.some((p) => p.provider_id === channel.id)) continue;
    flatrate = [...flatrate, { provider_id: channel.id, provider_name: channel.name, logo_path: base.logo_path, display_priority: base.display_priority }];
  }
  return flatrate === offers.flatrate ? offers : { ...offers, flatrate };
}

// Liste des plateformes des réglages (France) : l'offre Canal+ Ciné Séries juste après Canal+, chaque chaîne de
// Canal+ juste après sa plateforme
export function withVirtualProviders(list, region) {
  if (region !== 'FR') return list;
  const after = (items, base, extra) => {
    const i = items.indexOf(base);
    return i < 0 || items.some((p) => p.id === extra.id) ? items : [...items.slice(0, i + 1), extra, ...items.slice(i + 1)];
  };
  let out = list;
  const canal = out.find((p) => p.id === 381);
  if (canal) out = after(out, canal, { id: CANAL_CINE_SERIES.id, name: CANAL_CINE_SERIES.name, logo: canal.logo, priority: canal.priority });
  for (const channel of CANAL_CHANNELS) {
    const base = out.find((p) => isBaseOf(channel, p.id, p.name));
    if (base) out = after(out, base, { id: channel.id, name: channel.name, logo: base.logo, priority: base.priority });
  }
  return out;
}

// Page qui liste les épisodes d'une série sur la plateforme, quand on sait la construire
export function episodesLink(providerName, title) {
  return hostServiceFor(providerName)?.episodes?.(title) ?? null;
}

// Lien sans Streaming Availability : recherche du titre sur la plateforme, sinon sa page
// d'accueil, sinon la page « Où regarder » de TMDB (qui renvoie vers chaque plateforme).
export function fallbackLink(providerName, title, tmdbWatchLink) {
  const service = hostServiceFor(providerName);
  if (service?.page) return { href: service.page(title), hint: 'Page de la série' };
  if (service?.search) return { href: service.search(encodeURIComponent(title)), hint: 'Recherche sur la plateforme' };
  if (service?.home) return { href: service.home, hint: 'Accueil de la plateforme' };
  return { href: tmdbWatchLink, hint: 'Liens sur TMDB' };
}

// Lien qui lance la lecture, quand la plateforme n'en fournit pas mais que sa fiche sait le faire.
// Canal+ : la fiche du titre lance son lecteur toute seule avec « ?autoplay=true » (paramètre lu par le site,
// composant PrimaryActions : « launch main player with autoplay query param »). Le son démarre coupé.
// Prime Video : la fiche « app.primevideo.com/detail?gti=… » a son lien de lecture « …/watch?gti=… » (même
// identifiant, c'est le lien que donne JustWatch). Streaming Availability ne le donne pas toujours : Naruto
// s'arrêtait sur la fiche alors que New York Unité spéciale se lançait (constaté par l'utilisateur, version 44).
export function autoplayLink(href) {
  let url;
  try {
    url = new URL(href);
  } catch {
    return null;
  }
  // (« www.primevideo.com/detail/amzn1.dv.gti…/ » : même identifiant, même lien de lecture)
  const gti = url.searchParams.get('gti') ?? /\/detail\/(?:[^/]+\/)?(amzn1\.dv\.gti\.[A-Za-z0-9-]+)/.exec(url.pathname)?.[1];
  if (/(^|\.)primevideo\.com$/.test(url.hostname) && gti && /\/detail(\/|$)/.test(url.pathname)) {
    return `https://app.primevideo.com/watch?gti=${encodeURIComponent(gti)}`;
  }
  if (!/(^|\.)canalplus\.com$/.test(url.hostname) || !/\/h\/\d+/.test(url.pathname)) return null;
  url.searchParams.set('autoplay', 'true');
  return url.href;
}

// Lien à ouvrir depuis l'iPhone / iPad (appli web de l'écran d'accueil).
// iOS ouvre directement l'appli installée quand la plateforme a déclaré l'adresse comme « lien universel »
// (fichier apple-app-site-association) : c'est le cas de netflix.com/title, canalplus.com (tout le site),
// app.primevideo.com (tout le site), disneyplus.com/browse, tf1.fr/…/videos, m6.fr, france.tv, paramountplus.com,
// play.max.com. Sinon iOS ouvre le site, dans un navigateur intégré à StreamHub.
// Aucune adresse « appli » (nflx://, aiv://…) : si l'appli n'est pas installée, Safari affiche « l'adresse
// n'est pas valide » (constaté sur le simulateur iOS). Le lien universel, lui, retombe tout seul sur le site.
export function iosLink(href) {
  let url;
  try {
    url = new URL(href);
  } catch {
    return { href };
  }
  url.hash = ''; // pas de « #streamhub= » : le script de reprise ne tourne pas dans les applis
  // Prime Video : on garde « app.primevideo.com/watch?gti=… » (tout app.primevideo.com est déclaré pour l'appli),
  // la forme que JustWatch donne lui-même pour l'iPhone. La réécriture en « www.primevideo.com/detail/<gti>/ »
  // (version 37) avait été faite alors que l'appli n'était pas installée ; avec l'appli, elle restait dans le
  // navigateur (constaté par l'utilisateur, version 38).
  return { href: url.href };
}

// Adresse propre à l'appli, pour les rares cas où le lien web ouvre l'appli sans aller sur la bonne page.
// M6+ : « m6.fr/<programme>-p_<id>/<épisode>-c_<id> » ouvre l'appli sur la page du programme ; la page web de
// l'épisode annonce elle-même l'adresse que l'appli comprend (balise « al:ios:url ») :
// « sixplay://programme/<id>/video/clip_<id> ». Si l'appli n'est pas installée, cette adresse ne mène nulle
// part : l'appelant doit retomber sur le lien web.
export function iosAppLink(href) {
  let url;
  try {
    url = new URL(href);
  } catch {
    return null;
  }
  const m6 = /(^|\.)m6\.fr$/.test(url.hostname) && /^\/[a-z0-9-]+-p_(\d+)\/[a-z0-9-]+-c_(\d+)\/?$/i.exec(url.pathname);
  if (m6) return `sixplay://programme/${m6[1]}/video/clip_${m6[2]}`;
  return null;
}

// Lien vers l'appli installée sur l'ordinateur (réglage « Ouvrir les titres : dans l'appli »), null si la plateforme
// n'en a pas. Prime Video (Mac, Windows) : l'appli fabrique elle-même « aiv://aiv/detail?gti=…&action=watch&time=auto »
// pour lancer la lecture (reprise où on s'était arrêté) ; « aiv://aiv/detail?gti=… » seul n'ouvre que la fiche. Le
// lien sert à lancer un titre : on demande toujours la lecture, que le lien web soit celui de la fiche ou de la
// lecture. Liens « www.primevideo.com/detail/<id> » : identifiant « amzn1.dv.gti… » (gti) ou ancien identifiant (asin).
export function desktopAppLink(href) {
  let url;
  try {
    url = new URL(href);
  } catch {
    return null;
  }
  const watch = '&action=watch&time=auto';
  const gti = url.searchParams.get('gti');
  if (url.hostname === 'app.primevideo.com' && gti && /^\/(detail|watch)\/?$/.test(url.pathname)) {
    return `aiv://aiv/detail?gti=${encodeURIComponent(gti)}${watch}`;
  }
  const id = /(^|\.)primevideo\.com$/.test(url.hostname) && /\/detail\/(?:[^/]+\/)?([A-Za-z0-9.-]{10,})/.exec(url.pathname)?.[1];
  if (id) return `aiv://aiv/detail?${id.startsWith('amzn1.') ? 'gti' : 'asin'}=${encodeURIComponent(id)}${watch}`;
  return null;
}

// Lien à ouvrir dans le navigateur de l'ordinateur (réglage « Ouvrir les titres : sur le site internet »), null s'il
// n'y a rien à changer. Prime Video : l'appli Mac revendique « app.primevideo.com » (liens universels, entitlement
// applinks:app.primevideo.com) ; Safari ouvre alors l'appli même quand on veut le site (constaté par l'utilisateur,
// version 47). « www.primevideo.com » n'est pas revendiqué. Lecture : même adresse que la redirection de Prime pour
// « app.primevideo.com/watch?gti=… » (« /detail/<id>?deepLinkingRedirect=1&autoplay=1 ») ; avec « ?autoplay=1 » seul,
// certaines séries restaient sur la fiche (Naruto, constaté par l'utilisateur, version 49). Le site accepte
// l'identifiant « amzn1.dv.gti… » à la place de l'ancien (même traitement, vérifié sur ses redirections).
// play : lien lancé depuis un bouton « Regarder » ou un épisode (la lecture est alors toujours demandée, comme pour
// l'appli : un épisode sans lien propre renvoie à la fiche de la série, Naruto restait dessus, version 50) ; sans
// play (« Liker aussi sur »…), la fiche reste une fiche.
export function desktopWebLink(href, { play = false } = {}) {
  let url;
  try {
    url = new URL(href);
  } catch {
    return null;
  }
  // Identifiant du titre : « app.primevideo.com/detail?gti=… » (JustWatch), ou « www.primevideo.com/detail/<id>/ »
  // tel que le donne Streaming Availability (gti ou ancien identifiant, parfois précédé de /region/eu/). Ce second
  // format passait sans paramètre de lecture : c'est le lien de « Naruto épisode 1 » reçu par l'utilisateur (v50).
  const gti = url.hostname === 'app.primevideo.com' && /^\/(detail|watch)\/?$/.test(url.pathname) && url.searchParams.get('gti');
  const id = gti || (/(^|\.)primevideo\.com$/.test(url.hostname) && /\/detail\/(?:[^/]+\/)?([A-Za-z0-9.-]{10,})/.exec(url.pathname)?.[1]);
  if (!id) return null;
  const watch = play || url.pathname.startsWith('/watch') || url.searchParams.get('autoplay') === '1';
  return `https://www.primevideo.com/detail/${encodeURIComponent(id)}${watch ? '?deepLinkingRedirect=1&autoplay=1' : ''}${url.hash}`;
}

// Série : lien qui laisse la plateforme reprendre où on s'est arrêté (épisode suivant), ou commencer à l'épisode 1
// si on ne l'a jamais regardée. StreamHub ne peut pas lire la progression (pas d'API, données protégées par la
// connexion) : il envoie le lien que la plateforme sait reprendre elle-même, plutôt que celui de l'épisode 1.
// play : lien de lecture reçu (Streaming Availability ou JustWatch) ; page : lien de la page de la série.
// Renvoie { href, hint, click } ou null ; click : la plateforme n'a pas de lien de reprise, il faut appuyer sur son
// bouton « Reprendre » (fait par le script sur ordinateur).
export function seriesResumeLink(play, page) {
  const p = String(page ?? '');
  // Netflix : « /watch/<épisode> » lance cet épisode, « /watch/<série> » reprend la série
  const netflix = /netflix\.com\/(?:[a-z]{2}(?:-[a-z]{2})?\/)?title\/(\d+)/.exec(p)?.[1];
  if (netflix) return { href: `https://www.netflix.com/watch/${netflix}`, hint: 'Reprise de la série' };
  // Disney+ : « /play/<id> » est l'épisode 1 ; la page de la série affiche « Reprendre S1 E7 » (ou « Lecture »)
  if (/disneyplus\.com\/(?:[a-z]{2}-[a-z]{2}\/)?browse\/entity-/.test(p)) return { href: p, hint: 'Page de la série', click: true };
  // Prime Video : « watch?gti=<série> » reprend déjà (l'appli : « time=auto »)
  if (/^https:\/\/app\.primevideo\.com\/watch\?/.test(String(play))) return { href: play, hint: 'Reprise de la série' };
  // Canal+ : la fiche de la série avec « autoplay=true » lance son bouton principal (« Reprendre » s'il y a une
  // progression) ; un lien d'épisode (« episodeId= ») lancerait cet épisode
  if (/canalplus\.com\/.*\/h\/[^?]+\?(?:.*&)?autoplay=true/.test(String(play)) && !/episodeId=/.test(String(play))) {
    return { href: play, hint: 'Reprise de la série' };
  }
  return null;
}

// Identifiant d'un titre d'après son adresse sur la plateforme (même calcul que le script
// extension/streamhub-reprise.user.js) : reconnaît un même titre sous plusieurs adresses.
export function pageRef(href) {
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
