import Foundation

// Découpage « Netflix - Sans filler » (Naruto, Naruto Shippuden ; demande de l'utilisateur) : saisons et épisodes
// hors-série d'après la liste d'animotaku.fr, publiés avec le site (fillers.json, numérotation absolue = TMDB)
nonisolated struct FillerShow: Decodable, Sendable {
    let name: String
    let seasons: [[Int]] // [numéro, premier épisode, dernier épisode]
    let fillers: [[Int]] // [premier, dernier]
    let seasonNames: [String: String]? // titres des saisons sur Netflix (Boruto), par numéro

    func isFiller(_ episode: Int) -> Bool { fillers.contains { $0.count == 2 && episode >= $0[0] && episode <= $0[1] } }

    // Saison du découpage qui contient cet épisode (numérotation absolue)
    func season(of episode: Int) -> Int? { seasons.first { $0.count == 3 && episode >= $0[1] && episode <= $0[2] }?[0] }

    func range(of season: Int) -> ClosedRange<Int>? {
        seasons.first { $0.count == 3 && $0[0] == season }.map { $0[1]...$0[2] }
    }

    // Nombre de fillers d'une saison, et si elle n'a que ça
    func fillerCount(of season: Int) -> (count: Int, all: Bool) {
        guard let range = range(of: season) else { return (0, false) }
        let count = range.filter(isFiller).count
        return (count, count == range.count)
    }
}

enum Fillers {
    private nonisolated struct File: Decodable { let shows: [String: FillerShow] }
    private static var file: File?

    static func show(_ tmdbID: Int) async -> FillerShow? {
        if file == nil, let url = URL(string: "fillers.json", relativeTo: AppStore.site),
           let (data, response) = try? await URLSession.shared.data(from: url), (response as? HTTPURLResponse)?.statusCode == 200 {
            file = try? JSONDecoder().decode(File.self, from: data)
        }
        return file?.shows[String(tmdbID)]
    }
}
