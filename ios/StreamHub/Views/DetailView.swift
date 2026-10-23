import SwiftUI

// Fiche d'un titre : infos, et boutons « Regarder sur… » qui ouvrent l'appli de la plateforme
struct DetailView: View {
    @Environment(AppModel.self) private var model
    let ref: TitleRef

    @State private var details: TitleDetails?
    @State private var entries: [WatchEntry] = []
    @State private var resolving: Task<[WatchEntry], Never>?
    @State private var saSeasons: [SASeason] = []
    @State private var linksReady = false
    @State private var error: String?
    @State private var opening: String?
    @State private var tab: DetailTab?
    @State private var suggestions: Suggestions.Groups?
    @State private var suggestionsTask: Task<Void, Never>?
    @State private var suggestionsDone = false

    private enum DetailTab { case episodes, suggestions }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                if let details {
                    actions(details)
                    watchSection(details)
                    about(details)
                    tabs(details)
                } else if let error {
                    EmptyMessage(title: "Fiche indisponible", systemImage: "exclamationmark.triangle", message: error)
                } else {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, 40)
                }
            }
            .padding(.bottom, 32)
        }
        .ignoresSafeArea(edges: .top)
        .background(Color.appBackground)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: ref) { await load() }
    }

    // ---------- Chargement ----------

    private func load() async {
        do {
            let details = try await model.tmdb.details(ref.type, ref.id)
            self.details = details
            loadSuggestions(details) // dès l'ouverture de la fiche : l'onglet Suggestions est prêt quand on y va
            entries = Links.entries(for: details, type: ref.type, region: model.store.region, providers: model.store.providers)
            let resolver = model.resolver
            let initial = entries
            let full = Task { await resolver.resolve(initial, details: details, type: ref.type) }
            let task = Task { await full.value.entries }
            resolving = task
            let result = await full.value
            entries = result.entries
            saSeasons = result.seasons
            linksReady = true
        } catch {
            self.error = error.localizedDescription
        }
    }

    // Un appui avant l'arrivée des liens directs attend le lien (4 s au plus) au lieu d'ouvrir le lien de secours
    private func launch(_ entry: WatchEntry) {
        guard let details else { return }
        opening = entry.id
        Task {
            var target = entry
            if !linksReady, let resolving {
                let resolved = await withTaskGroup(of: [WatchEntry]?.self) { group in
                    group.addTask { await resolving.value }
                    group.addTask { try? await Task.sleep(for: .seconds(4)); return nil }
                    let first = await group.next() ?? nil
                    group.cancelAll()
                    return first
                }
                if let match = resolved?.first(where: { $0.id == entry.id }) { target = match }
            }
            await model.open(target, for: ref, date: details.date)
            opening = nil
        }
    }

    // ---------- En-tête ----------

    private var header: some View {
        ZStack(alignment: .bottomLeading) {
            // L'image remplit le cadre sans l'élargir (sinon toute la page déborde de l'écran)
            Color.appSurface
                .frame(height: 300)
                .overlay { RemoteImage(url: imageURL(details?.backdropPath, size: "w1280")) }
                .clipped()
            LinearGradient(colors: [.clear, .appBackground], startPoint: .center, endPoint: .bottom)
            HStack(alignment: .bottom, spacing: 14) {
                PosterView(ref: TitleRef(type: ref.type, id: ref.id, title: ref.title, poster: details?.posterPath ?? ref.poster), width: 104)
                    .shadow(radius: 12)
                VStack(alignment: .leading, spacing: 6) {
                    Text(loc(ref.type == .tv ? "SÉRIE" : "FILM"))
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(.white.opacity(0.15), in: .capsule)
                    Text(details?.displayTitle ?? ref.title)
                        .font(.title2.weight(.bold))
                        .lineLimit(3)
                    if let original = details?.originalDisplayTitle, !original.isEmpty, original != details?.displayTitle {
                        Text(original).font(.subheadline).foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 16)
            .offset(y: 40)
        }
        .padding(.bottom, 40)
    }

    private func metaLine(_ d: TitleDetails) -> String {
        let year = { (s: String?) in s.map { String($0.prefix(4)) } ?? "" }
        let genres = d.genres?.map(\.name).joined(separator: ", ") ?? ""
        var parts: [String]
        if ref.type == .tv {
            let start = year(d.firstAirDate)
            let end = d.inProduction == true ? "en cours" : year(d.lastAirDate)
            let seasons = d.numberOfSeasons.map { "\($0) saison\($0 > 1 ? "s" : "")" } ?? ""
            let episodes = d.numberOfEpisodes.map { "\($0) épisode\($0 > 1 ? "s" : "")" } ?? ""
            parts = [!start.isEmpty && !end.isEmpty && end != start ? "\(start) – \(end)" : start, seasons, episodes, genres]
        } else {
            let runtime = d.runtime.flatMap { $0 > 0 ? "\($0 / 60) h \(String(format: "%02d", $0 % 60))" : nil } ?? ""
            parts = [releaseDateLabel(d.releaseDate, long: true), runtime, genres]
        }
        if let vote = d.voteAverage, (d.voteCount ?? 0) > 0 { parts.append("★ \(String(format: "%.1f", vote))") }
        return parts.filter { !$0.isEmpty }.joined(separator: " · ")
    }

    private func actions(_ d: TitleDetails) -> some View {
        let full = TitleRef(type: ref.type, id: ref.id, title: d.displayTitle, poster: d.posterPath)
        let inList = model.store.contains(.watchlist, full)
        let liked = model.store.contains(.likes, full)
        return VStack(alignment: .leading, spacing: 14) {
            Text(loc(metaLine(d))).font(.subheadline).foregroundStyle(.secondary)
            // Boutons sur une ligne, qui défile si l'écran est trop étroit
            ScrollView(.horizontal) {
            HStack(spacing: 10) {
                Button {
                    model.store.toggle(.watchlist, full, date: d.date)
                } label: {
                    Label(loc("Ma liste"), systemImage: inList ? "checkmark" : "plus")
                }
                .buttonStyle(.glass)
                Button {
                    model.store.toggle(.likes, full, date: d.date)
                } label: {
                    Label(loc("J’aime"), systemImage: liked ? "heart.fill" : "heart")
                }
                .buttonStyle(.glass)
                .tint(liked ? .pink : nil)
                // Ce titre en grand en haut de l'accueil (un second appui revient au n° 1 du Top 50)
                let onHero = model.store.homeHero.map { $0.type == full.type && $0.id == full.id } ?? false
                Button {
                    model.store.setHome(rows: model.store.homeLayout, hero: onHero ? nil : full)
                } label: {
                    Label(loc("À l’affiche"), systemImage: onHero ? "star.fill" : "star")
                }
                .buttonStyle(.glass)
                .tint(onHero ? .yellow : nil)
                if let trailer = d.trailer {
                    Button {
                        model.openWeb("https://www.youtube.com/watch?v=\(trailer.key)")
                    } label: {
                        Label(loc("Bande-annonce"), systemImage: "play.rectangle")
                    }
                    .buttonStyle(.glass)
                }
            }
            .labelStyle(.titleAndIcon)
            .lineLimit(1)
            .controlSize(.regular)
            .padding(.horizontal, 16)
            }
            .scrollIndicators(.hidden)
            .padding(.horizontal, -16)
        }
        .padding(.horizontal, 16)
    }

    // ---------- Où regarder ----------

    @ViewBuilder
    private func watchSection(_ d: TitleDetails) -> some View {
        let mine = entries.filter(\.mine)
        let others = entries.filter { !$0.mine && !$0.kind.isPaid }
        let paid = entries.filter(\.kind.isPaid)
        let what = ref.type == .tv ? "Cette série" : "Ce film"
        VStack(alignment: .leading, spacing: 12) {
            if entries.isEmpty {
                Text(loc("\(what) n’est disponible sur aucune plateforme de streaming dans ce pays pour le moment."))
                    .foregroundStyle(.secondary)
            }
            if !mine.isEmpty {
                Text(loc("Dans tes abonnements")).font(.headline)
                ForEach(mine) { entry in
                    watchButton(entry)
                    // Film : « Télécharger » ouvre l'appli de la plateforme (épisodes : dans la liste des épisodes)
                    if ref.type == .movie, !entry.kind.isPaid { downloadButton(entry, d) }
                }
            } else if !entries.isEmpty, !model.store.providers.isEmpty {
                Text(loc("\(what) n’est \(ref.type == .tv ? "incluse" : "inclus") dans aucun de tes abonnements."))
                    .foregroundStyle(.secondary)
            }
            if !others.isEmpty, !mine.isEmpty {
                // Plateformes hors de tes abonnements : repliées, comme la location et l'achat
                DisclosureGroup(loc("Aussi disponible sur (\(others.count))")) {
                    VStack(spacing: 10) {
                        ForEach(others) { entry in watchButton(entry) }
                    }
                    .padding(.top, 8)
                }
                .tint(.secondary)
                .padding(.top, 6)
            } else if !others.isEmpty {
                Text(loc("Disponible sur")).font(.headline).padding(.top, 6)
                ForEach(others) { entry in watchButton(entry) }
            }
            if !paid.isEmpty {
                DisclosureGroup(loc("Location et achat (\(paid.count))")) {
                    VStack(spacing: 10) {
                        ForEach(paid) { entry in watchButton(entry) }
                    }
                    .padding(.top, 8)
                }
                .tint(.secondary)
                .padding(.top, 6)
            }
            // Offre ajoutée par StreamHub (JustWatch ne la référence pas encore dans le pays) : on le dit
            let unlisted = entries.filter { $0.unlisted != nil }
            if !unlisted.isEmpty {
                let names = unlisted.map(\.displayName).joined(separator: ", ")
                let source = unlisted.allSatisfy { $0.unlisted == "network" } ? "d’après son diffuseur, en attendant" : "d’après Streaming Availability"
                Text(loc("Pas encore référencé\(ref.type == .tv ? "e" : "") dans ce pays par JustWatch : \(names) ajouté \(source)."))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
    }

    private func downloadButton(_ entry: WatchEntry, _ d: TitleDetails) -> some View {
        let full = TitleRef(type: ref.type, id: ref.id, title: d.displayTitle, poster: d.posterPath)
        let done = model.store.isDownloaded(LibraryEntry(ref: full))
        return Button {
            Task { await model.startDownload(entry, for: full, date: d.date) }
        } label: {
            Label(loc(done ? "Téléchargé" : "Télécharger"), systemImage: done ? "checkmark.circle" : "arrow.down.circle")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 14))
        .accessibilityLabel(loc("Télécharger sur \(entry.displayName)"))
    }

    private func watchButton(_ entry: WatchEntry) -> some View {
        WatchButton(entry: entry, loading: !linksReady, opening: opening == entry.id) { launch(entry) }
    }

    // ---------- À propos ----------

    @ViewBuilder
    private func about(_ d: TitleDetails) -> some View {
        let makers = ref.type == .tv
            ? (d.createdBy ?? []).map(\.name)
            : (d.credits?.crew ?? []).filter { $0.job == "Director" }.map(\.name)
        let cast = (d.credits?.cast ?? []).prefix(5).map(\.name)
        VStack(alignment: .leading, spacing: 12) {
            if let tagline = d.tagline, !tagline.isEmpty {
                Text(tagline).font(.callout.italic()).foregroundStyle(.secondary)
            }
            if let overview = d.overview, !overview.isEmpty {
                Text(overview).font(.body)
            }
            if !makers.isEmpty {
                credit(ref.type == .tv ? "Création" : "Réalisation", makers.joined(separator: ", "))
            }
            if !cast.isEmpty {
                credit("Avec", cast.joined(separator: ", "))
            }
        }
        .padding(.horizontal, 16)
    }

    private func credit(_ label: String, _ value: String) -> some View {
        Text("\(Text(loc(label)).foregroundStyle(.secondary))  \(value)").font(.subheadline)
    }

    // ---------- Onglets : Épisodes (séries, ouvert d'abord) et Suggestions (seul onglet d'un film) ----------

    private func hasEpisodes(_ d: TitleDetails) -> Bool {
        ref.type == .tv && (d.seasons ?? []).contains { ($0.episodeCount ?? 0) > 0 }
    }

    @ViewBuilder
    private func tabs(_ d: TitleDetails) -> some View {
        let episodes = hasEpisodes(d)
        let current = tab ?? (episodes ? .episodes : .suggestions)
        VStack(alignment: .leading, spacing: 16) {
            VStack(spacing: 0) {
                HStack(spacing: 24) {
                    if episodes { tabButton("Épisodes", .episodes, current: current) }
                    tabButton("Suggestions", .suggestions, current: current)
                    Spacer()
                }
                .padding(.horizontal, 16)
                Divider()
            }
            if episodes {
                // Gardée affichée même cachée : la saison choisie et les épisodes chargés restent au retour sur l'onglet
                SeasonsSection(
                    details: d, entries: entries, saSeasons: saSeasons, linksReady: linksReady,
                    lastWatched: model.store.entries(.history).first { $0.key == LibraryEntry.key(.tv, ref.id) }
                ) { link, episode in
                    Task { await model.open(link.entry, for: ref, date: d.date, episode: episode) }
                } onDownload: { link, episode in
                    let full = TitleRef(type: ref.type, id: ref.id, title: d.displayTitle, poster: d.posterPath)
                    Task { await model.startDownload(link.entry, for: full, date: d.date, episode: episode) }
                }
                .frame(height: current == .episodes ? nil : 0, alignment: .top)
                .clipped()
                .opacity(current == .episodes ? 1 : 0)
                .accessibilityHidden(current != .episodes)
            }
            if current == .suggestions {
                suggestionsView(d)
            }
        }
    }

    private func tabButton(_ label: String, _ value: DetailTab, current: DetailTab) -> some View {
        Button { tab = value } label: {
            Text(loc(label))
                .font(.headline)
                .foregroundStyle(current == value ? .primary : .secondary)
                .padding(.vertical, 10)
                .overlay(alignment: .bottom) {
                    if current == value { Capsule().fill(Color.accentColor).frame(height: 3) }
                }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(current == value ? .isSelected : [])
    }

    // Rangées : la saga, le même univers, puis le même genre (voir Suggestions.swift), affichées dès qu'elles arrivent
    private func suggestionsView(_ d: TitleDetails) -> some View {
        VStack(alignment: .leading, spacing: 22) {
            if let s = suggestions {
                TitleRow(title: s.sagaName.isEmpty ? "La saga" : "La saga \(s.sagaName)", items: s.saga)
                TitleRow(title: "Dans le même univers", items: s.universe)
                TitleRow(title: "Dans le même genre", items: Array(s.genre.prefix(20)))
                if suggestionsDone && s.saga.isEmpty && s.universe.isEmpty && s.genre.isEmpty {
                    Text(loc("Pas de suggestion pour ce titre.")).foregroundStyle(.secondary).padding(.horizontal, 16)
                }
            }
            if !suggestionsDone {
                ProgressView(loc("Recherche des suggestions…")).frame(maxWidth: .infinity).padding(.vertical, 16)
            }
        }
        .onAppear { loadSuggestions(d) }
    }

    // Une seule recherche par fiche, qui continue si on change d'onglet entre-temps
    private func loadSuggestions(_ d: TitleDetails) {
        guard suggestionsTask == nil else { return }
        let tmdb = model.tmdb
        let type = ref.type
        let region = model.store.region
        let providers = model.store.providers
        suggestionsTask = Task {
            // Les trois rangées sont cherchées en même temps et chacune s'affiche dès qu'elle est prête
            let key = { (m: TMDBTitle) in "\(m.type.rawValue):\(m.id)" }
            async let genreTask = Suggestions.genre(tmdb, d, type: type, region: region, providers: providers)
            let saga = await Suggestions.saga(tmdb, d)
            var groups = Suggestions.Groups(sagaName: saga.name, saga: saga.items)
            suggestions = groups
            var shown = Set(saga.items.map(key)).union(["\(type.rawValue):\(d.id)"])
            let sagaShown = shown
            async let universeTask = Suggestions.universe(tmdb, d, type: type, exclude: sagaShown)
            let genre = await genreTask
            groups.genre = genre.filter { !shown.contains(key($0)) }
            suggestions = groups
            groups.universe = await universeTask
            shown.formUnion(groups.universe.map(key))
            groups.genre = genre.filter { !shown.contains(key($0)) } // sans les titres passés dans « même univers »
            suggestions = groups
            suggestionsDone = true
        }
    }
}

// Bouton « Regarder sur… » : logo, nom, type d'offre et nature du lien
private struct WatchButton: View {
    let entry: WatchEntry
    let loading: Bool
    let opening: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                PlatformLogo(path: entry.logo, size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(loc(entry.title)).font(.headline).foregroundStyle(.primary)
                    Text(loc("\(entry.kind.label) · \(loading && !entry.direct ? "Recherche du lien…" : entry.hint)"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                if opening {
                    ProgressView()
                } else {
                    Image(systemName: "arrow.up.right").font(.body.weight(.semibold)).foregroundStyle(entry.mine ? Color.mine : .secondary)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .glassEffect(entry.mine ? .regular.tint(.accentColor.opacity(0.25)).interactive() : .regular.interactive(), in: .rect(cornerRadius: 18))
    }
}
