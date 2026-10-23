import SwiftUI

// Image distante (TMDB ou site StreamHub), avec un fond en attendant
struct RemoteImage: View {
    let url: URL?
    var contentMode: ContentMode = .fill

    var body: some View {
        AsyncImage(url: url, transaction: Transaction(animation: .easeOut(duration: 0.2))) { phase in
            if let image = phase.image {
                image.resizable().aspectRatio(contentMode: contentMode)
            } else {
                Color.appSurface
            }
        }
    }
}

// Affiche d'un titre (2:3), avec son nom tant qu'elle n'est pas chargée
struct PosterView: View {
    let ref: TitleRef
    var width: CGFloat? = 118

    var body: some View {
        // Cadre 2:3 fixé d'abord, contenu posé dessus : la taille ne dépend pas de l'image (chargée ou non)
        Color.appSurface
            .aspectRatio(2 / 3, contentMode: .fit)
            .frame(width: width, height: width.map { $0 * 1.5 })
            .overlay {
                Text(ref.title)
                    .font(.caption.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(8)
            }
            .overlay { RemoteImage(url: imageURL(ref.poster)) }
            .clipShape(.rect(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.white.opacity(0.08)))
        .accessibilityLabel(ref.title)
    }
}

// Affiche cliquable : ouvre la fiche ; appui long : Ma liste
struct PosterLink: View {
    @Environment(AppModel.self) private var model
    let ref: TitleRef
    var width: CGFloat? = 118
    var rank: Int?
    var caption: String? // « S1 E31 · 16 oct. » (dernier épisode d'une série récente ; plus de date de sortie : fiche)

    var body: some View {
        NavigationLink(value: ref) {
            PosterView(ref: ref, width: width)
                .overlay(alignment: .bottom) {
                    if let caption {
                        Text(caption)
                            .font(.caption2.weight(.semibold))
                            .lineLimit(1)
                            .padding(.horizontal, 6).padding(.vertical, 3)
                            .background(.black.opacity(0.65), in: .capsule)
                            .padding(.bottom, 6)
                    }
                }
                .overlay(alignment: .bottomLeading) {
                    if let rank {
                        Text(loc("\(rank)"))
                            .font(.system(size: 30, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.8), radius: 4)
                            .padding(.leading, 6)
                    }
                }
        }
        .buttonStyle(.plain)
        .contextMenu {
            let inList = model.store.contains(.watchlist, ref)
            Button(loc(inList ? "Retirer de Ma liste" : "Ajouter à Ma liste"), systemImage: inList ? "bookmark.slash" : "bookmark") {
                model.store.toggle(.watchlist, ref)
            }
        }
    }
}

// Logo d'une plateforme (carré arrondi)
struct PlatformLogo: View {
    let path: String?
    var size: CGFloat = 40

    var body: some View {
        RemoteImage(url: imageURL(path, size: "w92"))
            .frame(width: size, height: size)
            .clipShape(.rect(cornerRadius: size * 0.22))
    }
}

// Titre de section façon Netflix
struct SectionTitle: View {
    let text: String
    var body: some View {
        Text(loc(text))
            .font(.title3.weight(.bold))
            .padding(.horizontal, 16)
    }
}

// Grille d'affiches (Ma liste, recherche)
struct PosterGrid: View {
    let refs: [TitleRef]
    var captions: [TitleRef: String] = [:] // dernier épisode des séries récentes

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 12)], spacing: 16) {
            ForEach(refs, id: \.self) { ref in
                PosterLink(ref: ref, width: nil, caption: captions[ref])
            }
        }
        .padding(.horizontal, 16)
    }
}

// Message centré (liste vide, erreur)
struct EmptyMessage: View {
    let title: String
    let systemImage: String
    var message: String?

    var body: some View {
        ContentUnavailableView {
            Label(loc(title), systemImage: systemImage)
        } description: {
            if let message { Text(loc(message)) }
        }
    }
}

extension View {
    // Destination commune : la fiche d'un titre
    func titleDestinations() -> some View {
        navigationDestination(for: TitleRef.self) { DetailView(ref: $0) }
    }
}
