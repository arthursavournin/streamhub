import SwiftUI

// Ma liste, J'aime, Historique (synchronisés avec le site)
struct LibraryView: View {
    @Environment(AppModel.self) private var model
    @State private var list: LibraryList = .watchlist

    var body: some View {
        NavigationStack {
            let entries = model.store.entries(list)
            ScrollView {
                VStack(spacing: 16) {
                    Picker("Liste", selection: $list) {
                        ForEach(LibraryList.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)
                    if entries.isEmpty {
                        EmptyMessage(title: emptyTitle, systemImage: emptyIcon, message: emptyMessage)
                            .padding(.top, 60)
                    } else {
                        PosterGrid(refs: entries.map(\.ref), captions: entries.captions)
                    }
                }
                .padding(.vertical, 8)
            }
            .background(Color.appBackground)
            .navigationTitle(list.title)
            .titleDestinations()
            .refreshable { _ = try? await model.sync.syncNow() }
        }
    }

    private var emptyTitle: String {
        switch list {
        case .watchlist: "Ma liste est vide"
        case .likes: "Aucun J’aime"
        case .history: "Aucun titre regardé"
        }
    }
    private var emptyIcon: String {
        switch list {
        case .watchlist: "bookmark"
        case .likes: "heart"
        case .history: "clock"
        }
    }
    private var emptyMessage: String {
        switch list {
        case .watchlist: "Ajoute des titres avec « + Ma liste » sur leur fiche."
        case .likes: "Les titres que tu aimes apparaîtront ici."
        case .history: "Les titres lancés depuis StreamHub apparaîtront ici."
        }
    }
}
