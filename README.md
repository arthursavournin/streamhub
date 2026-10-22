# StreamHub

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

## Installation

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

### Premier lancement

1. Ouvre StreamHub : crée un compte (e-mail, Google ou GitHub), connecte-toi, ou choisis **Continuer sans compte**.
   Tu utilises déjà StreamHub sur un autre appareil ? Connecte-toi : tout revient.
2. Colle ta **clé TMDB** dans **Clés API**. Elle est gratuite : crée un compte sur
   [themoviedb.org](https://www.themoviedb.org), puis **Paramètres → API**.
3. Coche tes **abonnements** dans **Mes abonnements**, puis **Enregistrer**.

---

## Script « reprise après connexion » (facultatif, surtout sur ordinateur)

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
dépannage…), tout est dans la **[documentation](DOCUMENTATION.md)**.

---

## Un problème, une idée ?

Ouvre un ticket sur GitHub : **[Issues → New issue](https://github.com/arthursavournin/streamhub/issues/new)**.
Indique ton appareil, ton navigateur et la version de StreamHub (affichée en bas des réglages).

[Mentions légales](https://arthursavournin.github.io/streamhub/mentions-legales.html) · [Confidentialité](https://arthursavournin.github.io/streamhub/confidentialite.html) · [Conditions d'utilisation](https://arthursavournin.github.io/streamhub/conditions.html)
