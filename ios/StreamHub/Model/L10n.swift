import Foundation

// Langue de l'interface (version 2.9.0, comme le site 2.7.0) : français (langue du code) ou anglais.
// Le français reste écrit dans le code ; chaque texte affiché passe par loc(), qui rend sa traduction anglaise quand
// l'anglais est choisi (Réglages → Pays, langue et lecture). Textes entiers dans `en`, phrases à trous (nombre, titre,
// plateforme) dans `patterns` ; un texte « a · b · c » sans traduction entière est traduit morceau par morceau.
// Tout nouveau texte affiché par l'appli doit être ajouté ici. Réglage propre à l'appareil (settings.uiLang).
nonisolated enum L10n {
    nonisolated(unsafe) static var english = false

    static var locale: Locale { Locale(identifier: english ? "en_GB" : "fr_FR") }
    static var tmdbLanguage: String? { english ? "en-US" : nil }

    static func translate(_ text: String) -> String {
        guard english else { return text }
        let key = text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        guard !key.isEmpty else { return text }
        return core(key) ?? text
    }

    private static func core(_ text: String) -> String? {
        if let exact = en[text] { return exact }
        for (pattern, make) in patterns {
            if let m = pattern.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)), m.range.length == (text as NSString).length {
                let groups = (1..<m.numberOfRanges).map { i -> String in
                    let r = m.range(at: i)
                    return r.location == NSNotFound ? "" : (text as NSString).substring(with: r)
                }
                return make(groups)
            }
        }
        if text.contains(" · ") {
            var changed = false
            let parts = text.components(separatedBy: " · ").map { part -> String in
                if let t = core(part.trimmingCharacters(in: .whitespaces)) { changed = true; return t }
                return part
            }
            if changed { return parts.joined(separator: " · ") }
        }
        return nil
    }

    private static func n(_ count: String, _ one: String, _ many: String) -> String {
        "\(count) \((Int(count) ?? 0) > 1 ? many : one)"
    }

    private static let en: [String: String] = [
        // Navigation, barre du haut
        "Accueil": "Home", "Bibliothèque": "Library", "Mon espace": "My space", "Rechercher": "Search",
        "Effacer la recherche": "Clear search", "Réglages": "Settings", "Tout": "All", "Films": "Movies", "Séries": "Series",
        "Animés": "Anime", "OK": "OK", "Fermer": "Close", "Type": "Type", "Liste": "List",
        // Listes
        "Ma liste": "My list", "J’aime": "Likes", "Historique": "History", "Téléchargements": "Downloads", "Téléchargés": "Downloads",
        "Ma liste est vide": "My list is empty", "Aucun J’aime": "No likes", "Aucun titre regardé": "Nothing watched yet",
        "Aucun téléchargement": "No downloads",
        "Ajoute des titres avec « + Ma liste » sur leur fiche.": "Add titles with “+ My list” on their page.",
        "Les titres que tu aimes apparaîtront ici.": "Titles you like will show up here.",
        "Les titres lancés depuis StreamHub apparaîtront ici.": "Titles started from StreamHub will show up here.",
        "Dans la fiche d’un film ou d’un épisode, touche « Télécharger » : StreamHub le note ici et ouvre l’appli de la plateforme pour lancer le téléchargement.":
            "On a movie or episode page, tap “Download”: StreamHub notes it here and opens the platform’s app to start the download.",
        "Voir la fiche": "See the title page", "Supprimer l’historique": "Clear history", "Supprimer l’historique ?": "Clear history?",
        "Supprimer": "Clear", "Annuler": "Cancel",
        "Tous les titres regardés seront retirés, sur tous tes appareils.": "All watched titles will be removed, on all your devices.",
        "Retirer de Ma liste": "Remove from My list", "Ajouter à Ma liste": "Add to My list",
        // Accueil et rangées
        "Top 50 du moment": "Top 50 right now", "Reprendre": "Continue watching", "Nouveautés": "New releases",
        "Nouveaux épisodes": "New episodes", "Nouveaux films": "New movies", "Les mieux notés": "Top rated", "Les mieux notées": "Top rated",
        "Action & aventure": "Action & adventure", "Action & Aventure": "Action & adventure", "Action": "Action", "Aventure": "Adventure",
        "Comédie": "Comedy", "Horreur": "Horror", "Science-fiction & fantastique": "Sci-fi & fantasy",
        "Science-Fiction & Fantastique": "Sci-fi & fantasy", "Science-Fiction": "Science fiction", "Thriller & policier": "Thriller & crime",
        "Thriller": "Thriller", "Crime": "Crime", "Drame": "Drama", "Animation": "Animation", "Animés japonais": "Japanese anime",
        "Romance": "Romance", "Famille": "Family", "Familial": "Family", "Documentaires": "Documentaries", "Documentaire": "Documentary",
        "Mystère": "Mystery", "Téléréalité": "Reality TV", "Films populaires": "Popular movies", "Séries populaires": "Popular series",
        "Animés populaires": "Popular anime", "Séries animées": "Animated series", "Films d’animation": "Animated movies",
        "Tout voir ›": "See all ›", "Voir": "Watch", "Impossible de charger l’accueil": "Couldn’t load the home page",
        "Série": "Series", "Film": "Movie", "à l’affiche": "featured", "n° 1 du moment": "No. 1 right now", "à la une": "featured",
        // Bibliothèque, recherche
        "Populaires": "Popular", "Mieux notés": "Top rated", "Plus récents": "Newest", "Plateformes": "Platforms",
        "Mes plateformes": "My platforms", "Toutes les plateformes": "All platforms", "Plateforme": "Platform", "Genre": "Genre",
        "Tous les genres": "All genres", "Tri": "Sort", "Catalogue indisponible": "Catalog unavailable", "Aucun titre": "No titles",
        "Rien ne correspond à ces filtres.": "Nothing matches these filters.", "Recherche impossible": "Search failed",
        "Aucun résultat": "No results", "Essaie un autre titre.": "Try another title.", "Seulement mes abonnements": "Only my subscriptions",
        // Fiche
        "Fiche indisponible": "Title page unavailable", "SÉRIE": "SERIES", "FILM": "MOVIE", "en cours": "ongoing",
        "À l’affiche": "Featured", "Bande-annonce": "Trailer", "Dans tes abonnements": "In your subscriptions",
        "Disponible sur": "Available on", "Télécharger": "Download", "Téléchargé": "Downloaded", "Création": "Created by",
        "Réalisation": "Directed by", "Avec": "Starring", "Épisodes": "Episodes", "Suggestions": "Suggestions", "La saga": "The saga",
        "Dans le même univers": "Same universe", "Dans le même genre": "Same genre",
        "Pas de suggestion pour ce titre.": "No suggestions for this title.", "Recherche des suggestions…": "Looking for suggestions…",
        "Recherche du lien…": "Looking for the link…", "Abonnement": "Subscription", "Gratuit": "Free", "Gratuit avec pub": "Free with ads",
        "Location": "Rent", "Achat": "Buy", "Lecture directe": "Direct playback", "Fiche du titre": "Title page",
        "Page de la série": "Series page", "Recherche sur la plateforme": "Search on the platform",
        "Accueil de la plateforme": "Platform home", "Liens sur TMDB": "Links on TMDB", "Reprise de la série": "Resume series",
        "Prime Video avec pub": "Prime Video with ads", "Netflix avec pub": "Netflix with ads",
        // Saisons
        "Épisodes spéciaux": "Specials", "Découpage": "Season layout", "Découpage TMDB": "TMDB layout",
        "Netflix - Sans filler": "Netflix - No filler", "Que des fillers dans cette saison": "Fillers only in this season",
        "Pas encore d’épisodes annoncés.": "No episodes announced yet.", "Dernier vu": "Last watched", "Filler": "Filler",
        "Pas encore de résumé en français.": "No summary yet.", "Pas disponible en streaming par abonnement": "Not available on subscription streaming",
        "Recherche des liens…": "Looking for links…",
        // « Où en es-tu ? »
        "Dernier épisode regardé": "Last episode watched", "Saison": "Season", "Épisode": "Episode", "Enregistrer": "Save",
        "Ignorer": "Ignore", "Tu aimes la série": "You like this series", "J’aime la série": "I like this series",
        // Réglages
        "Compte": "Account", "Mes abonnements": "My subscriptions", "Clés API": "API keys", "Pays, langue et lecture": "Country, language and playback",
        "À propos": "About", "Tes réglages et tes listes sur tous tes appareils, chiffrés de bout en bout.": "Your settings and lists on all your devices, end-to-end encrypted.",
        "Les clés qui donnent le catalogue et les liens directs vers les vidéos.": "The keys that provide the catalog and the direct links to videos.",
        "Pays du catalogue, langue de l’appli et ouverture des titres. Le pays suit celui de ta connexion (wifi, VPN, voyage) ; tu peux le changer à la main.":
            "Catalog country, app language and how titles open. The country follows the one of your connection (Wi-Fi, VPN, travel); you can change it by hand.",
        "Version, mentions légales et confidentialité.": "Version, legal notice and privacy.", "Adresse à confirmer": "Address to confirm",
        "Invité : données sur cet iPhone": "Guest: data on this iPhone", "Aucune plateforme cochée": "No platform ticked",
        "TMDB manquante": "TMDB missing", "TMDB ✓": "TMDB ✓", "affiche automatique": "automatic feature",
        "Clé API TMDB": "TMDB API key", "Clé API (v3) ou jeton d’accès (v4)": "API key (v3) or access token (v4)", "Obtenir": "Get one",
        "Obligatoire : catalogue, fiches, plateformes par pays.": "Required: catalog, title pages, platforms per country.",
        "Clé Streaming Availability": "Streaming Availability key", "Clé RapidAPI": "RapidAPI key",
        "Facultative : liens qui lancent directement le film, la série ou l’épisode.": "Optional: links that start the movie, series or episode directly.",
        "Enregistrées sur cet iPhone (et chiffrées dans ton compte). Elles ne sont jamais publiées.": "Saved on this iPhone (and encrypted in your account). They are never published.",
        "Pays": "Country", "Langue": "Language", "StreamHub sur le web": "StreamHub on the web", "Mentions légales": "Legal notice",
        "Politique de confidentialité": "Privacy policy", "Conditions d’utilisation": "Terms of use",
        "Catalogue et images : TMDB (ce produit utilise l’API de TMDB mais n’est ni approuvé ni certifié par TMDB). Liens vers les plateformes : JustWatch et Streaming Availability.":
            "Catalog and images: TMDB (this product uses the TMDB API but is not endorsed or certified by TMDB). Links to platforms: JustWatch and Streaming Availability.",
        "Coche les plateformes auxquelles tu es abonné : StreamHub n’affiche que ce que tu peux regarder.": "Tick the platforms you subscribe to: StreamHub only shows what you can watch.",
        "Rechercher une plateforme": "Search for a platform", "Automatique": "Automatic", "Revenir au n° 1 du Top 50": "Back to the No. 1 of the Top 50",
        "Les rangées de l’accueil et le titre à l’affiche.": "The home page rows and the featured title.",
        "Pour choisir un titre, ouvre sa fiche et appuie sur « À l’affiche ». Automatique : le n° 1 du Top 50 du moment.":
            "To choose a title, open its page and tap “Featured”. Automatic: the No. 1 of the current Top 50.",
        "Rangées": "Rows", "Active les rangées à afficher et fais-les glisser pour changer leur ordre.": "Turn on the rows to show and drag them to change their order.",
        // Compte
        "Se déconnecter": "Sign out", "Bienvenue sur StreamHub": "Welcome to StreamHub",
        "Tous tes films et séries, toutes tes plateformes, au même endroit.": "All your movies and series, all your platforms, in one place.",
        "Tu es en invité : tes données restent sur cet iPhone. Connecte-toi pour les retrouver partout, chiffrées de bout en bout.":
            "You’re a guest: your data stays on this iPhone. Sign in to find it everywhere, end-to-end encrypted.",
        "Mot de passe oublié": "Forgot password",
        "Tu recevras un lien qui ouvre StreamHub sur le web : choisis-y le nouveau mot de passe, avec ta clé de secours, puis reviens te connecter ici.":
            "You’ll get a link that opens StreamHub on the web: choose the new password there, with your recovery key, then come back and sign in here.",
        "Adresse e-mail": "Email address", "toi@exemple.fr": "you@example.com", "ou": "or", "Envoyer le lien": "Send the link",
        "← Retour à la connexion": "← Back to sign-in", "Créer un compte": "Create an account", "Se connecter": "Sign in",
        "Tes réglages et tes listes, sur tous tes appareils.": "Your settings and lists, on all your devices.",
        "Retrouve tes réglages et tes listes.": "Get your settings and lists back.", "Mot de passe": "Password",
        "Confirme le mot de passe": "Confirm the password", "Oublié ?": "Forgot?", "Compte créé.": "Account created.", "Connecté.": "Signed in.",
        "Créer mon compte": "Create my account", "Déjà un compte ?": "Already have an account?", "Pas encore de compte ?": "No account yet?",
        "Continuer sans compte": "Continue without an account",
        "Tes données resteront sur cet iPhone. Tu pourras créer un compte plus tard dans les réglages.": "Your data will stay on this iPhone. You can create an account later in the settings.",
        "Vérifie ta boîte mail": "Check your inbox", "J’ai confirmé mon adresse": "I’ve confirmed my address", "Renvoyer l’e-mail": "Resend the email",
        "E-mail renvoyé.": "Email resent.", "Utiliser une autre adresse": "Use another address", "Nouveau mot de passe": "New password",
        "Nouveau mot de passe du coffre": "New vault password",
        "Ta clé de secours rouvre tes données ; le nouveau mot de passe les referme.": "Your recovery key reopens your data; the new password locks it again.",
        "Ta clé de secours rouvre tes données ; le nouveau mot de passe du coffre les referme.": "Your recovery key reopens your data; the new vault password locks it again.",
        "Clé de secours": "Recovery key", "Nouveau mot de passe enregistré.": "New password saved.", "← Retour": "← Back",
        "Choisis un mot de passe du coffre": "Choose a vault password",
        "Il chiffre tes données sur l’iPhone, avant l’envoi. Tu le taperas une fois sur chaque nouvel appareil. Il ne sert qu’à StreamHub.":
            "It encrypts your data on the iPhone, before sending. You’ll type it once on each new device. It is only used by StreamHub.",
        "Mot de passe du coffre": "Vault password", "Créer mon coffre": "Create my vault", "Ouvre tes données": "Open your data",
        "Entre ton mot de passe pour ouvrir tes données sur cet iPhone.": "Enter your password to open your data on this iPhone.",
        "Entre ton mot de passe du coffre pour ouvrir tes données sur cet iPhone.": "Enter your vault password to open your data on this iPhone.",
        "Ouvrir": "Open", "Coffre ouvert : synchronisation…": "Vault open: syncing…", "Changer de mot de passe": "Change password",
        "Changer de mot de passe du coffre": "Change vault password",
        "Tes autres appareils seront déconnectés : reconnecte-les avec le nouveau mot de passe (leurs données restent).":
            "Your other devices will be signed out: sign them in again with the new password (their data stays).",
        "Mot de passe actuel": "Current password", "Mot de passe du coffre actuel": "Current vault password", "Mot de passe changé.": "Password changed.",
        "Supprimer ton compte ?": "Delete your account?",
        "Ton compte, ton coffre et tes données synchronisées seront effacés. Tes données restent sur cet iPhone (en invité). Impossible d’annuler.":
            "Your account, your vault and your synced data will be erased. Your data stays on this iPhone (as a guest). This can’t be undone.",
        "Supprimer définitivement": "Delete permanently", "Compte supprimé. Tes données restent sur cet iPhone.": "Account deleted. Your data stays on this iPhone.",
        "Synchroniser maintenant": "Sync now", "Nouvelle clé de secours": "New recovery key",
        "Nouvelle clé de secours : l’ancienne ne marche plus.": "New recovery key: the old one no longer works.", "Supprimer mon compte": "Delete my account",
        "Compte e-mail": "Email account", "Synchronisation…": "Syncing…", "Ta clé de secours": "Your recovery key",
        "Note-la dans ton gestionnaire de mots de passe. Si tu oublies ton mot de passe, elle seule permet de retrouver tes données : personne, pas même StreamHub, ne peut les rouvrir sans elle.":
            "Save it in your password manager. If you forget your password, it is the only way to recover your data: nobody, not even StreamHub, can open it without it.",
        "Copier": "Copy", "Clé copiée.": "Key copied.", "Je l’ai notée": "I’ve saved it",
        "Adresse e-mail invalide.": "Invalid email address.", "Les deux mots de passe ne sont pas identiques.": "The two passwords don’t match.",
        "Déconnecté. Tes données restent sur cet iPhone.": "Signed out. Your data stays on this iPhone.", "Dernière étape": "Last step",
        "Colle ta clé TMDB : elle donne le catalogue. Elle est gratuite, sur themoviedb.org → Paramètres → API.":
            "Paste your TMDB key: it provides the catalog. It’s free, on themoviedb.org → Settings → API.",
        "Récupération de tes réglages…": "Getting your settings…", "Continuer": "Continue", "Obtenir une clé gratuite": "Get a free key",
        "Me connecter plutôt": "Sign in instead", "Tu voulais dire": "Did you mean",
        "En créant un compte ou en te connectant, tu acceptes les [conditions d’utilisation](https://arthursavournin.github.io/streamhub/conditions.html) et la [politique de confidentialité](https://arthursavournin.github.io/streamhub/confidentialite.html).":
            "By creating an account or signing in, you accept the [terms of use](https://arthursavournin.github.io/streamhub/terms.html) and the [privacy policy](https://arthursavournin.github.io/streamhub/privacy.html).",
        // Messages des services
        "E-mail ou mot de passe incorrect.": "Wrong email or password.",
        "Adresse pas encore confirmée : ouvre le lien de l’e-mail reçu.": "Address not confirmed yet: open the link in the email you received.",
        "Un compte existe déjà avec cette adresse : connecte-toi.": "An account already exists with this address: sign in.",
        "Trop d’e-mails envoyés : réessaie dans quelques minutes.": "Too many emails sent: try again in a few minutes.",
        "Trop de tentatives : réessaie dans quelques minutes.": "Too many attempts: try again in a few minutes.",
        "Mot de passe trop faible.": "Password too weak.", "Le nouveau mot de passe est identique à l’ancien.": "The new password is the same as the old one.",
        "Session expirée : reconnecte-toi.": "Session expired: sign in again.",
        "Session fermée (mot de passe changé sur un autre appareil ?) : reconnecte-toi.": "Session closed (password changed on another device?): sign in again.",
        "Compte introuvable (supprimé ?) : tu es déconnecté.": "Account not found (deleted?): you are signed out.",
        "Compte : serveur injoignable (hors ligne ?).": "Account: server unreachable (offline?).", "Pas connecté.": "Not signed in.",
        "Ce mot de passe figure dans des fuites de données connues : choisis-en un autre.": "This password appears in known data breaches: choose another one.",
        "Mot de passe du coffre incorrect.": "Wrong vault password.", "Mot de passe incorrect.": "Wrong password.",
        "Connexion interrompue : recommence.": "Sign-in interrupted: start again.",
        "Clé de secours invalide : 20 lettres et chiffres (ex. ABCD-EFGH-JKLM-NPQR-STUV).": "Invalid recovery key: 20 letters and digits (e.g. ABCD-EFGH-JKLM-NPQR-STUV).",
        "Aucun coffre pour ce compte.": "No vault for this account.", "Clé de secours incorrecte.": "Wrong recovery key.",
        "Mot de passe actuel incorrect.": "Wrong current password.", "Coffre fermé.": "Vault closed.",
        "Données de synchronisation illisibles.": "Unreadable sync data.", "Ajoute ta clé TMDB dans les réglages.": "Add your TMDB key in the settings.",
        "Clé TMDB invalide. Vérifie-la dans les réglages.": "Invalid TMDB key. Check it in the settings.",
        "TMDB reçoit trop de requêtes, réessaie dans un instant.": "TMDB is getting too many requests, try again in a moment.",
    ]

    private static func re(_ p: String) -> NSRegularExpression { try! NSRegularExpression(pattern: "^" + p + "$") }

    nonisolated(unsafe) private static let patterns: [(NSRegularExpression, ([String]) -> String)] = [
        (re(#"(\d+) saisons?"#), { n($0[0], "season", "seasons") }),
        (re(#"(\d+) épisodes?"#), { n($0[0], "episode", "episodes") }),
        (re(#"(\d{4}) – en cours"#), { "\($0[0]) – ongoing" }),
        (re(#"Saison (\d+)"#), { "Season \($0[0])" }),
        (re(#"Épisode (\d+)"#), { "Episode \($0[0])" }),
        (re(#"épisode (\d+)"#), { "episode \($0[0])" }),
        (re(#"Diffusion le (.+)"#), { "Airs on \($0[0])" }),
        (re(#"Découpage TMDB"#), { _ in "TMDB layout" }),
        (re(#"Découpage ([^·]+)"#), { "\(en[$0[0].trimmingCharacters(in: .whitespaces)] ?? $0[0].trimmingCharacters(in: .whitespaces)) layout" }),
        (re(#"(\d+) fillers? dans cette saison"#), { "\(n($0[0], "filler", "fillers")) in this season" }),
        (re(#"Afficher (\d+) épisodes de plus"#), { "Show \($0[0]) more episodes" }),
        (re(#"Regarder sur (.+)"#), { "Watch on \($0[0])" }),
        (re(#"Télécharger sur (.+)"#), { "Download on \($0[0])" }),
        (re(#"(.+) · page de la série"#), { "\($0[0]) · series page" }),
        (re(#"La saison sur (.+)"#), { "The season on \($0[0])" }),
        (re(#"Voir les épisodes sur (.+)"#), { "See the episodes on \($0[0])" }),
        (re(#"Ouvrir la série sur (.+)"#), { "Open the series on \($0[0])" }),
        (re(#"Page (.+) de Canal\+"#), { "Canal+ \($0[0]) page" }),
        (re(#"(Cette série|Ce film) n’est disponible sur aucune plateforme de streaming dans ce pays pour le moment\."#),
         { "\($0[0] == "Ce film" ? "This movie" : "This series") isn’t available on any streaming platform in this country for now." }),
        (re(#"(Cette série|Ce film) n’est incluse? dans aucun de tes abonnements\."#),
         { "\($0[0] == "Ce film" ? "This movie" : "This series") isn’t included in any of your subscriptions." }),
        (re(#"Aussi disponible sur \((\d+)\)"#), { "Also available on (\($0[0]))" }),
        (re(#"Location et achat \((\d+)\)"#), { "Rent and buy (\($0[0]))" }),
        (re(#"Pas encore référencée? dans ce pays par JustWatch : (.+) ajouté d’après son diffuseur, en attendant\."#),
         { "Not yet listed in this country by JustWatch: \($0[0]) added based on its network, in the meantime." }),
        (re(#"Pas encore référencée? dans ce pays par JustWatch : (.+) ajouté d’après Streaming Availability\."#),
         { "Not yet listed in this country by JustWatch: \($0[0]) added based on Streaming Availability." }),
        (re(#"La saga (.+)"#), { "The \($0[0]) saga" }),
        (re(#"Où en es-tu de « (.+) » \?"#), { "Where are you in “\($0[0])”?" }),
        (re(#"sur (.+)"#), { "on \($0[0])" }),
        (re(#"Tu voulais dire « (.+) » \?"#), { "Did you mean “\($0[0])”?" }),
        (re(#"Pas sur tes abonnements"#), { _ in "Not on your subscriptions" }),
        (re(#"Pas sur (.+)"#), { "Not on \($0[0])" }),
        (re(#"Aucun (film|série|titre) trouvé pour « (.+) » sur tes abonnements\."#),
         { "No \(["film": "movie", "série": "series", "titre": "title"][$0[0]] ?? "title") found for “\($0[1])” on your subscriptions." }),
        (re(#"Aucun (film|série|titre) trouvé pour « (.+) » sur (.+)\."#),
         { "No \(["film": "movie", "série": "series", "titre": "title"][$0[0]] ?? "title") found for “\($0[1])” on \($0[2])." }),
        (re(#"(\d+) autres? hors de tes abonnements — tout afficher"#), { "\($0[0]) other\((Int($0[0]) ?? 0) > 1 ? "s" : "") outside your subscriptions — show all" }),
        (re(#"(\d+) autres? hors de (.+) — tout afficher"#), { "\($0[0]) other\((Int($0[0]) ?? 0) > 1 ? "s" : "") outside \($0[1]) — show all" }),
        (re(#"Impossible de charger les (.+)"#), { "Couldn’t load the \(en[$0[0].prefix(1).uppercased() + $0[0].dropFirst()]?.lowercased() ?? $0[0])" }),
        (re(#"Retirer (.+) de l’historique"#), { "Remove \($0[0]) from History" }),
        (re(#"Retirer (.+) des téléchargements"#), { "Remove \($0[0]) from Downloads" }),
        (re(#"Retirer (.+) de (Ma liste|J’aime|Historique|Téléchargements)"#), { "Remove \($0[0]) from \(en[$0[1]] ?? $0[1])" }),
        (re(#"(\d+) rangées? sur (\d+)"#), { "\($0[0]) of \($0[1]) rows" }),
        (re(#"à l’affiche : (.+)"#), { "featured: \($0[0])" }),
        (re(#"(\d+) plateformes? : (.+)"#), { "\(n($0[0], "platform", "platforms")): \($0[1])" }),
        (re(#"(.+) : coffre à ouvrir"#), { "\($0[0]): vault to open" }),
        (re(#"Connecté avec (.+?)\.?"#), { "Signed in with \($0[0])" }),
        (re(#"Continuer avec (.+)"#), { "Continue with \($0[0])" }),
        (re(#"Synchronisation impossible : (.+)"#), { "Sync failed: \(en[$0[0]] ?? $0[0])" }),
        (re(#"✓ Synchronisé (.+)"#), { "✓ Synced \($0[0])" }),
        (re(#"(\d+) caractères au moins"#), { "At least \($0[0]) characters" }),
        (re(#"Mot de passe trop court : (\d+) caractères au moins\."#), { "Password too short: at least \($0[0]) characters." }),
        (re(#"Si un compte existe pour (.+), un e-mail vient de partir\."#), { "If an account exists for \($0[0]), an email is on its way." }),
        (re(#"Ouvre le lien envoyé à (.+) \(regarde aussi dans les indésirables\), puis reviens ici\."#),
         { "Open the link sent to \($0[0]) (check your spam folder too), then come back here." }),
        (re(#"Connexion refusée : (.+)"#), { "Sign-in refused: \($0[0])" }),
        (re(#"(TMDB|Compte) : erreur (\d+)\."#), { "\($0[0] == "Compte" ? "Account" : "TMDB"): error \($0[1])." }),
        (re(#"Catalogue : (.+) \(pays détecté\)\."#), { "Catalog: \($0[0]) (detected country)." }),
        (re(#"Version (.+)"#), { "Version \($0[0])" }),
        (re(#"(\d+) min"#), { "\($0[0]) min" }),
    ]
}

// Texte affiché dans la langue choisie (voir L10n)
nonisolated func loc(_ text: String) -> String { L10n.translate(text) }
