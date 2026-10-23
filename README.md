# StreamHub

🇬🇧 [English](#streamhub-english-version) · 🇫🇷 [Français](#streamhub-version-française)

---

## StreamHub (English version)

**All your movies and series, all your streaming platforms, in one place.**

👉 **https://arthursavournin.github.io/streamhub/**

StreamHub brings together the catalog of movies and series available for streaming, tells you which platforms each
title is on (starting with your subscriptions) and opens it directly on the right platform: Netflix, Prime Video,
Disney+, Canal+, TF1+, M6+, france.tv, Arte, Apple TV, Max, Paramount+…

- Netflix-style browsing: home, movies, series, filterable library, search (even by nickname or acronym).
- Full title pages, seasons and episodes, with a button to start each title on your platform.
- Your lists: My list, Likes, History, Downloads.
- Optional account (email, Google or GitHub): settings and lists end-to-end encrypted and synced across all your
  devices. Or as a guest: everything stays in your browser.
- Free, no ads, no tracking.

Works on iPhone, iPad, Android, Mac, Windows and Linux, in Safari, Chrome, Edge and Firefox. The interface is in
French.

### Installation

StreamHub is a web app: it runs straight in the browser. Installing it as an app is optional, but handier (an icon,
its own window).

| Device | How to install it |
|---|---|
| **iPhone, iPad** | In **Safari**: **Share** button → **Add to Home Screen** → **Add** |
| **Android** | In **Chrome**: menu **⋮** → **Install app** |
| **Mac** | **Safari**: **File → Add to Dock** · **Chrome**: menu **⋮ → Cast, save and share → Install page as app** (or **Install StreamHub…** if it appears) · **Edge**: menu **… → Apps → Install this site as an app** |
| **Windows** | **Edge**: menu **… → Apps → Install this site as an app** · **Chrome**: menu **⋮ → Cast, save and share → Install page as app** (or **Install StreamHub…** if it appears) |
| **Linux** | **Chrome**, **Chromium** or **Edge**: as on Windows |
| **Firefox** (all systems) | Usually no app installation: just bookmark StreamHub |
| **TV** | 🚧 In development |

#### First launch

1. Open StreamHub: create an account (email, Google or GitHub), sign in, or choose **Continuer sans compte**
   (Continue without an account). Already using StreamHub on another device? Sign in: everything comes back.
2. Paste your **TMDB key** in **Clés API** (API keys). It is free: create an account on
   [themoviedb.org](https://www.themoviedb.org), then **Settings → API**.
3. Tick your **subscriptions** in **Mes abonnements** (My subscriptions), then **Enregistrer** (Save).

### "Resume after sign-in" script (optional, mostly on a computer)

When a platform asks you to sign in or choose your profile before showing the title, it then sends you to its home
page. This small script remembers the title started from StreamHub and opens it. It only runs on StreamHub and on the
platforms' sites, and sends nothing over the Internet.

| Browser | Installation |
|---|---|
| **Safari** (Mac, iPhone, iPad) | 1. Install the free **[Userscripts](https://apps.apple.com/app/userscripts/id1463298887)** app (App Store).<br>2. Enable it: Mac: **Safari → Settings → Extensions** → tick **Userscripts** and allow it on websites; iPhone / iPad: **Settings → Apps → Safari → Extensions → Userscripts** → on and allowed.<br>3. In Safari, open the **[script](https://arthursavournin.github.io/streamhub/streamhub-reprise.user.js)**, then the **Userscripts** icon → **Install**. |
| **Chrome, Edge, Brave, Opera** | 1. Install the **Violentmonkey** or **Tampermonkey** extension (the browser's extension store).<br>2. If the extension asks, turn on **"Allow user scripts"** in its details (`chrome://extensions`).<br>3. Open the **[script](https://arthursavournin.github.io/streamhub/streamhub-reprise.user.js)** → **Install**. |
| **Firefox** | 1. Install the **Violentmonkey** or **Tampermonkey** add-on.<br>2. Open the **[script](https://arthursavournin.github.io/streamhub/streamhub-reprise.user.js)** → **Install**. |

The script then updates itself. To check: reload StreamHub, then **Settings → Pays et lecture** (Country and
playback): the line **"✓ Script « reprise après connexion » installé"** appears. In the iPhone home screen app it is
not needed: titles open in the platform's app. Details and the Chrome extension without a script manager:
**[extension/README.md](extension/README.md)** (in French).

To go further (Streaming Availability key for links that start the video directly, settings, account,
troubleshooting…), everything is in the **[documentation](DOCUMENTATION.md)**.

### A problem, an idea?

Open an issue on GitHub: **[Issues → New issue](https://github.com/arthursavournin/streamhub/issues/new)**. Mention
your device, your browser and the StreamHub version (shown at the bottom of the settings).

[Legal notice](https://arthursavournin.github.io/streamhub/mentions-legales.html) · [Privacy](https://arthursavournin.github.io/streamhub/confidentialite.html) · [Terms of use](https://arthursavournin.github.io/streamhub/conditions.html) (in French)

---

## StreamHub (version française)

**Tous tes films et séries, toutes tes plateformes de streaming, au même endroit.**

👉 **https://arthursavournin.github.io/streamhub/**

StreamHub rassemble le catalogue des films et séries disponibles en streaming, t'indique sur quelles plateformes
chaque titre se trouve (en commençant par tes abonnements) et l'ouvre directement sur la bonne plateforme : Netflix,
Prime Video, Disney+, Canal+, TF1+, M6+, france.tv, Arte, Apple TV, Max, Paramount+…

- Parcours façon Netflix : accueil, films, séries, bibliothèque filtrable, recherche (même par surnom ou sigle).
- Fiches complètes, saisons et épisodes, avec un bouton pour lancer chaque titre sur ta plateforme.
- Tes listes : Ma liste, J'aime, Historique, Téléchargements.
- Compte facultatif (e-mail, Google ou GitHub) : réglages et listes chiffrés de bout en bout et synchronisés entre
  tous tes appareils. Ou en invité : tout reste dans ton navigateur.
- Gratuit, sans publicité, sans pistage.

Fonctionne sur iPhone, iPad, Android, Mac, Windows et Linux, dans Safari, Chrome, Edge et Firefox.

---

### Installation

StreamHub est une appli web : il s'utilise directement dans le navigateur. L'installer en appli est facultatif, mais
plus pratique (une icône, sa propre fenêtre).

| Appareil | Comment l'installer |
|---|---|
| **iPhone, iPad** | Dans **Safari** : bouton **Partager** → **Sur l'écran d'accueil** → **Ajouter** |
| **Android** | Dans **Chrome** : menu **⋮** → **Installer l'application** |
| **Mac** | **Safari** : **Fichier → Ajouter au Dock** · **Chrome** : menu **⋮ → Caster, enregistrer et partager → Installer la page en tant qu'appli** (ou **Installer StreamHub…** s'il apparaît) · **Edge** : menu **… → Applications → Installer ce site en tant qu'application** |
| **Windows** | **Edge** : menu **… → Applications → Installer ce site en tant qu'application** · **Chrome** : menu **⋮ → Caster, enregistrer et partager → Installer la page en tant qu'appli** (ou **Installer StreamHub…** s'il apparaît) |
| **Linux** | **Chrome**, **Chromium** ou **Edge** : comme sous Windows |
| **Firefox** (tous systèmes) | En général pas d'installation en appli : ajoute simplement StreamHub à tes favoris |
| **TV** | 🚧 En développement |

#### Premier lancement

1. Ouvre StreamHub : crée un compte (e-mail, Google ou GitHub), connecte-toi, ou choisis **Continuer sans compte**.
   Tu utilises déjà StreamHub sur un autre appareil ? Connecte-toi : tout revient.
2. Colle ta **clé TMDB** dans **Clés API**. Elle est gratuite : crée un compte sur
   [themoviedb.org](https://www.themoviedb.org), puis **Paramètres → API**.
3. Coche tes **abonnements** dans **Mes abonnements**, puis **Enregistrer**.

---

### Script « reprise après connexion » (facultatif, surtout sur ordinateur)

Quand une plateforme te demande de te connecter ou de choisir ton profil avant d'afficher le titre, elle t'envoie
ensuite sur son accueil. Ce petit script s'en souvient et ouvre le titre lancé depuis StreamHub. Il ne tourne que sur
StreamHub et sur les sites des plateformes, et n'envoie rien sur Internet.

| Navigateur | Installation |
|---|---|
| **Safari** (Mac, iPhone, iPad) | 1. Installe l'appli gratuite **[Userscripts](https://apps.apple.com/app/userscripts/id1463298887)** (App Store).<br>2. Active-la : Mac : **Safari → Réglages → Extensions** → coche **Userscripts** et autorise-la sur les sites web ; iPhone / iPad : **Réglages → Apps → Safari → Extensions → Userscripts** → activée et autorisée.<br>3. Dans Safari, ouvre le **[script](https://arthursavournin.github.io/streamhub/streamhub-reprise.user.js)**, puis icône **Userscripts** → **Installer**. |
| **Chrome, Edge, Brave, Opera** | 1. Installe l'extension **Violentmonkey** ou **Tampermonkey** (boutique d'extensions du navigateur).<br>2. Si l'extension le demande, active **« Autoriser les scripts utilisateur »** dans ses détails (`chrome://extensions`).<br>3. Ouvre le **[script](https://arthursavournin.github.io/streamhub/streamhub-reprise.user.js)** → **Installer**. |
| **Firefox** | 1. Installe le module **Violentmonkey** ou **Tampermonkey**.<br>2. Ouvre le **[script](https://arthursavournin.github.io/streamhub/streamhub-reprise.user.js)** → **Installer**. |

Le script se met ensuite à jour tout seul. Pour vérifier : recharge StreamHub, puis **Réglages → Pays et lecture** :
la ligne **« ✓ Script « reprise après connexion » installé »** apparaît. Dans l'appli de l'écran d'accueil de
l'iPhone, il n'est pas utile : les titres s'ouvrent dans l'appli de la plateforme. Détails et extension Chrome sans
gestionnaire : **[extension/README.md](extension/README.md)**.

---

Pour aller plus loin (clé Streaming Availability pour des liens qui lancent directement la vidéo, réglages, compte,
dépannage…), tout est dans la **[documentation](DOCUMENTATION_fr.md)**.

---

### Un problème, une idée ?

Ouvre un ticket sur GitHub : **[Issues → New issue](https://github.com/arthursavournin/streamhub/issues/new)**.
Indique ton appareil, ton navigateur et la version de StreamHub (affichée en bas des réglages).

[Mentions légales](https://arthursavournin.github.io/streamhub/mentions-legales.html) · [Confidentialité](https://arthursavournin.github.io/streamhub/confidentialite.html) · [Conditions d'utilisation](https://arthursavournin.github.io/streamhub/conditions.html)
