// Navigation aux flèches façon télécommande : on choisit l'élément focusable le plus proche
// dans la direction demandée. Les touches « retour » des télécommandes ferment les fenêtres.
const DIRECTIONS = {
  ArrowUp: [0, -1],
  ArrowDown: [0, 1],
  ArrowLeft: [-1, 0],
  ArrowRight: [1, 0],
};
const BACK_KEYS = new Set(['Backspace', 'BrowserBack', 'GoBack']);
const BACK_KEY_CODES = new Set([461, 10009]); // webOS (LG), Tizen (Samsung)
const FOCUSABLE =
  'button:not([disabled]):not([tabindex="-1"]), a[href]:not([tabindex="-1"]), input:not([disabled]), select:not([disabled]), summary, [tabindex]:not([tabindex="-1"])';

const center = (r) => ({ x: r.left + r.width / 2, y: r.top + r.height / 2 });

// Une question affichée par-dessus tout (popover marqué data-nav-trap) garde les flèches pour elle
function openTrap() {
  try {
    return document.querySelector('[data-nav-trap]:popover-open');
  } catch {
    return null; // navigateur sans popovers
  }
}

function isTyping(el) {
  return el?.tagName === 'INPUT' || el?.tagName === 'TEXTAREA';
}

export function initSpatialNav({ onBack }) {
  document.addEventListener('keydown', (e) => {
    const active = document.activeElement;

    if ((BACK_KEYS.has(e.key) || BACK_KEY_CODES.has(e.keyCode)) && !isTyping(active)) {
      if (onBack()) e.preventDefault();
      return;
    }

    const dir = DIRECTIONS[e.key];
    if (!dir || e.altKey || e.ctrlKey || e.metaKey) return;
    // Gauche/droite déplacent le curseur dans un champ ; un menu déroulant garde ses flèches
    if (isTyping(active) && dir[0] !== 0) return;
    if (active?.tagName === 'SELECT') return;

    const scope = openTrap() ?? document.querySelector('dialog[open]') ?? document;
    const items = [...scope.querySelectorAll(FOCUSABLE)].filter((el) => el.getClientRects().length > 0);
    if (!items.length) return;

    if (!active || active === document.body || !scope.contains(active)) {
      e.preventDefault();
      items[0].focus();
      return;
    }

    const from = center(active.getBoundingClientRect());
    let best = null;
    let bestScore = Infinity;
    for (const el of items) {
      if (el === active || el.contains(active) || active.contains(el)) continue;
      const to = center(el.getBoundingClientRect());
      const dx = to.x - from.x;
      const dy = to.y - from.y;
      const along = dx * dir[0] + dy * dir[1];
      if (along <= 1) continue;
      const across = Math.abs(dx * dir[1] + dy * dir[0]);
      const score = along + across * 2.5;
      if (score < bestScore) {
        bestScore = score;
        best = el;
      }
    }
    if (best) {
      e.preventDefault();
      best.focus();
      best.scrollIntoView({ block: 'nearest', inline: 'nearest', behavior: 'smooth' });
    }
  });
}
