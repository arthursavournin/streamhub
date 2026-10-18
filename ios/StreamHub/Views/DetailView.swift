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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                if let details {
                    actions(details)
                    watchSection(details)
                    about(details)
                    if ref.type == .tv {
                        SeasonsSection(
                            details: details, entries: entries, saSeasons: saSeasons, linksReady: linksReady,
                            lastWatched: model.store.entries(.history).first { $0.key == LibraryEntry.key(.tv, ref.id) }
                        ) { link, episode in
                            Task { await model.open(link.entry, for: ref, date: details.date, episode: episode) }
                        }
                    }
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
                    Text(ref.type == .tv ? "SÉRIE" : "FILM")
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
            parts = [year(d.releaseDate), runtime, genres]
        }
        if let vote = d.voteAverage, (d.voteCount ?? 0) > 0 { parts.append("★ \(String(format: "%.1f", vote))") }
        return parts.filter { !$0.isEmpty }.joined(separator: " · ")
    }

    private func actions(_ d: TitleDetails) -> some View {
        let full = TitleRef(type: ref.type, id: ref.id, title: d.displayTitle, poster: d.posterPath)
        let inList = model.store.contains(.watchlist, full)
        let liked = model.store.contains(.likes, full)
        return VStack(alignment: .leading, spacing: 14) {
            Text(metaLine(d)).font(.subheadline).foregroundStyle(.secondary)
            // Boutons sur une ligne, qui défile si l'écran est trop étroit
            ScrollView(.horizontal) {
            HStack(spacing: 10) {
                Button {
                    model.store.toggle(.watchlist, full, date: d.date)
                } label: {
                    Label("Ma liste", systemImage: inList ? "checkmark" : "plus")
                }
                .buttonStyle(.glass)
                Button {
                    model.store.toggle(.likes, full, date: d.date)
                } label: {
                    Label("J’aime", systemImage: liked ? "heart.fill" : "heart")
                }
                .buttonStyle(.glass)
                .tint(liked ? .pink : nil)
                if let trailer = d.trailer {
                    Button {
                        model.openWeb("https://www.youtube.com/watch?v=\(trailer.key)")
                    } label: {
                        Label("Bande-annonce", systemImage: "play.rectangle")
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
                Text("\(what) n’est disponible sur aucune plateforme de streaming dans ce pays pour le moment.")
                    .foregroundStyle(.secondary)
            }
            if !mine.isEmpty {
                Text("Dans tes abonnements").font(.headline)
                ForEach(mine) { entry in watchButton(entry) }
            } else if !entries.isEmpty, !model.store.providers.isEmpty {
                Text("\(what) n’est \(ref.type == .tv ? "incluse" : "inclus") dans aucun de tes abonnements.")
                    .foregroundStyle(.secondary)
            }
            if !others.isEmpty, !mine.isEmpty {
                // Plateformes hors de tes abonnements : repliées, comme la location et l'achat
                DisclosureGroup("Aussi disponible sur (\(others.count))") {
                    VStack(spacing: 10) {
                        ForEach(others) { entry in watchButton(entry) }
                    }
                    .padding(.top, 8)
                }
                .tint(.secondary)
                .padding(.top, 6)
            } else if !others.isEmpty {
                Text("Disponible sur").font(.headline).padding(.top, 6)
                ForEach(others) { entry in watchButton(entry) }
            }
            if !paid.isEmpty {
                DisclosureGroup("Location et achat (\(paid.count))") {
                    VStack(spacing: 10) {
                        ForEach(paid) { entry in watchButton(entry) }
                    }
                    .padding(.top, 8)
                }
                .tint(.secondary)
                .padding(.top, 6)
            }
        }
        .padding(.horizontal, 16)
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
        Text("\(Text(label).foregroundStyle(.secondary))  \(value)").font(.subheadline)
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
                    Text(entry.title).font(.headline).foregroundStyle(.primary)
                    Text("\(entry.kind.label) · \(loading && !entry.direct ? "Recherche du lien…" : entry.hint)")
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
