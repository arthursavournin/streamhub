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
                    } else if list == .history {
                        HistoryRow()
                    } else {
                        PosterGrid(refs: entries.map(\.ref))
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

// Historique : une seule rangée (le plus récent à gauche), une croix sur chaque affiche pour retirer ce titre, et
// « Supprimer l'historique » (demande de l'utilisateur, comme le site). Les retraits partent aux autres appareils.
struct HistoryRow: View {
    @Environment(AppModel.self) private var model
    @State private var confirming = false

    var body: some View {
        let entries = model.store.entries(.history)
        if entries.isEmpty {
            EmptyMessage(title: "Aucun titre regardé", systemImage: "clock", message: "Les titres lancés depuis StreamHub apparaîtront ici.")
                .padding(.top, 60)
        } else {
            VStack(alignment: .leading, spacing: 18) {
                ScrollView(.horizontal) {
                    LazyHStack(spacing: 12) {
                        ForEach(entries) { entry in
                            PosterLink(ref: entry.ref, width: 130)
                                .overlay(alignment: .topTrailing) { removeButton(entry) }
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .scrollIndicators(.hidden)
                // Bleu foncé, pas rouge (demande de l'utilisateur)
                Button("Supprimer l’historique", systemImage: "trash") { confirming = true }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(red: 0x1d / 255, green: 0x3b / 255, blue: 0x72 / 255))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
            }
            .alert("Supprimer l’historique ?", isPresented: $confirming) {
                Button("Supprimer") { withAnimation { model.store.clearHistory() } }
                Button("Annuler", role: .cancel) {}
            } message: {
                Text("Tous les titres regardés seront retirés, sur tous tes appareils.")
            }
        }
    }

    private func removeButton(_ entry: LibraryEntry) -> some View {
        Button {
            withAnimation { model.store.remove(.history, key: entry.key) }
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 26, height: 26)
                .background(.black.opacity(0.72), in: .circle)
                .overlay(Circle().strokeBorder(.white.opacity(0.25)))
                .padding(6) // zone d'appui plus large que la croix
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Retirer \(entry.title) de l’historique")
    }
}
