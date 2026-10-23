# StreamHub : documentation

Tout ce qu'il faut savoir pour utiliser StreamHub, de l'installation au dépannage, et pour les développeurs.
Pour une présentation rapide, voir le [README](README.md#streamhub-version-française).

🇬🇧 English version: **[DOCUMENTATION.md](DOCUMENTATION.md)**

👉 **https://arthursavournin.github.io/streamhub/**

---

## Sommaire

1. [Ce que fait StreamHub](#1-ce-que-fait-streamhub)
2. [Installer StreamHub sur chaque appareil](#2-installer-streamhub-sur-chaque-appareil)
3. [Premier lancement](#3-premier-lancement)
4. [Les clés API](#4-les-clés-api)
5. [Les réglages](#5-les-réglages)
6. [Ton compte et la synchronisation](#6-ton-compte-et-la-synchronisation)
7. [Comment StreamHub ouvre les titres](#7-comment-streamhub-ouvre-les-titres)
8. [Le script « reprise après connexion »](#8-le-script--reprise-après-connexion-)
9. [Tes données et ta vie privée](#9-tes-données-et-ta-vie-privée)
10. [Dépannage](#10-dépannage)
11. [Pour les développeurs](#11-pour-les-développeurs)

---

## 1. Ce que fait StreamHub

StreamHub rassemble le catalogue des films et séries disponibles en streaming dans ton pays, t'indique sur quelles
plateformes chaque titre se trouve, en commençant par tes abonnements, et l'ouvre directement sur la bonne
plateforme. C'est une appli web : elle fonctionne dans le navigateur, sans compte, et peut s'installer comme une
appli sur téléphone, tablette et ordinateur.

### Parcourir le catalogue

**Sur téléphone (site dans Safari et appli iPhone, même interface)** : en haut, le logo, la recherche et la roue des
réglages ; en bas, trois onglets : **Accueil**, **Bibliothèque** et **Mon espace**. Les pages Films, Séries et Animés
s'ouvrent depuis l'accueil, par les pastilles **Tout · Films · Séries · Animés** sous la barre du haut. Les affiches
s'affichent sans texte dessous (le dernier épisode d'une série récente est posé sur l'affiche), la grande affiche de
l'accueil propose « ▶ Voir » et « + Ma liste », et Mon espace se présente en segments (Ma liste, J'aime, Historique,
Téléchargés). Tire la page vers le bas pour actualiser l'accueil ou une rubrique. Sur ordinateur, rien ne change :
les rubriques sont dans la barre du haut.

**Sur iPhone Duo (site dans Safari)** : mêmes fonctions, mise en page adaptée à chaque forme. **Fermé**, l'interface du
téléphone, avec une grande affiche moins haute et trois affiches par ligne. **Ouvert en portrait**, l'interface du
téléphone en plus grand : grande affiche en image large qui s'arrête avant le pli, affiches plus grandes (quatre par
ligne), fiche plus aérée. **Ouvert en paysage**, l'interface d'ordinateur (comme sur iPad), avec le texte de la grande
affiche à gauche du pli et la fiche en plein écran. L'appli iPhone n'est pas encore adaptée à l'iPhone Duo.

- **Accueil** : une affiche mise en avant et des rangées façon Netflix : Top 50 du moment, Reprendre, Ma liste,
  Nouveautés, Nouveaux épisodes, Nouveaux films, Les mieux notés, puis une rangée par genre (Action & aventure, Comédie, Horreur, Science-fiction &
  fantastique, Thriller & policier, Drame, Animation, Animés japonais, Romance, Famille, Documentaires).
  **Personnaliser l'accueil** (Réglages → Accueil) : coche les rangées à afficher et range-les avec les flèches. Le
  titre en grand en haut est le n° 1 du Top 50 du moment, sauf si tu en choisis un : bouton « ☆ À l’affiche » dans sa
  fiche (un second appui, ou « Automatique » dans les réglages, revient au n° 1). Synchronisé avec tes autres appareils
  et l'appli iPhone.
  Une série compte comme nouvelle quand elle a eu un **épisode ces 7 derniers jours** (nouvelle saison ou épisode de la
  semaine), même si elle a commencé il y a des années ; son affiche indique le dernier épisode (« S3 E2 · 16 oct. »).
  Ces dates sont celles de la première diffusion dans le monde : un épisode diffusé aux États-Unis n'est pas forcément
  déjà sur ta plateforme en France. Les talk-shows, infos, feuilletons quotidiens et la téléréalité n'y figurent pas.
  Le **Top 50 du moment** reprend le classement « populaire » de JustWatch dans ton pays (ce que ses utilisateurs
  consultent en ce moment), mis à jour toutes les 6 heures et limité à tes abonnements : ce n'est pas un classement
  de tous les temps.
- **Films** et **Séries** : les mêmes rangées, réservées aux films ou aux séries.
- **Animés** : l'animation japonaise (genre Animation avec le Japon comme pays d'origine), films et séries : Animés
  populaires, Nouveaux épisodes, Séries animées, Films d’animation, Les mieux notés, puis Action & aventure,
  Science-fiction & fantastique, Comédie, Drame, Mystère et Famille. Le « Tout voir » de la rangée Animés japonais de
  l'accueil ouvre cette page.
- **Bibliothèque** : tout le catalogue en grille, avec des filtres (Tout / Films / Séries, plateforme, genre) et un
  tri (Populaires, Mieux notés, Plus récents). Le lien « Tout voir » de chaque rangée ouvre la Bibliothèque déjà
  filtrée. Le genre « Animés japonais » y est proposé avec les autres (aussi dans l'appli iPhone).
- **Mon espace** : tes listes (Ma liste, J'aime, Historique, Téléchargements) et tes plateformes. Chaque titre a une
  croix en haut à droite pour le retirer (aussi dans les rangées Ma liste et Reprendre de l'accueil).
- **Recherche** (site et appli iPhone, même fonctionnement) : tape directement dans la barre du haut ; les résultats
  apparaissent dès la première lettre, sans changer de page. Par titre, mais aussi par surnom ou sigle (« DNA » trouve *Demain nous appartient*, grâce à une
  liste intégrée et à Wikidata).
  - **Fautes de frappe** : « hary poter » affiche quand même les films Harry Potter, avec « Tu voulais dire
    « Harry Potter » ? » pour corriger la recherche (la recherche est comparée à environ 28 000 titres populaires).
  - **Numéro de film** : « harry potter 1 » ne donne que le premier film de la saga (pas *Les Reliques de la Mort,
    1re partie*, qui est le 7e) ; « toy story 3 » donne *Toy Story 3*. Le numéro est le premier nombre après le nom,
    et la suite peut préciser une partie : « harry potter 7 partie 2 » donne *Les Reliques de la Mort, 2e partie*,
    « hunger games 3 partie 2 » *La Révolte, partie 2* (les films sortis en plusieurs parties partagent un numéro :
    « harry potter 7 » donne les deux parties des *Reliques de la Mort*).
  - **Sagas dans l'ordre** : les films d'une même saga sont regroupés et rangés dans l'ordre de sortie (1, 2, 3).
  - **Seulement tes abonnements** : Tout / Films / Séries, plateformes et genre, et seuls les titres disponibles sur
    tes abonnements s'affichent ; les autres restent derrière « N autres hors de tes abonnements — tout afficher »
    (« Aucun titre trouvé… sur tes abonnements » si aucun ne l'est).

Par défaut, StreamHub ne montre que les titres disponibles sur **tes abonnements** ; un lien permet d'afficher aussi
les autres.

### La fiche d'un titre

Un clic sur une affiche ouvre sa fiche : résumé, date de sortie (film, seulement dans la fiche : sous les affiches,
l'année) ou années de diffusion (série), durée ou nombre de saisons, genres, bande-annonce, et les
boutons **« Regarder sur… »**, rangés en trois groupes :

- **Dans tes abonnements** : les plateformes que tu as cochées dans les réglages.
- **Aussi disponible sur** (menu replié, à ouvrir) : les autres plateformes où le titre est inclus (abonnement, gratuit, avec pub).
  Une chaîne vendue sur une autre plateforme s'affiche avec sa plateforme entre parenthèses : « HBO Max (Prime
  Video) », « HBO Max (Canal+) », « Apple TV (Canal+) », « Paramount+ (Canal+) ». Les chaînes HBO Max, Apple TV et
  Paramount+ de Canal+ ne sont pas référencées par TMDB ni JustWatch : StreamHub les propose pour chaque titre
  disponible sur ces plateformes (France), et ouvre la fiche du titre sur Canal+ (pas la fiche Canal VOD, qui est
  une location payante), grâce à l'index du catalogue de chaque chaîne qu'il publie toutes les 6 heures. Un titre
  absent de l'index ouvre la page de la chaîne sur Canal+. Sur iPhone et iPad, l'appli Canal+ s'ouvre sur la fiche.
- **Location et achat** : les boutiques (Apple TV, Amazon Video…), repliées par défaut.

Les plateformes viennent de TMDB, qui reprend les données de JustWatch. Une nouveauté peut sortir avant que JustWatch
la référence dans ton pays (exemple : VisionQuest, sortie sur Disney+ partout le même jour). StreamHub complète alors
la liste, avec la mention « Pas encore référencée dans ce pays par JustWatch » sous les boutons :

- **d'après son diffuseur** : une série en cours de diffusion (ou sortie depuis moins de 60 jours), création de
  Netflix, Disney+, Prime Video, Apple TV, HBO Max ou Paramount+, est ajoutée sur sa plateforme si elle n'a encore
  aucune offre dans ton pays. Ça marche sans clé, aussi pour les affiches, le filtre « Mes plateformes » de la
  recherche et les rangées de l'accueil qui la concernent (son genre, Nouveautés, Nouveaux épisodes…).
- **d'après Streaming Availability** (avec ta clé) : les plateformes que Streaming Availability donne dans ton pays,
  mais pas JustWatch, sont ajoutées à l'ouverture de la fiche, avec leur lien direct.

Sous chaque bouton, une indication précise ce qu'il va faire :

| Indication | Ce qui se passe |
|---|---|
| **Lecture directe** | La vidéo démarre sur la plateforme |
| **Reprise de la série** | La série reprend à l'épisode suivant, là où tu t'es arrêté (ou à l'épisode 1 si tu ne l'as jamais regardée) |
| **Épisode suivant : S1 E7** | L'épisode qui suit le dernier que tu as regardé depuis StreamHub (TF1+, M6+) |
| **Fiche du titre** | La page du titre s'ouvre sur la plateforme (il reste à appuyer sur Lecture) |
| **Page de la série** | La page de la série s'ouvre (Disney+, TF1+), avec son bouton « Reprendre » ou « Lecture » |
| **Recherche sur la plateforme** | Une recherche du titre s'ouvre sur la plateforme |
| **Accueil de la plateforme** | La plateforme s'ouvre sur son accueil (aucun lien plus précis n'existe) |
| **Liens sur TMDB** | La page « Où regarder » de TMDB, qui renvoie vers chaque plateforme |

Pour une **série**, le bouton « Regarder sur… » **reprend où tu t'es arrêté** (épisode suivant), ou commence à
l'épisode 1 si tu ne l'as jamais regardée ([détails](#reprendre-une-série)).

Sous le résumé, la fiche a des **onglets** (aussi dans l'appli iPhone) :

- **Épisodes** (séries, ouvert d'abord) : chaque saison se déplie pour afficher ses épisodes (résumé, date, durée),
  avec un bouton pour lancer directement celui que tu veux quand la plateforme le permet. Quand TMDB propose d'autres
  découpages (ex. « TF1+ » pour *Demain nous appartient* : 10 saisons au lieu de 3), le menu « Découpage » permet d'en
  changer ; celui qui porte le nom d'une plateforme où se trouve la série est choisi d'office. Pour **Naruto**,
  **Naruto Shippuden** et **Boruto**, le découpage **« Netflix - Sans filler »** est choisi d’office (9 saisons pour
  Naruto ; 21 comme sur Netflix pour Shippuden et pour Boruto, avec les titres de saison de Netflix) : les
  épisodes hors-série (fillers, d'après la liste d'animotaku.fr) sont en rouge avec l'étiquette « Filler », et une
  saison qui n'a que des fillers est entièrement en rouge. Le menu « Découpage » permet de revenir à celui de TMDB.
- **Suggestions** (ouvert d'abord pour un film, seul onglet) : des affiches à ouvrir, en trois rangées :
  - **La saga** : les autres films de la saga, dans l'ordre de sortie (les 7 autres Harry Potter) ;
  - **Dans le même univers** : les films et séries de la même franchise, que TMDB ne relie pas entre eux. Exemples :
    Naruto → Naruto Shippuden, Boruto et les films Naruto ; un film Harry Potter → la série Harry Potter et Les
    Animaux fantastiques ; Breaking Bad → Better Call Saul et El Camino. StreamHub les retrouve par le nom de la
    franchise (même langue d'origine, un genre en commun, et une société de production commune quand le nom n'est pas
    en tête du titre) et parmi les titres conseillés par TMDB (deux sociétés de production en commun et une suite ou
    une série dérivée) ;
  - **Dans le même genre** : les titres conseillés par TMDB, ceux de tes abonnements d'abord.

### Tes listes

- **Ma liste** : les titres mis de côté avec « + Ma liste » (dans la fiche ou sur l'affiche de l'accueil).
- **J'aime** : les titres aimés avec « ♡ J'aime ». Pour une série, le J'aime porte sur la série entière.
- **Historique** : les 30 derniers titres regardés depuis StreamHub, en une seule rangée (le plus récent à gauche).
  La croix en haut à droite d'une affiche retire ce titre ; **Supprimer l'historique** (avec confirmation) vide la
  liste. Avec un compte, ces retraits partent aussi sur tes autres appareils.
- **Téléchargements** : un rappel des titres téléchargés dans les applis des plateformes (voir plus bas).

Un film ou un épisode lancé depuis StreamHub entre tout de suite dans l'historique, sans question. Pour une série,
on enchaîne souvent plusieurs épisodes sur la plateforme : en revenant dans StreamHub (au moins 3 minutes après), une
seule fenêtre demande « Où en es-tu de *Naruto* ? » avec la saison et le dernier épisode regardé (l'épisode lancé est
déjà choisi) ; « Enregistrer » met l'historique à jour, « Ignorer » garde l'épisode lancé. La même fenêtre propose
« J'aime la série ». Un titre à télécharger entre tout de suite
dans les téléchargements, sans question au retour.

### Liker sur la plateforme

Aucune plateforme ne permet de liker un titre à distance : le J'aime de StreamHub reste dans StreamHub (depuis la
version 2.5.0, plus de notification « Liker aussi sur… » ni de question « Tu as liké… ? », comme dans l'appli iPhone).

### Télécharger pour regarder hors ligne

Seules les applis mobiles des plateformes savent télécharger, et elles ne permettent pas de le faire à distance. Le
bouton **« ⬇ Télécharger »** ouvre donc le titre dans l'appli de la plateforme, où tu appuies sur son bouton de
téléchargement, et le note dans Téléchargements (Mon espace → Téléchargés sur téléphone), qui sert de rappel. Il
n'apparaît que sur iPhone, iPad et Android, et dans l'appli iPhone (version 2.4.0 : bouton sous « Regarder sur… »
pour un film, ⬇ à côté de chaque épisode) : sur ordinateur et TV, les plateformes ne permettent pas de télécharger.
Le titre entre dans la liste dès l'appui, sans question au retour (version 2.4.1). Un appui sur un titre téléchargé l'ouvre dans
l'appli de la plateforme ; sa croix le retire de la liste (le fichier reste dans l'appli de la plateforme).

### Et aussi

- **Compte StreamHub** (facultatif) : réglages, clés et listes chiffrés et synchronisés entre tous tes appareils
  ([partie 6](#6-ton-compte-et-la-synchronisation)). Sans compte, en invité, tout reste sur l'appareil.
- **Effet verre**, inspiré de Liquid Glass, pour les barres, boutons et fenêtres, réglable sur chaque appareil.
- **Navigation au clavier et à la télécommande** : flèches, OK (Entrée) et Retour (Échap).
- **Hors ligne** : l'interface s'ouvre sans connexion (le catalogue, lui, demande Internet).
- **Mises à jour automatiques** : à chaque retour sur StreamHub, la nouvelle version est installée et la page se
  recharge (après la fermeture de la fiche ou des réglages si l'une est ouverte).

---

## 2. Installer StreamHub sur chaque appareil

StreamHub s'utilise directement dans le navigateur, sur n'importe quel appareil. L'installer en appli (une icône sur
l'écran d'accueil, dans le Dock ou dans le menu Démarrer) est facultatif, mais plus pratique : il s'ouvre dans sa
propre fenêtre, sans barre d'adresse.

### iPhone et iPad

1. Ouvre **https://arthursavournin.github.io/streamhub/** dans **Safari**.
2. Appuie sur le bouton **Partager** (le carré avec une flèche), puis sur **« Sur l'écran d'accueil »**.
3. Laisse **« Ouvrir comme app web »** activé, puis appuie sur **Ajouter**.
4. Ouvre StreamHub depuis sa nouvelle icône.

L'appli de l'écran d'accueil a son propre stockage, séparé de Safari : au premier lancement, connecte-toi à ton
compte (ou colle tes clés). C'est depuis cette icône que les boutons « Regarder sur… » ouvrent directement les
applis des plateformes ([partie 7](#sur-iphone-et-ipad)). Sur iPhone et iPad, toutes les applis de navigation
(Chrome, Firefox, Edge…) utilisent le moteur de Safari : StreamHub s'y comporte comme dans Safari.

### Android

1. Ouvre **https://arthursavournin.github.io/streamhub/** dans **Chrome** (ou Samsung Internet, Edge…).
2. Menu **⋮** → **« Installer l'application »** (ou « Ajouter à l'écran d'accueil »).
3. Ouvre StreamHub depuis son icône.

### Mac

- **Safari** (macOS Sonoma ou plus récent) : ouvre l'adresse, puis menu **Fichier → Ajouter au Dock**. StreamHub
  apparaît dans le Dock et le Launchpad comme une appli.
- **Chrome** : menu **⋮ → Caster, enregistrer et partager → Installer la page en tant qu'appli** (ou **Installer StreamHub…** s'il apparaît) (ou l'icône
  d'installation à droite de la barre d'adresse).
- **Edge** : menu **… → Applications → Installer ce site en tant qu'application**.
- **Firefox** : en général pas d'installation en appli ; ajoute StreamHub à tes favoris.

### Windows

- **Edge** (installé avec Windows) : menu **… → Applications → Installer ce site en tant qu'application**. StreamHub
  apparaît dans le menu Démarrer ; tu peux l'épingler à la barre des tâches.
- **Chrome** : menu **⋮ → Caster, enregistrer et partager → Installer la page en tant qu'appli** (ou **Installer StreamHub…** s'il apparaît).
- **Firefox** : en général pas d'installation en appli ; ajoute StreamHub à tes favoris ou épingle l'onglet.

### Linux

Avec **Chrome**, **Chromium**, **Brave** ou **Edge**, comme sous Windows. Avec **Firefox**, ajoute StreamHub à tes
favoris.

### TV

🚧 **En développement.** En attendant, StreamHub peut s'ouvrir dans le navigateur d'une TV connectée (Samsung, LG,
Android TV…) : l'interface se pilote déjà avec les flèches, OK et Retour de la télécommande. Pistes pour une vraie
appli TV :

- **Android TV / Google TV** : emballer l'appli web dans une appli Android (Bubblewrap/TWA ou Capacitor) ; les liens
  ouvriront les applis TV des plateformes.
- **Samsung (Tizen) / LG (webOS)** : ce sont des TV web, l'appli s'y empaquette presque telle quelle.
- **Apple TV** : pas de navigateur, il faudrait une appli native tvOS.

---

## 3. Premier lancement

1. Ouvre StreamHub : au premier lancement, seule la page de connexion s'affiche.
2. **Connecte-toi ou crée un compte** (e-mail et mot de passe, Google ou GitHub) : si tu utilises déjà StreamHub
   ailleurs, clés, abonnements et listes reviennent, et c'est fini. Tu peux aussi choisir **Continuer sans compte**
   (invité) : tout reste alors sur cet appareil ([partie 6](#6-ton-compte-et-la-synchronisation)).
3. Sinon, StreamHub te demande ta **clé TMDB** ([partie 4](#4-les-clés-api)). C'est la seule clé obligatoire.
4. Coche tes **abonnements** dans « Mes abonnements ».
5. Appuie sur **Enregistrer**.

Facultatif, mais recommandé : une clé **Streaming Availability** pour des liens qui lancent directement la vidéo ou
l'épisode, et, sur ordinateur, le **script « reprise après connexion »** ([partie 8](#8-le-script--reprise-après-connexion-)).

**Partager StreamHub avec tes proches** : envoie-leur simplement l'adresse. Chacun colle **ses propres clés**, coche
ses abonnements et crée, s'il le veut, **son propre compte**. Les données de chacun sont chiffrées avec sa propre clé :
personne ne voit les clés, abonnements ou listes des autres.

---

## 4. Les clés API

StreamHub n'a pas de serveur qui stocke tes données : il interroge directement des services publics avec **tes**
clés. Elles se gèrent dans **Réglages → Clés API**, avec un bouton **Tester** pour chacune.

| Clé | Obligatoire ? | À quoi elle sert |
|---|---|---|
| **TMDB** | Oui (gratuite) | Catalogue des films et séries, fiches, plateformes disponibles par pays |
| **Streaming Availability** | Non (offre gratuite) | Liens directs qui lancent la vidéo, la série ou l'épisode |

### Obtenir la clé TMDB (gratuite)

1. Crée un compte sur **https://www.themoviedb.org**.
2. Va dans ton profil → **Paramètres** → **API** (https://www.themoviedb.org/settings/api).
3. Demande une clé API pour un usage personnel, en remplissant le court formulaire.
4. Copie la **Clé d'API (v3)** ou le **Jeton d'accès en lecture (v4)** : les deux fonctionnent.
5. Colle-la dans StreamHub → Réglages → Clés API → **Clé API TMDB**, puis appuie sur **Tester**.

### Obtenir la clé Streaming Availability (facultative, gratuite)

1. Crée un compte sur **https://rapidapi.com**.
2. Cherche l'API **« Streaming Availability »** et abonne-toi à l'offre **Basic** (gratuite).
3. Copie ta clé (**X-RapidAPI-Key**), visible dans l'onglet de test de l'API.
4. Colle-la dans StreamHub → Réglages → Clés API → **Clé Streaming Availability**, puis appuie sur **Tester**.

L'offre gratuite est limitée en nombre de requêtes par jour : StreamHub ne fait une requête qu'à l'ouverture d'une
fiche et garde chaque réponse **3 jours** en mémoire. Sans cette clé, StreamHub utilise les liens de JustWatch (via
le relais), sinon une recherche du titre sur la plateforme.

**Tes clés ne sont jamais publiées** : elles ne sont pas dans le code, restent dans ton navigateur ou dans le
trousseau de l'iPhone pour l'appli (et, chiffrées, dans ton compte), et ne sont envoyées qu'à TMDB et RapidAPI.

---

## 5. Les réglages

La roue dentée en haut à droite ouvre la page des réglages : les sections dans la barre de gauche (Compte en premier),
le contenu de la section choisie à droite. Sur téléphone, la liste des sections, puis la section touchée. L'appli
iPhone a les mêmes sections, dans le même ordre et le même dessin. **Enregistrer** (en haut) garde les changements ;
les actions du compte, elles, s'appliquent tout de suite.

| Section | Contenu |
|---|---|
| **Compte** | Créer un compte, se connecter (e-mail, Google, GitHub), mot de passe oublié, changer de mot de passe, clé de secours, se déconnecter, supprimer le compte. En invité : la page de connexion, avec les boutons Google et GitHub. |
| **Mes abonnements** | Les plateformes auxquelles tu es abonné, avec un champ pour filtrer la liste. Cocher Prime Video coche aussi les chaînes incluses avec Prime. Les options payantes vendues sur une autre plateforme sont des « chaînes » à cocher à part, par exemple **HBO Max Amazon Channel** (HBO Max sur Prime Video) ou les chaînes de Canal+ (France) **HBO Max Canal+ Channel**, **Apple TV Canal+ Channel** et **Paramount Plus Canal+ Channel**, pour regarder ces catalogues sur Canal+. Cocher **Canal+ Ciné Séries** coche aussi les plateformes de l'offre : Canal+, Canal+ Séries, Netflix et les chaînes HBO Max, Apple TV et Paramount+ de Canal+ ; Ciné+ OCS est référencé sous Canal+. Netflix reste un compte à part (activé depuis ton espace Canal+) et s'ouvre dans l'appli Netflix. |
| **Clés API** | Clé TMDB, clé Streaming Availability, avec un bouton Tester pour chacune. (Le relais StreamHub, pour les liens JustWatch, n'a pas de réglage : son adresse est fixe depuis la version 2.3.4.) |
| **Accueil** | Rangées affichées sur l'accueil, leur ordre, et le titre à l'affiche. |
| **Apparence** | Effet verre : Automatique, Transparent ou Teinté (propre à chaque appareil). |
| **Pays et lecture** | Pays du catalogue (France, Belgique, Suisse, Luxembourg, Canada, Royaume-Uni, États-Unis, Allemagne, Espagne, Italie) et, sur ordinateur, **Ouvrir les titres**. |
| **À propos** | Version, mentions légales, politique de confidentialité, conditions d'utilisation, code source. |

### Ouvrir les titres (ordinateur)

Réglage propre à chaque appareil :

- **Sur le site internet** : les titres s'ouvrent dans un onglet du navigateur.
- **Dans l'appli de l'ordinateur** : les titres Prime Video s'ouvrent dans l'appli **Prime Video** installée sur le
  Mac ou le PC, et la lecture démarre. Les autres plateformes n'ont pas d'appli Mac ; sous Windows, leurs applis ne
  sont pas encore prises en charge. Le navigateur peut demander l'autorisation d'ouvrir l'appli la première fois.

### Effet verre

Une page web ne peut pas lire le réglage Liquid Glass d'iOS ou de macOS. En mode **Automatique**, StreamHub suit
« Augmenter le contraste » (et « Réduire la transparence » dans Chrome et Edge) ; sinon, choisis toi-même
**Transparent** ou **Teinté**.

---

## 6. Ton compte et la synchronisation

Chaque navigateur garde ses propres données : sans compte, StreamHub ouvert dans Chrome ne connaît ni les clés ni les
listes enregistrées dans Safari, et l'appli de l'écran d'accueil de l'iPhone ne connaît pas celles de Safari. Un
**compte StreamHub** (gratuit, facultatif) les garde partout. Sans compte, tu restes **en invité** : tout reste sur
l'appareil, rien n'est envoyé.

### Créer un compte ou se connecter

**Réglages → Compte**, puis au choix :

- **Avec ton e-mail** : onglet **Créer un compte**, adresse et mot de passe (12 caractères au moins), puis ouvre le lien
  reçu par e-mail (regarde aussi dans les indésirables). Sur tes autres appareils : **Se connecter** avec la même
  adresse et le même mot de passe.
- **Avec Google ou GitHub** (boutons affichés quand ils sont activés) : à la première connexion, StreamHub te demande
  de choisir un **mot de passe du coffre**. Il chiffre tes données ; il est propre à StreamHub, sans rapport avec ton
  compte Google ou GitHub. Tu le tapes une fois sur chaque nouvel appareil.

À la création, StreamHub affiche ta **clé de secours** (20 caractères, par exemple `ABCD-EFGH-JKLM-NPQR-STUV`) :
note-la dans ton gestionnaire de mots de passe. Elle seule permet de retrouver tes données si tu oublies ton mot de
passe. **Nouvelle clé de secours** en crée une autre (l'ancienne ne marche plus) : StreamHub redemande alors ton mot
de passe (ou ton mot de passe du coffre).

Un nouveau mot de passe (inscription, changement, oubli, mot de passe du coffre) doit faire **12 caractères au
moins** et ne pas figurer dans des fuites de données connues. Cette vérification se fait sur ton appareil, avant
l'envoi, auprès du service Have I Been Pwned : seuls les 5 premiers caractères d'une empreinte du mot de passe partent,
jamais le mot de passe. Un mot de passe choisi avant la version 2.3.4 marche toujours.

Dans l'appli iPhone : **Réglages → Compte**, avec le même compte (e-mail et mot de passe, Google ou GitHub : la
fenêtre de connexion d'Apple s'ouvre, puis revient dans l'appli). Les liens des e-mails (confirmation, mot de passe oublié) s'ouvrent sur le site : après la confirmation,
reviens dans l'appli et touche **J'ai confirmé mon adresse**.

Ensuite, chaque modification part toute seule quelques secondes après, et arrive sur les autres appareils à leur
ouverture ou quand tu reviens sur StreamHub. Deux appareils modifiés en même temps : les listes sont réunies, rien
n'est perdu. Un titre retiré d'une liste (ou l'historique supprimé) sur un appareil ne revient pas depuis un autre,
sauf s'il y est de nouveau ajouté ou regardé après le retrait.

- **Synchronisés** : clés, pays, abonnements, accueil, Ma liste, J'aime, historique, likes sur les plateformes.
- **Propres à chaque appareil** : téléchargements (ils sont sur l'appareil), questions en attente, effet verre,
  réglage « Ouvrir les titres ».
- **Toujours aussi gardés sur l'appareil** : StreamHub marche hors ligne, et rien n'est effacé à la déconnexion.

### Mot de passe oublié, changer de mot de passe, supprimer le compte

- **Mot de passe oublié ?** (sous **Se connecter**) : un e-mail t'envoie un lien ; il ouvre StreamHub, où tu choisis
  un nouveau mot de passe et entres ta **clé de secours**. Mot de passe du coffre oublié (Google, GitHub) : même
  chose, avec **Mot de passe du coffre oublié ?** une fois connecté.
- **« Ce lien est-il pour toi ? »** : un lien d'e-mail (confirmation, mot de passe oublié) ouvert sur un autre
  appareil ou navigateur que celui de la demande affiche d'abord l'adresse du compte. Continue seulement si c'est la
  tienne : un lien piégé ne peut pas te connecter à son insu au compte de quelqu'un d'autre.
- **Changer de mot de passe** : l'actuel, puis le nouveau. Les autres appareils sont déconnectés (au plus tard une
  heure après) : reconnecte-les avec le nouveau mot de passe, leurs données restent.
- **Se déconnecter** : les données restent sur cet appareil, elles ne suivent simplement plus.
- **Supprimer mon compte** : StreamHub redemande ton mot de passe (ou ton mot de passe du coffre), puis efface ton
  compte, ton coffre et tes données synchronisées. Ce qui est sur l'appareil reste.

### Chiffrement de bout en bout

Les comptes sont gérés par **Supabase** (hébergeur de base de données). Tes données y sont **chiffrées dans ton
navigateur** (AES-256-GCM) avant l'envoi, avec une **clé de coffre** tirée au hasard. Cette clé est elle-même gardée
deux fois, fermée à clé : par une clé tirée de ton mot de passe (PBKDF2, 600 000 tours) et par une clé tirée de ta
clé de secours. Ton vrai mot de passe ne quitte jamais l'appareil : Supabase reçoit un autre secret qui en est tiré.
Supabase ne voit donc que ton adresse e-mail, des données illisibles, leur taille et la date de la dernière
modification : ni lui ni personne ne peut lire tes clés ou tes listes sans ton mot de passe ou ta clé de secours.
C'est aussi pourquoi un mot de passe oublié **sans** clé de secours fait perdre les données synchronisées (celles
encore sur un appareil restent, et repartent dans un nouveau compte).

Sur chaque appareil, la clé du coffre est gardée par le navigateur sous une forme **non extractible** (IndexedDB) :
StreamHub peut s'en servir, mais personne ne peut la copier, même un code qui se serait glissé dans la page (version
2.3.4 ; dans l'appli iPhone : trousseau d'Apple). La page ne peut en outre contacter que les serveurs dont StreamHub a
besoin (règles de sécurité, « Content-Security-Policy », dans `index.html`).

### Avant les comptes : le code de synchronisation

Jusqu'à la version 2.0.0, la synchronisation passait par un **code de 20 caractères**. Il n'existe plus depuis la
version 2.1.0 : c'est le compte, ou rien (invité). Rien n'est perdu : chaque appareil a gardé ses données. Crée ton
compte sur l'un d'eux, puis connecte-toi sur les autres : leurs listes sont réunies dans le compte.

---

## 7. Comment StreamHub ouvre les titres

Aucune plateforme ne fournit de lecteur utilisable par un autre site, et les vidéos sont protégées (DRM) : seules
leurs applis et leurs sites officiels peuvent les lire. StreamHub ouvre donc le titre **sur la plateforme**, avec le
lien le plus précis possible :

1. **Streaming Availability** (avec ta clé) : lien direct vers la vidéo, la série ou l'épisode.
2. Sinon **JustWatch** (via le relais StreamHub) : lien vers le titre ou la lecture.
3. Sinon une **recherche** du titre sur la plateforme, ou sa page d'accueil.

Les deux premières sources sont interrogées en même temps à l'ouverture d'une fiche. Si tu cliques sur « Regarder
sur… » avant leur réponse, StreamHub attend le bon lien (4 secondes au plus) au lieu d'ouvrir la recherche.

Par sécurité, seuls des liens web (`https://`, `http://`) reçus de ces services sont gardés : une adresse d'un autre
type (`javascript:`…) est ignorée et n'est jamais ouverte (version 2.3.3, site et appli iPhone).

### Reprendre une série

Pour une série, « Regarder sur… » lance l'**épisode suivant**, là où tu t'es arrêté, ou l'épisode 1 si tu ne l'as
jamais regardée. StreamHub ne peut pas lire ta progression sur les plateformes (elles n'ont pas d'API publique, et
ta progression est protégée par ta connexion) : il leur envoie le lien qu'elles savent reprendre elles-mêmes.

| Plateforme | Comment la série reprend |
|---|---|
| **Netflix** | Lien vers la série (et non vers l'épisode 1) : Netflix lance l'épisode suivant |
| **Prime Video** | Lien de lecture de la série : Prime Video reprend où tu t'es arrêté (site et appli) |
| **Canal+** | Fiche de la série avec lecture automatique : Canal+ lance son bouton « Reprendre » |
| **Disney+** | Page de la série, qui affiche « Reprendre S1 E7 » (ou « Lecture ») ; sur ordinateur, le [script](#8-le-script--reprise-après-connexion-) appuie dessus à ta place, sur iPhone et iPad il reste un appui |
| **TF1+**, **M6+** | Pas de reprise par lien : StreamHub lance l'épisode qui suit le dernier que tu as regardé **depuis StreamHub** (chaque épisode lancé y est noté), grâce à son index des épisodes |

### Sur ordinateur

Chaque plateforme s'ouvre dans son propre onglet (un seul onglet Netflix, un seul onglet Canal+…).

| Plateforme | Ce qui se passe |
|---|---|
| **Netflix**, **Disney+** | La page du titre ou la lecture, selon le lien disponible |
| **Prime Video** | La lecture démarre, sur le site ou dans l'appli Prime Video selon le réglage « Ouvrir les titres » |
| **Canal+** | La fiche du titre s'ouvre et lance la lecture (son coupé au départ) |
| **TF1+**, **M6+** | La vidéo ou la page du programme ; pour les épisodes, StreamHub retrouve leur lien grâce à son index ([partie 11](#publication-et-index-tf1-m6-chaînes-de-canal)) |
| **Autres** | La page du titre, une recherche ou l'accueil de la plateforme |

Un site qui n'est pas celui d'une plateforme connue (lien d'une plateforme moins courante, TMDB…) s'ouvre dans un
onglet indépendant de StreamHub : il ne peut pas modifier l'onglet StreamHub.

Si la plateforme te demande de te connecter ou de choisir un profil, elle oublie souvent le titre demandé : le
**script « reprise après connexion »** le rouvre tout seul ([partie 8](#8-le-script--reprise-après-connexion-)).
Sans lui, une barre **« ▶ Relancer »** permet de le rouvrir en un clic une fois connecté.

### Sur iPhone et iPad

Depuis l'appli de l'écran d'accueil, « Regarder sur… » ouvre **directement l'appli de la plateforme** si elle est
installée, sinon son site sur la bonne page. StreamHub utilise les adresses que chaque plateforme a déclarées à
Apple pour son appli :

- **Netflix**, **Prime Video**, **Disney+** et **Canal+** ouvrent leur appli sur le titre.
- Les épisodes **M6+** s'ouvrent dans l'appli M6+ (avec retour au site si elle n'est pas installée).
- Les applis **TF1+** et **M6+** n'ouvrent parfois que leur accueil ou la fiche du programme.

Astuce : un appui long sur un bouton « Regarder sur… » montre l'adresse et, quand iOS la reconnaît, propose
« Ouvrir dans *l'appli* ».

### Sur Android

Les boutons ouvrent l'appli de la plateforme quand elle est installée, sinon son site.

---

## 8. Le script « reprise après connexion »

Quand tu lances un titre depuis StreamHub et que la plateforme te demande d'abord de te connecter ou de choisir ton
profil (code PIN compris), elle t'envoie ensuite sur son accueil et oublie le titre. Ce petit script s'en souvient :
une fois connecté et le profil choisi, il ouvre le titre demandé. Il sert surtout **sur ordinateur**.

Il fait aussi trois choses de plus :
- il rouvre une fois le titre quand M6+ affiche son accueil, ou TF1+ la fiche du programme, au lieu de la vidéo ;
- sur le site Prime Video, si la lecture a été demandée mais que la fiche reste affichée, il appuie une fois sur
  « Reprendre » ou « Lecture » ;
- sur Disney+, quand tu lances une série, il appuie sur « Reprendre » (ou « Lecture ») sur la page de la série :
  la série reprend à l'épisode suivant.

Il ne tourne que sur StreamHub et sur les sites des plateformes et de leur connexion (depuis la version 3.2 ; avant,
sur tous les sites). Il n'agit que dans un parcours lancé depuis StreamHub (moins de 15 minutes, lien vers la
plateforme du site ouvert), n'envoie rien sur Internet et ne garde, dans ton navigateur, que l'adresse du titre
lancé. Une fois installé, la ligne « Script… installé » apparaît dans
Réglages → Pays et lecture, et la barre « Relancer » ne s'affiche plus.

| Navigateur | Installation |
|---|---|
| **Safari** (Mac, iPhone, iPad) | Appli gratuite **Userscripts** (App Store), activée dans les extensions de Safari, puis ouvrir le script |
| **Chrome, Edge, Brave, Opera** (Windows, Mac, Linux) | Extension **Violentmonkey** ou **Tampermonkey**, puis ouvrir le script ; ou l'extension du dossier `extension/` |
| **Firefox** (Windows, Mac, Linux) | Module **Violentmonkey** ou **Tampermonkey**, puis ouvrir le script |

Adresse du script : **https://arthursavournin.github.io/streamhub/streamhub-reprise.user.js** (il se met ensuite à
jour tout seul). Dans Chrome et Edge, il peut falloir activer **« Autoriser les scripts utilisateur »** dans les
détails de l'extension Violentmonkey ou Tampermonkey.

Le pas à pas complet pour chaque navigateur est dans **[extension/README.md](extension/README.md)**.

---

## 9. Tes données et ta vie privée

Le détail est dans la **[politique de confidentialité](https://arthursavournin.github.io/streamhub/confidentialite.html)**
(aussi : [mentions légales](https://arthursavournin.github.io/streamhub/mentions-legales.html) et
[conditions d'utilisation](https://arthursavournin.github.io/streamhub/conditions.html), liens en bas des réglages).

- **Compte facultatif** : en invité, tout est stocké dans ton navigateur (localStorage). Avec un compte, une copie
  **chiffrée de bout en bout** est gardée chez Supabase ([partie 6](#chiffrement-de-bout-en-bout)).
- **Ce qui sort de ton appareil** : les recherches et fiches demandées à TMDB et Streaming Availability (avec tes
  clés), les demandes de liens au relais (identifiant TMDB et titre du film ou de la série), quand tu choisis un mot de
  passe les 5 premiers caractères de son empreinte (Have I Been Pwned, [partie 6](#créer-un-compte-ou-se-connecter))
  et, avec un compte, ton adresse e-mail et tes données synchronisées, chiffrées avant l'envoi.
- **Aucune publicité, aucun pistage, aucune statistique.**
- **Redémarrer ou fermer le navigateur ne fait rien perdre.** On perd les données d'un navigateur si on efface les
  données des sites, en navigation privée, et dans Safari si StreamHub n'est pas ouvert pendant 7 jours d'utilisation
  de Safari (protection anti-pistage d'Apple ; l'appli de l'écran d'accueil n'est pas concernée). Dans tous les cas,
  ton compte remet tout en place : il suffit de te reconnecter.

---

## 10. Dépannage

**Je n'ai pas la dernière version.**
La version s'affiche en bas des réglages. StreamHub se met à jour quand tu reviens dessus : s'il trouve une nouvelle
version, la page se recharge, après la fermeture des réglages ou de la fiche si l'une est ouverte. Sinon, recharge la
page (⌘R sur Mac, Ctrl+R ou F5 sous Windows et Linux). Sur iPhone, ferme complètement l'appli de l'écran d'accueil
(balaie-la vers le haut dans le sélecteur d'applis), puis rouvre-la.

**« Clé TMDB invalide », ou aucun titre ne s'affiche.**
Vérifie la clé dans Réglages → Clés API avec le bouton Tester. Les clés v3 (32 caractères) et les jetons v4 (longs,
commençant par `eyJ`) fonctionnent.

**Le bouton ouvre la fiche au lieu de lancer la vidéo.**
Ça dépend du lien disponible (voir l'indication sous le bouton). Une clé Streaming Availability donne plus souvent
la « Lecture directe ». TF1+ et M6+ ne permettent pas toujours de lancer une vidéo par un lien.

**La plateforme me demande de me connecter, puis reste sur son accueil.**
Installe le script « reprise après connexion », ou utilise la barre « ▶ Relancer » une fois connecté.

**Sur iPhone, le site de la plateforme s'ouvre au lieu de son appli.**
Ouvre StreamHub depuis son icône de l'écran d'accueil (pas dans Safari), et vérifie que l'appli de la plateforme est
installée. Si iOS a été réglé pour ouvrir ce site dans Safari, fais un appui long sur le bouton et choisis
« Ouvrir dans *l'appli* » : iOS s'en souviendra.

**Sur ordinateur, Prime Video s'ouvre dans l'appli alors que je veux le site (ou l'inverse).**
Choisis dans Réglages → Pays et lecture → Ouvrir les titres.

**« … n'est disponible sur aucune plateforme de streaming dans ce pays », alors que le titre est sorti.**
JustWatch ne l'a pas encore référencé dans ton pays. StreamHub le complète tout seul pour les séries des grandes
plateformes et avec une clé Streaming Availability (voir [La fiche d’un titre](#la-fiche-dun-titre)) ; sinon,
il apparaîtra quand JustWatch l'aura ajouté, en général sous quelques jours.

**Un titre s'affiche avec un titre anglais.**
TMDB n'a pas encore de titre français pour lui. Quand son titre d'origine est écrit dans un autre alphabet (hindi,
coréen, japonais…), StreamHub affiche le titre, le résumé et l'affiche de la version anglaise, souvent ceux qu'utilise
la plateforme en France (exemple : « Reporting Live » sur Netflix). Un titre d'origine en alphabet latin (espagnol,
italien…) est gardé tel quel.

**« Quota Streaming Availability atteint ».**
L'offre gratuite est limitée par jour : StreamHub utilise les liens JustWatch en attendant le lendemain.

**Mes listes ont disparu.**
Les données du navigateur ont été effacées ([partie 9](#9-tes-données-et-ta-vie-privée)) : reconnecte-toi à ton
compte.

**Je ne reçois pas l'e-mail de confirmation ou de mot de passe oublié.**
Regarde dans les indésirables, attends quelques minutes (le nombre d'e-mails par heure est limité), puis **Renvoyer
l'e-mail**. Le lien ne sert qu'une fois et expire au bout d'une heure.

**« Mot de passe trop court » ou « figure dans des fuites de données connues ».**
Un nouveau mot de passe doit faire 12 caractères au moins et ne jamais avoir fuité ailleurs : une phrase de quelques
mots, ou un mot de passe tiré au hasard par ton gestionnaire de mots de passe, convient.

**« Ce lien est-il pour toi ? »**
Le lien de l'e-mail a été ouvert ailleurs que là où il a été demandé. Vérifie l'adresse affichée : si c'est la tienne,
continue ; sinon, ignore le lien.

**« Connexion commencée dans un autre navigateur ».**
La connexion Google / GitHub doit se terminer dans le navigateur où elle a commencé : recommence depuis celui-ci.

**Le problème persiste ?**
Ouvre un ticket sur GitHub : **[Issues → New issue](https://github.com/arthursavournin/streamhub/issues/new)**, en
indiquant ton appareil, ton navigateur et la version de StreamHub.

---

## 11. Pour les développeurs

### Principe

Pas de framework ni d'étape de compilation : du HTML, du CSS et des modules JavaScript servis tels quels. Le site est
publié sur **GitHub Pages**, un petit **relais Cloudflare Workers** fournit les liens JustWatch, et **Supabase** gère
les comptes (Auth et deux tables, chiffrées de bout en bout).

### Lancer StreamHub sur ton ordinateur

Il suffit d'un serveur web local dans le dossier du projet. Python est installé d'office sur Mac et sur la plupart
des Linux ; sous Windows, installe-le depuis https://www.python.org ou le Microsoft Store.

- **Mac** : double-clique sur `lancer.command` (la première fois : clic droit → Ouvrir), ou dans le Terminal :
  ```bash
  cd streamhub
  python3 -m http.server 8080
  ```
- **Windows** (PowerShell ou Invite de commandes) :
  ```powershell
  cd streamhub
  py -m http.server 8080
  ```
- **Linux** :
  ```bash
  cd streamhub
  python3 -m http.server 8080
  ```

Puis ouvre **http://localhost:8080**. Le relais accepte les appels venant de `localhost:8080`.

### Organisation du code

| Fichier | Rôle |
|---|---|
| `index.html`, `styles.css` | Structure et styles de l'interface (effet verre à la fin de `styles.css`) |
| `app.js` | Toute l'interface : pages, fiches, saisons, lancement sur les plateformes, listes, réglages |
| `api.js` | Appels TMDB, Streaming Availability et relais ; tests des clés |
| `providers.js` | Plateformes, liens de secours, forme des liens selon l'appareil (iPhone, appli de l'ordinateur, site) |
| `library.js` | Ma liste, J'aime, historique, téléchargements, questions au retour |
| `store.js` | Réglages, bibliothèque et cache dans le navigateur |
| `sync.js` | Synchronisation chiffrée entre appareils par le compte : chiffrement, fusion, envoi conditionnel |
| `account.js` | Comptes Supabase (Auth et base, appels HTTP directs) : inscription, connexion, coffre, clé de secours |
| `account-ui.js` | Réglages → Compte |
| `supabase/schema.sql` | Tables `vaults` et `sync_data`, règles d'accès (chacun sa ligne), `delete_my_account`, `keepalive`, droits par défaut fermés pour les futurs objets |
| `mentions-legales.html`, `confidentialite.html`, `conditions.html`, `legal.css` | Pages légales (LCEN, RGPD, conditions d'utilisation demandées par Google pour la connexion) |
| `supabase/menage.sql` | Ménage quotidien (pg_cron) : durées de conservation annoncées dans la politique |
| `supabase/templates/` | E-mails en français (confirmation, mot de passe oublié), à coller dans Supabase : Authentication → Emails → Templates |
| `episodes.js` | Liens directs vers les épisodes TF1+ et M6+ (index publié dans `data/`) |
| `aliases.js` | Recherche par surnom ou sigle (liste intégrée + Wikidata) |
| `search.js` | Correction des fautes de frappe, numéro de film, ordre des sagas |
| `suggestions.js` | Onglet Suggestions de la fiche : saga, même univers (films et séries), même genre |
| `nav.js` | Navigation aux flèches (clavier, télécommande) |
| `sw.js`, `manifest.webmanifest`, icônes | Installation en appli (PWA), cache hors ligne et mises à jour |
| `relay/worker.js` | Relais Cloudflare Workers (liens JustWatch) |
| `extension/` | Script « reprise après connexion » et extension Chrome |
| `scripts/` | Index des épisodes TF1+ / M6+, publication du relais |

### Publication et index (TF1+, M6+, chaînes de Canal+, top du moment)

Le site est publié par `.github/workflows/pages.yml` à chaque modification de la branche `main` et **toutes les
6 heures**. À chaque publication, `scripts/build_episode_index.py` lit les plans de site publics de TF1+ et M6+ et
écrit `data/<plateforme>/<programme>.json` (numéro d'épisode, saison-épisode et date → lien de l'épisode) : les liens
d'épisode de ces plateformes contiennent un identifiant interne impossible à deviner.

Le même script écrit `data/canal/hbo.json`, `appletv.json` et `paramount.json` : le catalogue de chaque chaîne de
Canal+ (titre simplifié → adresse de la fiche, films et séries à part), lu dans les grilles de sa page sur Canal+.
Sur Canal+, la fiche d'un titre sur une chaîne a une adresse sans rapport avec sa fiche Canal VOD, et Canal+
n'autorise pas les autres sites à utiliser sa recherche.

Il écrit aussi `data/search/titles.json` : environ 28 000 titres populaires (exports quotidiens publics de TMDB et
titres français de JustWatch), auxquels la recherche compare ce que tu tapes pour proposer une correction.

Il écrit enfin `data/top/<pays>.json` : le classement « populaire » de JustWatch (environ 500 titres en streaming par
abonnement ou gratuits, avec leurs plateformes) pour chaque pays des réglages. Le Top 50 du moment en garde les
premiers titres disponibles sur tes abonnements.

GitHub met en pause les tâches planifiées d'un dépôt sans commit depuis 60 jours : le workflow la réactive à chaque
passage, pour que l'index continue de se mettre à jour.

Les actions du workflow sont épinglées par empreinte de commit (version en commentaire), et seul le travail de
publication (`deploy`) a le droit d'écrire sur GitHub Pages. La branche `main` est protégée (règle « Protéger main » :
ni suppression, ni réécriture de l'historique).

### Version

Le numéro de version est dans `app.js` (`APP_VERSION`) et `sw.js` (`SHELL_CACHE`) : les deux changent ensemble à
chaque publication, ce qui déclenche la mise à jour chez les utilisateurs. Numérotation : 1.0.1, 1.0.2… pour une
correction, 1.1.0 pour une nouvelle fonction. Le script « reprise après connexion » a son propre numéro
(`@version` et `extension/manifest.json`), qui ne doit jamais redescendre : les gestionnaires de scripts ne mettent
à jour que vers un numéro plus grand.

### Le relais (Cloudflare Workers)

`relay/worker.js` est publié sur https://streamhub-relay.arthursavournin.workers.dev (offre gratuite Cloudflare :
100 000 requêtes par jour). Il donne les **liens JustWatch** (`/offers`) : JustWatch refuse les appels venant
d'autres sites, le relais l'interroge à la place du navigateur. Seules les réponses trouvées sont gardées 6 heures
(un titre faux ne peut pas cacher les liens d'un film). Il limite chaque adresse IP à 30 questions à JustWatch par
minute (liaison `LIMITER`, limite de débit de Cloudflare). Il ne stocke rien (son ancienne route `/sync/<id>`, pour le
code de synchronisation d'avant la version 2.1.0, a été supprimée en version 2.3.3, avec son espace Workers KV).

Il n'accepte que les appels venant de l'adresse de StreamHub et de `localhost:8080`. Une copie de StreamHub publiée
ailleurs doit publier son propre relais, avec son compte Cloudflare, puis mettre son adresse dans `store.js`
(`DEFAULT_RELAY`), dans la Content-Security-Policy d'`index.html` et dans l'appli (`Store.swift`, `defaultRelay`).

Pour le publier, il faut un jeton Cloudflare (droit « Edit Cloudflare Workers ») et l'identifiant du compte. Rien de
tout cela n'est enregistré dans le projet.

- **Mac, Linux** :
  ```bash
  CF_API_TOKEN=… CF_ACCOUNT_ID=… scripts/deploy_relay.sh
  ```
- **Windows** (avec Git Bash, installé avec Git pour Windows, ou WSL) :
  ```bash
  CF_API_TOKEN=… CF_ACCOUNT_ID=… bash scripts/deploy_relay.sh
  ```

### Sécurité

Résultat de l'audit de sécurité d'octobre 2026, à garder en tête en modifiant le code :

- **Liens** : toute adresse venue d'un service passe par `webLink` / `safeLink` (`providers.js`) ; un clic sur un
  lien d'un autre type (`javascript:`…) est bloqué dans `app.js`. Les sites hors plateformes connues
  (`isPlatformLink`) s'ouvrent avec `noopener`.
- **Texte et attributs** : tout ce qui vient d'un service passe par `esc` avant `innerHTML` ; les chemins d'images
  passent par `img` (`api.js`), qui refuse ce qui n'est pas une image TMDB ou un logo de StreamHub.
- **Content-Security-Policy** (`<meta>` d'`index.html`) : un nouveau serveur appelé par le site doit y être ajouté.
- **Clés** : la clé du coffre est une `CryptoKey` non extractible dans IndexedDB ; dans l'appli, session, clé du
  coffre et clés API sont dans le trousseau.
- **Base** : chaque nouvelle table reçoit RLS et des droits explicites (rien n'est ouvert par défaut).

### Hébergement

GitHub Pages est gratuit, en HTTPS, et suffit largement (fichiers statiques, 100 Go de trafic par mois) tant que le
dépôt est public. Pour ne plus dépendre de l'hébergeur, la meilleure amélioration serait un **nom de domaine**
(une dizaine d'euros par an) pointé vers GitHub Pages ou Cloudflare Pages : l'adresse ne changerait plus jamais.
Changer d'adresse fait repartir les navigateurs de zéro (le stockage est propre à chaque adresse), mais le compte
récupère tout (ajouter la nouvelle adresse aux adresses autorisées de Supabase : Authentication → URL Configuration).

### Compatibilité

Pensé d'abord pour Safari (Mac, iPhone, iPad), StreamHub fonctionne aussi dans Chrome, Edge et Firefox, sur Mac,
Windows et Linux. Quelques ajustements ne s'appliquent qu'à ces navigateurs (par exemple des barres de défilement
fines sous Windows), jamais à Safari : `app.js` pose l'attribut `data-engine` sur la page pour Chrome, Edge et
Firefox, et les règles correspondantes sont à la fin de `styles.css`.
