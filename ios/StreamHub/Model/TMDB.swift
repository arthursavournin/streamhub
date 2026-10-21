import Foundation

// Un titre, de quoi l'afficher et l'ouvrir
nonisolated struct TitleRef: Hashable, Codable, Sendable {
    let type: MediaType
    let id: Int
    var title: String
    var poster: String?
}

// Résultat de recherche ou de découverte TMDB
nonisolated struct TMDBTitle: Decodable, Identifiable, Hashable, Sendable {
    let id: Int
    var mediaType: String?
    var title: String?
    var name: String?
    let originalTitle: String?
    let originalName: String?
    var posterPath: String?
    let backdropPath: String?
    var overview: String?
    let releaseDate: String?
    let firstAirDate: String?
    let voteAverage: Double?
    let popularity: Double?
    let voteCount: Int?
    let originalLanguage: String?
    let genreIds: [Int]?

    var latestEpisode: LatestEpisode? // séries récentes : dernier épisode diffusé (rempli par l'appli)

    var type: MediaType { MediaType(rawValue: mediaType ?? "") ?? (title != nil ? .movie : .tv) }
    // Date qui compte pour « récent » : celle du dernier épisode pour une série, sinon la date de sortie
    var recentDate: String { latestEpisode?.airDate ?? date }
    var displayTitle: String { title ?? name ?? "" }
    var date: String { releaseDate ?? firstAirDate ?? "" }
    var ref: TitleRef { TitleRef(type: type, id: id, title: displayTitle, poster: posterPath) }
    // Sur l'affiche : dernier épisode d'une série récente, ou date de sortie d'un film
    var caption: String? {
        if let label = latestEpisode?.label { return label }
        let release = type == .movie ? releaseDateLabel(releaseDate) : ""
        return release.isEmpty ? nil : release
    }
}

// Date de sortie d'un film : « 9 oct. 2026 » (affiches), « 1er octobre 2026 » (fiche) ; année seule si le jour manque
// (comme le site)
nonisolated func releaseDateLabel(_ date: String?, long: Bool = false) -> String {
    guard let date, !date.isEmpty else { return "" }
    let parser = DateFormatter()
    parser.dateFormat = "yyyy-MM-dd"
    parser.locale = Locale(identifier: "en_US_POSIX")
    guard let day = parser.date(from: String(date.prefix(10))) else { return String(date.prefix(4)) }
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "fr_FR")
    formatter.dateFormat = long ? "d MMMM y" : "d MMM y"
    let text = formatter.string(from: day)
    return Calendar.current.component(.day, from: day) == 1 ? "1er" + text.dropFirst(1) : text
}

extension [TMDBTitle] {
    // Légendes des affiches d'une grille (voir caption)
    var captions: [TitleRef: String] {
        Dictionary(compactMap { t in t.caption.map { (t.ref, $0) } }, uniquingKeysWith: { a, _ in a })
    }
}

nonisolated struct LatestEpisode: Codable, Hashable, Sendable {
    let seasonNumber: Int
    let episodeNumber: Int
    let airDate: String?

    // « S1 E31 · 16 oct. »
    var label: String {
        var text = "S\(seasonNumber) E\(episodeNumber)"
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        if let air = airDate, let date = f.date(from: air) {
            text += " · " + date.formatted(.dateTime.day().month(.abbreviated).locale(Locale(identifier: "fr_FR")))
        }
        return text
    }
}

nonisolated struct Page<T: Decodable & Sendable>: Decodable, Sendable {
    let results: [T]
    let totalPages: Int?
}

nonisolated struct ProviderOffer: Codable, Hashable, Sendable {
    var providerId: Int
    var providerName: String
    var logoPath: String?
    var displayPriority: Int?
    var unlisted: String? = nil // pas encore référencée dans le pays : "network" (diffuseur) ou "sa"
}

// Offres d'un titre pour un pays : { link, flatrate, free, ads, rent, buy }
nonisolated struct Offers: Codable, Sendable {
    var link: String?
    var flatrate: [ProviderOffer]?
    var free: [ProviderOffer]?
    var ads: [ProviderOffer]?
    var rent: [ProviderOffer]?
    var buy: [ProviderOffer]?

    var streamable: [ProviderOffer] { (flatrate ?? []) + (free ?? []) + (ads ?? []) }
}

nonisolated struct TitleDetails: Decodable, Sendable {
    struct Genre: Decodable, Sendable { let id: Int; let name: String }
    struct Person: Decodable, Sendable { let id: Int?; let name: String; let job: String? }
    struct Company: Decodable, Sendable { let id: Int }
    struct Credits: Decodable, Sendable { let cast: [Person]?; let crew: [Person]? }
    struct Video: Decodable, Sendable { let key: String; let site: String; let type: String }
    struct Videos: Decodable, Sendable { let results: [Video] }
    struct WatchProviders: Decodable, Sendable { var results: [String: Offers] }
    struct Network: Decodable, Sendable { let id: Int; let name: String }

    let id: Int
    var title: String?
    var name: String?
    let originalTitle: String?
    let originalName: String?
    var overview: String?
    let tagline: String?
    var posterPath: String?
    let backdropPath: String?
    let releaseDate: String?
    let firstAirDate: String?
    let lastAirDate: String?
    let inProduction: Bool?
    let runtime: Int?
    let numberOfSeasons: Int?
    let numberOfEpisodes: Int?
    let voteAverage: Double?
    let voteCount: Int?
    let genres: [Genre]?
    let createdBy: [Person]?
    let credits: Credits?
    let videos: Videos?
    let seasons: [SeasonSummary]?
    let networks: [Network]?
    let lastEpisodeToAir: LatestEpisode?
    let nextEpisodeToAir: LatestEpisode?
    var watchProviders: WatchProviders?
    // Pour les suggestions (voir Suggestions.swift)
    let originalLanguage: String?
    let belongsToCollection: TMDBClient.CollectionRef?
    let productionCompanies: [Company]?

    enum CodingKeys: String, CodingKey {
        case id, title, name, originalTitle, originalName, overview, tagline, posterPath, backdropPath, releaseDate
        case firstAirDate, lastAirDate, inProduction, runtime, numberOfSeasons, numberOfEpisodes, voteAverage, voteCount
        case genres, createdBy, credits, videos, seasons, networks, lastEpisodeToAir, nextEpisodeToAir
        case originalLanguage, belongsToCollection, productionCompanies
        case watchProviders = "watch/providers"
    }

    var displayTitle: String { title ?? name ?? "" }
    var originalDisplayTitle: String { originalTitle ?? originalName ?? "" }
    var date: String { releaseDate ?? firstAirDate ?? "" }
    var trailer: Video? { videos?.results.first { $0.site == "YouTube" && $0.type == "Trailer" } }
}

// Une plateforme proposée dans « Mes abonnements »
nonisolated struct ProviderChoice: Hashable, Identifiable, Sendable {
    let id: Int
    let name: String
    let logo: String?
    let priority: Int
}

nonisolated enum Sort: String, Sendable {
    case popularity, rating, recent
}

struct TMDBError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

// Images TMDB : les chemins TMDB commencent par « / » ; les autres sont des images du site StreamHub (logos/)
nonisolated func imageURL(_ path: String?, size: String = "w342") -> URL? {
    guard let path, !path.isEmpty else { return nil }
    return path.hasPrefix("/") ? URL(string: "https://image.tmdb.org/t/p/\(size)\(path)") : URL(string: path, relativeTo: AppStore.site)
}

// Accès à TMDB (catalogue, fiches, « où regarder » par pays), comme makeApi du site
struct TMDBClient {
    let key: String
    let region: String
    let language: String

    private static let base = "https://api.themoviedb.org/3"
    // Une même adresse n'est demandée qu'une fois par session
    private static var memo: [String: Task<Data, Error>] = [:]

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()

    func get<T: Decodable>(_ path: String, _ params: [String: String?] = [:]) async throws -> T {
        guard !key.isEmpty else { throw TMDBError(message: "Ajoute ta clé TMDB dans les réglages.") }
        var components = URLComponents(string: Self.base + path)!
        var items = params.compactMap { k, v in v.flatMap { $0.isEmpty ? nil : URLQueryItem(name: k, value: $0) } }
        // Jeton v4 (JWT, commence par « eyJ ») ou clé v3 classique
        if !key.hasPrefix("eyJ") { items.append(URLQueryItem(name: "api_key", value: key)) }
        components.queryItems = items.sorted { $0.name < $1.name }
        let url = components.url!
        let memoKey = "\(key)|\(url)"
        let task = Self.memo[memoKey] ?? Task { [key] in
            var request = URLRequest(url: url)
            request.setValue("application/json", forHTTPHeaderField: "accept")
            if key.hasPrefix("eyJ") { request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization") }
            let (data, response) = try await URLSession.shared.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            switch status {
            case 200: return data
            case 401: throw TMDBError(message: "Clé TMDB invalide. Vérifie-la dans les réglages.")
            case 429: throw TMDBError(message: "TMDB reçoit trop de requêtes, réessaie dans un instant.")
            default: throw TMDBError(message: "TMDB : erreur \(status).")
            }
        }
        Self.memo[memoKey] = task
        do {
            return try Self.decoder.decode(T.self, from: try await task.value)
        } catch {
            Self.memo[memoKey] = nil
            throw error
        }
    }

    // Plateformes du pays, films et séries confondus (certaines ne proposent que des séries)
    func providers() async throws -> [ProviderChoice] {
        nonisolated struct Item: Decodable {
            let providerId: Int
            let providerName: String
            let logoPath: String?
            let displayPriorities: [String: Int]?
            let displayPriority: Int?
        }
        nonisolated struct List: Decodable { let results: [Item] }
        async let movies: List = get("/watch/providers/movie", ["watch_region": region, "language": language])
        async let shows: List = get("/watch/providers/tv", ["watch_region": region, "language": language])
        var seen = Set<Int>()
        var list: [ProviderChoice] = []
        for p in try await movies.results + shows.results where seen.insert(p.providerId).inserted {
            list.append(ProviderChoice(
                id: p.providerId, name: p.providerName, logo: Platforms.providerLogo(p.providerName, p.logoPath),
                priority: p.displayPriorities?[region] ?? p.displayPriority ?? 999
            ))
        }
        return Platforms.withVirtualProviders(list.sorted { $0.priority < $1.priority }, region: region)
    }

    // extra : paramètres TMDB supplémentaires (ex. with_origin_country = JP)
    func discover(_ type: MediaType, page: Int = 1, genre: Int? = nil, sort: Sort, providers: [Int], extra: [String: String] = [:]) async throws -> [TMDBTitle] {
        try await discoverPage(type, page: page, genre: genre, sort: sort, providers: providers, extra: extra).results
    }

    // Une page du catalogue, avec le nombre de pages (TMDB en donne 500 au plus)
    func discoverPage(_ type: MediaType, page: Int = 1, genre: Int? = nil, sort: Sort, providers: [Int], extra: [String: String] = [:]) async throws -> (results: [TMDBTitle], totalPages: Int) {
        let today = String(ISO8601DateFormatter().string(from: Date()).prefix(10))
        // Séries les plus récentes : celles qui ont eu un épisode ces 7 derniers jours (nouvelle saison ou épisode de la
        // semaine), les plus populaires d'abord, sans talk-shows, infos, feuilletons quotidiens ni téléréalité (comme le site)
        if type == .tv, sort == .recent {
            var params: [String: String?] = [
                "language": language,
                "page": String(page),
                "watch_region": region,
                "with_watch_providers": providers.isEmpty ? nil : providers.map(String.init).joined(separator: "|"),
                "with_watch_monetization_types": providers.isEmpty ? nil : "flatrate|free|ads",
                "with_genres": genre.map(String.init),
                "without_genres": "10763,10764,10766,10767",
                "air_date.gte": String(ISO8601DateFormatter().string(from: Date().addingTimeInterval(-7 * 86400)).prefix(10)),
                "air_date.lte": today,
                "sort_by": "popularity.desc",
                "include_adult": "false",
            ]
            for (k, v) in extra { params[k] = v }
            let page: Page<TMDBTitle> = try await get("/discover/tv", params)
            return (await localized(page.results.map { var t = $0; t.mediaType = "tv"; return t }), min(page.totalPages ?? 1, 500))
        }
        let sortBy = switch sort {
        case .popularity: "popularity.desc"
        case .rating: "vote_average.desc"
        case .recent: type == .tv ? "first_air_date.desc" : "primary_release_date.desc"
        }
        let dateField = type == .tv ? "first_air_date" : "primary_release_date"
        var params: [String: String?] = [
            "language": language,
            "page": String(page),
            "region": type == .movie ? region : nil,
            "watch_region": region,
            "with_watch_providers": providers.isEmpty ? nil : providers.map(String.init).joined(separator: "|"),
            "with_watch_monetization_types": providers.isEmpty ? nil : "flatrate|free|ads",
            "with_genres": genre.map(String.init),
            "sort_by": sortBy,
            "vote_count.gte": sort == .rating ? (type == .tv ? "150" : "300") : sort == .recent ? "10" : nil,
            "\(dateField).lte": sort == .recent ? String(ISO8601DateFormatter().string(from: Date()).prefix(10)) : nil,
            "include_adult": "false",
        ]
        for (k, v) in extra { params[k] = v }
        let page: Page<TMDBTitle> = try await get("/discover/\(type.rawValue)", params)
        return (await localized(page.results.map { var t = $0; t.mediaType = type.rawValue; return t }), min(page.totalPages ?? 1, 500))
    }

    // Genres d'un type (« Action », « Comédie »…)
    func genres(_ type: MediaType) async throws -> [TitleDetails.Genre] {
        nonisolated struct List: Decodable { let genres: [TitleDetails.Genre] }
        let list: List = try await get("/genre/\(type.rawValue)/list", ["language": language])
        return list.genres
    }

    // Dernier épisode diffusé d'une série
    func latestEpisode(_ tvID: Int) async throws -> LatestEpisode? {
        nonisolated struct Info: Decodable { let lastEpisodeToAir: LatestEpisode? }
        let info: Info = try await get("/tv/\(tvID)", ["language": language])
        return info.lastEpisodeToAir
    }

    // Fiche courte d'un titre (affiche, titre, date), pour les titres venus du classement du moment
    func title(_ type: MediaType, _ id: Int) async throws -> TMDBTitle {
        var title: TMDBTitle = try await get("/\(type.rawValue)/\(id)", ["language": language])
        title.mediaType = type.rawValue
        return await localized(title)
    }

    // ---------- Titres sans traduction ----------

    // Titre sans traduction dans la langue choisie : TMDB renvoie le titre d'origine, parfois dans un autre alphabet
    // (« रिपोर्टिंग लाइव », « Reporting Live » sur Netflix France), avec l'affiche d'un autre pays. On prend alors le
    // titre, le résumé manquant et l'affiche de la version anglaise (comme le site). Un titre d'origine en alphabet latin
    // est gardé.
    nonisolated static func foreignScript(_ text: String) -> Bool {
        text.unicodeScalars.contains { c in
            let v = c.value
            let latin = v <= 0x024F || (0x0300...0x036F).contains(v) || (0x1E00...0x1EFF).contains(v)
                || (0x2C60...0x2C7F).contains(v) || (0xA720...0xA7FF).contains(v) || (0xAB30...0xAB6F).contains(v)
                || (0xFF21...0xFF5A).contains(v)
            return c.properties.isAlphabetic && !latin
        }
    }

    private nonisolated struct English: Decodable, Sendable {
        let title: String?
        let name: String?
        let overview: String?
        let posterPath: String?
    }

    private func english(_ type: MediaType, _ id: Int, name: String?) async -> English? {
        guard let name, Self.foreignScript(name), !language.hasPrefix("en"),
              let en: English = try? await get("/\(type.rawValue)/\(id)", ["language": "en-US"]),
              let enName = en.title ?? en.name, !Self.foreignScript(enName) else { return nil }
        return en
    }

    func localized(_ item: TMDBTitle) async -> TMDBTitle {
        guard let en = await english(item.type, item.id, name: item.title ?? item.name) else { return item }
        var out = item
        if out.title != nil { out.title = en.title ?? en.name } else { out.name = en.name ?? en.title }
        if (out.overview ?? "").isEmpty { out.overview = en.overview }
        out.posterPath = en.posterPath ?? out.posterPath
        return out
    }

    func localized(_ items: [TMDBTitle]) async -> [TMDBTitle] {
        await withTaskGroup(of: (Int, TMDBTitle).self) { group in
            for (i, item) in items.enumerated() { group.addTask { (i, await localized(item)) } }
            var out = items
            for await (i, item) in group { out[i] = item }
            return out
        }
    }

    // Détail d'une saison : épisodes avec résumé, image, date, durée
    func season(_ tvID: Int, _ number: Int) async throws -> SeasonDetails {
        try await get("/tv/\(tvID)/season/\(number)", ["language": language])
    }

    // ---------- Sagas ----------

    nonisolated struct Collection: Decodable, Sendable {
        let id: Int
        let name: String
        var parts: [TMDBTitle]
    }

    nonisolated struct CollectionRef: Decodable, Sendable {
        let id: Int
        let name: String
    }

    // Saga d'un film (« Harry Potter - Saga »), nil s'il n'en fait pas partie
    func collectionID(ofMovie id: Int) async throws -> Int? {
        nonisolated struct Info: Decodable { let belongsToCollection: CollectionRef? }
        let info: Info = try await get("/movie/\(id)", ["language": language])
        return info.belongsToCollection?.id
    }

    func searchCollections(_ query: String) async throws -> [CollectionRef] {
        let page: Page<CollectionRef> = try await get("/search/collection", ["query": query, "language": language])
        return page.results
    }

    func collection(_ id: Int) async throws -> Collection {
        var collection: Collection = try await get("/collection/\(id)", ["language": language])
        collection.parts = await localized(collection.parts.map { var t = $0; t.mediaType = t.mediaType ?? "movie"; return t })
        return collection
    }

    // ---------- Suggestions de la fiche (voir Suggestions.swift) ----------

    // Titres conseillés par TMDB (vus par les mêmes spectateurs)
    func recommendations(_ type: MediaType, _ id: Int) async throws -> [TMDBTitle] {
        let page: Page<TMDBTitle> = try await get("/\(type.rawValue)/\(id)/recommendations", ["language": language])
        return await localized(page.results.map { var t = $0; t.mediaType = t.mediaType ?? type.rawValue; return t })
    }

    // Titres proches (genres, mots-clés)
    func similar(_ type: MediaType, _ id: Int) async throws -> [TMDBTitle] {
        let page: Page<TMDBTitle> = try await get("/\(type.rawValue)/\(id)/similar", ["language": language])
        return await localized(page.results.map { var t = $0; t.mediaType = type.rawValue; return t })
    }

    // Sociétés de production, créateurs et mots-clés d'un titre (pour reconnaître une suite ou une série dérivée)
    nonisolated struct Facts: Decodable, Sendable {
        nonisolated struct Keyword: Decodable, Sendable { let name: String }
        nonisolated struct Keywords: Decodable, Sendable { let keywords: [Keyword]?; let results: [Keyword]? }
        let productionCompanies: [TitleDetails.Company]?
        let createdBy: [TitleDetails.Person]?
        let keywords: Keywords?
        var keywordNames: [String] { (keywords?.keywords ?? keywords?.results ?? []).map(\.name) }
    }

    func facts(_ type: MediaType, _ id: Int) async throws -> Facts {
        try await get("/\(type.rawValue)/\(id)", ["language": language, "append_to_response": "keywords"])
    }

    // Films et séries (pas les personnes)
    func search(_ query: String) async throws -> [TMDBTitle] {
        let page: Page<TMDBTitle> = try await get("/search/multi", ["query": query, "language": language, "include_adult": "false"])
        return await localized(page.results.filter { $0.mediaType == "movie" || $0.mediaType == "tv" })
    }

    func details(_ type: MediaType, _ id: Int) async throws -> TitleDetails {
        var details: TitleDetails = try await get("/\(type.rawValue)/\(id)", [
            "language": language,
            "append_to_response": "watch/providers,videos,credits",
            "include_video_language": "\(language.prefix(2)),en,null",
        ])
        // Créations d'une plateforme pas encore référencées dans le pays (voir Platforms.withOriginals)
        var offers = details.watchProviders?.results[region].map(Platforms.withLogos)
        if let networks = details.networks, !networks.isEmpty {
            let available = Set((try? await providers())?.map(\.id) ?? [])
            let dates = [details.firstAirDate, details.lastEpisodeToAir?.airDate].compactMap { $0 }
            offers = Platforms.withOriginals(offers, networks: networks.map(\.id), dates: dates, airing: details.nextEpisodeToAir != nil, available: available)
        }
        if let offers {
            if details.watchProviders == nil { details.watchProviders = TitleDetails.WatchProviders(results: [:]) }
            details.watchProviders?.results[region] = Platforms.withVirtualChannels(offers, region: region)
        }
        if let en = await english(type, id, name: details.title ?? details.name) {
            if details.title != nil { details.title = en.title ?? en.name } else { details.name = en.name ?? en.title }
            if (details.overview ?? "").isEmpty { details.overview = en.overview }
            details.posterPath = en.posterPath ?? details.posterPath
        }
        return details
    }

    // Offres pour le pays choisi, ou nil
    func offers(_ type: MediaType, _ id: Int) async throws -> Offers? {
        nonisolated struct Answer: Decodable { let results: [String: Offers] }
        let answer: Answer = try await get("/\(type.rawValue)/\(id)/watch/providers")
        return answer.results[region].map { Platforms.withVirtualChannels(Platforms.withLogos($0), region: region) }
    }
}
