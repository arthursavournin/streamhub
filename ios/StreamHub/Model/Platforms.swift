import Foundation

// Plateformes : reconnaissance des abonnements, chaînes de Canal+, liens de secours et liens de lecture.
// Portage de providers.js (mêmes règles que le site).
nonisolated enum Platforms {
    struct Service {
        let id: String
        let match: Regex<AnyRegexOutput>
        var search: (@Sendable (String) -> String)?
        var home: String?
        var page: (@Sendable (String) -> String)?
        var episodes: (@Sendable (String) -> String)?
    }

    // Correspondance entre les plateformes TMDB (noms variables : « Netflix Standard with Ads »…) et les identifiants
    // Streaming Availability, avec un lien de secours quand on n'a pas de lien direct vers le titre
    nonisolated(unsafe) static let services: [Service] = [
        Service(id: "netflix", match: try! Regex(#"netflix"#), search: { "https://www.netflix.com/search?q=\($0)" }),
        Service(id: "disney", match: try! Regex(#"disney"#), search: { "https://www.disneyplus.com/search?q=\($0)" }),
        Service(id: "apple", match: try! Regex(#"apple tv"#), search: { "https://tv.apple.com/search?term=\($0)" }),
        Service(id: "hbo", match: try! Regex(#"^(hbo )?max\b|hbo max"#), home: "https://www.hbomax.com/"),
        Service(id: "prime", match: try! Regex(#"amazon|prime video"#), search: { "https://www.primevideo.com/search?phrase=\($0)" }),
        Service(id: "canal", match: try! Regex(#"canal\+|canal plus"#), home: "https://www.canalplus.com/"),
        Service(id: "paramount", match: try! Regex(#"paramount"#), home: "https://www.paramountplus.com/"),
        Service(id: "mubi", match: try! Regex(#"mubi"#), search: { "https://mubi.com/search/films?query=\($0)" }),
        // TF1+ n'a pas de page de recherche accessible par un lien, mais ses pages de programme suivent
        // tf1.fr/<chaîne>/<titre> et redirigent vers la bonne chaîne
        Service(
            id: "tf1", match: try! Regex(#"^tf1"#),
            page: { "https://www.tf1.fr/tf1/\(slug($0))" },
            episodes: { "https://www.tf1.fr/tf1/\(slug($0))/videos/replay" }
        ),
        Service(id: "m6", match: try! Regex(#"^m6"#), search: { "https://www.m6.fr/recherche?q=\($0)" }),
        Service(id: "francetv", match: try! Regex(#"^france\.?tv|^france tv"#), search: { "https://www.france.tv/recherche/?q=\($0)" }),
        Service(id: "arte", match: try! Regex(#"^arte\b"#), search: { "https://www.arte.tv/fr/search/?q=\($0)" }),
    ]

    // « Demain nous appartient » → « demain-nous-appartient »
    static func slug(_ title: String) -> String {
        let plain = title.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "fr_FR")).lowercased()
        return plain.replacing(#/[^a-z0-9]+/#, with: "-").trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }

    // « NCIS : Enquêtes spéciales » → « ncisenquetesspeciales » (comme les noms simplifiés des index)
    static func simplify(_ title: String) -> String {
        title.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "fr_FR")).lowercased()
            .replacing(#/[^a-z0-9]/#, with: "")
    }

    // « France.tv » → « francetv » : pour comparer des noms de plateformes écrits différemment
    static func squash(_ name: String?) -> String {
        (name ?? "").lowercased().replacing(#/[^a-z0-9]/#, with: "")
    }

    // Les « chaînes » vendues en option sur une autre plateforme (« Crunchyroll Amazon Channel »…) demandent leur
    // propre abonnement : elles ne comptent jamais comme la plateforme qui les héberge
    static func isChannel(_ name: String) -> Bool {
        name.lowercased().contains(#/\bchannels?\b/#)
    }

    // Le service d'une plateforme, pour reconnaître tes abonnements. Une chaîne n'en a pas.
    static func service(for name: String) -> Service? {
        if isChannel(name) { return nil }
        let lower = name.lowercased()
        return services.first { lower.contains($0.match) }
    }

    // La plateforme où l'on regarde, pour les liens : une chaîne Amazon se regarde dans Prime Video
    static func hostService(for name: String) -> Service? {
        if !isChannel(name) { return service(for: name) }
        let lower = name.lowercased()
        let id: String? = lower.contains("canal") ? "canal" // avant Apple : « Apple TV Canal+ Channel »
            : lower.contains("amazon") ? "prime"
            : lower.contains("apple") ? "apple" : nil
        return services.first { $0.id == id }
    }

    // ---------- Chaînes de Canal+ ----------

    // Offres que TMDB et JustWatch ne référencent pas : HBO Max, Apple TV et Paramount+ regardés sur Canal+.
    // Identifiants inventés (pas des identifiants TMDB) ; tmdbIds sert aux recherches TMDB, key à l'index publié avec
    // le site (data/canal/<key>.json), hub à la page de la chaîne sur Canal+.
    struct CanalChannel: Sendable {
        let key: String
        let id: Int
        let name: String
        let service: String
        let tmdbIds: [Int]
        let hub: String
        let label: String
    }

    static let canalChannels = [
        CanalChannel(key: "hbo", id: 99001899, name: "HBO Max Canal+ Channel", service: "hbo", tmdbIds: [1899], hub: "/chaines/hbo-max/", label: "HBO Max"),
        CanalChannel(key: "appletv", id: 99000350, name: "Apple TV Canal+ Channel", service: "apple", tmdbIds: [350], hub: "/chaines/apple-tv/", label: "Apple TV"),
        CanalChannel(key: "paramount", id: 99000531, name: "Paramount Plus Canal+ Channel", service: "paramount", tmdbIds: [531], hub: "/chaines/paramount-plus/", label: "Paramount+"),
    ]

    // Offre Canal+ Ciné Séries : la cocher coche Canal+, Canal+ Séries, Netflix et les chaînes de Canal+
    static let cineSeriesID = 99000381
    static let cineSeriesName = "Canal+ Ciné Séries"
    static let cineSeriesIncludes = [381, 345, 8] + canalChannels.map(\.id)

    // La plateforme d'origine : même service, jamais une chaîne, ni la boutique « Apple TV Store »
    private static func isBase(of channel: CanalChannel, id: Int, name: String) -> Bool {
        channel.tmdbIds.contains(id) || (channel.service != "apple" && service(for: name)?.id == channel.service)
    }

    static func withVirtualChannels(_ offers: Offers, region: String) -> Offers {
        guard region == "FR", var flatrate = offers.flatrate else { return offers }
        for channel in canalChannels {
            guard let base = flatrate.first(where: { isBase(of: channel, id: $0.providerId, name: $0.providerName) }),
                  !flatrate.contains(where: { $0.providerId == channel.id }) else { continue }
            flatrate.append(ProviderOffer(
                providerId: channel.id, providerName: channel.name,
                logoPath: providerLogo(channel.name, base.logoPath), displayPriority: base.displayPriority
            ))
        }
        var out = offers
        out.flatrate = flatrate
        return out
    }

    // ---------- Offres pas encore référencées dans le pays ----------

    // Plateformes TMDB (= JustWatch) des services, pour ajouter une offre que les données du pays n'ont pas encore
    static let tmdbProviders: [String: ProviderOffer] = [
        "netflix": ProviderOffer(providerId: 8, providerName: "Netflix", logoPath: "/rK1KljqmbvO9HQa1PBFLILWah72.png"),
        "prime": ProviderOffer(providerId: 119, providerName: "Amazon Prime Video", logoPath: "/gMZdpavHmxFNnLpMHwVxfqeux2g.png"),
        "apple": ProviderOffer(providerId: 350, providerName: "Apple TV", logoPath: "/9icYBfYFcwgCbky5VdGUIKJ4C5i.png"),
        "disney": ProviderOffer(providerId: 337, providerName: "Disney Plus", logoPath: "/5eZ872CghnHFLB1j8grszbrx0dx.png"),
        "canal": ProviderOffer(providerId: 381, providerName: "Canal+", logoPath: "/gliWKhLJVdm7QwL1braBCRko5dx.png"),
        "hbo": ProviderOffer(providerId: 1899, providerName: "HBO Max", logoPath: "/skypuy7SXuugIQeYg0IglmzoKaS.png"),
        "paramount": ProviderOffer(providerId: 531, providerName: "Paramount Plus", logoPath: "/pkx3klJlwW5JdtaulvDx6hDNtch.png"),
        "mubi": ProviderOffer(providerId: 11, providerName: "MUBI", logoPath: "/k7iSlvgWzZuO4zU5PcBjhABMuia.png"),
        "tf1": ProviderOffer(providerId: 1754, providerName: "TF1+", logoPath: "/j5w5U61YwOM6Adiaa5zuEVqrpP8.png"),
        "m6": ProviderOffer(providerId: 147, providerName: "M6+", logoPath: "/9o7nQnmlVE94XqPcMhVPGycatxU.png"),
        "arte": ProviderOffer(providerId: 234, providerName: "Arte", logoPath: "/ieo2l4zOaljYqJNGxWY8jWryld5.png"),
    ]

    // Créations des grandes plateformes : diffuseur TMDB (« networks » d'une série) → service. Une nouvelle série
    // (VisionQuest, Disney+, octobre 2026) peut sortir partout le même jour sans que JustWatch l'ait encore référencée
    // dans le pays.
    static let originals: [Int: String] = [213: "netflix", 2739: "disney", 1024: "prime", 2552: "apple", 3186: "hbo", 49: "hbo", 4330: "paramount"]

    // Série en cours de diffusion (ou sortie il y a moins de 60 jours), création d'une plateforme présente dans le pays
    // (available), sans aucune offre d'abonnement ou gratuite dans le pays : la plateforme est ajoutée (unlisted "network")
    static func withOriginals(_ offers: Offers?, networks: [Int], dates: [String], airing: Bool, available: Set<Int>) -> Offers? {
        guard offers?.streamable.isEmpty ?? true else { return offers }
        let parser = DateFormatter()
        parser.dateFormat = "yyyy-MM-dd"
        parser.locale = Locale(identifier: "en_US_POSIX")
        let recent = airing || dates.compactMap(parser.date(from:)).contains { Date.now.timeIntervalSince($0) < 60 * 24 * 3600 }
        guard recent else { return offers }
        var added: [ProviderOffer] = []
        for network in networks {
            guard var provider = originals[network].flatMap({ tmdbProviders[$0] }), available.contains(provider.providerId),
                  !added.contains(where: { $0.providerId == provider.providerId }) else { continue }
            provider.unlisted = "network"
            added.append(provider)
        }
        guard !added.isEmpty else { return offers }
        var out = offers ?? Offers()
        out.flatrate = (out.flatrate ?? []) + added
        return out
    }

    // Offres de Streaming Availability absentes des données TMDB du pays (abonnement ou gratuit, plateformes connues
    // seulement ; pas les chaînes vendues en option) : ajoutées avec unlisted "sa". nil s'il n'y a rien à ajouter.
    static func withSaOffers(_ offers: Offers?, services: [(service: String?, type: String)]) -> Offers? {
        var present = Set((offers?.streamable ?? []).compactMap { hostService(for: $0.providerName)?.id })
        var out = offers ?? Offers()
        var changed = false
        for option in services {
            guard let service = option.service, var provider = tmdbProviders[service], !present.contains(service) else { continue }
            provider.unlisted = "sa"
            switch option.type {
            case "subscription": out.flatrate = (out.flatrate ?? []) + [provider]
            case "free": out.free = (out.free ?? []) + [provider]
            default: continue
            }
            present.insert(service)
            changed = true
        }
        return changed ? out : nil
    }

    // Liste des abonnements (France) : Ciné Séries juste après Canal+, chaque chaîne juste après sa plateforme
    static func withVirtualProviders(_ list: [ProviderChoice], region: String) -> [ProviderChoice] {
        guard region == "FR" else { return list }
        var out = list
        func insert(after base: ProviderChoice, _ extra: ProviderChoice) {
            guard let i = out.firstIndex(of: base), !out.contains(where: { $0.id == extra.id }) else { return }
            out.insert(extra, at: i + 1)
        }
        if let canal = out.first(where: { $0.id == 381 }) {
            insert(after: canal, ProviderChoice(id: cineSeriesID, name: cineSeriesName, logo: canal.logo, priority: canal.priority))
        }
        for channel in canalChannels {
            if let base = out.first(where: { isBase(of: channel, id: $0.id, name: $0.name) }) {
                insert(after: base, ProviderChoice(id: channel.id, name: channel.name, logo: providerLogo(channel.name, base.logo), priority: base.priority))
            }
        }
        return out
    }

    // Logos remplacés (dossier logos/ du site) : chaînes avec l'étiquette « prime video | channels » ou
    // « CANAL+ | channels »
    private static let logos = [
        "hbomaxamazonchannel": "logos/hbo-max-amazon-channel.png",
        "hbomaxcanalchannel": "logos/hbo-max-canal-channel.png",
        "appletvcanalchannel": "logos/apple-tv-canal-channel.png",
        "paramountpluscanalchannel": "logos/paramount-plus-canal-channel.png",
    ]

    static func providerLogo(_ name: String, _ path: String?) -> String? {
        logos[squash(name)] ?? path
    }

    static func withLogos(_ offers: Offers) -> Offers {
        let fix = { (list: [ProviderOffer]?) in
            list?.map { var p = $0; p.logoPath = providerLogo(p.providerName, p.logoPath); return p }
        }
        return Offers(link: offers.link, flatrate: fix(offers.flatrate), free: fix(offers.free), ads: fix(offers.ads), rent: fix(offers.rent), buy: fix(offers.buy))
    }

    // ---------- Noms affichés ----------

    private static let shortNames = [
        "amazonprimevideo": "Prime Video",
        "amazonprimevideowithads": "Prime Video avec pub",
        "disneyplus": "Disney+",
        "netflixbasicwithads": "Netflix avec pub",
        "netflixstandardwithads": "Netflix avec pub",
        "appletvplus": "Apple TV+",
        "paramountplus": "Paramount+",
    ]
    private static let channelHosts = ["amazon": "Prime Video", "apple tv": "Apple TV", "canal+": "Canal+"]

    // « HBO Max Amazon Channel » → « HBO Max (Prime Video) », « HBO Max Canal+ Channel » → « HBO Max (Canal+) »
    static func shortName(_ name: String) -> String {
        if let short = shortNames[squash(name)] { return short }
        if let m = name.firstMatch(of: #/^(.*?)\s+(Amazon|Apple TV|Canal\+)\s+Channels?$/#.ignoresCase()) {
            let base = String(m.1)
            return "\(shortNames[squash(base)] ?? base) (\(channelHosts[m.2.lowercased()] ?? String(m.2)))"
        }
        return name
    }

    // ---------- Liens ----------

    // Lien sans lien direct : page du programme, recherche du titre sur la plateforme, sinon sa page d'accueil,
    // sinon la page « Où regarder » de TMDB
    static func fallbackLink(_ providerName: String, title: String, tmdbLink: String) -> (href: String, hint: String) {
        let service = hostService(for: providerName)
        if let page = service?.page { return (page(title), "Page de la série") }
        let query = title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed.subtracting(CharacterSet(charactersIn: "&+=?"))) ?? title
        if let search = service?.search { return (search(query), "Recherche sur la plateforme") }
        if let home = service?.home { return (home, "Accueil de la plateforme") }
        return (tmdbLink, "Liens sur TMDB")
    }

    // Lien qui lance la lecture, quand la plateforme n'en fournit pas mais que sa fiche sait le faire.
    // Canal+ : la fiche avec « ?autoplay=true » lance son lecteur. Prime Video : la fiche « …/detail?gti=… » a son lien
    // de lecture « app.primevideo.com/watch?gti=… ».
    static func autoplayLink(_ href: String?) -> String? {
        guard let href, var url = URLComponents(string: href), let host = url.host else { return nil }
        let path = url.path
        let gti = url.queryItems?.first { $0.name == "gti" }?.value
            ?? path.firstMatch(of: #/\/detail\/(?:[^\/]+\/)?(amzn1\.dv\.gti\.[A-Za-z0-9-]+)/#).map { String($0.1) }
        if host.hasSuffix("primevideo.com"), let gti, path.contains(#/\/detail(\/|$)/#) {
            return "https://app.primevideo.com/watch?gti=\(gti.addingPercentEncoding(withAllowedCharacters: .alphanumerics.union(CharacterSet(charactersIn: ".-_"))) ?? gti)"
        }
        guard host.hasSuffix("canalplus.com"), path.contains(#/\/h\/\d+/#) else { return nil }
        var items = (url.queryItems ?? []).filter { $0.name != "autoplay" }
        items.append(URLQueryItem(name: "autoplay", value: "true"))
        url.queryItems = items
        return url.string
    }

    // Adresse propre à l'appli M6+ pour un épisode : « m6.fr/<programme>-p_<id>/<épisode>-c_<id> » ouvre l'appli sur la
    // page du programme ; la page de l'épisode annonce « sixplay://programme/<id>/video/clip_<id> ».
    static func appLink(_ href: String) -> String? {
        guard let url = URL(string: href), let host = url.host, host.hasSuffix("m6.fr"),
              let m = url.path.wholeMatch(of: #/\/[a-z0-9-]+-p_(\d+)\/[a-z0-9-]+-c_(\d+)\/?/#.ignoresCase()) else { return nil }
        return "sixplay://programme/\(m.1)/video/clip_\(m.2)"
    }

    // Série : lien qui laisse la plateforme reprendre où on s'est arrêté (épisode suivant), ou commencer à l'épisode 1.
    // play : lien de lecture reçu ; page : page de la série. click : il faut appuyer sur « Reprendre » (Disney+).
    static func seriesResumeLink(play: String?, page: String?) -> (href: String, hint: String, click: Bool)? {
        let p = page ?? ""
        let play = play ?? ""
        // Netflix : « /watch/<épisode> » lance cet épisode, « /watch/<série> » reprend la série
        if let m = p.firstMatch(of: #/netflix\.com\/(?:[a-z]{2}(?:-[a-z]{2})?\/)?title\/(\d+)/#) {
            return ("https://www.netflix.com/watch/\(m.1)", "Reprise de la série", false)
        }
        // Disney+ : « /play/<id> » est l'épisode 1 ; la page de la série affiche « Reprendre S1 E7 »
        if p.contains(#/disneyplus\.com\/(?:[a-z]{2}-[a-z]{2}\/)?browse\/entity-/#) { return (p, "Page de la série", true) }
        // Prime Video : « watch?gti=<série> » reprend déjà
        if play.hasPrefix("https://app.primevideo.com/watch?") { return (play, "Reprise de la série", false) }
        // Canal+ : la fiche de la série avec « autoplay=true » lance « Reprendre » s'il y a une progression
        if play.contains(#/canalplus\.com\/.*\/h\/[^?]+\?(?:.*&)?autoplay=true/#), !play.contains("episodeId=") {
            return (play, "Reprise de la série", false)
        }
        return nil
    }
}
