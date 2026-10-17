# StreamHub : documentation

Tout ce qu'il faut savoir pour utiliser StreamHub, de l'installation au dépannage, et pour les développeurs.
Pour une présentation rapide, voir le [README](README.md).

👉 **https://arthursavournin.github.io/streamhub/**

---

## Sommaire

1. [Ce que fait StreamHub](#1-ce-que-fait-streamhub)
2. [Installer StreamHub sur chaque appareil](#2-installer-streamhub-sur-chaque-appareil)
3. [Premier lancement](#3-premier-lancement)
4. [Les clés API](#4-les-clés-api)
5. [Les réglages](#5-les-réglages)
6. [Synchroniser plusieurs appareils](#6-synchroniser-plusieurs-appareils)
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

- **Accueil** : une affiche mise en avant et des rangées façon Netflix : Top 50 du moment, Reprendre, Ma liste,
  Nouveautés, Les mieux notés, puis une rangée par genre (Action & aventure, Comédie, Horreur, Science-fiction &
  fantastique, Thriller & policier, Drame, Animation, Animés japonais, Romance, Famille, Documentaires).
- **Films** et **Séries** : les mêmes rangées, réservées aux films ou aux séries.
- **Bibliothèque** : tout le catalogue en grille, avec des filtres (Tout / Films / Séries, plateforme, genre) et un
  tri (Populaires, Mieux notés, Plus récents). Le lien « Tout voir » de chaque rangée ouvre la Bibliothèque déjà
  filtrée.
- **Mon espace** : tes listes (Ma liste, J'aime, Historique, Téléchargements) et tes plateformes.
- **Recherche** : par titre, mais aussi par surnom ou sigle (« DNA » trouve *Demain nous appartient*, grâce à une
  liste intégrée et à Wikidata).

Par défaut, StreamHub ne montre que les titres disponibles sur **tes abonnements** ; un lien permet d'afficher aussi
les autres.

### La fiche d'un titre

Un clic sur une affiche ouvre sa fiche : résumé, année, durée ou nombre de saisons, genres, bande-annonce, et les
boutons **« Regarder sur… »**, rangés en trois groupes :

- **Dans tes abonnements** : les plateformes que tu as cochées dans les réglages.
- **Aussi disponible sur** : les autres plateformes où le titre est inclus (abonnement, gratuit, avec pub).
- **Location et achat** : les boutiques (Apple TV, Amazon Video…), repliées par défaut.

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
l'épisode 1 si tu ne l'as jamais regardée ([détails](#reprendre-une-série)). Chaque saison se déplie aussi pour
afficher ses épisodes (résumé, date, durée), avec un bouton pour lancer directement celui que tu veux quand la
plateforme le permet.

### Tes listes

- **Ma liste** : les titres mis de côté avec « + Ma liste » (dans la fiche ou sur l'affiche de l'accueil).
- **J'aime** : les titres aimés avec « ♡ J'aime ». Pour une série, le J'aime porte sur la série entière.
- **Historique** : les 30 derniers titres regardés depuis StreamHub.
- **Téléchargements** : un rappel des titres téléchargés dans les applis des plateformes (voir plus bas).

Quand tu reviens dans StreamHub après avoir lancé un titre, une question confirme ce qui s'est passé :
« Tu as regardé *Naruto* sur Prime Video ? » (posée au moins 3 minutes après le lancement) ou « Le téléchargement a
bien démarré ? ». Un titre n'entre dans l'historique ou les téléchargements que si tu réponds oui. La question
propose aussi d'aimer le titre.

### Liker aussi sur la plateforme

Aucune plateforme ne permet de liker un titre à distance. Quand tu aimes un titre dans StreamHub, une notification
propose pendant quelques secondes **« Liker aussi sur »**, avec une pastille par plateforme : elle ouvre la page du
titre, où tu appuies sur le pouce ou « J'adore ». Au retour, StreamHub demande « Tu as liké… ? » pour s'en souvenir.
Retirer un J'aime dans StreamHub rappelle que le like est toujours là sur la plateforme, avec un bouton pour y aller.

### Télécharger pour regarder hors ligne

Seules les applis mobiles des plateformes savent télécharger, et elles ne permettent pas de le faire à distance. Le
bouton **« ⬇ Télécharger »** ouvre donc le titre dans l'appli de la plateforme, où tu appuies sur son bouton de
téléchargement, et le note dans l'onglet Téléchargements, qui sert de rappel. Il n'apparaît que sur iPhone, iPad et
Android : sur ordinateur et TV, les plateformes ne permettent pas de télécharger.

### Et aussi

- **Synchronisation chiffrée** des réglages, clés et listes entre tous tes appareils ([partie 6](#6-synchroniser-plusieurs-appareils)).
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

L'appli de l'écran d'accueil a son propre stockage, séparé de Safari : au premier lancement, colle ton code de
synchronisation (ou tes clés). C'est depuis cette icône que les boutons « Regarder sur… » ouvrent directement les
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

1. Ouvre StreamHub : au premier lancement, les réglages s'ouvrent.
2. **Tu utilises déjà StreamHub ailleurs ?** Colle ton **code de synchronisation** dans « Synchronisation » →
   **Utiliser ce code** : clés, abonnements et listes reviennent. C'est fini.
3. Sinon, colle ta **clé TMDB** dans « Clés API » ([partie 4](#4-les-clés-api)). C'est la seule clé obligatoire.
4. Coche tes **abonnements** dans « Mes abonnements ».
5. Appuie sur **Enregistrer**.

Facultatif, mais recommandé : une clé **Streaming Availability** pour des liens qui lancent directement la vidéo ou
l'épisode, et, sur ordinateur, le **script « reprise après connexion »** ([partie 8](#8-le-script--reprise-après-connexion-)).

**Partager StreamHub avec tes proches** : envoie-leur simplement l'adresse. Chacun colle **ses propres clés**, coche
ses abonnements et crée, s'il le veut, **son propre code de synchronisation**. Les données de chacun restent dans son
navigateur : personne ne voit les clés, abonnements ou listes des autres.

---

## 4. Les clés API

StreamHub n'a pas de serveur qui stocke tes données : il interroge directement des services publics avec **tes**
clés. Elles se gèrent dans **Réglages → Clés API**, avec un bouton **Tester** pour chacune.

| Clé | Obligatoire ? | À quoi elle sert |
|---|---|---|
| **TMDB** | Oui (gratuite) | Catalogue des films et séries, fiches, plateformes disponibles par pays |
| **Streaming Availability** | Non (offre gratuite) | Liens directs qui lancent la vidéo, la série ou l'épisode |
| **Relais StreamHub** | Non (adresse préremplie) | Liens JustWatch (France TV, chaînes Prime…) et synchronisation |

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

**Tes clés ne sont jamais publiées** : elles ne sont pas dans le code, restent dans ton navigateur (et, chiffrées,
dans ta synchronisation), et ne sont envoyées qu'à TMDB et RapidAPI.

---

## 5. Les réglages

La roue dentée en haut à droite ouvre les réglages. Les sections sont repliées : touche celle que tu veux.

| Section | Contenu |
|---|---|
| **Mes abonnements** | Les plateformes auxquelles tu es abonné, avec un champ pour filtrer la liste. Cocher Prime Video coche aussi les chaînes incluses avec Prime. |
| **Synchronisation** | Créer ou utiliser un code, synchroniser maintenant, arrêter sur cet appareil. |
| **Clés API** | Clé TMDB, clé Streaming Availability, adresse du relais, avec un bouton Tester pour chacune. |
| **Apparence** | Effet verre : Automatique, Transparent ou Teinté (propre à chaque appareil). |
| **Pays et lecture** | Pays du catalogue (France, Belgique, Suisse, Luxembourg, Canada, Royaume-Uni, États-Unis, Allemagne, Espagne, Italie) et, sur ordinateur, **Ouvrir les titres**. |

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

## 6. Synchroniser plusieurs appareils

Chaque navigateur garde ses propres données : sans synchronisation, StreamHub ouvert dans Chrome ne connaît ni les
clés ni les listes enregistrées dans Safari, et l'appli de l'écran d'accueil de l'iPhone ne connaît pas celles de
Safari. Pour tout retrouver partout :

1. Sur l'appareil où tout est déjà réglé : **Réglages → Synchronisation → Créer mon code de synchronisation**.
   Note ce code (20 caractères, par exemple `ABCD-EFGH-JKLM-NPQR-STUV`) dans ton gestionnaire de mots de passe.
2. Sur chaque autre navigateur ou appareil : **Réglages → Synchronisation**, colle le code → **Utiliser ce code**.

Ensuite, chaque modification part toute seule quelques secondes après, et arrive sur les autres appareils à leur
ouverture ou quand tu reviens sur StreamHub.

- **Synchronisés** : clés, pays, abonnements, Ma liste, J'aime, historique, likes sur les plateformes.
- **Propres à chaque appareil** : téléchargements (ils sont sur l'appareil), questions en attente, effet verre,
  réglage « Ouvrir les titres ».

Les données sont **chiffrées dans ton navigateur** (AES-256-GCM, clé tirée du code) avant d'être envoyées au relais,
qui les stocke sous une empreinte du code : personne, pas même l'hébergeur, ne peut les lire sans le code. Garde-le
comme un mot de passe : il donne accès à tes clés. Code perdu ? Crée-en un nouveau depuis un appareil où les données
sont encore là.

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
| **TF1+**, **M6+** | Pas de reprise par lien : StreamHub lance l'épisode qui suit le dernier que tu as regardé **depuis StreamHub** (quand tu as répondu « Oui » à « Tu as regardé… ? »), grâce à son index des épisodes |

### Sur ordinateur

Chaque plateforme s'ouvre dans son propre onglet (un seul onglet Netflix, un seul onglet Canal+…).

| Plateforme | Ce qui se passe |
|---|---|
| **Netflix**, **Disney+** | La page du titre ou la lecture, selon le lien disponible |
| **Prime Video** | La lecture démarre, sur le site ou dans l'appli Prime Video selon le réglage « Ouvrir les titres » |
| **Canal+** | La fiche du titre s'ouvre et lance la lecture (son coupé au départ) |
| **TF1+**, **M6+** | La vidéo ou la page du programme ; pour les épisodes, StreamHub retrouve leur lien grâce à son index ([partie 11](#publication-et-index-tf1--m6)) |
| **Autres** | La page du titre, une recherche ou l'accueil de la plateforme |

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

Il n'agit que dans un parcours lancé depuis StreamHub (moins de 15 minutes), n'envoie rien sur Internet et ne garde,
dans ton navigateur, que l'adresse du titre lancé. Une fois installé, la ligne « Script… installé » apparaît dans
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

- **Pas de compte, pas de serveur de données** : tout est stocké dans ton navigateur (localStorage).
- **Ce qui sort de ton appareil** : les recherches et fiches demandées à TMDB et Streaming Availability (avec tes
  clés), les demandes de liens au relais (identifiant TMDB et titre du film ou de la série) et, si tu l'actives, ta
  synchronisation, chiffrée avant l'envoi.
- **Aucune publicité, aucun pistage, aucune statistique.**
- **Redémarrer ou fermer le navigateur ne fait rien perdre.** On perd les données d'un navigateur si on efface les
  données des sites, en navigation privée, et dans Safari si StreamHub n'est pas ouvert pendant 7 jours d'utilisation
  de Safari (protection anti-pistage d'Apple ; l'appli de l'écran d'accueil n'est pas concernée). Dans tous les cas,
  la synchronisation remet tout en place : il suffit de recoller le code.

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

**« Quota Streaming Availability atteint ».**
L'offre gratuite est limitée par jour : StreamHub utilise les liens JustWatch en attendant le lendemain.

**Mes listes ont disparu.**
Les données du navigateur ont été effacées ([partie 9](#9-tes-données-et-ta-vie-privée)) : recolle ton code de
synchronisation.

**Le problème persiste ?**
Ouvre un ticket sur GitHub : **[Issues → New issue](https://github.com/arthursavournin/streamhub/issues/new)**, en
indiquant ton appareil, ton navigateur et la version de StreamHub.

---

## 11. Pour les développeurs

### Principe

Pas de framework ni d'étape de compilation : du HTML, du CSS et des modules JavaScript servis tels quels. Le site est
publié sur **GitHub Pages**, et un petit **relais Cloudflare Workers** fournit les liens JustWatch et la
synchronisation.

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
| `sync.js` | Synchronisation chiffrée entre appareils (via le relais) |
| `episodes.js` | Liens directs vers les épisodes TF1+ et M6+ (index publié dans `data/`) |
| `aliases.js` | Recherche par surnom ou sigle (liste intégrée + Wikidata) |
| `nav.js` | Navigation aux flèches (clavier, télécommande) |
| `sw.js`, `manifest.webmanifest`, icônes | Installation en appli (PWA), cache hors ligne et mises à jour |
| `relay/worker.js` | Relais Cloudflare Workers (liens JustWatch, synchronisation) |
| `extension/` | Script « reprise après connexion » et extension Chrome |
| `scripts/` | Index des épisodes TF1+ / M6+, publication du relais |

### Publication et index TF1+ / M6+

Le site est publié par `.github/workflows/pages.yml` à chaque modification de la branche `main` et **toutes les
6 heures**. À chaque publication, `scripts/build_episode_index.py` lit les plans de site publics de TF1+ et M6+ et
écrit `data/<plateforme>/<programme>.json` (numéro d'épisode, saison-épisode et date → lien de l'épisode) : les liens
d'épisode de ces plateformes contiennent un identifiant interne impossible à deviner.

GitHub met en pause les tâches planifiées d'un dépôt sans commit depuis 60 jours : le workflow la réactive à chaque
passage, pour que l'index continue de se mettre à jour.

### Version

Le numéro de version est dans `app.js` (`APP_VERSION`) et `sw.js` (`SHELL_CACHE`) : les deux changent ensemble à
chaque publication, ce qui déclenche la mise à jour chez les utilisateurs. Numérotation : 1.0.1, 1.0.2… pour une
correction, 1.1.0 pour une nouvelle fonction. Le script « reprise après connexion » a son propre numéro
(`@version` et `extension/manifest.json`), qui ne doit jamais redescendre : les gestionnaires de scripts ne mettent
à jour que vers un numéro plus grand.

### Le relais (Cloudflare Workers)

`relay/worker.js` est publié sur https://streamhub-relay.arthursavournin.workers.dev (offre gratuite Cloudflare :
100 000 requêtes et 1 000 enregistrements par jour). Il a deux rôles :

- **Liens JustWatch** (`/offers`) : JustWatch refuse les appels venant d'autres sites, le relais l'interroge à la
  place du navigateur. Réponses gardées 6 heures.
- **Synchronisation** (`/sync/<id>`) : stocke les données chiffrées de chaque code dans Workers KV.

Il n'accepte que les appels venant de l'adresse de StreamHub et de `localhost:8080`. Une copie de StreamHub publiée
ailleurs doit publier son propre relais, avec son compte Cloudflare et son propre espace Workers KV, puis en mettre
l'adresse dans Réglages → Clés API → Relais StreamHub.

Pour le publier, il faut un jeton Cloudflare (droit « Edit Cloudflare Workers »), l'identifiant du compte et celui
de l'espace Workers KV. Rien de tout cela n'est enregistré dans le projet.

- **Mac, Linux** :
  ```bash
  CF_API_TOKEN=… CF_ACCOUNT_ID=… CF_KV_NAMESPACE_ID=… scripts/deploy_relay.sh
  ```
- **Windows** (avec Git Bash, installé avec Git pour Windows, ou WSL) :
  ```bash
  CF_API_TOKEN=… CF_ACCOUNT_ID=… CF_KV_NAMESPACE_ID=… bash scripts/deploy_relay.sh
  ```

### Hébergement

GitHub Pages est gratuit, en HTTPS, et suffit largement (fichiers statiques, 100 Go de trafic par mois) tant que le
dépôt est public. Pour ne plus dépendre de l'hébergeur, la meilleure amélioration serait un **nom de domaine**
(une dizaine d'euros par an) pointé vers GitHub Pages ou Cloudflare Pages : l'adresse ne changerait plus jamais.
Changer d'adresse fait repartir les navigateurs de zéro (le stockage est propre à chaque adresse), mais la
synchronisation récupère tout.

### Compatibilité

Pensé d'abord pour Safari (Mac, iPhone, iPad), StreamHub fonctionne aussi dans Chrome, Edge et Firefox, sur Mac,
Windows et Linux. Quelques ajustements ne s'appliquent qu'à ces navigateurs (par exemple des barres de défilement
fines sous Windows), jamais à Safari : `app.js` pose l'attribut `data-engine` sur la page pour Chrome, Edge et
Firefox, et les règles correspondantes sont à la fin de `styles.css`.
