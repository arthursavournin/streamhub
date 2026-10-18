import SwiftUI

// Recherche de films et de séries (TMDB), tolérante aux fautes, avec numéro de film et sagas dans l'ordre (Search.swift)
struct SearchView: View {
    @Environment(AppModel.self) private var model
    @State private var query = ""
    @State private var results: [TMDBTitle] = []
    @State private var suggestion: String?
    @State private var error: String?
    @State private var searching = false

    var body: some View {
        NavigationStack {
            ScrollView {
                if query.trimmingCharacters(in: .whitespaces).isEmpty {
                    EmptyMessage(title: "Rechercher", systemImage: "magnifyingglass", message: "Un film, une série, sur toutes tes plateformes.")
                        .padding(.top, 80)
                } else if let error {
                    EmptyMessage(title: "Recherche impossible", systemImage: "wifi.exclamationmark", message: error)
                        .padding(.top, 80)
                } else {
                    VStack(alignment: .leading, spacing: 12) {
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
                        if results.isEmpty, !searching {
                            EmptyMessage(title: "Aucun résultat", systemImage: "magnifyingglass", message: "Essaie un autre titre.")
                                .padding(.top, 60)
                        } else {
                            PosterGrid(refs: results.map(\.ref))
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .background(Color.appBackground)
            .navigationTitle("Recherche")
            // Champ toujours visible sous le titre (sinon il reste caché jusqu'à ce qu'on tire la page vers le bas)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Films, séries…")
            .titleDestinations()
            .task(id: query) { await search() }
            #if DEBUG
            // Tests dans le simulateur : recherche passée au lancement (STREAMHUB_SEARCH)
            .onAppear {
                if query.isEmpty, let q = ProcessInfo.processInfo.environment["STREAMHUB_SEARCH"] { query = q }
            }
            #endif
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
        try? await Task.sleep(for: .milliseconds(350)) // on attend la fin de la frappe
        guard !Task.isCancelled else { return }
        let tmdb = model.tmdb
        let list = await Search.titles()
        let fixed = await Task.detached { Search.suggest(text, in: list) }.value
        guard !Task.isCancelled else { return }
        do {
            // On cherche aussi la correction et, pour « harry potter 1 », le nom sans le numéro
            let (name, number) = Search.splitNumber(text)
            async let base = tmdb.search(text)
            async let corrected = searchOrEmpty(tmdb, fixed)
            async let withoutNumber = searchOrEmpty(tmdb, number.isEmpty ? nil : name)
            let others = await corrected + withoutNumber
            let found = try await base
            var seen = Set<String>()
            let merged = (fixed != nil ? others + found : found + others).filter { seen.insert("\($0.type.rawValue):\($0.id)").inserted }
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
