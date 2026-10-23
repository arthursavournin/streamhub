// Langue de l'interface (version 2.7.0, demande de l'utilisateur) : français (langue du code) ou anglais.
// Le français reste la langue écrite dans le code. En anglais, chaque texte affiché (texte, infobulle, champ, titre de
// la page…) est remplacé par sa traduction (i18n-en.js) dès qu'il apparaît, y compris ce qui est ajouté plus tard
// (fiches, messages, réglages) : un MutationObserver suit toute la page. En français, rien ne se passe.
// Réglage propre à chaque appareil (settings.uiLang, Réglages → Pays, langue et lecture) ; le changer recharge la page.
import { loadSettings } from './store.js';
import { EN, EN_PATTERNS } from './i18n-en.js';

export const LANG = (() => {
  try {
    return loadSettings().uiLang === 'en' ? 'en' : 'fr';
  } catch {
    return 'fr';
  }
})();
export const LOCALE = LANG === 'en' ? 'en-GB' : 'fr-FR';
// Langue des fiches demandées à TMDB (titres, résumés, genres)
export const TMDB_LANGUAGE = LANG === 'en' ? 'en-US' : null;

const collapse = (s) => s.replace(/\s+/g, ' ').trim();

// Traduction d'un texte (sans ses espaces autour), ou null s'il n'y en a pas
function translateCore(text) {
  if (EN[text] != null) return EN[text];
  for (const [re, to] of EN_PATTERNS) {
    const m = re.exec(text);
    if (m) return typeof to === 'function' ? to(...m.slice(1)) : text.replace(re, to);
  }
  // Ligne d'infos « 2017 – en cours · 3 saisons · Drame » : chaque morceau à part
  if (text.includes(' · ')) {
    let changed = false;
    const parts = text.split(' · ').map((p) => {
      const t = p.trim() && translateCore(p.trim());
      if (t == null || t === '' || t === false) return p;
      changed = true;
      return p.replace(p.trim(), t);
    });
    if (changed) return parts.join(' · ');
  }
  return null;
}

// Texte traduit (espaces autour gardés), ou le texte d'origine ; sert aussi au code (mesures, messages)
export function t(text) {
  if (LANG !== 'en' || typeof text !== 'string') return text;
  const key = collapse(text);
  if (!key) return text;
  const out = translateCore(key);
  if (out == null) return text;
  const lead = text.match(/^\s*/)[0];
  const trail = text.match(/\s*$/)[0];
  return lead + out + trail;
}

// Pages légales : leur version anglaise
const LEGAL_PAGES = { 'mentions-legales.html': 'legal-notice.html', 'confidentialite.html': 'privacy.html', 'conditions.html': 'terms.html' };
const ATTRS = ['placeholder', 'aria-label', 'title', 'alt'];

function translateNode(node) {
  if (node.nodeType === Node.TEXT_NODE) {
    const parent = node.parentNode;
    if (!parent || /^(SCRIPT|STYLE|TEXTAREA)$/.test(parent.nodeName)) return;
    const value = node.nodeValue;
    const out = t(value);
    if (out !== value) node.nodeValue = out;
    return;
  }
  if (node.nodeType !== Node.ELEMENT_NODE) return;
  translateAttrs(node);
  const walker = document.createTreeWalker(node, NodeFilter.SHOW_TEXT | NodeFilter.SHOW_ELEMENT);
  for (let n = walker.nextNode(); n; n = walker.nextNode()) {
    if (n.nodeType === Node.ELEMENT_NODE) translateAttrs(n);
    else translateNode(n);
  }
}

function translateAttrs(el) {
  for (const name of ATTRS) {
    const value = el.getAttribute?.(name);
    if (value) {
      const out = t(value);
      if (out !== value) el.setAttribute(name, out);
    }
  }
  if (el.nodeName === 'A') {
    const href = el.getAttribute('href');
    if (href && LEGAL_PAGES[href]) el.setAttribute('href', LEGAL_PAGES[href]);
  }
}

// Lance la traduction de toute la page et de ce qui y sera ajouté (anglais seulement)
export function startTranslation() {
  if (LANG !== 'en') return;
  document.documentElement.lang = 'en';
  const manifest = document.querySelector('link[rel="manifest"]');
  if (manifest) manifest.setAttribute('href', 'manifest-en.webmanifest?v=3');
  translateNode(document.documentElement);
  new MutationObserver((records) => {
    for (const r of records) {
      if (r.type === 'characterData') translateNode(r.target);
      else if (r.type === 'attributes') translateAttrs(r.target);
      else for (const n of r.addedNodes) translateNode(n);
    }
  }).observe(document.documentElement, {
    subtree: true,
    childList: true,
    characterData: true,
    attributes: true,
    attributeFilter: [...ATTRS, 'href'],
  });
}
