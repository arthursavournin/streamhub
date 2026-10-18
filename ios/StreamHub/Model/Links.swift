import Foundation

nonisolated enum OfferKind: String, CaseIterable, Sendable {
    case flatrate, free, ads, rent, buy

    var label: String {
        switch self {
        case .flatrate: "Abonnement"
        case .free: "Gratuit"
        case .ads: "Gratuit avec pub"
        case .rent: "Location"
        case .buy: "Achat"
        }
    }
    var isPaid: Bool { self == .rent || self == .buy }
    var justWatchType: String { rawValue.uppercased() }
}

// Un bouton « Regarder sur… » de la fiche
nonisolated struct WatchEntry: Identifiable, Hashable, Sendable {
    var id: String { "\(kind.rawValue):\(name)" }
    let name: String // nom TMDB (sert à reconnaître la plateforme)
    let logo: String?
    let kind: OfferKind
    let mine: Bool
    let service: String? // pour les liens ; une chaîne Amazon → Prime Video
    var href: String
    var page: String? // la fiche du titre sur la plateforme
    var hint: String
    var direct = false
    var resumeClick = false // Disney+ : il faut appuyer sur « Reprendre » dans l'appli

    var displayName: String { Platforms.shortName(name) }
    var title: String { kind.isPaid ? displayName : "Regarder sur \(displayName)" }
}

nonisolated enum Links {
    // Une offre est « à moi » si c'est la même plateforme TMDB ou le même service (ex. Netflix / Netflix avec pub)
    static func isMine(_ offer: ProviderOffer, providers: [Provider]) -> Bool {
        if providers.contains(where: { $0.id == offer.providerId }) { return true }
        guard let service = Platforms.service(for: offer.providerName)?.id else { return false }
        return providers.contains { Platforms.service(for: $0.name)?.id == service }
    }

    // Pour les recherches TMDB : les cases inventées correspondent à de vraies plateformes (chaîne de Canal+ →
    // catalogue de la plateforme ; Canal+ Ciné Séries → Canal+)
    static func tmdbProviderIDs(_ providers: [Provider]) -> [Int] {
        var seen = Set<Int>()
        return providers.flatMap { p in
            Platforms.canalChannels.first { $0.id == p.id }?.tmdbIds ?? (p.id == Platforms.cineSeriesID ? [381] : [p.id])
        }.filter { seen.insert($0).inserted }
    }

    static func tmdbLink(_ offers: Offers?, type: MediaType, id: Int, region: String) -> String {
        offers?.link ?? "https://www.themoviedb.org/\(type.rawValue)/\(id)/watch?locale=\(region)"
    }

    // Les boutons « Regarder sur… », d'après les offres TMDB (liens de secours en attendant les liens directs)
    static func entries(for details: TitleDetails, type: MediaType, region: String, providers: [Provider]) -> [WatchEntry] {
        let offers = details.watchProviders?.results[region]
        let tmdbLink = tmdbLink(offers, type: type, id: details.id, region: region)
        var seen = Set<String>()
        var entries: [WatchEntry] = []
        let lists: [(OfferKind, [ProviderOffer]?)] = [
            (.flatrate, offers?.flatrate), (.free, offers?.free), (.ads, offers?.ads), (.rent, offers?.rent), (.buy, offers?.buy),
        ]
        for (kind, list) in lists {
            for p in list ?? [] {
                let key = "\(kind.isPaid ? "paid" : "stream"):\(Platforms.service(for: p.providerName)?.id ?? String(p.providerId))"
                guard seen.insert(key).inserted else { continue }
                let fallback = Platforms.fallbackLink(p.providerName, title: details.displayTitle, tmdbLink: tmdbLink)
                entries.append(WatchEntry(
                    name: p.providerName, logo: p.logoPath, kind: kind,
                    mine: !kind.isPaid && isMine(p, providers: providers),
                    service: Platforms.hostService(for: p.providerName)?.id,
                    href: fallback.href, hint: fallback.hint
                ))
            }
        }
        return entries
    }
}

// Liens directs : Streaming Availability (clé facultative), JustWatch (via le relais StreamHub), index des chaînes de
// Canal+ publié avec le site, puis reprise des séries. Même ordre que le site.
struct LinkResolver {
    let saKey: String
    let relayURL: String
    let region: String

    private static var saCache: [String: (options: [SAOption], seasons: [SASeason])] = [:]
    private static var relayCache: [String: [RelayOffer]] = [:]
    private static var canalIndex: [String: [String: [String: String]]] = [:]

    nonisolated struct SAOption: Sendable {
        let service: String?
        let name: String?
        let type: String // subscription | free | addon | rent | buy
        let link: String?
        let videoLink: String?
        let addon: String?
    }

    nonisolated struct RelayOffer: Decodable, Sendable {
        let provider: String
        let type: String
        let url: String
        let deeplink: String?
    }

    // Boutons avec leurs liens directs, et liens Streaming Availability de chaque saison et épisode (séries)
    func resolve(_ entries: [WatchEntry], details: TitleDetails, type: MediaType) async -> (entries: [WatchEntry], seasons: [SASeason]) {
        async let sa = streamingOptions(type: type, id: details.id)
        async let relay = relayOffers(type: type, id: details.id, title: details.displayTitle)
        var out = entries
        let found = await sa
        apply(sa: found.options, to: &out)
        apply(relay: await relay, to: &out)
        await applyCanalChannels(&out, details: details, type: type)
        if type == .tv { applySeriesResume(&out) }
        return (out, found.seasons)
    }

    // ---------- Streaming Availability ----------

    // Pour une série, on récupère aussi les liens de chaque saison et de chaque épisode
    private func streamingOptions(type: MediaType, id: Int) async -> (options: [SAOption], seasons: [SASeason]) {
        guard !saKey.isEmpty else { return ([], []) }
        let country = region.lowercased()
        let cacheKey = "\(type.rawValue):\(country):\(id)"
        if let cached = Self.saCache[cacheKey] { return cached }
        let host = "streaming-availability.p.rapidapi.com"
        let granularity = type == .tv ? "&series_granularity=episode" : ""
        guard let url = URL(string: "https://\(host)/shows/\(type.rawValue)/\(id)?country=\(country)\(granularity)") else { return ([], []) }
        var request = URLRequest(url: url)
        request.setValue(saKey, forHTTPHeaderField: "X-RapidAPI-Key")
        request.setValue(host, forHTTPHeaderField: "X-RapidAPI-Host")
        guard let (data, response) = try? await URLSession.shared.data(for: request) else { return ([], []) }
        let status = (response as? HTTPURLResponse)?.statusCode
        if status == 404 { Self.saCache[cacheKey] = ([], []); return ([], []) }
        guard status == 200, let json = try? JSONDecoder().decode(JSON.self, from: data) else { return ([], []) }
        let pick = { (options: JSON?) in
            (options?[country]?.array ?? []).map { o in
                SAOption(
                    service: o["service"]?["id"]?.string, name: o["service"]?["name"]?.string,
                    type: o["type"]?.string ?? "", link: o["link"]?.string,
                    videoLink: o["videoLink"]?.string ?? Platforms.autoplayLink(o["link"]?.string),
                    addon: o["addon"]?["name"]?.string
                )
            }
        }
        let seasons = (json["seasons"]?.array ?? []).enumerated().map { i, s in
            // Le numéro n'est pas un champ documenté : on le lit dans le titre (« Season 2 »), sinon l'ordre
            let number = (s["title"]?.string?.firstMatch(of: #/\d+/#)).flatMap { Int($0.0) } ?? i + 1
            var episodes: [Int: [SAOption]] = [:]
            for (j, e) in (s["episodes"]?.array ?? []).enumerated() {
                episodes[e["episodeNumber"]?.int ?? j + 1] = pick(e["streamingOptions"])
            }
            return SASeason(number: number, options: pick(s["streamingOptions"]), episodes: episodes)
        }
        let result = (pick(json["streamingOptions"]), seasons)
        Self.saCache[cacheKey] = result
        return result
    }

    // L'offre qui correspond à un bouton. Le bouton « Prime Video » mène à l'offre Prime, jamais à une chaîne ; le
    // bouton d'une chaîne (« Crunchyroll Amazon Channel ») mène à cette chaîne.
    private func pickOption(_ options: [SAOption], for entry: WatchEntry) -> SAOption? {
        let candidates = options.filter { $0.service == entry.service }
        if entry.kind.isPaid { return candidates.first { $0.type == entry.kind.rawValue } }
        if Platforms.isChannel(entry.name) {
            let name = Platforms.squash(entry.name)
            return candidates.first { $0.type == "addon" && $0.addon.map { name.contains(Platforms.squash($0)) } == true }
        }
        return candidates.first { $0.type == "subscription" } ?? candidates.first { $0.type == "free" }
    }

    private func apply(sa options: [SAOption], to entries: inout [WatchEntry]) {
        for i in entries.indices where entries[i].service != nil {
            guard let option = pickOption(options, for: entries[i]), let link = option.link else { continue }
            let play = option.videoLink ?? Platforms.autoplayLink(link)
            entries[i].href = play ?? link
            entries[i].page = link
            entries[i].direct = true
            entries[i].hint = play != nil ? "Lecture directe" : "Fiche du titre"
        }
    }

    // ---------- JustWatch (relais) ----------

    private func relayOffers(type: MediaType, id: Int, title: String) async -> [RelayOffer] {
        let cacheKey = "\(type.rawValue):\(region):\(id)"
        if let cached = Self.relayCache[cacheKey] { return cached }
        var components = URLComponents(string: "\(relayURL)/offers")!
        components.queryItems = [
            URLQueryItem(name: "tmdb", value: String(id)), URLQueryItem(name: "type", value: type.rawValue),
            URLQueryItem(name: "title", value: title), URLQueryItem(name: "country", value: region),
        ]
        struct Answer: Decodable { let offers: [RelayOffer]? }
        guard let url = components.url, let (data, response) = try? await URLSession.shared.data(from: url),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let answer = try? JSONDecoder().decode(Answer.self, from: data) else { return [] }
        let offers = answer.offers ?? []
        Self.relayCache[cacheKey] = offers
        return offers
    }

    private func apply(relay offers: [RelayOffer], to entries: inout [WatchEntry]) {
        for i in entries.indices where !entries[i].direct {
            let same = offers.filter { Platforms.squash($0.provider) == Platforms.squash(entries[i].name) }
            guard let offer = same.first(where: { $0.type == entries[i].kind.justWatchType }) ?? same.first else { continue }
            let play = offer.deeplink.flatMap { $0 != offer.url ? $0 : nil } ?? Platforms.autoplayLink(offer.url)
            entries[i].href = play ?? offer.url
            entries[i].page = offer.url
            entries[i].direct = true
            entries[i].hint = play != nil ? "Lecture directe" : "Fiche du titre"
        }
    }

    // ---------- Chaînes de Canal+ ----------

    private func canalIndex(_ key: String) async -> [String: [String: String]]? {
        if let cached = Self.canalIndex[key] { return cached }
        guard let url = URL(string: "data/canal/\(key).json", relativeTo: AppStore.site),
              let (data, response) = try? await URLSession.shared.data(from: url),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let index = try? JSONDecoder().decode([String: [String: String]].self, from: data) else { return nil }
        Self.canalIndex[key] = index
        return index
    }

    // La fiche du titre sur la chaîne (la fiche Canal VOD est une autre offre, payante) ; titre absent de l'index :
    // la page de la chaîne sur Canal+. Sur iPhone, l'appli Canal+ s'ouvre sur la fiche.
    private func applyCanalChannels(_ entries: inout [WatchEntry], details: TitleDetails, type: MediaType) async {
        let titles = [details.displayTitle, details.originalDisplayTitle].map(Platforms.simplify)
        for channel in Platforms.canalChannels {
            guard let i = entries.firstIndex(where: { $0.name == channel.name }) else { continue }
            let list = await canalIndex(channel.key)?[type == .movie ? "movie" : "tv"] ?? [:]
            let path = titles.lazy.compactMap { list[$0] }.first
            let page = "https://www.canalplus.com\(path ?? channel.hub)"
            entries[i].href = path.flatMap { _ in Platforms.autoplayLink(page) } ?? page
            entries[i].page = page
            entries[i].direct = true
            entries[i].hint = path != nil ? "Lecture directe" : "Page \(channel.label) de Canal+"
        }
    }

    // ---------- Reprise des séries ----------

    // Netflix, Disney+, Prime Video, Canal+ gardent la progression : on leur envoie le lien qu'elles savent reprendre
    private func applySeriesResume(_ entries: inout [WatchEntry]) {
        for i in entries.indices where !entries[i].kind.isPaid && entries[i].service != nil {
            guard let resume = Platforms.seriesResumeLink(play: entries[i].href, page: entries[i].page) else { continue }
            entries[i].href = resume.href
            entries[i].hint = resume.click ? "Page de la série" : resume.hint
            entries[i].resumeClick = resume.click
        }
    }
}
