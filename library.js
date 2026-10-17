// Bibliothèque personnelle (J'aime, historique et likes sur les plateformes suivent sur tous les appareils
// avec la synchronisation ; téléchargements et questions en attente restent propres à chaque appareil) :
// - likes : titres aimés
// - watchlist : « Ma liste », les titres mis de côté pour plus tard
// - history : les 30 derniers titres regardés depuis StreamHub (un par titre)
// - downloads : rappel des films / épisodes téléchargés dans l'appli d'une plateforme
// - pending : questions à poser au retour dans StreamHub (« Tu as regardé… ? », « Le téléchargement a démarré ? »,
//   « Tu as liké… sur Netflix ? »). Rien n'est enregistré tant que la réponse n'est pas oui.
// - platformLikes : plateformes où un titre a aussi été liké, { 'movie:603': [{ service, platform }] }.
//   Gardé à part des likes : retirer un like dans StreamHub ne le retire pas sur la plateforme.
//
// Une entrée : { key, type, id, title, poster, date, platform, service, href,
//                season, episode, episodeName, at }
import { loadLibrary, saveLibrary, HISTORY_MAX } from './store.js';

const lib = loadLibrary();

// Après une synchronisation : relit la bibliothèque arrivée d'un autre appareil
export function reload() {
  Object.assign(lib, loadLibrary());
}

export const titleKey = (type, id) => `${type}:${id}`;
export const downloadKey = (type, id, season, episode) =>
  season != null && episode != null ? `${type}:${id}:s${season}e${episode}` : titleKey(type, id);

export const list = (name) => lib[name];
export const has = (name, key) => lib[name].some((e) => e.key === key);

export function remove(name, key) {
  lib[name] = lib[name].filter((e) => e.key !== key);
  saveLibrary(lib);
}

// Ajoute en tête de liste (en remplaçant l'éventuelle entrée existante)
function putFirst(name, entry, max = Infinity) {
  lib[name] = [{ ...entry, at: Date.now() }, ...lib[name].filter((e) => e.key !== entry.key)].slice(0, max);
  saveLibrary(lib);
}

export function toggleLike(entry) {
  const key = titleKey(entry.type, entry.id);
  if (has('likes', key)) {
    remove('likes', key);
    return false;
  }
  putFirst('likes', { ...entry, key });
  return true;
}

// « Ma liste » : ajoute ou retire le titre ; renvoie true s'il est maintenant dans la liste
export function toggleList(entry) {
  const key = titleKey(entry.type, entry.id);
  if (has('watchlist', key)) {
    remove('watchlist', key);
    return false;
  }
  putFirst('watchlist', { ...entry, key });
  return true;
}

// Pour une série, une seule ligne par série : le dernier épisode lancé
export function recordWatch(entry) {
  putFirst('history', { ...entry, key: titleKey(entry.type, entry.id) }, HISTORY_MAX);
}

export function addDownload(entry) {
  putFirst('downloads', { ...entry, key: downloadKey(entry.type, entry.id, entry.season, entry.episode) });
}

// ---------- Questions en attente ----------
// { id, kind: 'watch' | 'download', entry, at }

const platformId = (entry) => entry.service || entry.platform;

const pendingId = (kind, entry) => {
  if (kind === 'watch') return `watch:${titleKey(entry.type, entry.id)}`;
  if (kind === 'platformLike' || kind === 'platformUnlike') return `${kind}:${titleKey(entry.type, entry.id)}:${platformId(entry)}`;
  return `download:${downloadKey(entry.type, entry.id, entry.season, entry.episode)}`;
};

// Relancer le même titre remplace la question précédente (pour une série : le dernier épisode lancé)
export function addPending(kind, entry) {
  const id = pendingId(kind, entry);
  lib.pending = [...lib.pending.filter((p) => p.id !== id), { id, kind, entry, at: Date.now() }];
  saveLibrary(lib);
}

// Première question dont le délai est écoulé (delays : { watch: ms, download: ms })
export function nextPending(delays) {
  const now = Date.now();
  return lib.pending.find((p) => now - p.at >= delays[p.kind]) ?? null;
}

export function resolvePending(id, yes) {
  const item = lib.pending.find((p) => p.id === id);
  if (!item) return;
  lib.pending = lib.pending.filter((p) => p.id !== id);
  saveLibrary(lib);
  if (!yes) return;
  if (item.kind === 'watch') recordWatch(item.entry);
  else if (item.kind === 'platformLike') markLikedOn(item.entry);
  else if (item.kind === 'platformUnlike') unmarkLikedOn(item.entry);
  else addDownload(item.entry);
}

// ---------- Likes sur les plateformes ----------

export const likedOn = (type, id) => lib.platformLikes[titleKey(type, id)] ?? [];
export const isLikedOn = (type, id, service, platform) =>
  likedOn(type, id).some((p) => p.service ? p.service === service : p.platform === platform);

// href : la page du titre, pour pouvoir y retourner retirer le like (même depuis l'onglet J'aime).
// refs : identifiants du titre sur la plateforme (voir pageRef), pour reconnaître un retrait fait là-bas.
export function markLikedOn(entry) {
  const key = titleKey(entry.type, entry.id);
  const same = (p) => (p.service ? p.service === entry.service : p.platform === entry.platform);
  const others = likedOn(entry.type, entry.id).filter((p) => !same(p));
  lib.platformLikes[key] = [...others, { service: entry.service || null, platform: entry.platform, href: entry.href, refs: entry.refs ?? [] }];
  saveLibrary(lib);
}

// Le titre liké sur une plateforme dont l'un des identifiants correspond : { key, like } ou null
export function findPlatformLike(refs, refOf) {
  for (const [key, list] of Object.entries(lib.platformLikes)) {
    const like = list.find((p) => [...(p.refs ?? []), refOf(p.href ?? '')].some((r) => r && refs.includes(r)));
    if (like) return { key, like };
  }
  return null;
}

export function unmarkLikedOn(entry) {
  const key = titleKey(entry.type, entry.id);
  const rest = likedOn(entry.type, entry.id).filter((p) => (p.service ? p.service !== entry.service : p.platform !== entry.platform));
  if (rest.length) lib.platformLikes[key] = rest;
  else delete lib.platformLikes[key];
  saveLibrary(lib);
}
