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
            } else if (model.account.isOpen && model.account.recoveryKey == nil) || model.account.guest {
                // Connecté (clé de secours notée) ou invité, mais pas encore de clé TMDB : dernière étape
                KeySetupView()
            } else {
                // Premier lancement : seulement la connexion / création de compte, comme sur le site
                OnboardingView()
            }
        }
        .background(Color.appBackground)
        .sheet(isPresented: Binding(get: { model.progressQuestion != nil }, set: { if !$0 { model.progressQuestion = nil } })) {
            if let question = model.progressQuestion { ProgressSheet(entry: question.entry) }
        }
        #if DEBUG
        // Tests dans le simulateur (Supabase local : STREAMHUB_SUPABASE_URL / _KEY, voir Account.swift) ; « Où en es-tu ? »
        // affiché tout de suite pour une série (STREAMHUB_PROGRESS = identifiant TMDB, S1 E5)
        .task {
            // Compte (STREAMHUB_ACCOUNT = « action|valeur|valeur », la saisie au clavier du simulateur ne marchant pas
            // avec l'outil de test) : signin|e-mail|mdp, signup|e-mail|mdp, finish, unlock|mdp, change|ancien|nouveau,
            // reset|clé|nouveau, recovery, signout, delete|mdp, like|titre|id, watch|titre|id|movie ou tv|affiche (historique),
            // unwatch|movie:id, clear (historique), key|clé TMDB, sync.
            // Résultat dans la console (STREAMHUB_TEST).
            if let spec = ProcessInfo.processInfo.environment["STREAMHUB_ACCOUNT"] {
                let p = spec.split(separator: "|", omittingEmptySubsequences: false).map(String.init) + ["", ""]
                let account = model.account
                do {
                    switch p[0] {
                    case "signin": try await account.signIn(email: p[1], password: p[2])
                    case "signup": _ = try await account.signUp(email: p[1], password: p[2])
                    case "finish": try await account.finishSignUp()
                    case "unlock": try await account.unlockVault(p[1])
                    case "change": try await account.changePassword(current: p[1], new: p[2])
                    case "reset": try await account.resetWithRecovery(p[1], newPassword: p[2])
                    case "recovery": try await account.newRecovery()
                    case "signout": await account.signOut()
                    case "delete": try await account.deleteAccount(password: p[1])
                    case "like": model.store.toggle(.likes, TitleRef(type: .movie, id: Int(p[2]) ?? 1, title: p[1], poster: nil))
                    case "watch":
                        let ref = TitleRef(type: MediaType(rawValue: p[3]) ?? .movie, id: Int(p[2]) ?? 1, title: p[1], poster: p[4].isEmpty ? nil : p[4])
                        model.store.recordWatch(LibraryEntry(ref: ref, date: "2025-09-19"))
                    case "unwatch": model.store.remove(.history, key: p[1])
                    case "clear": model.store.clearHistory()
                    case "key": model.store.setSetting("tmdbKey", .string(p[1]))
                    case "sync": _ = try await model.sync.syncNow()
                    default: break
                    }
                    try? await Task.sleep(for: .seconds(3)) // première synchro
                    print("STREAMHUB_TEST ok \(p[0]) open=\(account.isOpen) pending=\(account.meta.pendingEmail ?? "-") needs=\(account.meta.needs?.rawValue ?? "-") recovery=\(account.recoveryKey ?? "-") synced=\(account.meta.syncedAt ?? -1) error=\(account.meta.error ?? "-") tmdb=\(model.store.tmdbKey) likes=\(model.store.entries(.likes).map(\.title)) history=\(model.store.entries(.history).map(\.title)) removed=\(model.store.library["removed"].map { String(decoding: $0.canonicalData, as: UTF8.self) } ?? "-")")
                } catch {
                    print("STREAMHUB_TEST error \(p[0]) \(error.localizedDescription)")
                }
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
