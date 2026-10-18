import Foundation
import Observation
import UIKit

// Lien qui laisse la question « Tu as regardé… ? » en attente du retour dans l'appli
struct PendingWatch: Identifiable {
    let entry: LibraryEntry
    let at: Date
    var id: String { entry.key }
}

// L'état de l'appli : réglages et bibliothèque, synchronisation, ouverture des titres sur les plateformes
@Observable
final class AppModel {
    let store = AppStore()
    let sync: SyncService
    var pending: PendingWatch?
    var question: PendingWatch?

    // « Tu as regardé… ? » n'est posé qu'après 3 minutes : un retour plus rapide, c'est souvent juste pour changer de
    // profil ou se connecter (comme sur le site)
    static let questionDelay: TimeInterval = 3 * 60

    init() {
        sync = SyncService(store: store)
    }

    var tmdb: TMDBClient { TMDBClient(key: store.tmdbKey, region: store.region, language: store.language) }
    var resolver: LinkResolver { LinkResolver(saKey: store.saKey, relayURL: store.relayURL, region: store.region) }
    var isConfigured: Bool { !store.tmdbKey.isEmpty }

    // Change quand le catalogue affiché doit être rechargé (clé, pays, abonnements)
    var catalogKey: String {
        "\(store.tmdbKey)|\(store.region)|\(store.providers.map(\.id).sorted())"
    }

    // ---------- Rangées de l'accueil ----------

    func fetch(_ row: HomeRow) async throws -> [TMDBTitle] {
        if row.ranked, let top = await fetchTop(limit: row.limit), !top.isEmpty { return top }
        guard case .catalog(let types, let sort, let genres, let extra, let pages) = row.kind else { return [] }
        let providers = Links.tmdbProviderIDs(store.providers)
        let shown = types.filter { genres.isEmpty || genres[$0] != nil }
        let tmdb = tmdb
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
        if shown.count > 1 {
            // Films et séries mélangés selon le tri choisi
            let score: (TMDBTitle) -> Double = switch sort {
            case .popularity: { $0.popularity ?? 0 }
            case .rating: { $0.voteAverage ?? 0 }
            case .recent: { Self.day.date(from: $0.date)?.timeIntervalSince1970 ?? 0 }
            }
            items.sort { score($0) > score($1) }
        }
        return Array(items.prefix(row.limit))
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
    func open(_ watch: WatchEntry, for ref: TitleRef, date: String?) async {
        var entry = LibraryEntry(ref: ref, date: date)
        entry.raw["platform"] = .string(watch.name)
        if let service = watch.service { entry.raw["service"] = .string(service) }
        entry.raw["href"] = .string(watch.page ?? watch.href)
        pending = PendingWatch(entry: entry, at: Date())

        if let app = Platforms.appLink(watch.href).flatMap(URL.init(string:)), await UIApplication.shared.open(app) { return }
        guard let url = URL(string: watch.href) else { return }
        if await UIApplication.shared.open(url, options: [.universalLinksOnly: true]) { return }
        await UIApplication.shared.open(url)
    }

    func openWeb(_ href: String) {
        guard let url = URL(string: href) else { return }
        UIApplication.shared.open(url)
    }

    // Retour dans l'appli : question « Tu as regardé… ? » si le titre a été lancé il y a plus de 3 minutes
    func appBecameActive() {
        sync.appBecameActive()
        guard let pending, Date().timeIntervalSince(pending.at) >= Self.questionDelay else { return }
        question = pending
        self.pending = nil
    }

    func answer(_ watched: Bool) {
        if watched, let question { store.recordWatch(question.entry) }
        question = nil
    }
}

// Une rangée de l'accueil : catalogue TMDB (sur tes abonnements) ou liste de la bibliothèque
struct HomeRow: Identifiable {
    enum Kind {
        case catalog(types: [MediaType], sort: Sort, genres: [MediaType: Int] = [:], extra: [String: String] = [:], pages: Int = 1)
        case local(LibraryList)
    }

    let title: String
    let kind: Kind
    var limit = 20
    var ranked = false
    var id: String { title }

    static let both: [MediaType] = [.movie, .tv]

    // Comme l'accueil du site (rowsFor('home'))
    static let home: [HomeRow] = [
        HomeRow(title: "Top 50 du moment", kind: .catalog(types: both, sort: .popularity, pages: 2), limit: 50, ranked: true),
        HomeRow(title: "Reprendre", kind: .local(.history)),
        HomeRow(title: "Ma liste", kind: .local(.watchlist)),
        HomeRow(title: "Nouveautés", kind: .catalog(types: both, sort: .recent)),
        HomeRow(title: "Les mieux notés", kind: .catalog(types: both, sort: .rating)),
        HomeRow(title: "Action & aventure", kind: .catalog(types: both, sort: .popularity, genres: [.movie: 28, .tv: 10759])),
        HomeRow(title: "Comédie", kind: .catalog(types: both, sort: .popularity, genres: [.movie: 35, .tv: 35])),
        HomeRow(title: "Horreur", kind: .catalog(types: both, sort: .popularity, genres: [.movie: 27])),
        HomeRow(title: "Science-fiction & fantastique", kind: .catalog(types: both, sort: .popularity, genres: [.movie: 878, .tv: 10765])),
        HomeRow(title: "Thriller & policier", kind: .catalog(types: both, sort: .popularity, genres: [.movie: 53, .tv: 80])),
        HomeRow(title: "Drame", kind: .catalog(types: both, sort: .popularity, genres: [.movie: 18, .tv: 18])),
        HomeRow(title: "Animation", kind: .catalog(types: both, sort: .popularity, genres: [.movie: 16, .tv: 16])),
        HomeRow(title: "Animés japonais", kind: .catalog(types: both, sort: .popularity, genres: [.movie: 16, .tv: 16], extra: ["with_origin_country": "JP"])),
        HomeRow(title: "Romance", kind: .catalog(types: both, sort: .popularity, genres: [.movie: 10749])),
        HomeRow(title: "Famille", kind: .catalog(types: both, sort: .popularity, genres: [.movie: 10751, .tv: 10751])),
        HomeRow(title: "Documentaires", kind: .catalog(types: both, sort: .popularity, genres: [.movie: 99, .tv: 99])),
    ]
}
