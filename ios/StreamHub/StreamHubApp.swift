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
                // Demande de l'utilisateur : barre entière Recherche, Accueil, Ma liste, Réglages, et barre réduite au
                // défilement avec la loupe à gauche et l'onglet en cours à droite. iOS place toujours l'onglet de
                // recherche à droite : la barre est donc affichée de droite à gauche (onglets écrits dans l'ordre inverse),
                // et chaque écran remis de gauche à droite.
                TabView(selection: $tab) {
                    Tab("Réglages", systemImage: "gearshape.fill", value: 3) { SettingsView().leftToRight() }
                    Tab("Ma liste", systemImage: "bookmark.fill", value: 2) { LibraryView().leftToRight() }
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
        #if DEBUG
        // Tests dans le simulateur : code de synchronisation passé au lancement (STREAMHUB_SYNC_CODE)
        .task {
            if let code = ProcessInfo.processInfo.environment["STREAMHUB_SYNC_CODE"], model.store.syncMeta.code == nil {
                try? await model.sync.join(code)
            }
        }
        #endif
        .alert(
            model.question.map { "Tu as regardé « \($0.entry.title) » ?" } ?? "",
            isPresented: Binding(get: { model.question != nil }, set: { if !$0 { model.question = nil } })
        ) {
            Button("Oui") { model.answer(true) }
            Button("Non", role: .cancel) { model.answer(false) }
        } message: {
            Text("S’il est dans ton historique, tu le retrouves dans « Reprendre ».")
        }
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
