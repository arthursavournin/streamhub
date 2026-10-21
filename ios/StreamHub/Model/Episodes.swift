import Foundation

// Saisons et épisodes d'une série, et le lien de chaque épisode sur tes plateformes (comme la fiche du site)

nonisolated struct SeasonSummary: Decodable, Hashable, Sendable {
    let seasonNumber: Int
    let name: String?
    let episodeCount: Int?
    let airDate: String?
    let posterPath: String?

    var title: String { seasonNumber == 0 ? "Épisodes spéciaux" : "Saison \(seasonNumber)" }
}

nonisolated struct Episode: Decodable, Identifiable, Hashable, Sendable {
    let episodeNumber: Int
    let seasonNumber: Int
    let name: String?
    let overview: String?
    let stillPath: String?
    let airDate: String?
    let runtime: Int?

    var id: String { "\(seasonNumber)-\(episodeNumber)" }
}

nonisolated struct SeasonDetails: Decodable, Sendable {
    let episodes: [Episode]
}

// Lien d'un épisode sur une plateforme (bouton sous l'épisode)
nonisolated struct EpisodeLink: Identifiable, Hashable, Sendable {
    let label: String
    let entry: WatchEntry // plateforme et lien, comme un bouton « Regarder sur… »
    var id: String { "\(entry.name)|\(label)" }
}

// Liens Streaming Availability d'une série, par saison et par épisode
nonisolated struct SASeason: Sendable {
    let number: Int
    let options: [LinkResolver.SAOption]
    let episodes: [Int: [LinkResolver.SAOption]]
}

// Index des épisodes TF1+ et M6+ publié avec le site (scripts/build_episode_index.py) : leurs liens d'épisode
// contiennent un identifiant impossible à deviner.
//   data/<plateforme>/_programs.json : nom simplifié → programme
//   data/<plateforme>/<programme>.json : { base, e: numéro absolu, s: « saison-épisode », d: date }
enum EpisodeIndex {
    static let platforms: Set<String> = ["tf1", "m6"]

    private struct Program: Decodable {
        let base: String
        let e: [String: String]?
        let s: [String: String]?
        let d: [String: String]?
    }

    private static var programs: [String: [String: String]] = [:]
    private static var files: [String: Program] = [:]

    private static func load<T: Decodable>(_ path: String) async -> T? {
        guard let url = URL(string: path, relativeTo: AppStore.site),
              let (data, response) = try? await URLSession.shared.data(from: url),
              (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    // Lien direct de l'épisode, nil si introuvable. Recherche : saison-épisode, date de diffusion, numéro absolu
    // (feuilletons quotidiens : « épisode 2299 »).
    static func link(platform: String, titles: [String], season: Int, episode: Int, airDate: String?, absolute: Int?) async -> String? {
        guard platforms.contains(platform) else { return nil }
        if programs[platform] == nil, let list: [String: String] = await load("data/\(platform)/_programs.json") { programs[platform] = list }
        guard let name = titles.map(Platforms.simplify).lazy.compactMap({ programs[platform]?[$0] }).first else { return nil }
        let key = "\(platform)/\(name)"
        if files[key] == nil, let file: Program = await load("data/\(platform)/\(name).json") { files[key] = file }
        guard let index = files[key] else { return nil }
        let file = index.s?["\(season)-\(episode)"]
            ?? airDate.flatMap { index.d?[$0] }
            ?? absolute.flatMap { index.e?[String($0)] }
        return file.map { index.base + $0 }
    }
}

enum EpisodeLinks {
    static let streamTypes: Set<String> = ["subscription", "free", "addon"]

    // Une option Streaming Availability est-elle dans tes abonnements ? Une chaîne vendue en plus (« addon ») ne l'est
    // que si tu as coché cette chaîne.
    static func isMine(_ o: LinkResolver.SAOption, providers: [Provider]) -> Bool {
        if o.type == "addon" {
            let addon = Platforms.squash(o.addon)
            return !addon.isEmpty && providers.contains { Platforms.squash($0.name).contains(addon) }
        }
        return providers.contains { Platforms.service(for: $0.name)?.id == o.service }
    }

    // Options par abonnement, une par plateforme (ou chaîne), tes abonnements en premier
    static func streamOptions(_ options: [LinkResolver.SAOption], providers: [Provider]) -> [LinkResolver.SAOption] {
        var seen = Set<String>()
        return options
            .filter { streamTypes.contains($0.type) && seen.insert("\($0.service ?? ""):\($0.addon ?? "")").inserted }
            .sorted { isMine($0, providers: providers) && !isMine($1, providers: providers) }
    }

    private static func entry(for o: LinkResolver.SAOption, providers: [Provider]) -> WatchEntry? {
        guard let link = o.link else { return nil }
        let name = o.name ?? o.service ?? ""
        return WatchEntry(
            name: name, logo: nil, kind: .flatrate, mine: isMine(o, providers: providers), service: o.service,
            href: o.videoLink ?? Platforms.autoplayLink(link) ?? link, page: link, hint: "Lecture directe", direct: true
        )
    }

    // Liens d'un épisode, dans l'ordre du site : liens de l'épisode (Streaming Availability), sinon ceux de la saison,
    // sinon pour chacune de tes plateformes : lien direct (TF1+, M6+ grâce à l'index), page des épisodes ou page de la série.
    static func links(for ep: Episode, sa: [SASeason], entries: [WatchEntry], titles: [String], absolute: Int?, providers: [Provider]) async -> [EpisodeLink] {
        let saSeason = sa.first { $0.number == ep.seasonNumber }
        let episodeOptions = streamOptions(saSeason?.episodes[ep.episodeNumber] ?? [], providers: providers)
        if !episodeOptions.isEmpty {
            var out = episodeOptions.compactMap { o in
                entry(for: o, providers: providers).map { e in
                    EpisodeLink(label: o.addon.map { "\($0) (\(Platforms.shortName(e.name)))" } ?? Platforms.shortName(e.name), entry: e)
                }
            }
            // Tes plateformes qui ont la série mais pas de lien pour cet épisode (Streaming Availability ne connaît que
            // les 15 premiers épisodes de Boruto sur Netflix, qui les a tous) : bouton vers la page de la série
            let covered = Set(out.map { Platforms.hostService(for: $0.entry.name)?.id ?? $0.entry.name })
            for e in entries where e.mine && !Platforms.isChannel(e.name) {
                let key = Platforms.hostService(for: e.name)?.id ?? e.name
                guard !covered.contains(key), let page = e.page else { continue }
                var link = e
                link.href = page
                out.append(EpisodeLink(label: "\(Platforms.shortName(e.name)) · page de la série", entry: link))
            }
            return out
        }
        let seasonOptions = streamOptions(saSeason?.options ?? [], providers: providers)
        if !seasonOptions.isEmpty {
            return seasonOptions.compactMap { o in
                entry(for: o, providers: providers).map { EpisodeLink(label: "La saison sur \(Platforms.shortName($0.name))", entry: $0) }
            }
        }
        var out: [EpisodeLink] = []
        for e in entries where e.mine {
            let name = Platforms.shortName(e.name)
            let platform = Platforms.hostService(for: e.name)?.id ?? ""
            if let direct = await EpisodeIndex.link(platform: platform, titles: titles, season: ep.seasonNumber, episode: ep.episodeNumber, airDate: ep.airDate, absolute: absolute) {
                var link = e
                link.href = direct
                out.append(EpisodeLink(label: name, entry: link))
            } else if let list = Platforms.hostService(for: e.name)?.episodes?(titles.first ?? "") {
                var link = e
                link.href = list
                out.append(EpisodeLink(label: "Voir les épisodes sur \(name)", entry: link))
            } else {
                var link = e
                link.href = e.page ?? e.href
                out.append(EpisodeLink(label: "Ouvrir la série sur \(name)", entry: link))
            }
        }
        return out
    }
}
