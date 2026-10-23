import SwiftUI

// Recherche de films et de séries (TMDB), tolérante aux fautes, avec numéro de film et sagas dans l'ordre (Search.swift).
// Comme sur le site : Tout / Films / Séries, et seulement les titres de tes abonnements (les autres derrière « tout
// afficher », pour éviter la fausse joie d'un titre qu'on ne peut pas regarder).
struct SearchView: View {
    @Environment(AppModel.self) private var model
    @State private var query = ""
    @State private var results: [TMDBTitle] = []
    @State private var type: CatalogType = .all
    @State private var showAll = false // « tout afficher » : aussi les titres hors de tes abonnements
    @State private var mine: [String: Bool] = [:] // titre → sur un de tes abonnements (vérifié une fois par titre)
    @State private var suggestion: String?
    @State private var error: String?
    @State private var searching = false
    @FocusState private var focused: Bool

    // Ouverte depuis la barre du haut, dans la pile de l'onglet en cours
    var body: some View {
            ScrollView {
                if query.trimmingCharacters(in: .whitespaces).isEmpty {
                    EmptyMessage(title: "Rechercher", systemImage: "magnifyingglass", message: "Un film, une série, sur toutes tes plateformes.")
                        .padding(.top, 80)
                } else if let error {
                    EmptyMessage(title: "Recherche impossible", systemImage: "wifi.exclamationmark", message: error)
                        .padding(.top, 80)
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        Picker("Type", selection: $type) {
                            ForEach(CatalogType.allCases, id: \.self) { Text($0.label).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal, 16)
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
                        if typed.isEmpty, !searching {
                            EmptyMessage(title: "Aucun résultat", systemImage: "magnifyingglass", message: "Essaie un autre titre.")
                                .padding(.top, 60)
                        } else if shown.isEmpty, !checking, !searching {
                            // Rien sur tes abonnements : on le dit, sans montrer les autres d'office
                            EmptyMessage(title: "Pas sur tes abonnements", systemImage: "tv.slash",
                                         message: "Aucun \(noun) trouvé pour « \(query.trimmingCharacters(in: .whitespaces)) » sur tes abonnements.")
                                .padding(.top, 40)
                            showAllButton
                        } else {
                            if hidden > 0 || showAll { showAllButton }
                            PosterGrid(refs: shown.map(\.ref), captions: shown.captions)
                            if checking {
                                ProgressView().frame(maxWidth: .infinity).padding(.vertical, 12)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .background(Color.appBackground)
            .navigationTitle("Recherche")
            // Champ toujours visible sous le titre (sinon il reste caché jusqu'à ce qu'on tire la page vers le bas)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Films, séries…")
            .searchFocused($focused)
            .onAppear { focused = true }
            .task(id: query) { showAll = false; await search() }
            .task(id: results.map { key($0) }) { await checkOffers() }
            #if DEBUG
            // Tests dans le simulateur : recherche passée au lancement (STREAMHUB_SEARCH)
            .onAppear {
                if query.isEmpty, let q = ProcessInfo.processInfo.environment["STREAMHUB_SEARCH"] { query = q }
            }
            #endif
    }

    // ---------- Filtre par abonnement ----------

    private func key(_ t: TMDBTitle) -> String { "\(t.type.rawValue):\(t.id)" }
    private var filtering: Bool { !model.store.providers.isEmpty } // aucun abonnement coché : tout le catalogue
    private var typed: [TMDBTitle] { results.filter { type.types.contains($0.type) } }
    private var shown: [TMDBTitle] { filtering && !showAll ? typed.filter { mine[key($0)] == true } : typed }
    private var hidden: Int { filtering ? typed.filter { mine[key($0)] == false }.count : 0 }
    private var checking: Bool { filtering && !showAll && typed.contains { mine[key($0)] == nil } }
    private var noun: String { type == .movie ? "film" : type == .tv ? "série" : "titre" }

    @ViewBuilder private var showAllButton: some View {
        Button {
            showAll.toggle()
        } label: {
            Text(showAll ? "Seulement mes abonnements" : "\(hidden) autre\(hidden > 1 ? "s" : "") hors de tes abonnements — tout afficher")
                .font(.callout)
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: showAll || !shown.isEmpty ? .leading : .center)
    }

    // Offres de chaque titre trouvé (les mêmes que sa fiche) ; une série sans aucune offre dans le pays peut être une
    // création d'une de tes plateformes pas encore référencée par JustWatch (VisionQuest) : on lit alors sa fiche
    private func checkOffers() async {
        guard filtering else { return }
        let tmdb = model.tmdb
        let providers = model.store.providers
        let region = model.store.region
        let todo = results.filter { mine[key($0)] == nil }
        guard !todo.isEmpty else { return }
        await withTaskGroup(of: (String, Bool).self) { group in
            for item in todo {
                let k = key(item)
                group.addTask {
                    let offers = try? await tmdb.offers(item.type, item.id)
                    let streamable = offers?.streamable ?? []
                    if streamable.contains(where: { Links.isMine($0, providers: providers) }) { return (k, true) }
                    guard item.type == .tv, streamable.isEmpty else { return (k, false) }
                    let full = (try? await tmdb.details(.tv, item.id))?.watchProviders?.results[region]?.streamable ?? []
                    return (k, full.contains { Links.isMine($0, providers: providers) })
                }
            }
            for await (k, ok) in group { mine[k] = ok }
        }
    }

    private func searchOrEmpty(_ tmdb: TMDBClient, _ query: String?) async -> [TMDBTitle] {
        guard let query else { return [] }
        return (try? await tmdb.search(query)) ?? []
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
            // Tout part en même temps (avant : la correction des fautes était calculée avant d'interroger TMDB) : la
            // recherche, le nom sans le numéro (« harry potter 1 »), et la correction, cherchée dès qu'elle est trouvée
            let (name, number) = Search.splitNumber(text)
            async let base = tmdb.search(text)
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
            guard !Task.isCancelled else { return }
            var seen = Set<String>()
            let merged = (fixed != nil ? others + found : found + others).filter { seen.insert("\($0.type.rawValue):\($0.id)").inserted }
            results = merged
            suggestion = fixed
            let arranged = await Search.arrangeSagas(merged, query: fixed ?? text, tmdb: tmdb)
            guard !Task.isCancelled else { return }
            results = arranged
            suggestion = fixed
            error = nil
        } catch {
            if !Task.isCancelled { self.error = error.localizedDescription }
        }
    }
}
