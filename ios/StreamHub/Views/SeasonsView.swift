import SwiftUI

// Saisons et épisodes d'une série : choix de la saison, puis chaque épisode avec ses boutons de lecture
struct SeasonsSection: View {
    @Environment(AppModel.self) private var model
    let details: TitleDetails
    let entries: [WatchEntry]
    let saSeasons: [SASeason]
    let linksReady: Bool
    let lastWatched: LibraryEntry?
    let onLaunch: (EpisodeLink, Episode) -> Void

    @State private var selected: Int?
    @State private var episodes: [Episode] = []
    @State private var links: [String: [EpisodeLink]] = [:]
    @State private var loading = false
    @State private var error: String?
    @State private var shown = 30 // feuilletons : des centaines d'épisodes par saison, affichés par paquets

    // Saisons régulières d'abord, épisodes spéciaux (saison 0) à la fin
    private var seasons: [SeasonSummary] {
        (details.seasons ?? [])
            .filter { ($0.episodeCount ?? 0) > 0 }
            .sorted { ($0.seasonNumber == 0 ? 999 : $0.seasonNumber) < ($1.seasonNumber == 0 ? 999 : $1.seasonNumber) }
    }

    var body: some View {
        if !seasons.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                Text("Épisodes").font(.title3.weight(.bold)).padding(.horizontal, 16)
                ScrollViewReader { proxy in
                    ScrollView(.horizontal) {
                        HStack(spacing: 8) {
                            ForEach(seasons, id: \.seasonNumber) { season in
                                let active = season.seasonNumber == selected
                                Button(season.title) { selected = season.seasonNumber }
                                    .buttonStyle(.glass)
                                    .tint(active ? .accentColor : nil)
                                    .fontWeight(active ? .semibold : .regular)
                                    .id(season.seasonNumber)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    .scrollIndicators(.hidden)
                    .onChange(of: selected) { _, value in withAnimation { proxy.scrollTo(value, anchor: .center) } }
                }
                if let error {
                    Text(error).foregroundStyle(.secondary).padding(.horizontal, 16)
                } else if loading {
                    ProgressView().frame(maxWidth: .infinity).padding(.vertical, 20)
                } else if episodes.isEmpty {
                    Text("Pas encore d’épisodes annoncés.").foregroundStyle(.secondary).padding(.horizontal, 16)
                } else {
                    LazyVStack(alignment: .leading, spacing: 18) {
                        ForEach(episodes.prefix(shown)) { ep in
                            EpisodeRow(episode: ep, links: links[ep.id], linksReady: linksReady, watched: isLastWatched(ep)) { link in
                                onLaunch(link, ep)
                            }
                        }
                        if episodes.count > shown {
                            Button("Afficher \(min(30, episodes.count - shown)) épisodes de plus") { shown += 30 }
                                .buttonStyle(.glass)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            .task(id: details.id) {
                // Saison du dernier épisode regardé, sinon la première
                selected = lastWatched?.season.flatMap { s in seasons.contains { $0.seasonNumber == s } ? s : nil } ?? seasons.first?.seasonNumber
            }
            .task(id: selected) { await loadSeason() }
            .task(id: "\(selected ?? -1)|\(linksReady)|\(episodes.count)|\(shown)") { await loadLinks() }
        }
    }

    private func isLastWatched(_ ep: Episode) -> Bool {
        lastWatched?.season == ep.seasonNumber && lastWatched?.episode == ep.episodeNumber
    }

    private func loadSeason() async {
        guard let selected else { return }
        loading = true
        error = nil
        shown = 30
        defer { loading = false }
        do {
            episodes = try await model.tmdb.season(details.id, selected).episodes
            links = [:]
        } catch {
            if !Task.isCancelled { self.error = error.localizedDescription }
        }
    }

    // Numéro de l'épisode depuis le début de la série (feuilletons de TF1+ et M6+ : « épisode 2299 »)
    private func absolute(_ ep: Episode) -> Int? {
        var before = 0
        for s in seasons where s.seasonNumber > 0 {
            if s.seasonNumber == ep.seasonNumber { return before + ep.episodeNumber }
            before += s.episodeCount ?? 0
        }
        return nil
    }

    private func loadLinks() async {
        guard linksReady else { return }
        let titles = [details.displayTitle, details.originalDisplayTitle]
        let providers = model.store.providers
        for ep in episodes.prefix(shown) where links[ep.id] == nil {
            let found = await EpisodeLinks.links(for: ep, sa: saSeasons, entries: entries, titles: titles, absolute: absolute(ep), providers: providers)
            if Task.isCancelled { return }
            links[ep.id] = found
        }
    }
}

private struct EpisodeRow: View {
    let episode: Episode
    let links: [EpisodeLink]?
    let linksReady: Bool
    let watched: Bool
    let onLaunch: (EpisodeLink) -> Void

    private static let day: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    private var meta: String {
        var parts: [String] = []
        if let air = episode.airDate, let date = Self.day.date(from: air) {
            let text = date.formatted(.dateTime.day().month(.wide).year().locale(Locale(identifier: "fr_FR")))
            parts.append(date > Date() ? "Diffusion le \(text)" : text)
        }
        if let runtime = episode.runtime, runtime > 0 { parts.append("\(runtime) min") }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                Color.appSurface
                    .frame(width: 128, height: 72)
                    .overlay { RemoteImage(url: imageURL(episode.stillPath, size: "w300")) }
                    .clipShape(.rect(cornerRadius: 8))
                    .overlay(alignment: .bottomLeading) {
                        if watched {
                            Text("Dernier vu").font(.caption2.weight(.bold)).padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Color.accentColor, in: .capsule).padding(4)
                        }
                    }
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(episode.episodeNumber). \(episode.name ?? "Épisode \(episode.episodeNumber)")")
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(2)
                    if !meta.isEmpty {
                        Text(meta).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            Text(episode.overview.flatMap { $0.isEmpty ? nil : $0 } ?? "Pas encore de résumé en français.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(3)
            if let links, !links.isEmpty {
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(links) { link in
                            Button {
                                onLaunch(link)
                            } label: {
                                Label(link.label, systemImage: "play.fill").font(.footnote.weight(.semibold))
                            }
                            .buttonStyle(.glass)
                            .tint(link.entry.mine ? .accentColor : nil)
                        }
                    }
                }
                .scrollIndicators(.hidden)
            } else if links != nil {
                Text("Pas disponible en streaming par abonnement").font(.caption).foregroundStyle(.secondary)
            } else {
                Text("Recherche des liens…").font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
