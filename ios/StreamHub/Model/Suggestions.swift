import Foundation

// Onglet « Suggestions » de la fiche (portage de suggestions.js du site), dans cet ordre :
// - les autres films de la saga (Harry Potter : les 7 autres films, dans l'ordre de sortie) ;
// - les titres du même univers, films et séries : TMDB ne relie pas un film à une série (Harry Potter → la série HBO,
//   Naruto → Naruto Shippuden, Boruto et les films, Breaking Bad → El Camino et Better Call Saul). Voir universe ;
// - des titres du même genre (conseillés par TMDB, puis proches), ceux de tes abonnements d'abord.
nonisolated enum Suggestions {
    struct Groups: Sendable {
        var sagaName = ""
        var saga: [TMDBTitle] = []
        var universe: [TMDBTitle] = []
        var genre: [TMDBTitle] = []
    }

    // Genres des séries → genres des films équivalents (TMDB n'a pas les mêmes)
    private static let tvToMovie: [Int: [Int]] = [10759: [28, 12], 10765: [878, 14], 10768: [10752], 10762: [10751]]
    private static func genreSet(_ ids: [Int]) -> Set<Int> { Set(ids.flatMap { tvToMovie[$0] ?? [$0] }) }
    // Documentaires, infos, téléréalité, talk-shows : « Harry Potter : Les Sorciers de la pâtisserie »
    private static let offGenres: Set<Int> = [99, 10763, 10764, 10767]
    // Mots-clés TMDB d'une suite ou d'une série dérivée (Better Call Saul : « prequel », « spin off »)
    private static func isSequel(_ keyword: String) -> Bool { keyword.contains(/sequel|prequel|spin.?off|based on (tv series|movie|film)/) }
    // Vérifications (fiche complète d'un titre) au plus : titres contenant le nom, titres conseillés
    private static let maxNamedChecks = 12
    private static let maxRecommendedChecks = 10

    private static func key(_ m: TMDBTitle) -> String { "\(m.type.rawValue):\(m.id)" }

    // Nom de la saga sans « - Saga » / « Collection » : « Harry Potter - Saga » → « Harry Potter »
    static func sagaName(_ name: String?) -> String {
        (name ?? "")
            .replacing(/^(?i)(la )?saga\s+/, with: "")
            .replacing(/(?i)\s*[-–:]?\s*(la saga|saga|the collection|collection)$/, with: "")
            .trimmingCharacters(in: .whitespaces)
    }

    // Le nom en mots entiers dans le titre (« Rogue One : A Star Wars Story » contient « Star Wars »)
    private static func contains(_ title: String?, _ name: String) -> Bool {
        " \(Search.simplify(title ?? "")) ".contains(" \(Search.simplify(name)) ")
    }

    // Noms sous lesquels chercher l'univers : la saga, puis le titre et le titre d'origine avant « : »
    // (« Boruto : Naruto Next Generations » → « Boruto »), sans ceux qui contiennent un nom déjà retenu
    private static func universeNames(_ d: TitleDetails) -> [String] {
        let names = [sagaName(d.belongsToCollection?.name), d.displayTitle, d.originalDisplayTitle]
            .filter { !$0.isEmpty && !TMDBClient.foreignScript($0) }
            .map { String($0.split(separator: /\s*[:–]\s+|\s+-\s+/).first ?? "").trimmingCharacters(in: .whitespaces) }
        var kept: [String] = []
        for (i, n) in names.enumerated() where Search.simplify(n).count > 1 && !names[..<i].contains(where: { contains(n, $0) }) {
            kept.append(n)
        }
        return kept
    }

    // Le titre commence par le nom suivi de rien, d'une ponctuation ou d'un numéro : « Harry Potter », « Star Wars :
    // Andor », « Naruto Shippuden : Les Liens » (les autres alphabets sont ignorés). Pas « Lost in Space » pour « Lost ».
    private static func namedAfter(_ title: String?, _ name: String) -> Bool {
        let text = String((title ?? "").folding(options: .diacriticInsensitive, locale: Locale(identifier: "fr_FR"))
            .lowercased().unicodeScalars.filter { (0x20...0x7E).contains($0.value) }.map(Character.init))
        let words = Search.simplify(name).split(separator: " ").map { NSRegularExpression.escapedPattern(for: String($0)) }
        guard let regex = try? NSRegularExpression(pattern: "^[^a-z0-9]*\(words.joined(separator: "[^a-z0-9]+"))(.*)$"),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text) else { return false }
        let rest = text[range]
        return rest.trimmingCharacters(in: .whitespaces).isEmpty || rest.wholeMatch(of: /\s*([:,(-]|\d|(i{1,3}|iv)\b).*/) != nil
    }

    // Les autres films de la saga, dans l'ordre de sortie
    static func saga(_ tmdb: TMDBClient, _ d: TitleDetails) async -> (name: String, items: [TMDBTitle]) {
        guard let ref = d.belongsToCollection, let saga = try? await tmdb.collection(ref.id) else { return ("", []) }
        let items = saga.parts
            .filter { $0.id != d.id }
            .map { var t = $0; t.mediaType = "movie"; return t }
            .sorted { ($0.date.isEmpty ? "9999" : $0.date) < ($1.date.isEmpty ? "9999" : $1.date) }
        let name = sagaName(saga.name)
        return (name.isEmpty ? sagaName(ref.name) : name, items)
    }

    // Titres du même univers (même méthode que le site). Candidats : recherche TMDB par le nom de l'univers (films et
    // séries, et autres sagas de ce nom) et titres conseillés. Gardés s'ils ont la même langue d'origine, ne sont pas
    // documentaires ni téléréalité (sauf si le titre l'est), sont sortis (5 votes) ou annoncés / sortis depuis moins d'un
    // an, et : nommés d'après l'univers avec un genre en commun ; ou contenant le nom avec une société de production ou un
    // créateur en commun ; ou conseillés avec deux sociétés en commun et un mot-clé de suite ou de série dérivée.
    static func universe(_ tmdb: TMDBClient, _ d: TitleDetails, type: MediaType, exclude: Set<String>) async -> [TMDBTitle] {
        let names = universeNames(d)
        let language = d.originalLanguage
        let baseGenres = genreSet((d.genres ?? []).map(\.id))
        let companies = Set((d.productionCompanies ?? []).map(\.id))
        let creators = Set((d.createdBy ?? []).compactMap(\.id))
        let collectionID = d.belongsToCollection?.id

        async let recommended = (try? await tmdb.recommendations(type, d.id)) ?? []
        let found = await withTaskGroup(of: (Int, [TMDBTitle]).self) { group in
            for (i, name) in names.enumerated() {
                group.addTask { (i * 2, (try? await tmdb.search(name)) ?? []) }
                group.addTask {
                    let sagas = ((try? await tmdb.searchCollections(name)) ?? []).filter { contains($0.name, name) && $0.id != collectionID }.prefix(4)
                    var parts: [TMDBTitle] = []
                    for saga in sagas {
                        parts += ((try? await tmdb.collection(saga.id))?.parts ?? []).map { var t = $0; t.mediaType = "movie"; return t }
                    }
                    return (i * 2 + 1, parts)
                }
            }
            var all: [(Int, [TMDBTitle])] = []
            for await result in group { all.append(result) }
            return all.sorted { $0.0 < $1.0 }.flatMap(\.1)
        }

        var seen = exclude.union(["\(type.rawValue):\(d.id)"])
        let yearAgo = String(ISO8601DateFormatter().string(from: Date().addingTimeInterval(-365 * 86400)).prefix(10))
        let baseOff = !baseGenres.isDisjoint(with: offGenres)
        var candidates: [(m: TMDBTitle, names: [String], recommended: Bool)] = []
        for (m, isRecommended) in found.map({ ($0, false) }) + (await recommended).map({ ($0, true) }) {
            let genres = genreSet(m.genreIds ?? [])
            if seen.contains(key(m)) || m.originalLanguage != language || (!genres.isDisjoint(with: offGenres) && !baseOff) { continue }
            if (m.voteCount ?? 0) < 5 && !(m.date >= yearAgo) { continue }
            let inTitle = names.filter { contains(m.displayTitle, $0) || contains(m.originalTitle ?? m.originalName, $0) }
            if !inTitle.isEmpty && genres.isDisjoint(with: baseGenres) { continue }
            if inTitle.isEmpty && !isRecommended { continue }
            candidates.append((m, inTitle, isRecommended))
        }

        var kept: [TMDBTitle] = []
        var namedChecks = 0
        var recommendedChecks = 0
        for (m, inTitle, _) in candidates where !seen.contains(key(m)) {
            var ok = inTitle.contains { namedAfter(m.displayTitle, $0) || namedAfter(m.originalTitle ?? m.originalName, $0) }
            let named = !inTitle.isEmpty
            if !ok && (named ? namedChecks < maxNamedChecks : recommendedChecks < maxRecommendedChecks) {
                if named { namedChecks += 1 } else { recommendedChecks += 1 }
                if let facts = try? await tmdb.facts(m.type, m.id) {
                    let shared = (facts.productionCompanies ?? []).filter { companies.contains($0.id) }.count
                    let creator = (facts.createdBy ?? []).contains { $0.id.map(creators.contains) ?? false }
                    ok = named ? shared > 0 || creator : shared >= 2 && facts.keywordNames.contains(where: isSequel)
                }
            }
            guard ok else { continue }
            seen.insert(key(m))
            kept.append(m)
        }
        // Les plus connus d'abord (Star Wars en a des dizaines : séries LEGO, parodies…)
        return Array(kept.sorted { ($0.voteCount ?? 0) > ($1.voteCount ?? 0) }.prefix(20))
    }

    // Titres du même genre : conseillés par TMDB, complétés par les titres proches s'il y en a peu ; ceux de tes
    // abonnements d'abord
    static func genre(_ tmdb: TMDBClient, _ d: TitleDetails, type: MediaType, region: String, providers: [Provider]) async -> [TMDBTitle] {
        let recommended = (try? await tmdb.recommendations(type, d.id)) ?? []
        let similar = recommended.count < 12 ? ((try? await tmdb.similar(type, d.id)) ?? []) : []
        var seen = Set<String>()
        let items = (recommended + similar).filter { seen.insert(key($0)).inserted }
        guard !providers.isEmpty else { return items }
        let mine = await withTaskGroup(of: (String, Bool).self) { group in
            for item in items {
                group.addTask {
                    let offers = try? await tmdb.offers(item.type, item.id)
                    return (key(item), (offers?.streamable ?? []).contains { Links.isMine($0, providers: providers) })
                }
            }
            var keys = Set<String>()
            for await (k, isMine) in group where isMine { keys.insert(k) }
            return keys
        }
        return items.filter { mine.contains(key($0)) } + items.filter { !mine.contains(key($0)) }
    }
}
