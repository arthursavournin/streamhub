import SwiftUI

// Bibliothèque : tout le catalogue en grille, avec filtres (Tout / Films / Séries, plateforme, genre) et tri, chargé
// page après page en descendant. Aussi ouverte par « Tout voir » d'une rangée de l'accueil, déjà réglée comme elle.

enum CatalogType: String, CaseIterable, Hashable {
    case all, movie, tv
    var label: String {
        switch self {
        case .all: "Tout"
        case .movie: "Films"
        case .tv: "Séries"
        }
    }
    var types: [MediaType] {
        switch self {
        case .all: [.movie, .tv]
        case .movie: [.movie]
        case .tv: [.tv]
        }
    }
}

// Un genre a des identifiants différents pour les films et les séries (et parfois un seul des deux)
struct CatalogGenre: Hashable {
    let name: String
    let movie: Int?
    let tv: Int?
    var extra: [String: String] = [:] // paramètres TMDB en plus (animés japonais : pays d'origine)
    func id(for type: MediaType) -> Int? { type == .movie ? movie : tv }

    // Animation japonaise : genre Animation avec le Japon comme pays d'origine (comme le site, ANIME dans app.js)
    static let anime = CatalogGenre(name: "Animés japonais", movie: 16, tv: 16, extra: ["with_origin_country": "JP"])
}

// Plateformes : tes abonnements, tout le catalogue, ou un seul abonnement
enum PlatformChoice: Hashable {
    case mine, all, one(Int)
}

struct CatalogPreset: Hashable {
    var title = "Bibliothèque"
    var type: CatalogType = .all
    var sort: Sort = .popularity
    var genre: CatalogGenre?
}

nonisolated extension Sort: CaseIterable {
    static let allCases: [Sort] = [.popularity, .rating, .recent]
    var label: String {
        switch self {
        case .popularity: "Populaires"
        case .rating: "Mieux notés"
        case .recent: "Plus récents"
        }
    }
}

struct CatalogView: View {
    @Environment(AppModel.self) private var model
    let preset: CatalogPreset
    var showsTitle = false // onglet Bibliothèque : titre dans la page (la barre du haut remplace celle d'iOS)

    @State private var type: CatalogType = .all
    @State private var platform: PlatformChoice = .mine
    @State private var genre: CatalogGenre?
    @State private var sort: Sort = .popularity
    @State private var genres: [CatalogGenre] = []
    @State private var items: [TMDBTitle] = []
    @State private var page = 0
    @State private var totalPages: [MediaType: Int] = [:]
    @State private var loading = false
    @State private var error: String?
    @State private var started = false

    private var filterKey: String { "\(type)|\(platform)|\(genre?.name ?? "")|\(sort)|\(model.catalogKey)" }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if showsTitle {
                    Text(preset.title).font(.largeTitle.weight(.bold)).padding(.horizontal, 16)
                }
                controls
                if let error, items.isEmpty {
                    EmptyMessage(title: "Catalogue indisponible", systemImage: "wifi.exclamationmark", message: error)
                        .padding(.top, 40)
                } else if items.isEmpty, !loading {
                    EmptyMessage(title: "Aucun titre", systemImage: "film.stack", message: "Rien ne correspond à ces filtres.")
                        .padding(.top, 40)
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 12)], spacing: 16) {
                        ForEach(items) { item in
                            PosterLink(ref: item.ref, width: nil, caption: item.caption)
                                .onAppear { if item.id == items.last?.id { Task { await loadMore() } } }
                        }
                    }
                    .padding(.horizontal, 16)
                }
                if loading {
                    ProgressView().frame(maxWidth: .infinity).padding(.vertical, 20)
                }
            }
            .padding(.vertical, 8)
        }
        .background(Color.appBackground)
        .navigationTitle(preset.title)
        .task {
            // Réglages de départ (une seule fois : les changements de l'utilisateur sont gardés)
            guard !started else { return }
            started = true
            type = preset.type
            sort = preset.sort
            genre = preset.genre
            platform = model.store.providers.isEmpty ? .all : .mine
            await loadGenres()
        }
        .task(id: filterKey) {
            guard started else { return }
            await reload()
        }
    }

    // ---------- Filtres ----------

    private var controls: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("Type", selection: $type) {
                ForEach(CatalogType.allCases, id: \.self) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    Menu {
                        Picker("Plateformes", selection: $platform) {
                            if !model.store.providers.isEmpty { Text("Mes plateformes").tag(PlatformChoice.mine) }
                            Text("Toutes les plateformes").tag(PlatformChoice.all)
                            ForEach(model.store.providers) { p in Text(Platforms.shortName(p.name)).tag(PlatformChoice.one(p.id)) }
                        }
                    } label: { filterLabel(platformName, systemImage: "tv") }
                    Menu {
                        Picker("Genre", selection: $genre) {
                            Text("Tous les genres").tag(CatalogGenre?.none)
                            ForEach(genres, id: \.self) { Text($0.name).tag(CatalogGenre?.some($0)) }
                            if let genre, !genres.contains(genre) { Text(genre.name).tag(CatalogGenre?.some(genre)) }
                        }
                    } label: { filterLabel(genre?.name ?? "Tous les genres", systemImage: "theatermasks") }
                    Menu {
                        Picker("Tri", selection: $sort) {
                            ForEach(Sort.allCases, id: \.self) { Text($0.label).tag($0) }
                        }
                    } label: { filterLabel(sort.label, systemImage: "arrow.up.arrow.down") }
                }
            }
            .scrollIndicators(.hidden)
        }
        .padding(.horizontal, 16)
    }

    private func filterLabel(_ text: String, systemImage: String) -> some View {
        Label(text, systemImage: systemImage)
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, 12).padding(.vertical, 8)
            .glassEffect(.regular.interactive(), in: .capsule)
    }

    private var platformName: String {
        switch platform {
        case .mine: "Mes plateformes"
        case .all: "Toutes les plateformes"
        case .one(let id): model.store.providers.first { $0.id == id }.map { Platforms.shortName($0.name) } ?? "Plateforme"
        }
    }

    // Genres films et séries réunis par nom (« Drame » a le même nom des deux côtés)
    private func loadGenres() async {
        let tmdb = model.tmdb
        async let movies = (try? await tmdb.genres(.movie)) ?? []
        async let shows = (try? await tmdb.genres(.tv)) ?? []
        var byName: [String: CatalogGenre] = [:]
        for g in await movies { byName[g.name] = CatalogGenre(name: g.name, movie: g.id, tv: byName[g.name]?.tv) }
        for g in await shows { byName[g.name] = CatalogGenre(name: g.name, movie: byName[g.name]?.movie, tv: g.id) }
        genres = (Array(byName.values) + [.anime]).sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
    }

    // ---------- Chargement ----------

    private var providerIDs: [Int] {
        switch platform {
        case .mine: Links.tmdbProviderIDs(model.store.providers)
        case .all: []
        case .one(let id): Links.tmdbProviderIDs(model.store.providers.filter { $0.id == id })
        }
    }

    // Types affichés : un type est ignoré si le genre choisi n'existe pas pour lui (Horreur : films seulement)
    private var shownTypes: [MediaType] { type.types.filter { genre == nil || genre!.id(for: $0) != nil } }

    private func reload() async {
        items = []
        page = 0
        totalPages = [:]
        error = nil
        await loadMore()
    }

    private func loadMore() async {
        guard !loading else { return }
        let next = page + 1
        let types = shownTypes.filter { next <= (totalPages[$0] ?? 1) }
        guard !types.isEmpty else { return }
        loading = true
        defer { loading = false }
        let tmdb = model.tmdb
        let (sort, genre, extra, providers, key) = (sort, genre, genre?.extra ?? [:], providerIDs, filterKey)
        do {
            var found: [TMDBTitle] = []
            for t in types {
                let result = try await tmdb.discoverPage(t, page: next, genre: genre?.id(for: t), sort: sort, providers: providers, extra: extra)
                totalPages[t] = result.totalPages
                found += result.results
            }
            // Séries récentes : leur dernier épisode (tri parmi les films, et affiché sur l'affiche)
            if sort == .recent {
                for (i, m) in found.enumerated() where m.type == .tv {
                    found[i].latestEpisode = try? await tmdb.latestEpisode(m.id)
                }
            }
            if types.count > 1 {
                let score: (TMDBTitle) -> Double = switch sort {
                case .popularity: { $0.popularity ?? 0 }
                case .rating: { $0.voteAverage ?? 0 }
                case .recent: { Self.day.date(from: $0.recentDate)?.timeIntervalSince1970 ?? 0 }
                }
                found.sort { score($0) > score($1) }
            }
            guard key == filterKey else { return } // filtres changés pendant le chargement
            let known = Set(items.map { "\($0.type.rawValue):\($0.id)" })
            items += found.filter { !known.contains("\($0.type.rawValue):\($0.id)") }
            page = next
        } catch {
            if key == filterKey { self.error = error.localizedDescription }
        }
    }

    private static let day: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()
}
