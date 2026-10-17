# StreamHub

Tous les films et séries disponibles en streaming, au même endroit. On clique sur un titre, l'appli indique sur quelles
plateformes il est disponible (en commençant par tes abonnements) et l'ouvre directement sur la bonne plateforme.
Navigation façon Netflix : **Accueil** (une affiche mise en avant et des rangées : Reprendre, Ma liste, Tendances,
populaires, Top 50 du moment, Nouveautés, une rangée par genre…), **Films** et **Séries** (rangées par genre), **Bibliothèque** (tout le catalogue
en grille, avec les filtres Tout / Films / Séries, plateforme, genre, tri) et **Mon espace** (J'aime, Historique,
Téléchargements). Chaque rangée a un « Tout voir » qui ouvre la Bibliothèque filtrée. Sur téléphone, la navigation
passe en bas de l'écran. Les abonnements se choisissent dans les réglages. Pour une série, on clique sur une saison pour voir
ses épisodes (résumé, date, durée) et lancer directement celui qu'on veut.

Onglets **Ma liste** (titres mis de côté avec « + Ma liste »), **J'aime**, **Historique** (les 30 derniers titres regardés depuis StreamHub) et **Téléchargements**.
Au retour dans StreamHub, une question confirme ce qui s'est passé : « Tu as regardé Shrek 4 ? » (posée au moins
3 minutes après le lancement, avec un bouton J'aime) ou « Le téléchargement a bien démarré ? ». Un titre n'entre dans
l'historique ou les téléchargements que si la réponse est oui. Pour une série, le J'aime porte sur la série entière.
Avec la **synchronisation** (voir plus bas), Ma liste, J'aime et historique suivent sur tous tes navigateurs et appareils.

- **Liker aussi sur la plateforme** : aucune plateforme ne permet de liker à distance. Une fois un titre aimé, le
  bouton « Liker aussi sur Netflix » (ou Prime Video, Canal+…), proposé quelques secondes dans une notification, ouvre la page du titre, où tu appuies sur
  « J'adore », le pouce ou « Ma liste » ; au retour, StreamHub demande « Tu as liké… ? » pour s'en souvenir.
  Retirer un J'aime dans StreamHub rappelle que le like est toujours là sur la plateforme, avec un bouton pour y aller.
- **Télécharger** ne peut pas lancer le téléchargement à distance : seules les applis mobiles des plateformes
  téléchargent, et elles ne l'exposent pas. Le bouton ouvre le titre dans l'appli de la plateforme (où tu appuies sur
  son bouton de téléchargement) et le note dans l'onglet Téléchargements, qui sert de rappel.
  Il n'apparaît que sur iPhone, iPad et Android : sur ordinateur et TV, les plateformes ne permettent pas de
  télécharger, la fiche indique donc seulement de passer par l'appli mobile.
- **Premier lancement** : si la plateforme demande d'abord de se connecter ou de choisir un profil, le script
  « reprise après connexion » (voir plus bas) ouvre ensuite le titre. Sans lui, la barre « Relancer » le fait en un clic.

- **PC** : fonctionne dans n'importe quel navigateur.
- **Téléphone** : s'ajoute à l'écran d'accueil comme une appli (PWA, voir « Sur le téléphone »).
- **TV** : l'interface se pilote entièrement aux flèches + OK + Retour, comme une télécommande.

## Utiliser StreamHub

L'appli est en ligne : **https://arthursavournin.github.io/streamhub/**. Rien à installer sur un ordinateur ;
sur téléphone, on l'ajoute à l'écran d'accueil (voir « Sur le téléphone »).

**Pour tes amis** : envoie-leur simplement cette adresse. Au premier lancement, chacun colle **ses propres clés**
(TMDB gratuite, Streaming Availability facultative), coche ses abonnements et, s'il le veut, crée **son propre code
de synchronisation**. Les données de chacun restent dans son navigateur et dans sa synchronisation chiffrée :
personne ne voit les clés, abonnements ou J'aime des autres. Pas besoin de leur donner le dépôt GitHub.
Ils partagent seulement le relais (gratuit, voir plus bas), largement suffisant pour quelques personnes.

## Lancer en local (développement)

Sur Mac, double-clique sur `lancer.command` (la première fois : clic droit → Ouvrir), ou dans un terminal :

```bash
cd streamhub && python3 -m http.server 8080
```

Puis ouvre http://localhost:8080.

## Les clés API

Toutes se voient et se gèrent dans les **Réglages** (roue dentée), section « Clés API », avec un bouton
**Tester** pour chacune.

| Clé | À quoi elle sert | Où la créer |
|---|---|---|
| **TMDB** (obligatoire, gratuite) | Catalogue des films et séries, fiches, et « où regarder » par pays | themoviedb.org → compte → Paramètres → API |
| **Streaming Availability** (facultative) | Liens directs vers le film, la série ou l'épisode sur Netflix, Disney+… | rapidapi.com → API « Streaming Availability » → offre Basic gratuite |
| **Relais StreamHub** (adresse, sans clé) | Liens JustWatch (France TV, chaînes Prime…) et synchronisation | Prérempli ; à changer seulement si tu publies ton propre relais |

**Les clés ne sont pas sur GitHub** : elles ne sont jamais dans le code. Elles restent dans le navigateur
(et, chiffrées, dans ta synchronisation), et ne sont envoyées qu'à TMDB et RapidAPI.
Le **jeton Cloudflare** ne sert qu'à publier le relais (`scripts/deploy_relay.sh`) : l'appli ne s'en sert pas et il
n'est enregistré nulle part dans le projet.

Sans la clé Streaming Availability, le bouton « Regarder sur… » ouvre une recherche du titre sur la plateforme
(ou sa page d'accueil quand la recherche par lien n'existe pas, comme pour Canal+ et HBO Max).
L'offre gratuite de Streaming Availability est limitée en nombre de requêtes par jour : l'appli garde donc
chaque résultat en cache pendant 3 jours et ne fait une requête qu'à l'ouverture d'une fiche.

## Synchronisation entre navigateurs et appareils

Chaque navigateur garde ses propres données : sans synchronisation, StreamHub ouvert dans Chrome ne connaît
ni les clés ni les J'aime enregistrés dans Safari. Pour les retrouver partout :

1. Sur l'appareil où tout est déjà réglé : Réglages → Synchronisation → **Créer mon code de synchronisation**.
2. Sur chaque autre navigateur ou appareil : Réglages → colle le code → **Utiliser ce code**.

Ensuite, chaque modification part toute seule (quelques secondes après) et arrive sur les autres appareils à leur
ouverture ou quand on revient sur l'onglet. Sont synchronisés : clés, pays, abonnements, J'aime, historique et likes
sur les plateformes. Restent propres à chaque appareil : téléchargements (ils sont sur l'appareil), questions en
attente, effet verre et le réglage « Ouvrir les titres ».

**Ouvrir les titres sur le site ou dans l'appli** (Réglages › Pays et lecture, sur ordinateur seulement) : avec
« Dans l'appli de l'ordinateur », les titres Prime Video s'ouvrent dans l'appli Prime Video installée sur le Mac ou
le PC et la lecture démarre (adresse `aiv://aiv/detail?gti=…&action=watch&time=auto`, celle que l'appli fabrique
elle-même) ; avec « Sur le site internet », dans un onglet du navigateur.
Les autres plateformes n'ont pas d'appli Mac (sous Windows, leurs applis ne sont pas encore prises en charge) ;
d'autres pourront s'ajouter dans `desktopAppLink` (`providers.js`).

Les données sont **chiffrées dans le navigateur** (AES-256-GCM, clé tirée du code) avant d'être envoyées au relais,
qui les stocke dans Cloudflare KV sous une empreinte du code : ni Cloudflare ni personne d'autre ne peut les lire
sans le code. Garde-le comme un mot de passe : il donne accès à tes clés. Code perdu : crée-en un nouveau depuis un
appareil où les données sont encore là.

## Où sont gardées les données, et combien de temps

- **Redémarrer l'ordinateur ou fermer le navigateur ne fait rien perdre** : tout est dans le stockage du site
  (localStorage), qui persiste.
- On perd les données d'un navigateur si on **efface l'historique / les données des sites**, en navigation privée,
  et dans **Safari** si le site n'est pas ouvert pendant **7 jours** d'utilisation de Safari (protection
  anti-pistage d'Apple). L'appli **ajoutée à l'écran d'accueil** de l'iPhone n'est pas concernée.
- Dans tous ces cas, la synchronisation remet tout en place : il suffit de recoller le code.

## Hébergement : GitHub Pages, et après ?

GitHub Pages est gratuit, en HTTPS, et convient bien à une appli comme celle-ci (fichiers statiques, limite de
100 Go de trafic par mois). Il reste en ligne tant que le dépôt est public et le compte actif. La mise à jour
planifiée de l'index TF1+ / M6+ est maintenue active automatiquement (GitHub met en pause les tâches planifiées
d'un dépôt sans commit depuis 60 jours ; le workflow la réactive à chaque passage).

Pour être indépendant de l'hébergeur, la vraie amélioration serait un **nom de domaine à toi** (ex. streamhub.fr,
une dizaine d'euros par an) pointé vers GitHub Pages ou Cloudflare Pages : l'adresse ne changerait plus jamais,
même en changeant d'hébergeur. Changer d'adresse fait repartir les navigateurs de zéro (stockage par site),
mais la synchronisation récupère tout.

## Pourquoi le film ne se lit pas *dans* l'appli

Aucune plateforme (Netflix, Disney+, Canal+, HBO Max, Apple TV…) ne fournit d'API de lecture, et les vidéos sont
protégées par DRM : seules leurs applis officielles peuvent les lire. StreamHub ouvre donc le film dans la plateforme.
Sur téléphone et TV, les liens ouvrent directement l'appli de la plateforme si elle est installée.

## Sur le téléphone

Ouvre https://arthursavournin.github.io/streamhub/ puis :

- **iPhone** (Safari) : Partager → « Sur l'écran d'accueil »
- **Android** (Chrome) : menu ⋮ → « Installer l'application »

Au premier lancement, colle ton code de synchronisation dans les Réglages : clés, abonnements et J'aime arrivent
de tes autres appareils. (L'appli de l'écran d'accueil a son propre stockage, distinct de Safari : le code s'y entre
une fois.)

Dans l'appli de l'écran d'accueil (« Ouvrir comme app web » activé, réglage par défaut), toucher « Regarder sur… »
ouvre **directement** l'appli de la plateforme si elle est installée, sinon son site, sans page intermédiaire :
StreamHub utilise les liens web que chaque plateforme a déclarés à Apple pour son appli (Netflix, Canal+, Prime
Video, Disney+, TF1+, M6+, france.tv, Paramount+, HBO Max) : sans l'appli installée, le site s'ouvre sur la bonne
page. Netflix, Prime Video, Disney+ et Canal+ ouvrent leur appli sur le titre. Les épisodes M6+ passent par
l'adresse de l'appli M6+ (`sixplay://…`, celle qu'annonce la page de l'épisode), avec retour au site si l'appli
n'est pas installée. Les applis TF1+ et M6+ n'ouvrent parfois que leur accueil ou la fiche du programme.

**Navigateurs** : pensé pour Safari (Mac, iPhone, iPad), il marche aussi dans Chrome, Edge et Firefox, sur Mac comme
sous Windows. Quelques ajustements ne s'appliquent qu'à ces navigateurs (barres de défilement fines sous Windows),
jamais à Safari.

**Effet verre** : barres, boutons et fenêtres en verre dépoli, inspiré de Liquid Glass. Une page web n'a pas accès
au réglage Liquid Glass d'iOS / macOS (« Transparent » / « Teinté ») ni aux matériaux natifs : StreamHub suit
automatiquement « Augmenter le contraste » (transmis par Safari) et « Réduire la transparence » (transmis par
Chrome / Edge ; Safari ne le transmet pas aux sites), et propose son propre réglage
Réglages › Effet verre (Automatique, Transparent, Teinté), propre à chaque appareil.

Sur Android (Chrome), les liens ouvrent l'appli de la plateforme quand elle est installée.

## Sur la TV — prochaines étapes

- **Android TV / Google TV** : emballer la PWA dans une appli Android (Bubblewrap/TWA ou Capacitor). Les liens Netflix,
  Disney+, etc. ouvriront les applis TV correspondantes.
- **Samsung (Tizen) / LG (webOS)** : ce sont des TV web ; l'appli s'y empaquette presque telle quelle
  (les touches Retour des télécommandes sont déjà gérées).
- **Apple TV** : pas de navigateur ni d'appli web possible, il faudrait une appli native tvOS (SwiftUI).

## Organisation du code

| Fichier | Rôle |
|---|---|
| `index.html`, `styles.css` | Interface |
| `app.js` | Catalogue films / séries, recherche, fiches (avec saisons), réglages |
| `api.js` | Appels TMDB, Streaming Availability et relais ; tests des clés |
| `sync.js` | Synchronisation chiffrée entre appareils (via le relais) |
| `providers.js` | Correspondance des plateformes et liens de secours |
| `library.js` | Ma liste, J'aime, historique et téléchargements |
| `episodes.js` | Liens directs vers les épisodes TF1+ et M6+ (index publié dans `data/`) |
| `aliases.js` | Recherche par surnom ou sigle : liste intégrée + Wikidata (« DNA » → Demain nous appartient) |
| `nav.js` | Navigation aux flèches (télécommande) |
| `store.js` | Réglages, bibliothèque et cache dans le navigateur |
| `sw.js`, `manifest.webmanifest`, `icon.svg` | Installation en appli (PWA), cache et mises à jour |
| `relay/worker.js` | Relais Cloudflare (liens JustWatch, synchronisation) |
| `extension/` | Script « reprise après connexion » et extension Chrome |
| `scripts/` | Index des épisodes TF1+ / M6+, publication du relais |

## Publication et index TF1+ / M6+

Le site est publié par `.github/workflows/pages.yml` à chaque modification et **toutes les 6 heures**.
À chaque publication, `scripts/build_episode_index.py` lit les plans de site publics de TF1+ et M6+ et écrit
`data/<plateforme>/<programme>.json` (numéro d'épisode, saison-épisode et date → lien de l'épisode). Les liens
d'épisode de ces plateformes contiennent un identifiant interne que StreamHub ne peut pas deviner ni lire lui-même.

## Relais StreamHub (Cloudflare Workers)

`relay/worker.js`, publié sur https://streamhub-relay.arthursavournin.workers.dev (offre gratuite Cloudflare :
100 000 requêtes et 1 000 enregistrements de synchronisation par jour). Il a deux rôles :

- **Liens JustWatch** : quand Streaming Availability n'a pas de lien direct (titre ou plateforme qu'il ne connaît
  pas, comme les chaînes Amazon type France TV), StreamHub demande les liens de JustWatch au relais (JustWatch
  refuse les appels directs des autres sites). Les deux sont interrogés en même temps à l'ouverture d'une fiche ;
  un clic sur « Regarder sur… » avant leur réponse attend le lien direct (4 s au plus) au lieu d'ouvrir la page de
  secours (accueil ou fiche du programme).
- **Synchronisation** : stocke les données chiffrées de chaque code (Workers KV, espace `streamhub-sync`).

Il n'accepte que les appels venant de l'adresse de StreamHub (et de `localhost:8080`, pour le développement). Quelqu'un
qui publie sa propre copie de StreamHub doit publier son propre relais (ce script, avec son compte Cloudflare
et son propre espace KV), puis en mettre l'adresse dans les Réglages. Pour mettre le relais à jour :

```bash
CF_API_TOKEN=… CF_ACCOUNT_ID=… CF_KV_NAMESPACE_ID=… scripts/deploy_relay.sh
```

## Script « StreamHub » (reprise après connexion)

Si une plateforme demande de se connecter ou de choisir un profil (même affiché à l'adresse du titre, comme chez
Netflix), ce script ouvre ensuite le titre lancé depuis StreamHub au lieu de l'accueil. Il rouvre aussi le titre
une fois quand M6+ affiche son accueil, ou TF1+ la fiche du programme, au lieu de la vidéo demandée. Sur le site
Prime Video, si la lecture était demandée mais que la fiche reste affichée, il appuie une fois sur « Reprendre » /
« Lecture ».
Un seul fichier pour Safari (appli Userscripts, Mac et iPhone), Firefox et Chrome (gestionnaire de scripts ou
extension du dossier `extension/`).
Installation et fonctionnement : [extension/README.md](extension/README.md).
