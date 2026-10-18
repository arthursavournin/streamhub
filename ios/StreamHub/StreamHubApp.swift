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

    var body: some View {
        @Bindable var model = model
        Group {
            if model.isConfigured {
                TabView {
                    Tab("Accueil", systemImage: "house.fill") { HomeView() }
                    Tab("Ma liste", systemImage: "bookmark.fill") { LibraryView() }
                    Tab("Réglages", systemImage: "gearshape.fill") { SettingsView() }
                    Tab(role: .search) { SearchView() }
                }
                .tabBarMinimizeBehavior(.onScrollDown)
            } else {
                WelcomeView()
            }
        }
        .background(Color.appBackground)
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
