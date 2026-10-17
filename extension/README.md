# Script StreamHub – reprise après connexion

Quand tu lances un titre depuis StreamHub et que la plateforme te demande d'abord de te connecter ou de
choisir ton profil (code PIN compris), elle t'envoie ensuite sur sa page d'accueil et oublie le titre.
Ce script s'en souvient : une fois connecté et le profil choisi, il ouvre le titre demandé.

Fonctionne avec **toutes les plateformes** proposées par StreamHub (Netflix, Disney+, Prime Video, Apple TV+,
Paramount+, Canal+, HBO Max, TF1+, M6+, ADN, Crunchyroll…), y compris celles qui se connectent sur un autre site
(Apple, Canal+…). Le script s'exécute sur tous les sites, mais n'agit que dans un parcours ouvert depuis
StreamHub (lien `#streamhub=` de moins de 15 minutes) ; partout ailleurs il s'arrête aussitôt.

Un seul fichier, `streamhub-reprise.user.js`, pour tous les navigateurs :

| Navigateur | Comment |
|---|---|
| Safari (Mac, iPhone, iPad) | appli **Userscripts** (ci-dessous) |
| Chrome, Edge, Brave, Opera | extension de ce dossier, ou **Tampermonkey** / **Violentmonkey** |
| Firefox | module **Violentmonkey** ou **Tampermonkey**, puis ouvrir le lien du script |

## Installation dans Safari (Mac, iPhone, iPad)

1. Installe l'appli gratuite **Userscripts** depuis l'App Store
   (https://apps.apple.com/app/userscripts/id1463298887), sur chaque appareil.
2. Active-la dans Safari :
   - Mac : Safari → Réglages → **Extensions** → coche **Userscripts**, puis autorise-la sur « Tous les sites web ».
   - iPhone / iPad : Réglages → Safari (ou Apps → Safari) → **Extensions** → Userscripts → activée, et « Autoriser » pour tous les sites.
3. Dans Safari, ouvre **https://arthursavournin.github.io/streamhub/streamhub-reprise.user.js** (ou le lien
   « installe ce script » dans les réglages de StreamHub), puis appuie sur l'icône Userscripts → **Installer**.
4. Recharge StreamHub : la ligne « Script … installé » dans les réglages le confirme.

## Installation dans Firefox (ou Chrome avec un gestionnaire de scripts)

1. Installe le module **Violentmonkey** (ou Tampermonkey) depuis la boutique de modules du navigateur.
2. Ouvre **https://arthursavournin.github.io/streamhub/streamhub-reprise.user.js** : le gestionnaire propose
   d'installer le script → **Installer**. Il se mettra à jour tout seul depuis cette adresse.

## Installation dans Chrome (Edge, Brave…) sans gestionnaire

1. Télécharge le projet : sur https://github.com/arthursavournin/streamhub, bouton **Code → Download ZIP**,
   puis décompresse-le.
2. Ouvre `chrome://extensions` (Edge : `edge://extensions`).
3. Active le **Mode développeur** (en haut à droite).
4. Clique sur **Charger l'extension non empaquetée** et choisis le dossier **`extension`**.
5. Recharge StreamHub : dans les réglages, la ligne « Script … installé » le confirme.

Avec le script installé, StreamHub n'affiche plus la barre « Relancer » : ce n'est plus nécessaire.

## Comment ça marche

StreamHub ajoute à ses liens `#streamhub=<adresse du titre>`. Le navigateur garde cette partie de
l'adresse pendant la redirection vers la page de connexion. L'extension la lit, la mémorise pour l'onglet
(15 minutes au plus), puis surveille la page : dès que la page d'accueil est affichée sans écran de
connexion, de profil ou de code PIN, elle ouvre le titre. Une seule tentative par lancement.

Pour une plateforme sans réglage particulier, le script ne reprend le titre qu'après avoir vu un écran de
connexion, de profil ou de code PIN, puis l'avoir vu disparaître (pendant 1,5 s). Netflix, Disney+ et Prime
Video ont des réglages plus précis (page d'accueil et écrans de profil reconnus).

Les navigateurs indiquent que le script peut « lire et modifier les données de tous les sites » : c'est
nécessaire pour couvrir toutes les plateformes et leurs sites de connexion. Il n'envoie rien sur Internet : il
mémorise seulement, dans le navigateur, l'adresse du titre lancé depuis StreamHub.

L'appli **Prime Video pour Mac** n'est pas un navigateur : le script n'y agit pas. Quand StreamHub ouvre
l'appli (option des réglages), c'est elle qui gère le choix du profil.
