import Foundation

// Recherche par surnom ou sigle (« DNA » → Demain nous appartient), que TMDB ne connaît pas (comme aliases.js du site).
// Wikidata (la base de Wikipédia) recense ces alias et, pour chaque œuvre, son identifiant TMDB. Gratuit, sans clé.
nonisolated enum Aliases {
    struct Match: Hashable, Sendable {
        let type: MediaType
        let id: Int
    }

    // Sigles courants absents de Wikidata (ou mal reliés à TMDB), vérifiés à la main sur TMDB (mêmes que le site)
    private static let known: [String: [Match]] = [
        "pblv": [Match(type: .tv, id: 8590), Match(type: .tv, id: 243117)], // Plus belle la vie (+ encore plus belle)
        "twd": [Match(type: .tv, id: 1402)], // The Walking Dead
        "tbbt": [Match(type: .tv, id: 1418)], // The Big Bang Theory
        "b99": [Match(type: .tv, id: 48891)], // Brooklyn Nine-Nine
        "oitnb": [Match(type: .tv, id: 1424)], // Orange Is the New Black
        "svu": [Match(type: .tv, id: 2734)], // New York, unité spéciale
        "hpi": [Match(type: .tv, id: 112738)], // HPI : Haut Potentiel Intellectuel
        "lcdp": [Match(type: .tv, id: 71446)], // La casa de papel
        "fpcfpc": [Match(type: .tv, id: 35690)], // Fais pas ci, fais pas ça
        "sdm": [Match(type: .tv, id: 55216)], // Scènes de ménages
        "itc": [Match(type: .tv, id: 112470)], // Ici tout commence
        "usgs": [Match(type: .tv, id: 81329)], // Un si grand soleil
        "hotd": [Match(type: .tv, id: 94997)], // House of the Dragon
        "got": [Match(type: .tv, id: 1399)], // Game of Thrones
        "himym": [Match(type: .tv, id: 1100)], // How I Met Your Mother
        "dna": [Match(type: .tv, id: 72879)], // Demain nous appartient
    ]

    // Une même recherche (frappe après frappe) n'interroge Wikidata qu'une fois
    @MainActor private static var cache: [String: Task<[Match], Never>] = [:]

    // Titres correspondant à un surnom ou sigle : liste intégrée + Wikidata
    @MainActor static func matches(_ query: String) async -> [Match] {
        let q = query.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "\"", with: "").replacingOccurrences(of: "\\", with: "")
        guard q.count >= 2 else { return [] }
        let key = q.lowercased()
        if let task = cache[key] { return await task.value }
        let fixed = known[key.filter { $0.isLetter && $0.isASCII || $0.isNumber }] ?? []
        let task = Task { () -> [Match] in
            let found = (try? await wikidata(q)) ?? []
            var seen = Set<Match>()
            return (fixed + found).filter { seen.insert($0).inserted }
        }
        cache[key] = task
        return await task.value
    }

    private static func get(_ params: [String: String]) async throws -> Any {
        var url = URLComponents(string: "https://www.wikidata.org/w/api.php")!
        url.queryItems = (params.merging(["format": "json"]) { a, _ in a }).map { URLQueryItem(name: $0.key, value: $0.value) }
        var request = URLRequest(url: url.url!)
        request.setValue("StreamHub (https://arthursavournin.github.io/streamhub/)", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        return try JSONSerialization.jsonObject(with: data)
    }

    // Œuvres dont le nom ou un alias en français est exactement la recherche, et qui ont un identifiant TMDB
    // (P4983 : série, P4947 : film)
    private static func wikidata(_ q: String) async throws -> [Match] {
        let search = try await get([
            "action": "query", "list": "search", "srlimit": "5",
            "srsearch": "inlabel:\"\(q)\"@fr haswbstatement:P4983|P4947",
        ]) as? [String: Any]
        let ids = ((search?["query"] as? [String: Any])?["search"] as? [[String: Any]] ?? []).compactMap { $0["title"] as? String }
        guard !ids.isEmpty else { return [] }
        let found = try await get(["action": "wbgetentities", "ids": ids.joined(separator: "|"), "props": "claims"]) as? [String: Any]
        let entities = found?["entities"] as? [String: Any] ?? [:]
        var matches: [Match] = []
        for id in ids {
            let claims = (entities[id] as? [String: Any])?["claims"] as? [String: Any] ?? [:]
            for (prop, type) in [("P4983", MediaType.tv), ("P4947", MediaType.movie)] {
                let snak = ((claims[prop] as? [[String: Any]])?.first?["mainsnak"] as? [String: Any])
                if let value = (snak?["datavalue"] as? [String: Any])?["value"] as? String, let n = Int(value) {
                    matches.append(Match(type: type, id: n))
                }
            }
        }
        return matches
    }
}
