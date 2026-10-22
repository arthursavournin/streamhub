import SwiftUI

// Mon espace : Ma liste, J'aime, Historique (synchronisés avec le site) et Téléchargés (sur cet iPhone), en segments,
// comme le site sur iPhone
struct LibraryView: View {
    @Environment(AppModel.self) private var model
    @State private var list: LibraryList = .watchlist

    var body: some View {
        NavigationStack {
            let entries = model.store.entries(list)
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(list.title)
                        .font(.largeTitle.weight(.bold))
                        .padding(.horizontal, 16)
                    Picker("Liste", selection: $list) {
                        ForEach(LibraryList.allCases) { Text($0.shortTitle).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)
                    if entries.isEmpty {
                        EmptyMessage(title: emptyTitle, systemImage: emptyIcon, message: emptyMessage)
                            .padding(.top, 60)
                    } else if list == .history {
                        HistoryRow()
                    } else if list == .downloads {
                        DownloadsGrid(entries: entries)
                    } else {
                        PosterGrid(refs: entries.map(\.ref))
                    }
                }
                .padding(.vertical, 8)
            }
            .background(Color.appBackground)
            .appTopBar()
            .titleDestinations()
            .refreshable { _ = try? await model.sync.syncNow() }
        }
    }

    private var emptyTitle: String {
        switch list {
        case .watchlist: "Ma liste est vide"
        case .likes: "Aucun J’aime"
        case .history: "Aucun titre regardé"
        case .downloads: "Aucun téléchargement"
        }
    }
    private var emptyIcon: String {
        switch list {
        case .watchlist: "bookmark"
        case .likes: "heart"
        case .history: "clock"
        case .downloads: "arrow.down.circle"
        }
    }
    private var emptyMessage: String {
        switch list {
        case .watchlist: "Ajoute des titres avec « + Ma liste » sur leur fiche."
        case .likes: "Les titres que tu aimes apparaîtront ici."
        case .history: "Les titres lancés depuis StreamHub apparaîtront ici."
        case .downloads: "Dans la fiche d’un film ou d’un épisode, touche « Télécharger » : StreamHub le note ici et ouvre l’appli de la plateforme pour lancer le téléchargement."
        }
    }
}

// Téléchargés : un appui ouvre le titre dans l'appli de la plateforme, où se trouve le fichier ; la croix le retire de
// la liste (demande de l'utilisateur), sans toucher au fichier
struct DownloadsGrid: View {
    @Environment(AppModel.self) private var model
    let entries: [LibraryEntry]

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 12)], spacing: 16) {
            ForEach(entries) { entry in
                Button {
                    Task { await model.openDownload(entry) }
                } label: {
                    PosterView(ref: entry.ref, width: nil)
                        .overlay(alignment: .bottom) {
                            Text(caption(entry))
                                .font(.caption2.weight(.semibold))
                                .lineLimit(1)
                                .padding(.horizontal, 6).padding(.vertical, 3)
                                .background(.black.opacity(0.65), in: .capsule)
                                .padding(6)
                        }
                }
                .buttonStyle(.plain)
                .overlay(alignment: .topTrailing) {
                    RemoveButton(label: "Retirer \(entry.title) des téléchargements") {
                        withAnimation { model.store.remove(.downloads, key: entry.key) }
                    }
                }
                .contextMenu {
                    NavigationLink(value: entry.ref) { Label("Voir la fiche", systemImage: "info.circle") }
                }
            }
        }
        .padding(.horizontal, 16)
    }

    // « ⬇ S1 E3 · Netflix »
    private func caption(_ entry: LibraryEntry) -> String {
        let episode = entry.season.flatMap { s in entry.episode.map { "S\(s) E\($0)" } }
        return "⬇ " + [episode, entry.platform.map(Platforms.shortName)].compactMap { $0 }.joined(separator: " · ")
    }
}

// Petite croix en haut à droite d'une affiche (Historique, Téléchargés)
struct RemoveButton: View {
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
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
        .accessibilityLabel(label)
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
                                .overlay(alignment: .topTrailing) {
                                    RemoveButton(label: "Retirer \(entry.title) de l’historique") {
                                        withAnimation { model.store.remove(.history, key: entry.key) }
                                    }
                                }
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
}
