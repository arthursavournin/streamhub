import SwiftUI

struct HomeView: View {
    @Environment(AppModel.self) private var model
    @State private var top: [TMDBTitle] = []
    @State private var hero: TMDBTitle?
    @State private var error: String?
    @State private var path = NavigationPath()
    // Rubrique affichée par les pastilles (nil : Tout) ; les rubriques déjà ouvertes restent en mémoire (pas de
    // rechargement ni de page vide quand on y revient)
    @State private var section: HomeSection?
    @State private var opened: Set<HomeSection> = []

    // Rangées choisies dans Réglages → Accueil, dans l'ordre choisi
    private var rows: [HomeRow] { model.store.homeLayout.filter(\.on).compactMap { HomeRow.named($0.key) } }

    var body: some View {
        NavigationStack(path: $path) {
            // Tout, Films, Séries et Animés sur la même page, en fondu : avant, Tout → rubrique ouvrait une nouvelle page
            // (glissement de la navigation iOS) alors qu'entre rubriques la page était remplacée sans transition
            ZStack {
                home.pane(shown: section == nil)
                ForEach(HomeSection.allCases) { s in
                    if opened.contains(s) {
                        SectionContent(section: s).pane(shown: section == s)
                    }
                }
            }
            .background(Color.appBackground)
            .appTopBar(section: .some(section), transparent: true, onSection: showSection)
            .titleDestinations()
            .navigationDestination(for: CatalogPreset.self) { CatalogView(preset: $0) }
            .navigationDestination(for: LibraryList.self) { LocalListPage(list: $0) }
            .task(id: "\(model.catalogKey)|\(model.store.homeHero?.id ?? 0)") { await loadTop() }
            .task {
                // Rubriques préparées en arrière-plan une fois l'accueil affiché (grande affiche et premières rangées) :
                // le premier passage sur Films, Séries ou Animés est immédiat
                try? await Task.sleep(for: .seconds(2))
                opened.formUnion(HomeSection.allCases)
            }
        }
    }

    // L'accueil (Tout) : grande affiche, puis les rangées choisies
    private var home: some View {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 26) {
                    if let hero = hero ?? top.first {
                        HeroView(title: hero, subtitle: "\(hero.type == .tv ? "Série" : "Film") · \(self.hero != nil ? "à l’affiche" : "n° 1 du moment")")
                    } else if let error {
                        EmptyMessage(title: "Impossible de charger l’accueil", systemImage: "wifi.exclamationmark", message: error)
                            .padding(.top, 170) // sous la barre du haut et ses pastilles
                    } else {
                        Color.appSurface.frame(height: 460).overlay(ProgressView())
                    }
                    ForEach(rows) { row in
                        switch row.kind {
                        case .local(let list):
                            LocalRow(title: row.title, list: list)
                        case .catalog:
                            if row.ranked {
                                TitleRow(title: row.title, items: top, ranked: true, seeAllTop: true)
                            } else {
                                CatalogRow(row: row)
                            }
                        }
                    }
                }
                .padding(.bottom, 24)
            }
            .ignoresSafeArea(edges: .top)
            .refreshable {
                model.clearRows()
                await loadTop()
            }
    }

    // Pastilles : Tout (l'accueil) ou une rubrique, à la place de celle affichée, dans un même fondu
    private func showSection(_ next: HomeSection?) {
        if let next { opened.insert(next) }
        withAnimation(.easeInOut(duration: 0.25)) { section = next }
    }

    // Top 50 (rangée et affiche), et titre choisi pour l'affiche (Réglages → Accueil ou « À l'affiche » dans sa fiche)
    private func loadTop() async {
        if let chosen = model.store.homeHero {
            hero = try? await model.tmdb.title(chosen.type, chosen.id)
        } else {
            hero = nil
        }
        do {
            top = try await model.fetch(HomeRow.home[0])
            error = nil
        } catch {
            if top.isEmpty, hero == nil { self.error = error.localizedDescription }
        }
    }
}

// Grande affiche en haut de l'accueil (le titre n° 1 du moment ou celui choisi) et des pages Films, Séries, Animés
struct HeroView: View {
    @Environment(AppModel.self) private var model
    let title: TMDBTitle
    let subtitle: String // « Série · n° 1 du moment »

    var body: some View {
        let ref = title.ref
        ZStack(alignment: .bottom) {
            Color.appSurface
                .frame(height: 520)
                .overlay { RemoteImage(url: imageURL(title.posterPath, size: "w780")) }
                .clipped()
            LinearGradient(colors: [.clear, .appBackground.opacity(0.6), .appBackground], startPoint: .center, endPoint: .bottom)
            VStack(spacing: 14) {
                Text(title.displayTitle)
                    .font(.largeTitle.weight(.heavy))
                    .multilineTextAlignment(.center)
                    .shadow(radius: 8)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                HStack(spacing: 12) {
                    NavigationLink(value: ref) {
                        Label("Voir", systemImage: "play.fill").frame(minWidth: 110)
                    }
                    .buttonStyle(.glassProminent)
                    let inList = model.store.contains(.watchlist, ref)
                    Button {
                        model.store.toggle(.watchlist, ref, date: title.date)
                    } label: {
                        Label("Ma liste", systemImage: inList ? "checkmark" : "plus").frame(minWidth: 110)
                    }
                    .buttonStyle(.glass)
                }
                .controlSize(.large)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 8)
        }
    }
}

// Rangée horizontale d'affiches
struct TitleRow: View {
    let title: String
    let items: [TMDBTitle]
    var ranked = false
    var seeAll: CatalogPreset?
    var seeAllTop = false // « Tout voir » du Top 50 : les titres de la rangée en grille

    var body: some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                RowHeader(title: title) {
                    if let seeAll {
                        NavigationLink(value: seeAll) { SeeAllLabel() }
                    } else if seeAllTop {
                        NavigationLink { TitlesGridPage(title: title, items: items) } label: { SeeAllLabel() }
                    }
                }
                ScrollView(.horizontal) {
                    LazyHStack(spacing: 10) {
                        ForEach(Array(items.enumerated()), id: \.element.id) { i, item in
                            PosterLink(ref: item.ref, rank: ranked ? i + 1 : nil, caption: item.caption)
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .scrollIndicators(.hidden)
            }
        }
    }
}

// Rangée du catalogue (TMDB), chargée quand elle apparaît. Pendant le chargement, une rangée provisoire tient la
// place : une vue vide n'apparaît jamais à l'écran, et sa tâche de chargement ne partirait pas.
struct CatalogRow: View {
    @Environment(AppModel.self) private var model
    let row: HomeRow
    @State private var items: [TMDBTitle] = []
    @State private var loadedKey: String?

    var body: some View {
        Group {
            if loadedKey == nil {
                PlaceholderRow(title: row.title)
            } else {
                TitleRow(title: row.title, items: items, seeAll: row.preset)
            }
        }
        .task(id: model.catalogKey) {
            let key = model.catalogKey
            items = (try? await model.fetch(row)) ?? items
            loadedKey = key
        }
    }
}

// Rangée grise en attendant les affiches
private struct PlaceholderRow: View {
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(text: title)
            HStack(spacing: 10) {
                ForEach(0..<4, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 10).fill(Color.appSurface).frame(width: 118, height: 177)
                }
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .clipped()
        }
    }
}

// Rangée d'une liste de la bibliothèque (Reprendre, Ma liste)
private struct LocalRow: View {
    @Environment(AppModel.self) private var model
    let title: String
    let list: LibraryList

    var body: some View {
        let entries = model.store.entries(list)
        if !entries.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                RowHeader(title: title) { NavigationLink(value: list) { SeeAllLabel() } }
                ScrollView(.horizontal) {
                    LazyHStack(spacing: 10) {
                        ForEach(entries) { entry in
                            PosterLink(ref: entry.ref)
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .scrollIndicators(.hidden)
            }
        }
    }
}

// Titre d'une rangée, avec « Tout voir › » à droite
private struct RowHeader<Trailing: View>: View {
    let title: String
    @ViewBuilder let trailing: Trailing

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            SectionTitle(text: title)
            Spacer()
            trailing.padding(.trailing, 16)
        }
    }
}

private struct SeeAllLabel: View {
    var body: some View {
        Text("Tout voir ›").font(.subheadline.weight(.semibold)).foregroundStyle(Color.accentColor)
    }
}

// « Tout voir » du Top 50 : les titres de la rangée en grille, dans l'ordre du classement
private struct TitlesGridPage: View {
    let title: String
    let items: [TMDBTitle]

    var body: some View {
        ScrollView {
            PosterGrid(refs: items.map(\.ref), captions: items.captions).padding(.vertical, 8)
        }
        .background(Color.appBackground)
        .navigationTitle(title)
    }
}

// « Tout voir » de Reprendre (l'historique, en une rangée) ou Ma liste
struct LocalListPage: View {
    @Environment(AppModel.self) private var model
    let list: LibraryList

    var body: some View {
        ScrollView {
            Group {
                if list == .history { HistoryRow() } else { PosterGrid(refs: model.store.entries(list).map(\.ref)) }
            }
            .padding(.vertical, 8)
        }
        .background(Color.appBackground)
        .navigationTitle(list == .history ? "Reprendre" : list.title)
    }
}
