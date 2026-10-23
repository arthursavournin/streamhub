# StreamHub: documentation

Everything you need to know to use StreamHub, from installation to troubleshooting, plus a section for developers.
For a quick overview, see the [README](README.md).

🇫🇷 Version française : **[DOCUMENTATION_fr.md](DOCUMENTATION_fr.md)**

👉 **https://arthursavournin.github.io/streamhub/**

> StreamHub's interface is in French. Button and menu names are quoted here as they appear on screen, with an English
> translation the first time they come up.

---

## Contents

1. [What StreamHub does](#1-what-streamhub-does)
2. [Installing StreamHub on each device](#2-installing-streamhub-on-each-device)
3. [First launch](#3-first-launch)
4. [API keys](#4-api-keys)
5. [Settings](#5-settings)
6. [Your account and sync](#6-your-account-and-sync)
7. [How StreamHub opens titles](#7-how-streamhub-opens-titles)
8. [The "resume after sign-in" script](#8-the-resume-after-sign-in-script)
9. [Your data and privacy](#9-your-data-and-privacy)
10. [Troubleshooting](#10-troubleshooting)
11. [For developers](#11-for-developers)

---

## 1. What StreamHub does

StreamHub brings together the catalog of movies and series available for streaming in your country, shows you which
platforms each title is on (starting with your subscriptions), and opens it directly on the right platform. It is a
web app: it runs in the browser, works without an account, and can be installed like an app on phones, tablets and
computers.

### Browsing the catalog

**On a phone (the site in Safari and the iPhone app share the same interface)**: at the top, the logo, the search
field and the settings gear; at the bottom, three tabs: **Accueil** (Home), **Bibliothèque** (Library) and
**Mon espace** (My space). The Movies, Series and Anime pages open from the home page, using the chips
**Tout · Films · Séries · Animés** (All · Movies · Series · Anime) under the top bar. Posters are shown without text
underneath (the latest episode of a recent series is printed on the poster), the big poster on the home page offers
"▶ Voir" (Watch) and "+ Ma liste" (+ My list), and My space is split into segments (My list, Likes, History,
Downloads). Pull the page down to refresh the home page or a section. On a computer nothing changes: the sections are
in the top bar.

**On iPhone Duo (the site in Safari)**: same features, with a layout adapted to each form. **Closed**: the phone
interface, with a shorter big poster and three posters per line. **Open in portrait**: the phone interface, larger:
a wide image as the big poster that stops before the fold, bigger posters (four per line), a roomier title page.
**Open in landscape**: the computer interface (as on iPad), with the big poster's text kept left of the fold and the
title page full screen. The iPhone app is not adapted to the iPhone Duo yet.

- **Home**: a featured poster and Netflix-style rows: Top 50 right now, Continue watching, My list, New releases, New
  episodes, New movies, Top rated, then one row per genre (Action & adventure, Comedy, Horror, Sci-fi & fantasy,
  Thriller & crime, Drama, Animation, Japanese anime, Romance, Family, Documentaries).
  **Customize the home page** (Settings → Accueil): tick the rows to show and order them with the arrows. The big
  title at the top is the No. 1 of the current Top 50, unless you pick one yourself with the "☆ À l’affiche"
  (Feature it) button on its page (tap it again, or choose "Automatique" in the settings, to go back to the No. 1).
  Synced with your other devices and the iPhone app.
  A series counts as new when it had an **episode in the last 7 days** (new season or weekly episode), even if it
  started years ago; its poster shows the latest episode ("S3 E2 · 16 oct."). These are worldwide first-air dates: an
  episode aired in the United States is not necessarily on your platform in France yet. Talk shows, news, daily soaps
  and reality TV are left out.
  The **Top 50 right now** uses JustWatch's "popular" ranking in your country (what its users are looking at right
  now), updated every 6 hours and limited to your subscriptions: it is not an all-time ranking.
- **Movies** and **Series**: the same rows, for movies only or series only.
- **Anime**: Japanese animation (Animation genre with Japan as the country of origin), movies and series: Popular
  anime, New episodes, Animated series, Animated movies, Top rated, then Action & adventure, Sci-fi & fantasy, Comedy,
  Drama, Mystery and Family. The "Tout voir" (See all) link of the Japanese anime row on the home page opens this page.
- **Library**: the whole catalog as a grid, with filters (All / Movies / Series, platform, genre) and a sort order
  (Popular, Top rated, Newest). The "See all" link of each row opens the Library already filtered. The "Animés
  japonais" genre is offered alongside the others (also in the iPhone app).
- **My space**: your lists (My list, Likes, History, Downloads) and your platforms. Each title has a cross in its
  top-right corner to remove it (also in the My list and Continue watching rows of the home page).
- **Search** (same behavior on the site and in the iPhone app): type straight into the top bar; results appear from
  the first letter, without changing pages. By title, but also by nickname or acronym ("DNA" finds *Demain nous
  appartient*, thanks to a built-in list and Wikidata).
  - **Typos**: "hary poter" still shows the Harry Potter movies, with "Tu voulais dire « Harry Potter » ?" (Did you
    mean…?) to fix the search (your query is compared with about 28,000 popular titles).
  - **Movie number**: "harry potter 1" only gives the first movie of the saga (not *Deathly Hallows Part 1*, which is
    the 7th); "toy story 3" gives *Toy Story 3*. The number is the first number after the name, and what follows can
    name a part: "harry potter 7 partie 2" gives *Deathly Hallows Part 2*, "hunger games 3 partie 2" *Mockingjay
    Part 2* (movies released in several parts share one number: "harry potter 7" gives both parts of *Deathly
    Hallows*).
  - **Sagas in order**: movies from the same saga are grouped and sorted by release date (1, 2, 3).
  - **Only your subscriptions**: All / Movies / Series, platforms and genre, and only titles available on your
    subscriptions are shown; the others stay behind "N autres hors de tes abonnements — tout afficher" (N others
    outside your subscriptions — show all), or "Aucun titre trouvé… sur tes abonnements" (No title found… on your
    subscriptions) when none is.

By default, StreamHub only shows titles available on **your subscriptions**; a link lets you show the others too.

### A title's page

Tapping a poster opens its page: summary, release date (movies; only on the page, posters show the year) or years on
air (series), runtime or number of seasons, genres, trailer, and the **"Regarder sur…"** (Watch on…) buttons, in
three groups:

- **Dans tes abonnements** (In your subscriptions): the platforms you ticked in the settings.
- **Aussi disponible sur** (Also available on; a collapsed menu): the other platforms where the title is included
  (subscription, free, with ads). A channel sold on another platform is shown with that platform in parentheses:
  "HBO Max (Prime Video)", "HBO Max (Canal+)", "Apple TV (Canal+)", "Paramount+ (Canal+)". Canal+'s HBO Max, Apple TV
  and Paramount+ channels are not listed by TMDB or JustWatch: StreamHub offers them for every title available on
  those platforms (France) and opens the title's page on Canal+ (not the Canal VOD page, which is a paid rental),
  thanks to an index of each channel's catalog it publishes every 6 hours. A title missing from the index opens the
  channel's page on Canal+. On iPhone and iPad, the Canal+ app opens on the title.
- **Location et achat** (Rent and buy): the stores (Apple TV, Amazon Video…), collapsed by default.

Platforms come from TMDB, which uses JustWatch data. A new release can come out before JustWatch lists it in your
country (example: VisionQuest, released on Disney+ everywhere on the same day). StreamHub then completes the list,
with the note "Pas encore référencée dans ce pays par JustWatch" (Not yet listed in this country by JustWatch) under
the buttons:

- **from its network**: a series currently airing (or released less than 60 days ago) that is an original from
  Netflix, Disney+, Prime Video, Apple TV, HBO Max or Paramount+ is added on its platform if it has no offer yet in
  your country. This works without a key, also for posters, the "Mes plateformes" (My platforms) search filter and
  the home rows it belongs to (its genre, New releases, New episodes…).
- **from Streaming Availability** (with your key): platforms that Streaming Availability lists in your country but
  JustWatch does not are added when the page opens, with their direct link.

Under each button, a hint says what it will do:

| Hint | What happens |
|---|---|
| **Lecture directe** (Direct playback) | The video starts on the platform |
| **Reprise de la série** (Resume series) | The series resumes at the next episode, where you left off (or episode 1 if you never watched it) |
| **Épisode suivant : S1 E7** (Next episode) | The episode after the last one you watched from StreamHub (TF1+, M6+) |
| **Fiche du titre** (Title page) | The title's page opens on the platform (you still have to press Play) |
| **Page de la série** (Series page) | The series page opens (Disney+, TF1+), with its "Resume" or "Play" button |
| **Recherche sur la plateforme** (Search on the platform) | A search for the title opens on the platform |
| **Accueil de la plateforme** (Platform home) | The platform opens on its home page (no more precise link exists) |
| **Liens sur TMDB** (Links on TMDB) | TMDB's "Where to watch" page, which links to each platform |

For a **series**, the "Watch on…" button **resumes where you left off** (next episode), or starts at episode 1 if
you never watched it ([details](#resuming-a-series)).

Below the summary, the page has **tabs** (also in the iPhone app):

- **Épisodes** (Episodes; series, opened first): each season expands to show its episodes (summary, date, runtime),
  with a button to start the one you want directly when the platform allows it. When TMDB offers other season layouts
  (e.g. "TF1+" for *Demain nous appartient*: 10 seasons instead of 3), the "Découpage" (Season layout) menu lets you
  switch; the one named after a platform carrying the series is picked automatically. For **Naruto**, **Naruto
  Shippuden** and **Boruto**, the **"Netflix - Sans filler"** (no filler) layout is picked automatically (9 seasons
  for Naruto; 21 like Netflix for Shippuden and Boruto, with Netflix's season titles): filler episodes (according to
  animotaku.fr's list) are red with a "Filler" tag, and a season made only of fillers is entirely red. The
  "Découpage" menu lets you go back to TMDB's layout.
- **Suggestions** (opened first for a movie, its only tab): posters to open, in three rows:
  - **La saga** (The saga): the saga's other movies, in release order (the 7 other Harry Potter movies);
  - **Dans le même univers** (Same universe): movies and series from the same franchise, which TMDB does not link
    together. Examples: Naruto → Naruto Shippuden, Boruto and the Naruto movies; a Harry Potter movie → the Harry
    Potter series and Fantastic Beasts; Breaking Bad → Better Call Saul and El Camino. StreamHub finds them by the
    franchise name (same original language, a genre in common, and a production company in common when the name is
    not at the start of the title) and among TMDB's recommendations (two production companies in common and a
    sequel or spin-off);
  - **Dans le même genre** (Same genre): titles recommended by TMDB, those on your subscriptions first.

### Your lists

- **Ma liste** (My list): titles saved with "+ Ma liste" (on their page or on the home page poster).
- **J'aime** (Likes): titles liked with "♡ J'aime". For a series, the like covers the whole series.
- **Historique** (History): the last 30 titles watched from StreamHub, in a single row (most recent on the left). The
  cross in a poster's top-right corner removes that title; **Supprimer l'historique** (Clear history, with
  confirmation) empties the list. With an account, these removals also reach your other devices.
- **Téléchargements** (Downloads): a reminder of titles downloaded in the platforms' apps (see below).

A movie or episode started from StreamHub goes straight into the history, without asking. For a series, people often
watch several episodes in a row on the platform: when you come back to StreamHub (at least 3 minutes later), a single
window asks "Où en es-tu de *Naruto* ?" (Where are you in *Naruto*?) with the season and the last episode watched
(the episode you started is preselected); "Enregistrer" (Save) updates the history, "Ignorer" (Ignore) keeps the
episode you started. The same window offers "J'aime la série" (I like this series). A title you download goes
straight into Downloads, without a question when you come back.

### Liking on the platform

No platform lets another site like a title for you: StreamHub's like stays in StreamHub (since version 2.5.0 there is
no "Liker aussi sur…" (Also like on…) notification or "Tu as liké… ?" (Did you like…?) question any more, as in the
iPhone app).

### Downloading to watch offline

Only the platforms' mobile apps can download, and they cannot be told to do it remotely. The **"⬇ Télécharger"**
(Download) button therefore opens the title in the platform's app, where you press its download button, and records
it in Downloads (My space → Téléchargés on a phone) as a reminder. It only appears on iPhone, iPad and Android, and in
the iPhone app (version 2.4.0: a button under "Watch on…" for a movie, ⬇ next to each episode): on computers and TVs,
platforms do not allow downloads. The title enters the list as soon as you tap, without a question when you come back
(version 2.4.1). Tapping a downloaded title opens it in the platform's app; its cross removes it from the list (the
file stays in the platform's app).

### And also

- **StreamHub account** (optional): settings, keys and lists encrypted and synced across all your devices
  ([part 6](#6-your-account-and-sync)). Without an account, as a guest, everything stays on the device.
- **Glass effect**, inspired by Liquid Glass, for bars, buttons and windows, adjustable on each device.
- **Keyboard and remote navigation**: arrows, OK (Enter) and Back (Escape).
- **Offline**: the interface opens without a connection (the catalog itself needs the Internet).
- **Automatic updates**: each time you come back to StreamHub, the new version is installed and the page reloads
  (after the title page or settings are closed, if one is open).

---

## 2. Installing StreamHub on each device

StreamHub works straight in the browser, on any device. Installing it as an app (an icon on the home screen, in the
Dock or in the Start menu) is optional but handier: it opens in its own window, without an address bar.

### iPhone and iPad

1. Open **https://arthursavournin.github.io/streamhub/** in **Safari**.
2. Tap the **Share** button (the square with an arrow), then **"Add to Home Screen"**.
3. Leave **"Open as Web App"** on, then tap **Add**.
4. Open StreamHub from its new icon.

The home screen app has its own storage, separate from Safari: on first launch, sign in to your account (or paste
your keys). It is from this icon that the "Watch on…" buttons open the platforms' apps directly
([part 7](#on-iphone-and-ipad)). On iPhone and iPad, every browser app (Chrome, Firefox, Edge…) uses Safari's engine:
StreamHub behaves there as in Safari.

### Android

1. Open **https://arthursavournin.github.io/streamhub/** in **Chrome** (or Samsung Internet, Edge…).
2. Menu **⋮** → **"Install app"** (or "Add to Home screen").
3. Open StreamHub from its icon.

### Mac

- **Safari** (macOS Sonoma or later): open the address, then **File → Add to Dock**. StreamHub appears in the Dock and
  Launchpad like an app.
- **Chrome**: menu **⋮ → Cast, save and share → Install page as app** (or **Install StreamHub…** if it appears), or
  the install icon on the right of the address bar.
- **Edge**: menu **… → Apps → Install this site as an app**.
- **Firefox**: usually no app installation; add StreamHub to your bookmarks.

### Windows

- **Edge** (comes with Windows): menu **… → Apps → Install this site as an app**. StreamHub appears in the Start menu;
  you can pin it to the taskbar.
- **Chrome**: menu **⋮ → Cast, save and share → Install page as app** (or **Install StreamHub…** if it appears).
- **Firefox**: usually no app installation; add StreamHub to your bookmarks or pin the tab.

### Linux

With **Chrome**, **Chromium**, **Brave** or **Edge**, as on Windows. With **Firefox**, add StreamHub to your
bookmarks.

### TV

🚧 **In development.** In the meantime, StreamHub can open in a smart TV's browser (Samsung, LG, Android TV…): the
interface can already be driven with the remote's arrows, OK and Back. Ideas for a real TV app:

- **Android TV / Google TV**: wrap the web app in an Android app (Bubblewrap/TWA or Capacitor); links would open the
  platforms' TV apps.
- **Samsung (Tizen) / LG (webOS)**: these are web-based TVs, the app can be packaged almost as is.
- **Apple TV**: no browser, a native tvOS app would be needed.

---

## 3. First launch

1. Open StreamHub: on first launch, only the sign-in page is shown.
2. **Sign in or create an account** (email and password, Google or GitHub): if you already use StreamHub elsewhere,
   your keys, subscriptions and lists come back, and you are done. You can also choose **Continuer sans compte**
   (Continue without an account, as a guest): everything then stays on this device
   ([part 6](#6-your-account-and-sync)).
3. Otherwise, StreamHub asks for your **TMDB key** ([part 4](#4-api-keys)). It is the only required key.
4. Tick your **subscriptions** in "Mes abonnements" (My subscriptions).
5. Tap **Enregistrer** (Save).

Optional but recommended: a **Streaming Availability** key for links that start the video or episode directly, and,
on a computer, the **"resume after sign-in" script** ([part 8](#8-the-resume-after-sign-in-script)).

**Sharing StreamHub with family and friends**: just send them the address. Each person pastes **their own keys**,
ticks their subscriptions and, if they want, creates **their own account**. Everyone's data is encrypted with their
own key: nobody sees anyone else's keys, subscriptions or lists.

---

## 4. API keys

StreamHub has no server storing your data: it queries public services directly with **your** keys. They are managed
in **Settings → Clés API** (API keys), with a **Tester** (Test) button for each.

| Key | Required? | What it is for |
|---|---|---|
| **TMDB** | Yes (free) | Movie and series catalog, title pages, platforms available per country |
| **Streaming Availability** | No (free plan) | Direct links that start the video, series or episode |

### Getting the TMDB key (free)

1. Create an account on **https://www.themoviedb.org**.
2. Go to your profile → **Settings** → **API** (https://www.themoviedb.org/settings/api).
3. Request an API key for personal use by filling in the short form.
4. Copy the **API Key (v3)** or the **API Read Access Token (v4)**: both work.
5. Paste it into StreamHub → Settings → Clés API → **Clé API TMDB**, then tap **Tester**.

### Getting the Streaming Availability key (optional, free)

1. Create an account on **https://rapidapi.com**.
2. Look for the **"Streaming Availability"** API and subscribe to the **Basic** (free) plan.
3. Copy your key (**X-RapidAPI-Key**), shown in the API's test tab.
4. Paste it into StreamHub → Settings → Clés API → **Clé Streaming Availability**, then tap **Tester**.

The free plan limits the number of requests per day: StreamHub only makes a request when a title page opens and keeps
each answer for **3 days**. Without this key, StreamHub uses JustWatch links (through the relay), or else a search for
the title on the platform.

**Your keys are never published**: they are not in the code, they stay in your browser, or in the iPhone keychain for
the app (and, encrypted, in your account), and are only sent to TMDB and RapidAPI.

---

## 5. Settings

The gear at the top right opens the settings page: the sections in the left sidebar (Account first), the content of
the chosen section on the right. On a phone: the list of sections, then the section you tap. The iPhone app has the
same sections, in the same order and with the same design. **Enregistrer** (Save, at the top) keeps your changes;
account actions apply immediately.

| Section | Content |
|---|---|
| **Compte** (Account) | Create an account, sign in (email, Google, GitHub), forgot password, change password, recovery key, sign out, delete the account. As a guest: the sign-in page, with the Google and GitHub buttons. |
| **Mes abonnements** (My subscriptions) | The platforms you subscribe to, with a field to filter the list. Ticking Prime Video also ticks the channels included with Prime. Paid add-ons sold on another platform are "channels" ticked separately, e.g. **HBO Max Amazon Channel** (HBO Max on Prime Video) or Canal+'s channels (France) **HBO Max Canal+ Channel**, **Apple TV Canal+ Channel** and **Paramount Plus Canal+ Channel**, to watch those catalogs on Canal+. Ticking **Canal+ Ciné Séries** also ticks the bundle's platforms: Canal+, Canal+ Séries, Netflix and Canal+'s HBO Max, Apple TV and Paramount+ channels; Ciné+ OCS is listed under Canal+. Netflix remains a separate account (activated from your Canal+ space) and opens in the Netflix app. |
| **Clés API** (API keys) | TMDB key, Streaming Availability key, with a Test button for each. (The StreamHub relay, for JustWatch links, has no setting: its address is fixed since version 2.3.4.) |
| **Accueil** (Home) | Rows shown on the home page, their order, and the featured title. |
| **Apparence** (Appearance) | Glass effect: Automatic, Transparent or Tinted (per device). |
| **Pays et lecture** (Country and playback) | Catalog country (France, Belgium, Switzerland, Luxembourg, Canada, United Kingdom, United States, Germany, Spain, Italy) and, on a computer, **Ouvrir les titres** (Open titles). |
| **À propos** (About) | Version, legal notice, privacy policy, terms of use, source code. |

### Open titles (computer)

A per-device setting:

- **Sur le site internet** (On the website): titles open in a browser tab.
- **Dans l'appli de l'ordinateur** (In the computer's app): Prime Video titles open in the **Prime Video** app
  installed on the Mac or PC, and playback starts. Other platforms have no Mac app; on Windows, their apps are not
  supported yet. The browser may ask for permission to open the app the first time.

### Glass effect

A web page cannot read the Liquid Glass setting of iOS or macOS. In **Automatic** mode, StreamHub follows "Increase
contrast" (and "Reduce transparency" in Chrome and Edge); otherwise, choose **Transparent** or **Tinted** yourself.

---

## 6. Your account and sync

Each browser keeps its own data: without an account, StreamHub opened in Chrome knows neither the keys nor the lists
saved in Safari, and the iPhone home screen app does not know those of Safari. A **StreamHub account** (free,
optional) keeps them everywhere. Without an account you stay a **guest**: everything stays on the device, nothing is
sent.

### Creating an account or signing in

**Settings → Compte**, then either:

- **With your email**: **Créer un compte** (Create an account) tab, address and password (at least 12 characters),
  then open the link received by email (check your spam folder too). On your other devices: **Se connecter** (Sign in)
  with the same address and password.
- **With Google or GitHub** (buttons shown when enabled): on the first sign-in, StreamHub asks you to choose a **vault
  password**. It encrypts your data; it is specific to StreamHub and unrelated to your Google or GitHub account. You
  type it once on each new device.

When the account is created, StreamHub shows your **recovery key** (20 characters, for example
`ABCD-EFGH-JKLM-NPQR-STUV`): save it in your password manager. It is the only way to recover your data if you forget
your password. **Nouvelle clé de secours** (New recovery key) creates another one (the old one stops working):
StreamHub then asks for your password (or vault password) again.

A new password (sign-up, change, forgotten, vault password) must be **at least 12 characters** long and must not
appear in known data breaches. This check runs on your device, before anything is sent, against the Have I Been Pwned
service: only the first 5 characters of a hash of the password are sent, never the password. A password chosen before
version 2.3.4 still works.

In the iPhone app: **Settings → Compte**, with the same account (email and password, Google or GitHub: Apple's sign-in
window opens, then returns to the app). Links in emails (confirmation, forgotten password) open on the site: after
confirming, come back to the app and tap **J'ai confirmé mon adresse** (I've confirmed my address).

After that, each change is sent automatically a few seconds later and reaches the other devices when they open or
when you come back to StreamHub. If two devices are changed at the same time, the lists are merged: nothing is lost.
A title removed from a list (or a cleared history) on one device does not come back from another, unless it is added
or watched again there after the removal.

- **Synced**: keys, country, subscriptions, home page, My list, Likes, history, likes on platforms.
- **Per device**: downloads (they live on the device), pending questions, glass effect, "Open titles" setting.
- **Always kept on the device too**: StreamHub works offline, and nothing is erased when you sign out.

### Forgotten password, changing your password, deleting the account

- **Mot de passe oublié ?** (Forgot password?, under **Se connecter**): an email sends you a link; it opens
  StreamHub, where you choose a new password and enter your **recovery key**. Forgot your vault password (Google,
  GitHub)? Same thing, with **Mot de passe du coffre oublié ?** once signed in.
- **"Ce lien est-il pour toi ?"** (Is this link for you?): an email link (confirmation, forgotten password) opened on
  a different device or browser than the one that requested it first shows the account's address. Only continue if
  it is yours: a booby-trapped link cannot silently sign you in to someone else's account.
- **Changer de mot de passe** (Change password): the current one, then the new one. Other devices are signed out
  (within an hour at most): sign them in again with the new password, their data stays.
- **Se déconnecter** (Sign out): the data stays on this device, it simply no longer syncs.
- **Supprimer mon compte** (Delete my account): StreamHub asks for your password (or vault password) again, then
  erases your account, your vault and your synced data. What is on the device stays.

### End-to-end encryption

Accounts are handled by **Supabase** (a database host). Your data is **encrypted in your browser** (AES-256-GCM)
before being sent, with a randomly generated **vault key**. That key is itself stored twice, locked: by a key derived
from your password (PBKDF2, 600,000 iterations) and by a key derived from your recovery key. Your real password never
leaves the device: Supabase receives another secret derived from it. Supabase therefore only sees your email address,
unreadable data, its size and the date of the last change: neither it nor anyone else can read your keys or lists
without your password or recovery key. That is also why a forgotten password **without** a recovery key loses the
synced data (data still on a device stays, and goes into a new account).

On each device, the vault key is kept by the browser in a **non-extractable** form (IndexedDB): StreamHub can use it,
but nobody can copy it, not even code that might have slipped into the page (version 2.3.4; in the iPhone app: Apple's
keychain). The page can also only contact the servers StreamHub needs (security rules, "Content-Security-Policy", in
`index.html`).

### Before accounts: the sync code

Up to version 2.0.0, sync used a **20-character code**. It no longer exists since version 2.1.0: it is an account or
nothing (guest). Nothing is lost: each device kept its data. Create your account on one of them, then sign in on the
others: their lists are merged into the account.

---

## 7. How StreamHub opens titles

No platform provides a player another site can use, and videos are protected (DRM): only their apps and official
sites can play them. StreamHub therefore opens the title **on the platform**, with the most precise link possible:

1. **Streaming Availability** (with your key): a direct link to the video, series or episode.
2. Otherwise **JustWatch** (through the StreamHub relay): a link to the title or to playback.
3. Otherwise a **search** for the title on the platform, or its home page.

The first two sources are queried at the same time when a title page opens. If you click "Watch on…" before they
answer, StreamHub waits for the right link (4 seconds at most) instead of opening the search.

For safety, only web links (`https://`, `http://`) received from these services are kept: an address of another type
(`javascript:`…) is ignored and never opened (version 2.3.3, site and iPhone app).

### Resuming a series

For a series, "Watch on…" starts the **next episode**, where you left off, or episode 1 if you never watched it.
StreamHub cannot read your progress on the platforms (they have no public API, and your progress is behind your
sign-in): it sends them the link they know how to resume themselves.

| Platform | How the series resumes |
|---|---|
| **Netflix** | Link to the series (not to episode 1): Netflix starts the next episode |
| **Prime Video** | Playback link for the series: Prime Video resumes where you left off (site and app) |
| **Canal+** | Series page with autoplay: Canal+ triggers its "Reprendre" (Resume) button |
| **Disney+** | Series page, which shows "Reprendre S1 E7" (or "Lecture"); on a computer, the [script](#8-the-resume-after-sign-in-script) presses it for you, on iPhone and iPad one tap remains |
| **TF1+**, **M6+** | No resuming by link: StreamHub starts the episode after the last one you watched **from StreamHub** (each episode started is recorded there), thanks to its episode index |

### On a computer

Each platform opens in its own tab (a single Netflix tab, a single Canal+ tab…).

| Platform | What happens |
|---|---|
| **Netflix**, **Disney+** | The title page or playback, depending on the available link |
| **Prime Video** | Playback starts, on the site or in the Prime Video app depending on the "Open titles" setting |
| **Canal+** | The title page opens and starts playback (muted at first) |
| **TF1+**, **M6+** | The video or the program page; for episodes, StreamHub finds their link thanks to its index ([part 11](#publishing-and-indexes-tf1-m6-canal-channels-top-titles)) |
| **Others** | The title page, a search, or the platform's home page |

A site that is not a known platform's (a less common platform's link, TMDB…) opens in a tab independent from
StreamHub: it cannot change the StreamHub tab.

If the platform asks you to sign in or choose a profile, it often forgets the requested title: the **"resume after
sign-in" script** reopens it automatically ([part 8](#8-the-resume-after-sign-in-script)). Without it, a
**"▶ Relancer"** (Relaunch) bar lets you reopen it in one click once signed in.

### On iPhone and iPad

From the home screen app, "Watch on…" opens **the platform's app directly** if it is installed, otherwise its site on
the right page. StreamHub uses the addresses each platform has declared to Apple for its app:

- **Netflix**, **Prime Video**, **Disney+** and **Canal+** open their app on the title.
- **M6+** episodes open in the M6+ app (falling back to the site if it is not installed).
- The **TF1+** and **M6+** apps sometimes only open their home page or the program page.

Tip: a long press on a "Watch on…" button shows the address and, when iOS recognizes it, offers "Open in *the app*".

### On Android

The buttons open the platform's app when it is installed, otherwise its site.

---

## 8. The "resume after sign-in" script

When you start a title from StreamHub and the platform first asks you to sign in or choose your profile (PIN code
included), it then sends you to its home page and forgets the title. This small script remembers it: once you are
signed in and the profile is chosen, it opens the requested title. It is mostly useful **on a computer**.

It also does three more things:
- it reopens the title once when M6+ shows its home page, or TF1+ the program page, instead of the video;
- on the Prime Video site, if playback was requested but the title page stays on screen, it presses "Reprendre" or
  "Lecture" once;
- on Disney+, when you start a series, it presses "Reprendre" (or "Lecture") on the series page: the series resumes
  at the next episode.

It only runs on StreamHub and on the platforms' sites and their sign-in pages (since version 3.2; before, on every
site). It only acts during a flow started from StreamHub (less than 15 minutes, a link to the platform of the open
site), sends nothing over the Internet, and only keeps, in your browser, the address of the title you started. Once
installed, the line "Script… installé" (Script… installed) appears in Settings → Pays et lecture, and the "Relaunch"
bar is no longer shown.

| Browser | Installation |
|---|---|
| **Safari** (Mac, iPhone, iPad) | Free **Userscripts** app (App Store), enabled in Safari's extensions, then open the script |
| **Chrome, Edge, Brave, Opera** (Windows, Mac, Linux) | **Violentmonkey** or **Tampermonkey** extension, then open the script; or the extension in the `extension/` folder |
| **Firefox** (Windows, Mac, Linux) | **Violentmonkey** or **Tampermonkey** add-on, then open the script |

Script address: **https://arthursavournin.github.io/streamhub/streamhub-reprise.user.js** (it then updates itself).
In Chrome and Edge, you may need to turn on **"Allow user scripts"** in the Violentmonkey or Tampermonkey extension
details.

The full step-by-step guide for each browser is in **[extension/README.md](extension/README.md)** (in French).

---

## 9. Your data and privacy

The details are in the **[privacy policy](https://arthursavournin.github.io/streamhub/confidentialite.html)** (also:
[legal notice](https://arthursavournin.github.io/streamhub/mentions-legales.html) and
[terms of use](https://arthursavournin.github.io/streamhub/conditions.html), linked at the bottom of the settings;
these pages are in French).

- **Optional account**: as a guest, everything is stored in your browser (localStorage). With an account, an
  **end-to-end encrypted** copy is kept at Supabase ([part 6](#end-to-end-encryption)).
- **What leaves your device**: searches and title pages requested from TMDB and Streaming Availability (with your
  keys), link requests to the relay (TMDB identifier and title of the movie or series), when you choose a password the
  first 5 characters of its hash (Have I Been Pwned, [part 6](#creating-an-account-or-signing-in)) and, with an
  account, your email address and your synced data, encrypted before sending.
- **No ads, no tracking, no analytics.**
- **Restarting or closing the browser loses nothing.** A browser's data is lost if you clear site data, in private
  browsing, and in Safari if StreamHub is not opened during 7 days of Safari use (Apple's anti-tracking protection; the
  home screen app is not affected). In every case, your account puts everything back: just sign in again.

---

## 10. Troubleshooting

**I don't have the latest version.**
The version is shown at the bottom of the settings. StreamHub updates itself when you come back to it: if it finds a
new version, the page reloads, after the settings or title page are closed if one is open. Otherwise, reload the page
(⌘R on Mac, Ctrl+R or F5 on Windows and Linux). On iPhone, fully close the home screen app (swipe it up in the app
switcher), then reopen it.

**"Clé TMDB invalide" (Invalid TMDB key), or no title shows up.**
Check the key in Settings → Clés API with the Test button. Both v3 keys (32 characters) and v4 tokens (long, starting
with `eyJ`) work.

**The button opens the title page instead of starting the video.**
It depends on the available link (see the hint under the button). A Streaming Availability key more often gives
"Lecture directe". TF1+ and M6+ do not always allow starting a video from a link.

**The platform asks me to sign in, then stays on its home page.**
Install the "resume after sign-in" script, or use the "▶ Relancer" bar once signed in.

**On iPhone, the platform's site opens instead of its app.**
Open StreamHub from its home screen icon (not in Safari), and check that the platform's app is installed. If iOS was
set to open this site in Safari, long-press the button and choose "Open in *the app*": iOS will remember it.

**On a computer, Prime Video opens in the app when I want the site (or the other way round).**
Choose in Settings → Pays et lecture → Ouvrir les titres.

**"… n'est disponible sur aucune plateforme de streaming dans ce pays" (… is not available on any streaming platform
in this country), although the title is out.**
JustWatch has not listed it in your country yet. StreamHub fills it in automatically for the big platforms' series and
with a Streaming Availability key (see [A title's page](#a-titles-page)); otherwise it will appear once JustWatch adds
it, usually within a few days.

**A title is shown with an English title.**
TMDB has no French title for it yet. When its original title is written in another script (Hindi, Korean,
Japanese…), StreamHub shows the title, summary and poster of the English version, often the ones the platform uses in
France (example: "Reporting Live" on Netflix). An original title in the Latin alphabet (Spanish, Italian…) is kept as
is.

**"Quota Streaming Availability atteint" (Streaming Availability quota reached).**
The free plan is limited per day: StreamHub uses JustWatch links until the next day.

**My lists are gone.**
The browser's data was cleared ([part 9](#9-your-data-and-privacy)): sign in to your account again.

**I don't receive the confirmation or forgotten-password email.**
Check your spam folder, wait a few minutes (the number of emails per hour is limited), then **Renvoyer l'e-mail**
(Resend the email). The link only works once and expires after an hour.

**"Mot de passe trop court" (Password too short) or "figure dans des fuites de données connues" (appears in known data
breaches).**
A new password must be at least 12 characters long and must never have leaked elsewhere: a phrase of a few words, or
a password generated by your password manager, will do.

**"Ce lien est-il pour toi ?" (Is this link for you?)**
The email link was opened somewhere other than where it was requested. Check the address shown: if it is yours,
continue; otherwise, ignore the link.

**"Connexion commencée dans un autre navigateur" (Sign-in started in another browser).**
Google / GitHub sign-in must finish in the browser where it started: start again from that one.

**Still stuck?**
Open an issue on GitHub: **[Issues → New issue](https://github.com/arthursavournin/streamhub/issues/new)**, with your
device, browser and StreamHub version.

---

## 11. For developers

### Principle

No framework and no build step: HTML, CSS and JavaScript modules served as is. The site is published on **GitHub
Pages**, a small **Cloudflare Workers relay** provides the JustWatch links, and **Supabase** handles accounts (Auth and
two tables, end-to-end encrypted).

### Running StreamHub on your computer

All you need is a local web server in the project folder. Python comes preinstalled on Mac and most Linux
distributions; on Windows, install it from https://www.python.org or the Microsoft Store.

- **Mac**: double-click `lancer.command` (the first time: right-click → Open), or in Terminal:
  ```bash
  cd streamhub
  python3 -m http.server 8080
  ```
- **Windows** (PowerShell or Command Prompt):
  ```powershell
  cd streamhub
  py -m http.server 8080
  ```
- **Linux**:
  ```bash
  cd streamhub
  python3 -m http.server 8080
  ```

Then open **http://localhost:8080**. The relay accepts calls coming from `localhost:8080`.

### Code layout

| File | Role |
|---|---|
| `index.html`, `styles.css` | Interface structure and styles (glass effect at the end of `styles.css`) |
| `app.js` | The whole interface: pages, title pages, seasons, launching on platforms, lists, settings |
| `api.js` | TMDB, Streaming Availability and relay calls; key tests |
| `providers.js` | Platforms, fallback links, link shape per device (iPhone, computer app, site) |
| `library.js` | My list, Likes, history, downloads, questions on return |
| `store.js` | Settings, library and cache in the browser |
| `sync.js` | Encrypted sync between devices through the account: encryption, merging, conditional upload |
| `account.js` | Supabase accounts (Auth and database, direct HTTP calls): sign-up, sign-in, vault, recovery key |
| `account-ui.js` | Settings → Account |
| `supabase/schema.sql` | `vaults` and `sync_data` tables, access rules (one row each), `delete_my_account`, `keepalive`, closed default privileges for future objects |
| `mentions-legales.html`, `confidentialite.html`, `conditions.html`, `legal.css` | Legal pages (French law LCEN, GDPR, terms of use required by Google for sign-in) |
| `supabase/menage.sql` | Daily cleanup (pg_cron): retention periods stated in the policy |
| `supabase/templates/` | Emails in French (confirmation, forgotten password), to paste into Supabase: Authentication → Emails → Templates |
| `episodes.js` | Direct links to TF1+ and M6+ episodes (index published in `data/`) |
| `aliases.js` | Search by nickname or acronym (built-in list + Wikidata) |
| `search.js` | Typo correction, movie number, saga order |
| `suggestions.js` | The title page's Suggestions tab: saga, same universe (movies and series), same genre |
| `nav.js` | Arrow navigation (keyboard, remote) |
| `sw.js`, `manifest.webmanifest`, icons | App installation (PWA), offline cache and updates |
| `relay/worker.js` | Cloudflare Workers relay (JustWatch links) |
| `extension/` | "Resume after sign-in" script and Chrome extension |
| `scripts/` | TF1+ / M6+ episode indexes, relay publishing |

### Publishing and indexes (TF1+, M6+, Canal+ channels, top titles)

The site is published by `.github/workflows/pages.yml` on every change to the `main` branch and **every 6 hours**. On
each publication, `scripts/build_episode_index.py` reads the public sitemaps of TF1+ and M6+ and writes
`data/<platform>/<program>.json` (episode number, season-episode and date → episode link): these platforms' episode
links contain an internal identifier that cannot be guessed.

The same script writes `data/canal/hbo.json`, `appletv.json` and `paramount.json`: the catalog of each Canal+ channel
(simplified title → page address, movies and series separately), read from the grids of its page on Canal+. On
Canal+, a title's page on a channel has an address unrelated to its Canal VOD page, and Canal+ does not let other
sites use its search.

It also writes `data/search/titles.json`: about 28,000 popular titles (TMDB's public daily exports and JustWatch's
French titles), which search compares your query with to suggest a correction.

Finally it writes `data/top/<country>.json`: JustWatch's "popular" ranking (about 500 subscription or free streaming
titles, with their platforms) for each country in the settings. The Top 50 right now keeps its first titles available
on your subscriptions.

GitHub pauses scheduled jobs in a repository with no commit for 60 days: the workflow re-enables it on every run so
that the index keeps updating.

The workflow's actions are pinned by commit hash (version in a comment), and only the publishing job (`deploy`) may
write to GitHub Pages. The `main` branch is protected ("Protéger main" rule: no deletion, no history rewrite).

### Version

The version number is in `app.js` (`APP_VERSION`) and `sw.js` (`SHELL_CACHE`): both change together on each
publication, which triggers the update for users. Numbering: 1.0.1, 1.0.2… for a fix, 1.1.0 for a new feature. The
"resume after sign-in" script has its own number (`@version` and `extension/manifest.json`), which must never go down:
script managers only update to a higher number.

### The relay (Cloudflare Workers)

`relay/worker.js` is published at https://streamhub-relay.arthursavournin.workers.dev (Cloudflare free plan: 100,000
requests per day). It provides **JustWatch links** (`/offers`): JustWatch refuses calls coming from other sites, so the
relay queries it instead of the browser. Only answers that found something are kept for 6 hours (a wrong title cannot
hide a movie's links). It limits each IP address to 30 JustWatch questions per minute (`LIMITER` binding, Cloudflare
rate limiting). It stores nothing (its former `/sync/<id>` route, for the sync code used before version 2.1.0, was
removed in version 2.3.3, along with its Workers KV namespace).

It only accepts calls coming from StreamHub's address and from `localhost:8080`. A copy of StreamHub published
elsewhere must publish its own relay with its own Cloudflare account, then put its address in `store.js`
(`DEFAULT_RELAY`), in `index.html`'s Content-Security-Policy and in the app (`Store.swift`, `defaultRelay`).

To publish it, you need a Cloudflare token ("Edit Cloudflare Workers" permission) and the account ID. None of this is
saved in the project.

- **Mac, Linux**:
  ```bash
  CF_API_TOKEN=… CF_ACCOUNT_ID=… scripts/deploy_relay.sh
  ```
- **Windows** (with Git Bash, installed with Git for Windows, or WSL):
  ```bash
  CF_API_TOKEN=… CF_ACCOUNT_ID=… bash scripts/deploy_relay.sh
  ```

### Security

Outcome of the October 2026 security audit, to keep in mind when changing the code:

- **Links**: any address coming from a service goes through `webLink` / `safeLink` (`providers.js`); a click on a link
  of another type (`javascript:`…) is blocked in `app.js`. Sites outside known platforms (`isPlatformLink`) open with
  `noopener`.
- **Text and attributes**: everything coming from a service goes through `esc` before `innerHTML`; image paths go
  through `img` (`api.js`), which rejects anything that is not a TMDB image or a StreamHub logo.
- **Content-Security-Policy** (`<meta>` in `index.html`): a new server called by the site must be added there.
- **Keys**: the vault key is a non-extractable `CryptoKey` in IndexedDB; in the app, session, vault key and API keys
  are in the keychain.
- **Database**: every new table gets RLS and explicit privileges (nothing is open by default).

### Hosting

GitHub Pages is free, served over HTTPS, and more than enough (static files, 100 GB of traffic per month) as long as
the repository is public. To stop depending on the host, the best improvement would be a **domain name** (around ten
euros a year) pointed at GitHub Pages or Cloudflare Pages: the address would never change again. Changing the address
makes browsers start from scratch (storage is per address), but the account restores everything (add the new address
to Supabase's allowed URLs: Authentication → URL Configuration).

### Compatibility

Designed first for Safari (Mac, iPhone, iPad), StreamHub also works in Chrome, Edge and Firefox, on Mac, Windows and
Linux. A few tweaks only apply to those browsers (for example thin scrollbars on Windows), never to Safari: `app.js`
sets the `data-engine` attribute on the page for Chrome, Edge and Firefox, and the matching rules are at the end of
`styles.css`.
