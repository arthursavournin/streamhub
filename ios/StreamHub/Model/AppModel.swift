import Foundation
import Observation
import UIKit

// Série lancée : au retour, « Où en es-tu ? » note le dernier épisode vraiment regardé (comme le site)
struct PendingProgress: Identifiable {
    let entry: LibraryEntry
    let at: Date
    var id: String { entry.key }
}

// L'état de l'appli : réglages et bibliothèque, synchronisation, ouverture des titres sur les plateformes
@Observable
final class AppModel {
    let store = AppStore()
    let account = AccountService()
    let sync: SyncService
    var pendingProgress: PendingProgress?
    var progressQuestion: PendingProgress?
    var showSettings = false // roue des réglages en haut de chaque page

    // « Où en es-tu ? » n'est posé qu'après 3 minutes : un retour plus rapide, c'est souvent juste pour changer de profil
    // ou se connecter
    static let progressDelay: TimeInterval = 3 * 60

    init() {
        sync = SyncService(store: store, account: account)
    }

    var tmdb: TMDBClient { TMDBClient(key: store.tmdbKey, region: store.region, language: store.language) }
    var resolver: LinkResolver { LinkResolver(saKey: store.saKey, relayURL: store.relayURL, region: store.region, providers: store.providers) }
    var isConfigured: Bool { !store.tmdbKey.isEmpty }

    // Change quand le catalogue affiché doit être rechargé (clé, pays, abonnements)
    var catalogKey: String {
        "\(store.tmdbKey)|\(store.region)|\(store.providers.map(\.id).sorted())"
    }

    // ---------- Rangées de l'accueil ----------

    // Rangées déjà chargées (ou en cours) pendant la session : une rangée qui réapparaît (défilement, retour sur une
    // rubrique, grande affiche qui lit la même rangée) s'affiche tout de suite, sans tout recalculer
    @ObservationIgnored private var rowCache: [String: Task<[TMDBTitle], Error>] = [:]

    func fetch(_ row: HomeRow) async throws -> [TMDBTitle] {
        let key = "\(catalogKey)|\(row.key)|\(row.limit)"
        if let task = rowCache[key] { return try await task.value }
        let task = Task { try await load(row) }
        rowCache[key] = task
        do {
            return try await task.value
        } catch {
            rowCache[key] = nil // réessayer la prochaine fois
            throw error
        }
    }

    // Rangées oubliées (« tirer pour actualiser » de l'accueil)
    func clearRows() { rowCache = [:] }

    private func load(_ row: HomeRow) async throws -> [TMDBTitle] {
        if row.ranked, let top = await fetchTop(limit: row.limit), !top.isEmpty { return top }
        guard case .catalog(let types, let sort, let genres, let extra, let pages) = row.kind else { return [] }
        let providers = Links.tmdbProviderIDs(store.providers)
        let shown = types.filter { genres.isEmpty || genres[$0] != nil }
        let tmdb = tmdb
        // Séries pas encore référencées dans le pays : cherchées en même temps que la rangée (avant : après)
        async let unlistedTask = shown.contains(.tv) ? fetchUnlisted(sort: sort, genre: genres[.tv], extra: extra, providers: providers) : []
        let lists = try await withThrowingTaskGroup(of: (Int, [TMDBTitle]).self) { group in
            for (i, type) in shown.enumerated() {
                for page in 1...pages {
                    group.addTask {
                        do {
                            return (i * 100 + page, try await tmdb.discover(type, page: page, genre: genres[type], sort: sort, providers: providers, extra: extra))
                        } catch where page > 1 {
                            return (i * 100 + page, []) // une page en trop n'est pas une erreur
                        }
                    }
                }
            }
            var all: [(Int, [TMDBTitle])] = []
            for try await result in group { all.append(result) }
            return all.sorted { $0.0 < $1.0 }.map(\.1)
        }
        var seen = Set<String>()
        var items = lists.flatMap { $0 }.filter { seen.insert("\($0.type.rawValue):\($0.id)").inserted }
        let unlisted = await unlistedTask
        items += unlisted.filter { seen.insert("tv:\($0.id)").inserted }
        // Séries récentes : leur dernier épisode (pour les classer parmi les films, et affiché sur l'affiche)
        if sort == .recent {
            let latest = await withTaskGroup(of: (Int, LatestEpisode?).self) { group in
                for item in items where item.type == .tv { group.addTask { (item.id, try? await tmdb.latestEpisode(item.id)) } }
                var all: [Int: LatestEpisode] = [:]
                for await (id, episode) in group { if let episode { all[id] = episode } }
                return all
            }
            items = items.map { var m = $0; if m.type == .tv { m.latestEpisode = latest[m.id] }; return m }
        }
        if shown.count > 1 || !unlisted.isEmpty {
            // Films et séries mélangés selon le tri choisi (et séries ajoutées par fetchUnlisted)
            let score: (TMDBTitle) -> Double = switch sort {
            case .popularity: { $0.popularity ?? 0 }
            case .rating: { $0.voteAverage ?? 0 }
            case .recent: { Self.day.date(from: $0.recentDate)?.timeIntervalSince1970 ?? 0 }
            }
            items.sort { score($0) > score($1) }
        }
        return Array(items.prefix(row.limit))
    }

    // Séries de la rangée que JustWatch n'a pas encore dans le pays : créations de tes plateformes (VisionQuest sur
    // Disney+) absentes de la recherche TMDB par plateforme. Même recherche, par diffuseur (épisode ces 60 derniers
    // jours, 7 pour les nouveautés) ; on ne garde que celles que withOriginals ajoute à une de tes plateformes (comme le site).
    private func fetchUnlisted(sort: Sort, genre: Int?, extra: [String: String], providers: [Int]) async -> [TMDBTitle] {
        let networks = Platforms.originalNetworks(providers)
        guard !networks.isEmpty else { return [] }
        let tmdb = tmdb
        let region = store.region
        let mine = store.providers
        let since = String(ISO8601DateFormatter().string(from: Date().addingTimeInterval(-(sort == .recent ? 7 : 60) * 86400)).prefix(10))
        var params = ["with_networks": networks.map(String.init).joined(separator: "|"), "air_date.gte": since]
        for (k, v) in extra { params[k] = v }
        guard let found = try? await tmdb.discover(.tv, genre: genre, sort: sort, providers: [], extra: params) else { return [] }
        let kept = await withTaskGroup(of: (Int, Bool).self) { group in
            for item in found {
                group.addTask {
                    let offers = (try? await tmdb.details(.tv, item.id))?.watchProviders?.results[region]
                    let streamable = offers?.streamable ?? []
                    return (item.id, streamable.contains { $0.unlisted != nil } && streamable.contains { Links.isMine($0, providers: mine) })
                }
            }
            var ids = Set<Int>()
            for await (id, keep) in group where keep { ids.insert(id) }
            return ids
        }
        return found.filter { kept.contains($0.id) }
    }

    // ---------- Top du moment ----------

    // Classement « populaire » de JustWatch dans le pays (data/top/<pays>.json, publié avec le site toutes les 6 heures)
    private struct Ranking: Decodable {
        struct Title: Decodable {
            let t: String
            let id: Int
            let p: [Int]
        }
        let names: [String: String]
        let titles: [Title]
    }

    // Les premiers titres du classement disponibles sur tes abonnements (tout le classement sans abonnement coché) ;
    // nil sans classement (on retombe alors sur la popularité TMDB)
    private func fetchTop(limit: Int) async -> [TMDBTitle]? {
        let region = store.region
        guard let url = URL(string: "data/top/\(region).json", relativeTo: AppStore.site),
              let (data, response) = try? await URLSession.shared.data(from: url),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let ranking = try? JSONDecoder().decode(Ranking.self, from: data) else { return nil }
        let providers = store.providers
        let picked = ranking.titles.filter { title in
            guard !providers.isEmpty else { return true }
            let offers = Offers(flatrate: title.p.map { ProviderOffer(providerId: $0, providerName: ranking.names[String($0)] ?? "") })
            return Platforms.withVirtualChannels(offers, region: region).streamable.contains { Links.isMine($0, providers: providers) }
        }.prefix(limit)
        let tmdb = tmdb
        let found = await withTaskGroup(of: (Int, TMDBTitle?).self) { group in
            for (i, title) in picked.enumerated() {
                group.addTask {
                    let type = MediaType(rawValue: title.t) ?? .movie
                    return (i, try? await tmdb.title(type, title.id))
                }
            }
            var all: [(Int, TMDBTitle?)] = []
            for await result in group { all.append(result) }
            return all.sorted { $0.0 < $1.0 }.compactMap(\.1)
        }
        return found.isEmpty ? nil : found
    }

    private static let day: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    // ---------- Ouverture des titres ----------

    // iOS ouvre l'appli de la plateforme quand elle reconnaît l'adresse (lien universel) ; sinon le site s'ouvre dans
    // Safari, où tu es peut-être déjà connecté. Épisodes M6+ : l'adresse propre à l'appli d'abord.
    // episode : saison et épisode lancés (gardés dans l'historique, comme sur le site)
    func open(_ watch: WatchEntry, for ref: TitleRef, date: String?, episode: Episode? = nil) async {
        let entry = libraryEntry(watch, for: ref, date: date, episode: episode)
        // Lancé = regardé : dans l'historique tout de suite, sans « Tu as regardé… ? » au retour (demande de
        // l'utilisateur, comme le site depuis la version 1.9.2)
        store.recordWatch(entry)
        // Série : on enchaîne souvent plusieurs épisodes sur la plateforme
        if ref.type == .tv { pendingProgress = PendingProgress(entry: entry, at: Date()) }
        await openPlatform(watch.href)
    }

    // « Télécharger » : note le titre dans Mon espace → Téléchargés tout de suite, sans question au retour (demande de
    // l'utilisateur, version 2.4.1), et l'ouvre dans l'appli de la plateforme (c'est là qu'on télécharge)
    func startDownload(_ watch: WatchEntry, for ref: TitleRef, date: String?, episode: Episode? = nil) async {
        var entry = libraryEntry(watch, for: ref, date: date, episode: episode)
        if episode != nil { entry.raw["href"] = .string(watch.href) } // épisode : son propre lien, pas la page de la série
        store.addDownload(entry)
        await openPlatform(watch.page ?? watch.href)
    }

    // Titre téléchargé : ouvert directement dans l'appli de la plateforme, où se trouve le fichier
    func openDownload(_ entry: LibraryEntry) async {
        guard let href = entry.raw["href"]?.string else { return }
        await openPlatform(href)
    }

    // Entrée de la bibliothèque pour un lancement ou un téléchargement : plateforme, lien, saison et épisode
    private func libraryEntry(_ watch: WatchEntry, for ref: TitleRef, date: String?, episode: Episode?) -> LibraryEntry {
        var entry = LibraryEntry(ref: ref, date: date)
        if let episode {
            entry.raw["season"] = .int(Int64(episode.seasonNumber))
            entry.raw["episode"] = .int(Int64(episode.episodeNumber))
            if let name = episode.name { entry.raw["episodeName"] = .string(name) }
        }
        entry.raw["platform"] = .string(watch.name)
        if let service = watch.service { entry.raw["service"] = .string(service) }
        entry.raw["href"] = .string(watch.page ?? watch.href)
        return entry
    }

    private func openPlatform(_ href: String) async {
        if let app = Platforms.appLink(href).flatMap(URL.init(string:)), await UIApplication.shared.open(app) { return }
        guard let url = Platforms.webLink(href).flatMap(URL.init(string:)) else { return } // liens web seulement
        if await UIApplication.shared.open(url, options: [.universalLinksOnly: true]) { return }
        await UIApplication.shared.open(url)
    }

    func openWeb(_ href: String) {
        guard let url = Platforms.webLink(href).flatMap(URL.init(string:)) else { return }
        UIApplication.shared.open(url)
    }

    // Retour dans l'appli : synchronisation, et « Où en es-tu ? » si une série a été lancée il y a plus de 3 minutes
    func appBecameActive() {
        sync.appBecameActive()
        guard let pendingProgress, Date().timeIntervalSince(pendingProgress.at) >= Self.progressDelay else { return }
        progressQuestion = pendingProgress
        self.pendingProgress = nil
    }

    // Réponse : le dernier épisode regardé remplace l'épisode lancé dans l'historique
    func saveProgress(_ entry: LibraryEntry, season: Int, episode: Int, name: String?) {
        var entry = entry
        entry.raw["season"] = .int(Int64(season))
        entry.raw["episode"] = .int(Int64(episode))
        entry.raw["episodeName"] = name.map { .string($0) } ?? .null
        store.recordWatch(entry)
        progressQuestion = nil
    }
}

// Une rangée de l'accueil : catalogue TMDB (sur tes abonnements) ou liste de la bibliothèque
struct HomeRow: Identifiable {
    enum Kind {
        case catalog(types: [MediaType], sort: Sort, genres: [MediaType: Int] = [:], extra: [String: String] = [:], pages: Int = 1)
        case local(LibraryList)
    }

    let key: String // clé commune avec le site (réglage « Accueil » synchronisé)
    let title: String
    let kind: Kind
    var limit = 20
    var ranked = false
    var id: String { key }

    static let both: [MediaType] = [.movie, .tv]

    // Bibliothèque déjà réglée comme cette rangée (« Tout voir »)
    var preset: CatalogPreset? {
        guard case .catalog(let types, let sort, let genres, let extra, _) = kind, !ranked else { return nil }
        return CatalogPreset(
            title: title, type: types.count > 1 ? .all : (types[0] == .movie ? .movie : .tv), sort: sort,
            genre: genres.isEmpty ? nil : CatalogGenre(name: title, movie: genres[.movie], tv: genres[.tv], extra: extra)
        )
    }

    // Comme l'accueil du site (HOME_ROWS), dans l'ordre par défaut
    static let home: [HomeRow] = [
        HomeRow(key: "top", title: "Top 50 du moment", kind: .catalog(types: both, sort: .popularity, pages: 2), limit: 50, ranked: true),
        HomeRow(key: "history", title: "Reprendre", kind: .local(.history)),
        HomeRow(key: "watchlist", title: "Ma liste", kind: .local(.watchlist)),
        HomeRow(key: "recent", title: "Nouveautés", kind: .catalog(types: both, sort: .recent, pages: 2), limit: 30),
        HomeRow(key: "new-episodes", title: "Nouveaux épisodes", kind: .catalog(types: [.tv], sort: .recent, pages: 2), limit: 40),
        HomeRow(key: "new-movies", title: "Nouveaux films", kind: .catalog(types: [.movie], sort: .recent)),
        HomeRow(key: "rating", title: "Les mieux notés", kind: .catalog(types: both, sort: .rating)),
        HomeRow(key: "action", title: "Action & aventure", kind: .catalog(types: both, sort: .popularity, genres: [.movie: 28, .tv: 10759])),
        HomeRow(key: "comedy", title: "Comédie", kind: .catalog(types: both, sort: .popularity, genres: [.movie: 35, .tv: 35])),
        HomeRow(key: "horror", title: "Horreur", kind: .catalog(types: both, sort: .popularity, genres: [.movie: 27])),
        HomeRow(key: "scifi", title: "Science-fiction & fantastique", kind: .catalog(types: both, sort: .popularity, genres: [.movie: 878, .tv: 10765])),
        HomeRow(key: "thriller", title: "Thriller & policier", kind: .catalog(types: both, sort: .popularity, genres: [.movie: 53, .tv: 80])),
        HomeRow(key: "drama", title: "Drame", kind: .catalog(types: both, sort: .popularity, genres: [.movie: 18, .tv: 18])),
        HomeRow(key: "animation", title: "Animation", kind: .catalog(types: both, sort: .popularity, genres: [.movie: 16, .tv: 16])),
        HomeRow(key: "anime", title: "Animés japonais", kind: .catalog(types: both, sort: .popularity, genres: [.movie: 16, .tv: 16], extra: ["with_origin_country": "JP"])),
        HomeRow(key: "romance", title: "Romance", kind: .catalog(types: both, sort: .popularity, genres: [.movie: 10749])),
        HomeRow(key: "family", title: "Famille", kind: .catalog(types: both, sort: .popularity, genres: [.movie: 10751, .tv: 10751])),
        HomeRow(key: "documentary", title: "Documentaires", kind: .catalog(types: both, sort: .popularity, genres: [.movie: 99, .tv: 99])),
    ]

    static func named(_ key: String) -> HomeRow? { home.first { $0.key == key } }
}
