import SwiftUI

// « Où en es-tu ? » : au retour dans l'appli après avoir lancé une série, choix du dernier épisode vraiment regardé
// (on en enchaîne souvent plusieurs sur la plateforme), et J'aime de la série, dans une seule fenêtre (comme le site)
struct ProgressSheet: View {
    @Environment(AppModel.self) private var model
    let entry: LibraryEntry

    @State private var seasons: [SeasonSummary] = []
    @State private var episodes: [Episode] = []
    @State private var season = 1
    @State private var episode = 1
    @State private var loadedSeason: Int? // saison dont les épisodes sont affichés

    var body: some View {
        let ref = entry.ref
        let liked = model.store.contains(.likes, ref)
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text(loc("Où en es-tu de « \(entry.title) » ?"))
                    .font(.title3.weight(.bold))
                if let platform = entry.platform {
                    Text(loc("sur \(Platforms.shortName(platform))")).foregroundStyle(Color.appMuted)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(loc("Dernier épisode regardé")).font(.subheadline.weight(.semibold)).foregroundStyle(Color.appMuted)
                if seasons.isEmpty {
                    ProgressView().frame(maxWidth: .infinity)
                } else {
                    // Menus en capsule, comme ceux de la Bibliothèque (charte commune, version 2.10.0)
                    HStack(spacing: 10) {
                        Menu {
                            Picker(loc("Saison"), selection: $season) {
                                ForEach(seasons, id: \.seasonNumber) { s in Text(loc("Saison \(s.seasonNumber)")).tag(s.seasonNumber) }
                            }
                        } label: { MenuCapsule(text: loc("Saison \(season)")) }
                        .fixedSize()
                        Menu {
                            Picker(loc("Épisode"), selection: $episode) {
                                ForEach(episodes) { e in Text(loc(label(e))).tag(e.episodeNumber) }
                            }
                        } label: {
                            MenuCapsule(text: episodes.first { $0.episodeNumber == episode }.map { loc(label($0)) } ?? loc("Épisode \(episode)"))
                        }
                    }
                }
            }

            VStack(spacing: 10) {
                Button {
                    let name = episodes.first { $0.episodeNumber == episode }?.name
                    model.saveProgress(entry, season: season, episode: episode, name: name)
                } label: {
                    Text(loc("Enregistrer")).frame(maxWidth: .infinity)
                }
                .buttonStyle(WideButtonStyle())
                .disabled(episodes.isEmpty)

                HStack {
                    Button(loc(liked ? "Tu aimes la série" : "J’aime la série"), systemImage: liked ? "heart.fill" : "heart") {
                        _ = model.store.toggle(.likes, ref, date: entry.raw["date"]?.string)
                    }
                    .tint(liked ? .mine : .primary)
                    Spacer()
                    Button(loc("Ignorer")) { model.progressQuestion = nil }
                        .foregroundStyle(Color.appMuted)
                }
                .font(.subheadline)
            }
        }
        .padding(20)
        .presentationDetents([.height(320)])
        .presentationBackground(Color.appSurface)
        .presentationCornerRadius(22)
        .presentationDragIndicator(.visible)
        .task { await loadSeasons() }
        .onChange(of: season) { _, number in
            guard number != loadedSeason else { return } // saison de départ : déjà chargée
            Task { await loadEpisodes(number, keep: nil) }
        }
    }

    // « Épisode 5 · Le titre » (sans répéter « Épisode 5 » quand c'est tout le titre)
    private func label(_ e: Episode) -> String {
        guard let name = e.name, !name.isEmpty, name.range(of: #"^(Épisode|Episode) \d+$"#, options: .regularExpression) == nil else {
            return "Épisode \(e.episodeNumber)"
        }
        return "Épisode \(e.episodeNumber) · \(name)"
    }

    // Saisons de la série, puis épisodes de la saison de l'épisode lancé (numérotation TMDB)
    private func loadSeasons() async {
        guard let details = try? await model.tmdb.details(.tv, entry.tmdbID) else { return }
        let list = (details.seasons ?? []).filter { $0.seasonNumber > 0 && ($0.episodeCount ?? 0) > 0 }
        let start = list.first { $0.seasonNumber == entry.season }?.seasonNumber ?? list.first?.seasonNumber ?? 1
        await loadEpisodes(start, keep: entry.season == start ? entry.episode : nil)
        seasons = list
        season = start
    }

    private func loadEpisodes(_ number: Int, keep: Int?) async {
        let list = (try? await model.tmdb.season(entry.tmdbID, number))?.episodes ?? []
        loadedSeason = number
        episodes = list
        episode = list.first { $0.episodeNumber == keep }?.episodeNumber ?? list.first?.episodeNumber ?? 1
    }
}
