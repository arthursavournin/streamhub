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

    // ---------- Numéro et partie ----------

    private static let roman = ["i": 1, "ii": 2, "iii": 3, "iv": 4, "v": 5, "vi": 6, "vii": 7, "viii": 8, "ix": 9, "x": 10]
    private static let numberWords = [
        "un": 1, "une": 1, "one": 1, "premier": 1, "premiere": 1, "first": 1,
        "deux": 2, "two": 2, "deuxieme": 2, "second": 2, "seconde": 2,
        "trois": 3, "three": 3, "troisieme": 3, "third": 3, "quatre": 4, "four": 4, "quatrieme": 4, "fourth": 4,
    ]
    // Mots qui annoncent une partie (« 2e partie », « Part Two », « Vol. 2 »). Pas « chapitre » : c'est le numéro de la
    // suite (« Twilight, chapitre 4 : Révélation, 1re partie »).
    private static let partWords: Set<String> = ["partie", "part", "volume", "vol"]

    // « 2 », « 2eme », « 2nd », « ii », « deux » → 2 ; sinon nil
    private static func toNumber(_ word: String) -> Int? {
        if let m = word.wholeMatch(of: #/(\d{1,3})(?:e|er|ere|eme|nd|st|rd|th)?/#) { return Int(m.1) }
        return roman[word] ?? numberWords[word]
    }

    // Partie écrite dans des mots (« … 2eme partie », « … part two ») : numéro et début du titre avant la partie, sans ses
    // numéros (pour reconnaître les parties d'un même film). S'il y a plusieurs mentions (« Twilight, chapitre 4 :
    // Révélation, 1re partie »), la dernière est la partie.
    private static func part(in words: [String]) -> (n: Int, prefix: String)? {
        var best: (n: Int, start: Int)?
        for (i, w) in words.enumerated() where partWords.contains(w) {
            if i > 0, let n = toNumber(words[i - 1]), (best?.start ?? -1) < i - 1 { best = (n, i - 1) }
            if i + 1 < words.count, let n = toNumber(words[i + 1]), (best?.start ?? -1) < i { best = (n, i) }
        }
        guard let best else { return nil }
        return (best.n, words[..<best.start].filter { toNumber($0) == nil }.joined(separator: " "))
    }

    private static func partOf(_ item: TMDBTitle) -> (n: Int, prefix: String)? {
        for title in [item.displayTitle, item.originalTitle ?? item.originalName ?? ""] {
            if let p = part(in: simplify(title).split(separator: " ").map(String.init)) { return p }
        }
        return nil
    }

    // « harry potter 7 partie 2 » → (« harry potter », « 7 », 2, « 7 partie 2 »). Le numéro du film est le premier
    // nombre après le nom ; la suite peut préciser une partie.
    static func parseQuery(_ query: String) -> (text: String, number: String, part: Int?, rest: String) {
        let words = simplify(query).split(separator: " ").map(String.init)
        guard let i = words.indices.first(where: { $0 > 0 && words[$0].wholeMatch(of: #/\d{1,3}/#) != nil }),
              words[..<i].joined(separator: " ").count >= 2 else { return (words.joined(separator: " "), "", nil, "") }
        return (words[..<i].joined(separator: " "), words[i], part(in: Array(words[(i + 1)...]))?.n, words[i...].joined(separator: " "))
    }

    // (nom, numéro) : pour la recherche sans le numéro (« harry potter 1 » → « harry potter »)
    static func splitNumber(_ query: String) -> (text: String, number: String) {
        let q = parseQuery(query)
        return (q.text, q.number)
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
        let (text, _, _, rest) = parseQuery(query)
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
        return rest.isEmpty ? best.shown : "\(best.shown) \(rest)"
    }

    // ---------- Sagas et numéros ----------

    // Numéro écrit juste après le nom dans le titre (« Toy Story 3 », « Rocky II »), sinon nil
    private static func numberInTitle(_ item: TMDBTitle, text: String) -> Int? {
        for title in [item.displayTitle, item.originalTitle ?? item.originalName ?? ""] {
            let s = simplify(title)
            guard (s + " ").hasPrefix(text + " ") else { continue } // mots entiers : « dune » n'est pas le début de « dunes »
            let next = s.dropFirst(text.count).split(separator: " ").first.map(String.init) ?? ""
            if let n = Int(next) { return n }
            if let n = roman[next] { return n }
        }
        return nil
    }

    // Range les résultats : chaque saga regroupée à la place de son premier film, dans l'ordre de sortie.
    // Avec un numéro, seuls les films dont le rang dans la saga commence par celui-ci (1, 10, 11…). Avec une partie
    // (« harry potter 7 partie 2 ») : les films en plusieurs parties partagent un numéro (Les Reliques de la Mort 1 et 2
    // = 7), on garde le numéro et la partie demandés. Sans film correspondant, tous les résultats restent.
    @MainActor
    static func arrangeSagas(_ found: [TMDBTitle], query: String, tmdb: TMDBClient) async -> [TMDBTitle] {
        let (text, number, wantedPart, _) = parseQuery(query)
        var seen = Set<String>()
        let results = found.filter { seen.insert("\($0.type.rawValue):\($0.id)").inserted }
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

        // Position de chaque film dans sa saga (ordre de sortie), et numéro « logique » : un film coupé en parties qui se
        // suivent (« … 1re partie », « … 2e partie », même début de titre) n'a qu'un numéro. Le groupe doit commencer à la
        // 1re partie : chez Dune, « Deuxième partie » et « Troisième partie » sont des suites, pas un même film.
        struct Place { let collection: Int; let name: String; let index: Int; let logical: Int; let part: Int? }
        var place: [Int: Place] = [:]
        for c in collections {
            let parts = c.parts.filter { !($0.releaseDate ?? "").isEmpty }.sorted { ($0.releaseDate ?? "") < ($1.releaseDate ?? "") }
            var logical = 0
            var previous: (n: Int, prefix: String)? // partie du film précédent, si son groupe a commencé à la 1re partie
            for (index, p) in parts.enumerated() {
                let info = partOf(p)
                let sameFilm = info != nil && previous != nil && previous!.prefix == info!.prefix && info!.n == previous!.n + 1
                if !sameFilm { logical += 1 }
                previous = info != nil && (sameFilm || info!.n == 1) ? info : nil
                place[p.id] = Place(collection: c.id, name: c.name, index: index, logical: logical, part: info?.n)
            }
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
            // Saga du film, seulement si elle correspond au nom cherché (nom de la saga ou titre, mots entiers ; apostrophe
            // = séparation : « d'une » ne contient pas « dune »). Pour « dune 2 », Millénium 2 ne compte pas.
            let words = { (t: String) in " " + simplify(t.replacingOccurrences(of: "'", with: " ").replacingOccurrences(of: "’", with: " ")) + " " }
            let sagaOf = { (m: TMDBTitle) -> Place? in
                guard let p = placeOf(m) else { return nil }
                let names = [p.name, m.displayTitle, m.originalTitle ?? m.originalName ?? ""]
                return names.contains { words($0).contains(" \(text) ") } ? p : nil
            }
            let numberOf = { (m: TMDBTitle) -> Int? in sagaOf(m).map { $0.index + 1 } ?? numberInTitle(m, text: text) }
            let starts = { (n: Int?) in n.map { String($0).hasPrefix(number) } ?? false }
            var matching: [TMDBTitle] = []
            if let wantedPart {
                matching = list.filter { m in
                    if let p = sagaOf(m) { return starts(p.logical) && p.part == wantedPart }
                    return starts(numberInTitle(m, text: text)) && partOf(m)?.n == wantedPart
                }
            }
            // Sans partie : le rang, et toutes les parties du numéro (« harry potter 7 » : Reliques 1re et 2e partie)
            if matching.isEmpty { matching = list.filter { starts(numberOf($0)) || starts(sagaOf($0)?.logical) } }
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
