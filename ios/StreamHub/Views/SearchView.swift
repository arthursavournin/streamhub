import SwiftUI

// Recherche de films et de séries (TMDB)
struct SearchView: View {
    @Environment(AppModel.self) private var model
    @State private var query = ""
    @State private var results: [TMDBTitle] = []
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
                } else if results.isEmpty, !searching {
                    EmptyMessage(title: "Aucun résultat", systemImage: "magnifyingglass", message: "Essaie un autre titre.")
                        .padding(.top, 80)
                } else {
                    PosterGrid(refs: results.map(\.ref)).padding(.vertical, 8)
                }
            }
            .background(Color.appBackground)
            .navigationTitle("Recherche")
            .searchable(text: $query, prompt: "Films, séries…")
            .titleDestinations()
            .task(id: query) { await search() }
        }
    }

    private func search() async {
        let text = query.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { results = []; return }
        searching = true
        defer { searching = false }
        try? await Task.sleep(for: .milliseconds(350)) // on attend la fin de la frappe
        guard !Task.isCancelled else { return }
        do {
            results = try await model.tmdb.search(text)
            error = nil
        } catch {
            if !Task.isCancelled { self.error = error.localizedDescription }
        }
    }
}
