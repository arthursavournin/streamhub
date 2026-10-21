import SwiftUI

struct HomeView: View {
    @Environment(AppModel.self) private var model
    @State private var top: [TMDBTitle] = []
    @State private var hero: TMDBTitle?
    @State private var error: String?

    // Rangées choisies dans Réglages → Accueil, dans l'ordre choisi
    private var rows: [HomeRow] { model.store.homeLayout.filter(\.on).compactMap { HomeRow.named($0.key) } }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 26) {
                    if let hero = hero ?? top.first {
                        HeroView(title: hero)
                    } else if let error {
                        EmptyMessage(title: "Impossible de charger l’accueil", systemImage: "wifi.exclamationmark", message: error)
                            .padding(.top, 80)
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
            .background(Color.appBackground)
            .titleDestinations()
            .navigationDestination(for: CatalogPreset.self) { CatalogView(preset: $0) }
            .navigationDestination(for: LibraryList.self) { LocalListPage(list: $0) }
            .refreshable { await loadTop() }
            .task(id: "\(model.catalogKey)|\(model.store.homeHero?.id ?? 0)") { await loadTop() }
        }
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

// Grande affiche en haut de l'accueil : le titre n° 1 du moment
private struct HeroView: View {
    @Environment(AppModel.self) private var model
    let title: TMDBTitle

    var body: some View {
        let ref = title.ref
        let chosen = model.store.homeHero?.id == title.id
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
                Text(title.type == .tv ? (chosen ? "Série · à l’affiche" : "Série · n° 1 du moment") : (chosen ? "Film · à l’affiche" : "Film · n° 1 du moment"))
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
private struct CatalogRow: View {
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
                            PosterLink(ref: entry.ref, caption: entry.caption)
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

// « Tout voir » de Reprendre ou Ma liste
struct LocalListPage: View {
    @Environment(AppModel.self) private var model
    let list: LibraryList

    var body: some View {
        ScrollView {
            PosterGrid(refs: model.store.entries(list).map(\.ref), captions: model.store.entries(list).captions).padding(.vertical, 8)
        }
        .background(Color.appBackground)
        .navigationTitle(list == .history ? "Reprendre" : list.title)
    }
}
