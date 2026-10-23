import SwiftUI

// Résultats de la recherche tapée dans la barre du haut (version 2.5.0, comme le site sur iPhone : pas de page à part,
// les résultats remplacent la page dès qu'on tape). Tolérante aux fautes, avec numéro de film, sagas dans l'ordre
// (Search.swift) et surnoms ou sigles (Aliases.swift). Comme sur le site : Tout / Films / Séries, plateformes, genre,
// et seulement les titres de tes abonnements (les autres derrière « tout afficher », pour éviter une fausse joie).
struct SearchResults: View {
    @Environment(AppModel.self) private var model
    @Binding var query: String
    @State private var results: [TMDBTitle] = []
    @State private var suggestion: String?
    @State private var error: String?
    @State private var searching = false
    @State private var type: CatalogType = .all
    @State private var platform: PlatformChoice?
    @State private var genre: CatalogGenre?
    @State private var genres: [CatalogGenre] = []
    @State private var offers: [String: [ProviderOffer]] = [:] // titre → offres abonnement / gratuites (une fois par titre)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                controls
                if let suggestion {
                    // « Tu voulais dire… ? » : corrige la recherche et la relance
                    Button {
                        query = suggestion
                    } label: {
                        Text("Tu voulais dire \(Text("« \(suggestion) »").bold()) ?")
                            .font(.callout)
                    }
                    .padding(.horizontal, 16)
                }
                if let error {
                    EmptyMessage(title: "Recherche impossible", systemImage: "wifi.exclamationmark", message: error)
                        .padding(.top, 40)
                } else if typed.isEmpty, !searching {
                    EmptyMessage(title: "Aucun résultat", systemImage: "magnifyingglass", message: "Essaie un autre titre.")
                        .padding(.top, 40)
                } else if shown.isEmpty, !checking, !searching {
                    // Rien sur tes abonnements : on le dit, sans montrer les autres d'office
                    EmptyMessage(title: "Pas sur \(whereText)", systemImage: "tv.slash",
                                 message: "Aucun \(noun) trouvé pour « \(query.trimmingCharacters(in: .whitespaces)) » sur \(whereText).")
                        .padding(.top, 30)
                    if hidden > 0 { showAllButton }
                } else {
                    if hidden > 0 || (platform == .all && filtering) { showAllButton }
                    PosterGrid(refs: shown.map(\.ref), captions: shown.captions)
                    if checking || searching {
                        ProgressView().frame(maxWidth: .infinity).padding(.vertical, 12)
                    }
                }
            }
            .padding(.vertical, 8)
        }
        .scrollDismissesKeyboard(.immediately)
        .background(Color.appBackground)
        .task {
            if platform == nil { platform = filtering ? .mine : .all }
            if genres.isEmpty { genres = await CatalogView.loadGenres(model.tmdb) }
        }
        .task(id: query) { await search() }
        .task(id: results.map { key($0) }) { await checkOffers() }
    }

    // ---------- Filtres (comme la Bibliothèque) ----------

    private var controls: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("Type", selection: $type) {
                ForEach(CatalogType.allCases, id: \.self) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    Menu {
                        Picker("Plateformes", selection: $platform) {
                            if filtering { Text("Mes plateformes").tag(PlatformChoice?.some(.mine)) }
                            Text("Toutes les plateformes").tag(PlatformChoice?.some(.all))
                            ForEach(model.store.providers) { p in Text(Platforms.shortName(p.name)).tag(PlatformChoice?.some(.one(p.id))) }
                        }
                    } label: { filterLabel(platformName, systemImage: "tv") }
                    Menu {
                        Picker("Genre", selection: $genre) {
                            Text("Tous les genres").tag(CatalogGenre?.none)
                            ForEach(genres, id: \.self) { Text($0.name).tag(CatalogGenre?.some($0)) }
                        }
                    } label: { filterLabel(genre?.name ?? "Tous les genres", systemImage: "theatermasks") }
                }
            }
            .scrollIndicators(.hidden)
        }
        .padding(.horizontal, 16)
    }

    private func filterLabel(_ text: String, systemImage: String) -> some View {
        Label(text, systemImage: systemImage)
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, 12).padding(.vertical, 8)
            .glassEffect(.regular.interactive(), in: .capsule)
    }

    private var platformName: String {
        switch platform ?? .all {
        case .mine: "Mes plateformes"
        case .all: "Toutes les plateformes"
        case .one(let id): model.store.providers.first { $0.id == id }.map { Platforms.shortName($0.name) } ?? "Plateforme"
        }
    }

    // ---------- Tri des résultats ----------

    private func key(_ t: TMDBTitle) -> String { "\(t.type.rawValue):\(t.id)" }
    private var filtering: Bool { !model.store.providers.isEmpty } // aucun abonnement coché : tout le catalogue
    // Plateformes demandées (nil : toutes)
    private var wanted: [Provider]? {
        switch platform ?? .all {
        case .mine: model.store.providers
        case .all: nil
        case .one(let id): model.store.providers.filter { $0.id == id }
        }
    }
    private var typed: [TMDBTitle] { results.filter { type.types.contains($0.type) && matchesGenre($0) } }
    private func isWanted(_ t: TMDBTitle) -> Bool? {
        guard let wanted else { return true }
        guard let list = offers[key(t)] else { return nil } // pas encore vérifié
        return list.contains { Links.isMine($0, providers: wanted) }
    }
    private var shown: [TMDBTitle] { typed.filter { isWanted($0) == true } }
    private var hidden: Int { wanted == nil ? 0 : typed.filter { isWanted($0) == false }.count }
    private var checking: Bool { wanted != nil && typed.contains { isWanted($0) == nil } }
    private var noun: String { type == .movie ? "film" : type == .tv ? "série" : "titre" }
    private var whereText: String {
        if case .one = platform ?? .all { return platformName }
        return "tes abonnements"
    }

    // Genre choisi : tous ses identifiants dans le titre ; animés japonais : animation en japonais (comme matchesGenre)
    private func matchesGenre(_ t: TMDBTitle) -> Bool {
        guard let genre else { return true }
        guard let id = genre.id(for: t.type), t.genreIds?.contains(id) == true else { return false }
        return genre.extra["with_origin_country"] == nil || t.originalLanguage == "ja"
    }

    @ViewBuilder private var showAllButton: some View {
        Button {
            platform = platform == .all ? (filtering ? .mine : .all) : .all
        } label: {
            Text(platform == .all ? "Seulement mes abonnements" : "\(hidden) autre\(hidden > 1 ? "s" : "") hors de \(whereText) — tout afficher")
                .font(.callout)
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: shown.isEmpty ? .center : .leading)
    }

    // Offres de chaque titre trouvé (les mêmes que sa fiche) ; une série sans aucune offre dans le pays peut être une
    // création d'une de tes plateformes pas encore référencée par JustWatch (VisionQuest) : on lit alors sa fiche
    private func checkOffers() async {
        guard filtering else { return }
        let tmdb = model.tmdb
        let region = model.store.region
        let todo = results.filter { offers[key($0)] == nil }
        guard !todo.isEmpty else { return }
        await withTaskGroup(of: (String, [ProviderOffer]).self) { group in
            for item in todo {
                let k = key(item)
                group.addTask {
                    let streamable = (try? await tmdb.offers(item.type, item.id))?.streamable ?? []
                    guard item.type == .tv, streamable.isEmpty else { return (k, streamable) }
                    return (k, (try? await tmdb.details(.tv, item.id))?.watchProviders?.results[region]?.streamable ?? [])
                }
            }
            for await (k, list) in group { offers[k] = list }
        }
    }

    // ---------- Recherche ----------

    private func searchOrEmpty(_ tmdb: TMDBClient, _ query: String?) async -> [TMDBTitle] {
        guard let query else { return [] }
        return (try? await tmdb.search(query)) ?? []
    }

    // Titres trouvés par surnom ou sigle et absents de la recherche TMDB : placés en tête (comme aliasResults du site)
    private func aliasTitles(_ tmdb: TMDBClient, _ matches: [Aliases.Match], besides found: [TMDBTitle]) async -> [TMDBTitle] {
        let wanted = matches.filter { m in !found.contains { $0.id == m.id && $0.type == m.type } }
        var titles: [TMDBTitle?] = Array(repeating: nil, count: wanted.count)
        await withTaskGroup(of: (Int, TMDBTitle?).self) { group in
            for (i, m) in wanted.enumerated() { group.addTask { (i, try? await tmdb.title(m.type, m.id)) } }
            for await (i, t) in group { titles[i] = t }
        }
        return titles.compactMap { $0 }
    }

    private func search() async {
        let text = query.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { results = []; suggestion = nil; return }
        searching = true
        defer { searching = false }
        try? await Task.sleep(for: .milliseconds(250)) // on attend la fin de la frappe
        guard !Task.isCancelled else { return }
        let tmdb = model.tmdb
        do {
            // Tout part en même temps : la recherche, les surnoms, le nom sans le numéro (« harry potter 1 ») et la
            // correction, cherchée dès qu'elle est trouvée
            let (name, number) = Search.splitNumber(text)
            async let base = tmdb.search(text)
            async let aliases = Aliases.matches(text)
            async let withoutNumber = searchOrEmpty(tmdb, number.isEmpty ? nil : name)
            async let fixedTask: String? = {
                let list = await Search.titles()
                return await Task.detached { Search.suggest(text, in: list) }.value
            }()
            // Premiers résultats affichés tout de suite, puis complétés et rangés (sagas, correction)
            let found = try await base
            guard !Task.isCancelled else { return }
            if !found.isEmpty { results = found }
            let fixed = await fixedTask
            let others = await searchOrEmpty(tmdb, fixed) + withoutNumber
            let nicknamed = await aliasTitles(tmdb, await aliases, besides: found + others)
            guard !Task.isCancelled else { return }
            var seen = Set<String>()
            let merged = (nicknamed + (fixed != nil ? others + found : found + others)).filter { seen.insert(key($0)).inserted }
            results = merged
            suggestion = fixed
            let arranged = await Search.arrangeSagas(merged, query: fixed ?? text, tmdb: tmdb)
            guard !Task.isCancelled else { return }
            results = arranged
            error = nil
        } catch {
            if !Task.isCancelled { self.error = error.localizedDescription }
        }
    }
}
