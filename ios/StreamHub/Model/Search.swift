import Foundation

// Recherche plus tolérante et plus précise que celle de TMDB (portage de search.js du site) :
// - fautes de frappe : comparaison aux titres populaires (data/search/titles.json du site) → « Tu voulais dire… ? »
// - numéro de film : « harry potter 1 » ne garde que le 1er film de la saga (et un éventuel 11e)
// - sagas : films d'une même saga regroupés et rangés dans l'ordre (1, 2, 3)
nonisolated enum Search {
    struct Title: Sendable {
        let words: [[UInt8]] // mots simplifiés
        let shown: [String] // mots tels qu'affichés
        let weight: Int
    }

    // « Grey's Anatomy » → « greys anatomy » (même calcul que le site)
    static func simplify(_ text: String) -> String {
        let plain = text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "fr_FR"))
            .lowercased()
            .replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: "’", with: "")
        return plain.split { !($0.isASCII && ($0.isLetter || $0.isNumber)) }.joined(separator: " ")
    }

    // « harry potter 12 » → (« harry potter », « 12 ») ; numéro vide sans numéro à la fin
    static func splitNumber(_ query: String) -> (text: String, number: String) {
        let s = simplify(query)
        if let m = s.wholeMatch(of: #/(.*\D)\s*(\d{1,3})/#), m.1.trimmingCharacters(in: .whitespaces).count >= 2 {
            return (m.1.trimmingCharacters(in: .whitespaces), String(m.2))
        }
        return (s, "")
    }

    // ---------- Fautes de frappe ----------

    @MainActor private static var loading: Task<[Title], Never>?

    // Liste des titres, chargée à la première recherche
    @MainActor
    static func titles() async -> [Title] {
        if loading == nil {
            loading = Task.detached {
                guard let url = URL(string: "data/search/titles.json", relativeTo: AppStore.site),
                      let (data, response) = try? await URLSession.shared.data(from: url),
                      (response as? HTTPURLResponse)?.statusCode == 200,
                      let list = try? JSONDecoder().decode([JSON].self, from: data) else { return [] }
                return list.compactMap { item -> Title? in
                    guard let title = item.array?.first?.string else { return nil }
                    let pairs = title.split(whereSeparator: { $0 == " " || $0 == "-" || $0 == "–" }).compactMap { word -> ([UInt8], String)? in
                        let simple = simplify(String(word)).replacingOccurrences(of: " ", with: "")
                        guard !simple.isEmpty else { return nil }
                        return (Array(simple.utf8), String(word).trimmingCharacters(in: CharacterSet(charactersIn: ":,;.!?")))
                    }
                    return Title(words: pairs.map(\.0), shown: pairs.map(\.1), weight: item.array?.last?.int ?? 0)
                }
            }
        }
        let list = await loading!.value
        if list.isEmpty { loading = nil } // réessayer à la prochaine recherche
        return list
    }

    // Distance de Damerau-Levenshtein ; au-delà de max : max + 1
    private static func distance(_ a: [UInt8], _ b: [UInt8], _ max: Int) -> Int {
        if abs(a.count - b.count) > max { return max + 1 }
        if a.isEmpty || b.isEmpty { return Swift.max(a.count, b.count) }
        var prev2: [Int] = []
        var prev = Array(0...b.count)
        for i in 1...a.count {
            var cur = [i] + Array(repeating: 0, count: b.count)
            var best = i
            for j in 1...b.count {
                var v = Swift.min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1))
                if !prev2.isEmpty, i > 1, j > 1, a[i - 1] == b[j - 2], a[i - 2] == b[j - 1] { v = Swift.min(v, prev2[j - 2] + 1) }
                cur[j] = v
                best = Swift.min(best, v)
            }
            if best > max { return max + 1 }
            prev2 = prev
            prev = cur
        }
        return prev[b.count]
    }

    // Correction proposée (« Harry Potter 1 » pour « hary poter 1 »), ou nil si la recherche correspond déjà à un titre
    // (ou à son début : « harry pot »). Au plus une faute pour 4 lettres, 3 en tout ; à égalité, le plus populaire.
    static func suggest(_ query: String, in list: [Title]) -> String? {
        let (text, number) = splitNumber(query)
        let words = text.split(separator: " ").map { Array($0.utf8) }
        guard let typed = words.last else { return nil }
        let joined = words.map { String(decoding: $0, as: UTF8.self) }.joined(separator: " ")
        let glued = Array(words.joined())
        let max = Swift.min(3, glued.count / 4)
        guard max > 0 else { return nil }
        var best: (d: Int, weight: Int, shown: String)?
        for t in list {
            for size in [words.count, words.count + 1] where size <= t.words.count {
                for i in 0...(t.words.count - size) {
                    let win = Array(t.words[i..<(i + size)])
                    let end = win[size - 1]
                    let cutWords = end.count > typed.count ? win.dropLast() + [Array(end.prefix(typed.count))] : win
                    if size == words.count, cutWords.map({ String(decoding: $0, as: UTF8.self) }).joined(separator: " ") == joined {
                        return nil // un vrai titre (ou son début) : rien à corriger
                    }
                    let full = Array(win.joined())
                    let cut = Array(cutWords.joined())
                    if Swift.min(abs(full.count - glued.count), abs(cut.count - glued.count)) > max { continue }
                    let limit = best.map { Swift.min(max, $0.d) } ?? max
                    let d = Swift.min(distance(glued, full, limit), distance(glued, cut, limit))
                    if d <= max, best == nil || d < best!.d || (d == best!.d && t.weight > best!.weight) {
                        best = (d, t.weight, t.shown[i..<(i + size)].joined(separator: " "))
                    }
                }
            }
        }
        guard let best else { return nil }
        return number.isEmpty ? best.shown : "\(best.shown) \(number)"
    }

    // ---------- Sagas et numéros ----------

    private static let roman = ["i": 1, "ii": 2, "iii": 3, "iv": 4, "v": 5, "vi": 6, "vii": 7, "viii": 8, "ix": 9, "x": 10]

    // Numéro écrit juste après le nom dans le titre (« Toy Story 3 », « Rocky II »), sinon nil
    private static func numberInTitle(_ item: TMDBTitle, text: String) -> Int? {
        for title in [item.displayTitle, item.originalTitle ?? item.originalName ?? ""] {
            let s = simplify(title)
            guard s.hasPrefix(text) else { continue }
            let next = s.dropFirst(text.count).split(separator: " ").first.map(String.init) ?? ""
            if let n = Int(next) { return n }
            if let n = roman[next] { return n }
        }
        return nil
    }

    // Range les résultats : chaque saga regroupée à la place de son premier film, dans l'ordre de sortie ; avec un numéro,
    // seuls les films dont le numéro commence par celui-ci (1, 10, 11…), sauf si aucun ne correspond.
    @MainActor
    static func arrangeSagas(_ results: [TMDBTitle], query: String, tmdb: TMDBClient) async -> [TMDBTitle] {
        let (text, number) = splitNumber(query)
        let movies = results.filter { $0.type == .movie }.prefix(20)
        var collectionIDs = Set<Int>()
        await withTaskGroup(of: Int?.self) { group in
            for movie in movies { group.addTask { try? await tmdb.collectionID(ofMovie: movie.id) } }
            for await id in group { if let id { collectionIDs.insert(id) } }
        }
        // Avec un numéro, la saga peut manquer des résultats (« harry potter 1 » ne trouve pas le 1er film)
        if !number.isEmpty, let found = try? await tmdb.searchCollections(text) {
            for c in found.prefix(2) where simplify(c.name).hasPrefix(text) { collectionIDs.insert(c.id) }
        }
        var collections: [TMDBClient.Collection] = []
        await withTaskGroup(of: TMDBClient.Collection?.self) { group in
            for id in collectionIDs { group.addTask { try? await tmdb.collection(id) } }
            for await c in group { if let c { collections.append(c) } }
        }

        // Position de chaque film dans sa saga (films sortis, dans l'ordre de sortie)
        var place: [Int: (collection: Int, index: Int)] = [:]
        for c in collections {
            let parts = c.parts.filter { !($0.releaseDate ?? "").isEmpty }.sorted { ($0.releaseDate ?? "") < ($1.releaseDate ?? "") }
            for (index, p) in parts.enumerated() { place[p.id] = (c.id, index) }
        }
        let placeOf = { (m: TMDBTitle) in m.type == .movie ? place[m.id] : nil }

        var list = results
        if !number.isEmpty {
            for c in collections {
                for p in c.parts where !list.contains(where: { $0.type == .movie && $0.id == p.id }) {
                    var part = p
                    part.mediaType = "movie"
                    list.append(part)
                }
            }
            let numberOf = { (m: TMDBTitle) -> Int? in placeOf(m).map { $0.index + 1 } ?? numberInTitle(m, text: text) }
            let matching = list.filter { numberOf($0).map { String($0).hasPrefix(number) } ?? false }
            list = matching.isEmpty ? results : matching.sorted { (numberOf($0) ?? 0) < (numberOf($1) ?? 0) }
        }

        // Regroupement des sagas, à la place du premier film de chacune
        var out: [TMDBTitle] = []
        var done = Set<Int>()
        for m in list {
            guard let p = placeOf(m) else { out.append(m); continue }
            guard done.insert(p.collection).inserted else { continue }
            out += list.filter { placeOf($0)?.collection == p.collection }.sorted { placeOf($0)!.index < placeOf($1)!.index }
        }
        return out
    }
}
