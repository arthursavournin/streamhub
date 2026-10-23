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
    let onDownload: (EpisodeLink, Episode) -> Void // ⬇ : téléchargement dans l'appli de la plateforme

    @State private var selected: Int?
    @State private var episodes: [Episode] = []
    @State private var links: [String: [EpisodeLink]] = [:]
    @State private var loading = false
    @State private var error: String?
    @State private var shown = 30 // feuilletons : des centaines d'épisodes par saison, affichés par paquets
    @State private var fillerShow: FillerShow? // découpage « Netflix - Sans filler » (Naruto, Naruto Shippuden)
    // Découpage choisi : « fillers » (sans filler), « tmdb », ou l'identifiant d'un groupe d'épisodes TMDB (version 2.5.0,
    // comme le site : ex. « TF1+ » pour Demain nous appartient, choisi d'office quand il porte le nom d'une plateforme)
    @State private var source = "tmdb"
    @State private var groupChoices: [EpisodeGroupRef] = []
    @State private var groupSeasons: [GroupSeason] = []
    @State private var allEpisodes: [Episode]? // tous les épisodes TMDB, pour le découpage sans filler
    @State private var netflixShow: NetflixEpisodes.Show? // liens Netflix de chaque épisode (Naruto, Shippuden, Boruto)

    private var fillerMode: Bool { fillerShow != nil && source == Self.fillers }
    private var groupMode: Bool { source != Self.fillers && source != Self.tmdbSource }
    private static let fillers = "fillers"
    private static let tmdbSource = "tmdb"

    // Saison d'un groupe d'épisodes : numéro affiché, nom, épisodes dans l'ordre du groupe
    struct GroupSeason {
        let number: Int
        let name: String
        var episodes: [Episode]
    }

    // Saisons régulières d'abord, épisodes spéciaux (saison 0) à la fin
    private var seasons: [SeasonSummary] {
        (details.seasons ?? [])
            .filter { ($0.episodeCount ?? 0) > 0 }
            .sorted { ($0.seasonNumber == 0 ? 999 : $0.seasonNumber) < ($1.seasonNumber == 0 ? 999 : $1.seasonNumber) }
    }

    // Boutons de saison : numéro, titre, et pour le découpage sans filler, s'il n'y a que des fillers
    private var seasonButtons: [(number: Int, title: String, allFiller: Bool)] {
        if fillerMode, let fillerShow {
            return fillerShow.seasons.compactMap { $0.first }.map { ($0, "Saison \($0)", fillerShow.fillerCount(of: $0).all) }
        }
        if groupMode { return groupSeasons.map { ($0.number, $0.name, false) } }
        return seasons.map { ($0.seasonNumber, $0.title, false) }
    }

    var body: some View {
        if !seasons.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                if fillerShow != nil || !groupChoices.isEmpty {
                    Picker("Découpage", selection: $source) {
                        if let fillerShow { Text("Découpage \(fillerShow.name)").tag(Self.fillers) }
                        Text("Découpage TMDB").tag(Self.tmdbSource)
                        ForEach(groupChoices, id: \.id) { g in
                            Text("Découpage \(g.name)\(g.groupCount.map { " · \($0) saison\($0 > 1 ? "s" : "")" } ?? "")").tag(g.id)
                        }
                    }
                    .pickerStyle(.menu)
                    .padding(.horizontal, 6)
                }
                ScrollViewReader { proxy in
                    ScrollView(.horizontal) {
                        HStack(spacing: 8) {
                            ForEach(seasonButtons, id: \.number) { season in
                                let active = season.number == selected
                                Button(season.title) { selected = season.number }
                                    .buttonStyle(.glass)
                                    .tint(season.allFiller ? .red : active ? .accentColor : nil)
                                    .fontWeight(active ? .semibold : .regular)
                                    .overlay {
                                        if active && season.allFiller { Capsule().stroke(.white.opacity(0.8), lineWidth: 1.5) }
                                    }
                                    .id(season.number)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    .scrollIndicators(.hidden)
                    .onChange(of: selected) { _, value in withAnimation { proxy.scrollTo(value, anchor: .center) } }
                }
                if fillerMode, let fillerShow, let selected {
                    if let title = fillerShow.seasonNames?[String(selected)] {
                        Text(title).font(.subheadline.weight(.semibold)).padding(.horizontal, 16)
                    }
                    let fillers = fillerShow.fillerCount(of: selected)
                    if fillers.count > 0 {
                        Text(fillers.all ? "Que des fillers dans cette saison" : "\(fillers.count) filler\(fillers.count > 1 ? "s" : "") dans cette saison")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.red)
                            .padding(.horizontal, 16)
                    }
                }
                if let error {
                    Text(error).foregroundStyle(.secondary).padding(.horizontal, 16)
                } else if loading {
                    ProgressView().frame(maxWidth: .infinity).padding(.vertical, 20)
                } else if episodes.isEmpty {
                    Text("Pas encore d’épisodes annoncés.").foregroundStyle(.secondary).padding(.horizontal, 16)
                } else {
                    LazyVStack(alignment: .leading, spacing: 18) {
                        ForEach(Array(episodes.prefix(shown).enumerated()), id: \.element.id) { i, ep in
                            EpisodeRow(
                                episode: ep, links: links[ep.id], linksReady: linksReady, watched: isLastWatched(ep),
                                number: fillerMode || groupMode ? i + 1 : nil, absolute: fillerMode,
                                filler: fillerMode && fillerShow?.isFiller(ep.episodeNumber) == true
                            ) { link in
                                onLaunch(link, ep)
                            } onDownload: { link in
                                onDownload(link, ep)
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
                async let groups = (try? await model.tmdb.episodeGroups(details.id)) ?? []
                fillerShow = await Fillers.show(details.id)
                netflixShow = await NetflixEpisodes.show(details.id)
                groupChoices = await groups
                links = [:] // liens d'épisodes recalculés avec les épisodes absents d'une plateforme
                await choose(fillerShow != nil ? Self.fillers : preferredGroup?.id ?? Self.tmdbSource)
            }
            .onChange(of: source) { _, value in Task { await choose(value) } }
            .task(id: "\(selected ?? -1)|\(source)|\(groupSeasons.count)") { await loadSeason() }
            .task(id: "\(selected ?? -1)|\(linksReady)|\(episodes.count)|\(shown)") { await loadLinks() }
        }
    }

    // Le bouton Netflix de l'épisode, avec son lien de lecture (netflix-episodes.json), à la place de celui de Streaming
    // Availability ou du lien vers la page de la série
    private func withNetflix(_ links: [EpisodeLink], _ ep: Episode) -> [EpisodeLink] {
        guard let netflixShow, let id = netflixShow.episodes["\(ep.seasonNumber):\(ep.episodeNumber)"],
              var entry = entries.first(where: { $0.mine && $0.service == "netflix" && !Platforms.isChannel($0.name) }) else { return links }
        entry.href = "https://www.netflix.com/watch/\(id)"
        entry.page = "https://www.netflix.com/title/\(netflixShow.netflix)"
        entry.direct = true
        let others = links.filter { !($0.entry.service == "netflix" && !Platforms.isChannel($0.entry.name)) }
        return [EpisodeLink(label: Platforms.shortName(entry.name), entry: entry)] + others
    }

    // Groupe qui porte le nom d'une plateforme où la série est disponible (« TF1+ ») : ce sont les saisons que tu verras
    // sur cette plateforme (comme loadEpisodeGroups du site)
    private var preferredGroup: EpisodeGroupRef? {
        let platforms = (details.watchProviders?.results[model.store.region]?.streamable ?? []).map { $0.providerName.lowercased() }
        return groupChoices.first { g in
            let name = g.name.trimmingCharacters(in: .whitespaces).lowercased()
            return platforms.contains { $0 == name || $0.hasPrefix(name + " ") }
        }
    }

    // Change de découpage (groupe d'épisodes : saisons lues sur TMDB), puis choisit la saison de départ
    private func choose(_ value: String) async {
        if source != value { source = value } // onChange rappelle choose avec la même valeur : sans effet
        if value != Self.fillers, value != Self.tmdbSource {
            do {
                groupSeasons = try await loadGroup(value)
                error = nil
            } catch {
                self.error = error.localizedDescription
                groupSeasons = []
            }
        }
        guard source == value else { return }
        selectStart()
    }

    // Saisons d'un groupe d'épisodes (comme groupSeasons + completeGroupSeasons du site) : un groupe n'est pas toujours à
    // jour (Demain nous appartient : 2 épisodes de la saison 10 dans le groupe, 40 chez TMDB) ; les épisodes TMDB
    // manquants sont ajoutés à la saison du groupe qui les précède
    private func loadGroup(_ id: String) async throws -> [GroupSeason] {
        let group = try await model.tmdb.episodeGroup(id)
        var result = group.groups.sorted { $0.order < $1.order }.filter { !$0.episodes.isEmpty }.enumerated().map { i, part in
            let generic = part.name.trimmingCharacters(in: .whitespaces).range(of: #"^(season|saison) \d+$"#, options: [.regularExpression, .caseInsensitive]) != nil
            return GroupSeason(number: i + 1, name: generic ? "Saison \(i + 1)" : part.name,
                               episodes: part.episodes.sorted { ($0.order ?? 0) < ($1.order ?? 0) })
        }
        guard !result.isEmpty else { return [] }
        var covered = Set(result.flatMap { $0.episodes.map(\.id) })
        for tmdbSeason in seasons where tmdbSeason.seasonNumber > 0 {
            let n = tmdbSeason.seasonNumber
            let known = result.flatMap(\.episodes).filter { $0.seasonNumber == n }.count
            guard known < (tmdbSeason.episodeCount ?? 0),
                  let full = try? await model.tmdb.season(details.id, n) else { continue }
            let missing = full.episodes.filter { !covered.contains($0.id) }
            guard !missing.isEmpty else { continue }
            let target = result.lastIndex { $0.episodes.contains { $0.seasonNumber == n } } ?? result.count - 1
            result[target].episodes += missing
            covered.formUnion(missing.map(\.id))
        }
        return result
    }

    // Saison du dernier épisode regardé, sinon la première (découpage sans filler : la saison qui le contient)
    private func selectStart() {
        if fillerMode, let fillerShow {
            selected = lastWatched?.episode.flatMap { fillerShow.season(of: $0) } ?? fillerShow.seasons.first?.first
        } else if groupMode {
            let last = lastWatched.flatMap { w in groupSeasons.first { $0.episodes.contains { $0.seasonNumber == w.season && $0.episodeNumber == w.episode } } }
            selected = last?.number ?? groupSeasons.first?.number
        } else {
            selected = lastWatched?.season.flatMap { s in seasons.contains { $0.seasonNumber == s } ? s : nil } ?? seasons.first?.seasonNumber
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
            if fillerMode, let range = fillerShow?.range(of: selected) {
                // Toutes les saisons TMDB une fois (Naruto : 4 saisons, Shippuden : 20), puis les épisodes de la saison
                if allEpisodes == nil {
                    let tmdb = model.tmdb
                    let numbers = seasons.map(\.seasonNumber).filter { $0 > 0 }
                    var all: [Episode] = []
                    for n in numbers { all += (try? await tmdb.season(details.id, n).episodes) ?? [] }
                    allEpisodes = all
                }
                episodes = (allEpisodes ?? []).filter { range.contains($0.episodeNumber) }.sorted { $0.episodeNumber < $1.episodeNumber }
            } else if groupMode {
                episodes = groupSeasons.first { $0.number == selected }?.episodes ?? []
            } else {
                episodes = try await model.tmdb.season(details.id, selected).episodes
            }
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
            links[ep.id] = withNetflix(found.filter { fillerShow?.isUnavailable(ep.episodeNumber, on: $0.entry.service) != true }, ep)
        }
    }
}

private struct EpisodeRow: View {
    let episode: Episode
    let links: [EpisodeLink]?
    let linksReady: Bool
    let watched: Bool
    var number: Int? // numéro dans la saison d'un autre découpage (sinon celui de TMDB)
    var absolute = false // découpage sans filler : « épisode 26 » (numéro depuis le début) en plus
    var filler = false
    let onLaunch: (EpisodeLink) -> Void
    let onDownload: (EpisodeLink) -> Void

    private static let day: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    private var meta: String {
        var parts: [String] = []
        if absolute { parts.append("épisode \(episode.episodeNumber)") }
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
                    Text("\(number ?? episode.episodeNumber). \(episode.name ?? "Épisode \(episode.episodeNumber)")")
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(2)
                    if filler {
                        Text("Filler").font(.caption2.weight(.bold)).foregroundStyle(.white)
                            .padding(.horizontal, 7).padding(.vertical, 2)
                            .background(.red, in: .capsule)
                    }
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
                            // Tes abonnements : télécharger l'épisode (comme le ⬇ du site sur téléphone)
                            if link.entry.mine, !link.entry.kind.isPaid {
                                Button {
                                    onDownload(link)
                                } label: {
                                    Image(systemName: "arrow.down.circle").font(.footnote.weight(.semibold))
                                }
                                .buttonStyle(.glass)
                                .accessibilityLabel("Télécharger sur \(link.entry.displayName)")
                            }
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
        // Filler : fond et bord rouges, comme sur le site
        .padding(filler ? 8 : 0)
        .background(filler ? Color.red.opacity(0.12) : .clear, in: .rect(cornerRadius: 12))
        .overlay(alignment: .leading) {
            if filler { Rectangle().fill(.red).frame(width: 3).clipShape(.rect(cornerRadius: 2)) }
        }
    }
}
