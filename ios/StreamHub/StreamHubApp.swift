import SwiftUI

@main
struct StreamHubApp: App {
    @State private var model = AppModel()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // Affiches et logos gardés en cache entre deux lancements
        URLCache.shared = URLCache(memoryCapacity: 64 << 20, diskCapacity: 512 << 20)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .preferredColorScheme(.dark)
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active: model.appBecameActive()
            case .background: model.sync.appWentToBackground()
            default: break
            }
        }
    }
}

struct RootView: View {
    @Environment(AppModel.self) private var model
    @State private var tab = 1 // l'appli s'ouvre sur l'accueil

    var body: some View {
        @Bindable var model = model
        Group {
            if model.isConfigured {
                // Demande de l'utilisateur : barre entière Recherche, Accueil, Bibliothèque, Ma liste, Réglages, et barre réduite au
                // défilement avec la loupe à gauche et l'onglet en cours à droite. iOS place toujours l'onglet de
                // recherche à droite : la barre est donc affichée de droite à gauche (onglets écrits dans l'ordre inverse),
                // et chaque écran remis de gauche à droite.
                TabView(selection: $tab) {
                    Tab("Réglages", systemImage: "gearshape.fill", value: 3) { SettingsView().leftToRight() }
                    Tab("Ma liste", systemImage: "bookmark.fill", value: 2) { LibraryView().leftToRight() }
                    Tab("Bibliothèque", systemImage: "square.grid.2x2.fill", value: 4) {
                        NavigationStack {
                            CatalogView(preset: CatalogPreset())
                                .titleDestinations()
                        }
                        .leftToRight()
                    }
                    Tab("Accueil", systemImage: "house.fill", value: 1) { HomeView().leftToRight() }
                    Tab(value: 0, role: .search) { SearchView().leftToRight() }
                }
                .tabBarMinimizeBehavior(.onScrollDown)
                .environment(\.layoutDirection, .rightToLeft)
            } else {
                WelcomeView()
            }
        }
        .background(Color.appBackground)
        .sheet(isPresented: Binding(get: { model.progressQuestion != nil }, set: { if !$0 { model.progressQuestion = nil } })) {
            if let question = model.progressQuestion { ProgressSheet(entry: question.entry) }
        }
        #if DEBUG
        // Tests dans le simulateur : code de synchronisation passé au lancement (STREAMHUB_SYNC_CODE) ; « Où en es-tu ? »
        // affiché tout de suite pour une série (STREAMHUB_PROGRESS = identifiant TMDB, S1 E5)
        .task {
            if let code = ProcessInfo.processInfo.environment["STREAMHUB_SYNC_CODE"], model.store.syncMeta.code == nil {
                try? await model.sync.join(code)
            }
            if let id = ProcessInfo.processInfo.environment["STREAMHUB_PROGRESS"].flatMap(Int.init) {
                var entry = LibraryEntry(ref: TitleRef(type: .tv, id: id, title: "Naruto", poster: nil))
                entry.raw["season"] = .int(1)
                entry.raw["episode"] = .int(5)
                entry.raw["platform"] = .string("Netflix")
                model.progressQuestion = PendingProgress(entry: entry, at: Date())
            }
        }
        #endif
    }
}

extension Color {
    static let appBackground = Color(red: 0x07 / 255, green: 0x0d / 255, blue: 0x1a / 255)
    static let appSurface = Color(red: 0x0e / 255, green: 0x17 / 255, blue: 0x29 / 255)
    static let mine = Color(red: 0x9c / 255, green: 0xcb / 255, blue: 0xff / 255)
}

extension View {
    func leftToRight() -> some View { environment(\.layoutDirection, .leftToRight) }
}
