import SwiftUI

// Navigation commune au site sur iPhone et à l'appli (version 2.4.0, demande de l'utilisateur) : en haut, le logo, la
// recherche et la roue des réglages ; en bas, Accueil, Bibliothèque, Mon espace ; sur l'accueil, les pastilles Tout,
// Films, Séries, Animés.

// Page de recherche, ouverte par la barre du haut
struct SearchRoute: Hashable {}

// Rubriques de l'accueil (pastilles)
enum HomeSection: String, CaseIterable, Identifiable, Hashable {
    case movies, tv, anime
    var id: String { rawValue }
    var title: String {
        switch self {
        case .movies: "Films"
        case .tv: "Séries"
        case .anime: "Animés"
        }
    }

    // Rangées de la page, comme rowsFor du site ; la première fournit la grande affiche
    var rows: [HomeRow] {
        switch self {
        case .movies:
            [
                HomeRow(key: "movies-popular", title: "Films populaires", kind: .catalog(types: [.movie], sort: .popularity)),
                HomeRow(key: "movies-recent", title: "Nouveautés", kind: .catalog(types: [.movie], sort: .recent)),
                HomeRow(key: "movies-rating", title: "Les mieux notés", kind: .catalog(types: [.movie], sort: .rating)),
            ] + Self.genres(.movie, [
                (28, "Action"), (35, "Comédie"), (18, "Drame"), (16, "Animation"), (878, "Science-Fiction"), (53, "Thriller"),
                (12, "Aventure"), (80, "Crime"), (27, "Horreur"), (10749, "Romance"), (10751, "Familial"), (99, "Documentaire"),
            ])
        case .tv:
            [
                HomeRow(key: "tv-popular", title: "Séries populaires", kind: .catalog(types: [.tv], sort: .popularity)),
                HomeRow(key: "tv-recent", title: "Nouveaux épisodes", kind: .catalog(types: [.tv], sort: .recent, pages: 2), limit: 40),
                HomeRow(key: "tv-rating", title: "Les mieux notées", kind: .catalog(types: [.tv], sort: .rating)),
            ] + Self.genres(.tv, [
                (10759, "Action & Aventure"), (35, "Comédie"), (18, "Drame"), (16, "Animation"), (10765, "Science-Fiction & Fantastique"),
                (80, "Crime"), (9648, "Mystère"), (10751, "Familial"), (99, "Documentaire"), (10764, "Téléréalité"),
            ])
        case .anime:
            // Animation japonaise (ANIME et ANIME_GENRES du site) ; genres croisés « 16,28 » par type (TMDBClient.typed)
            [
                Self.anime("anime-popular", "Animés populaires", Self.both),
                Self.anime("anime-recent", "Nouveaux épisodes", [.tv], sort: .recent, pages: 2, limit: 40),
                Self.anime("anime-tv", "Séries animées", [.tv]),
                Self.anime("anime-movies", "Films d’animation", [.movie]),
                Self.anime("anime-rating", "Les mieux notés", Self.both, sort: .rating),
            ] + [
                ("Action & aventure", 28, 10759), ("Science-fiction & fantastique", 878, 10765), ("Comédie", 35, 35),
                ("Drame", 18, 18), ("Mystère", 9648, 9648), ("Famille", 10751, 10751),
            ].map { title, movie, tv in
                Self.anime("anime-\(movie)", title, Self.both, extra: ["with_genres_movie": "16,\(movie)", "with_genres_tv": "16,\(tv)"])
            }
        }
    }

    private static let both: [MediaType] = [.movie, .tv]

    private static func genres(_ type: MediaType, _ list: [(Int, String)]) -> [HomeRow] {
        list.map { id, name in HomeRow(key: "\(type.rawValue)-\(id)", title: name, kind: .catalog(types: [type], sort: .popularity, genres: [type: id])) }
    }

    private static func anime(_ key: String, _ title: String, _ types: [MediaType], sort: Sort = .popularity, pages: Int = 1,
                              limit: Int = 20, extra: [String: String] = [:]) -> HomeRow {
        HomeRow(key: key, title: title, kind: .catalog(types: types, sort: sort, genres: [.movie: 16, .tv: 16],
                                                       extra: ["with_origin_country": "JP"].merging(extra) { a, _ in a }, pages: pages), limit: limit)
    }
}

// Barre du haut : logo, recherche, réglages ; sur l'accueil et ses rubriques, une seconde ligne de pastilles
struct AppTopBar: View {
    @Environment(AppModel.self) private var model
    var section: HomeSection?? = nil // nil : pas de pastilles ; .some(nil) : l'accueil (Tout)
    var onSection: (HomeSection?) -> Void = { _ in }
    var transparent = false // au-dessus de la grande affiche

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Image("WelcomeIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 34, height: 34)
                    .clipShape(.rect(cornerRadius: 9))
                    .accessibilityLabel("StreamHub")
                NavigationLink(value: SearchRoute()) {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                        Text("Rechercher")
                        Spacer(minLength: 0)
                    }
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 14)
                    .frame(height: 42)
                    .contentShape(.capsule)
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: .capsule)
                Button {
                    model.showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                        .font(.title3)
                        .frame(width: 42, height: 42)
                        .contentShape(.circle)
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: .circle)
                .accessibilityLabel("Réglages")
            }
            if let current = section {
                HStack(spacing: 8) {
                    chip("Tout", selected: current == nil) { onSection(nil) }
                    ForEach(HomeSection.allCases) { s in
                        chip(s.title, selected: current == s) { onSection(s) }
                    }
                }
                .frame(maxWidth: .infinity) // pastilles centrées (demande de l'utilisateur)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
        .background {
            Group {
                if transparent {
                    LinearGradient(colors: [.appBackground.opacity(0.85), .appBackground.opacity(0)], startPoint: .top, endPoint: .bottom)
                } else {
                    Color.appBackground.opacity(0.94)
                }
            }
            .ignoresSafeArea(edges: .top)
        }
    }

    private func chip(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(selected ? Color.appBackground : .white)
                .padding(.horizontal, 16)
                .padding(.vertical, 7)
                .background(selected ? Color.white : .clear, in: .capsule)
                .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .glassEffect(selected ? .identity : .regular.interactive(), in: .capsule)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

extension View {
    // Page racine d'un onglet : la barre du haut à la place de la barre de navigation d'iOS
    func appTopBar(section: HomeSection?? = nil, transparent: Bool = false, onSection: @escaping (HomeSection?) -> Void = { _ in }) -> some View {
        toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .top, spacing: 0) {
                AppTopBar(section: section, onSection: onSection, transparent: transparent)
            }
    }
}

// Une rubrique de l'accueil ou l'accueil lui-même, superposés : seule celle choisie se voit et réagit aux appuis
extension View {
    func pane(shown: Bool) -> some View {
        opacity(shown ? 1 : 0)
            .allowsHitTesting(shown)
            .accessibilityHidden(!shown)
            .zIndex(shown ? 1 : 0)
    }
}

// Rubrique Films, Séries ou Animés de l'accueil : grande affiche (le premier titre de la première rangée), puis les
// rangées (la barre du haut et ses pastilles sont celles de l'accueil)
struct SectionContent: View {
    @Environment(AppModel.self) private var model
    let section: HomeSection
    @State private var hero: TMDBTitle?
    @State private var error: String?

    var body: some View {
        let rows = section.rows
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 26) {
                if let hero {
                    HeroView(title: hero, subtitle: "\(hero.type == .tv ? "Série" : "Film") · à la une")
                } else if let error {
                    EmptyMessage(title: "Impossible de charger les \(section.title.lowercased())", systemImage: "wifi.exclamationmark", message: error)
                        .padding(.top, 170)
                } else {
                    Color.appSurface.frame(height: 460).overlay(ProgressView())
                }
                ForEach(rows) { row in CatalogRow(row: row) }
            }
            .padding(.bottom, 24)
        }
        .ignoresSafeArea(edges: .top)
        .background(Color.appBackground)
        .task(id: "\(section.rawValue)|\(model.catalogKey)") {
            do {
                hero = try await model.fetch(rows[0]).first
                error = nil
            } catch {
                self.error = error.localizedDescription
            }
        }
    }
}
