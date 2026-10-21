import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        NavigationStack {
            Form {
                SyncSection()
                Section("Accueil") {
                    NavigationLink {
                        HomeSettingsView()
                    } label: {
                        let shown = model.store.homeLayout.filter(\.on).count
                        LabeledContent("Rangées et affiche", value: "\(shown) rangées")
                    }
                }
                Section("Mes abonnements") {
                    NavigationLink {
                        ProvidersView()
                    } label: {
                        LabeledContent("Plateformes", value: model.store.providers.isEmpty ? "Aucune" : "\(model.store.providers.count)")
                    }
                }
                KeysSection()
                Section("Pays") {
                    Picker("Catalogue", selection: Binding(get: { model.store.region }, set: { model.store.setSetting("region", .string($0)) })) {
                        ForEach(Self.regions, id: \.0) { Text($0.1).tag($0.0) }
                    }
                }
                Section {
                    LabeledContent("Version", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")
                    Link("StreamHub sur le web", destination: AppStore.site)
                } footer: {
                    Text("Catalogue et images : TMDB. Liens vers les plateformes : JustWatch et Streaming Availability.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.appBackground)
            .navigationTitle("Réglages")
        }
    }

    static let regions = [
        ("FR", "France"), ("BE", "Belgique"), ("CH", "Suisse"), ("LU", "Luxembourg"), ("CA", "Canada"),
        ("GB", "Royaume-Uni"), ("US", "États-Unis"), ("DE", "Allemagne"), ("ES", "Espagne"), ("IT", "Italie"),
    ]
}

// Synchronisation avec le site et les autres appareils
private struct SyncSection: View {
    @Environment(AppModel.self) private var model
    @State private var input = ""
    @State private var busy = false
    @State private var message: String?

    var body: some View {
        Section {
            if let code = model.sync.code {
                LabeledContent("Code") {
                    Text(code).font(.callout.monospaced()).textSelection(.enabled)
                }
                if let last = model.store.syncMeta.lastSyncAt {
                    LabeledContent("Dernière synchro", value: Date(timeIntervalSince1970: last / 1000).formatted(.relative(presentation: .named)))
                }
                if let error = model.store.syncMeta.error {
                    Text(error).foregroundStyle(.red).font(.footnote)
                }
                Button {
                    run { try await model.sync.syncNow() }
                } label: {
                    HStack {
                        Text("Synchroniser maintenant")
                        if busy || model.sync.isRunning { Spacer(); ProgressView() }
                    }
                }
                .disabled(busy)
                ShareLink("Partager le code", item: code)
                Button("Arrêter la synchronisation", role: .destructive) { model.sync.leave() }
            } else {
                TextField("Code (ABCD-EFGH-…)", text: $input)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .font(.body.monospaced())
                Button("Utiliser ce code") {
                    run { try await model.sync.join(input) }
                }
                .disabled(busy || input.isEmpty)
                Button("Créer un nouveau code") {
                    run { try await model.sync.createCode() }
                }
                .disabled(busy)
            }
            if let message {
                Text(message).font(.footnote).foregroundStyle(.secondary)
            }
        } header: {
            Text("Synchronisation")
        } footer: {
            Text("Le même code que sur le site : réglages, clés, Ma liste, J’aime et historique suivent partout. Tout est chiffré avant d’être envoyé.")
        }
    }

    private func run(_ action: @escaping () async throws -> Void) {
        busy = true
        message = nil
        Task {
            do {
                try await action()
                input = ""
            } catch {
                message = error.localizedDescription
            }
            busy = false
        }
    }
}

// Clés TMDB et Streaming Availability
private struct KeysSection: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Section {
            SecureField("Clé TMDB", text: binding("tmdbKey"))
                .textInputAutocapitalization(.never).autocorrectionDisabled()
            SecureField("Clé Streaming Availability (facultative)", text: binding("saKey"))
                .textInputAutocapitalization(.never).autocorrectionDisabled()
        } header: {
            Text("Clés API")
        } footer: {
            Text("La clé TMDB (gratuite sur themoviedb.org) donne le catalogue. Streaming Availability donne des liens qui lancent directement la vidéo.")
        }
    }

    private func binding(_ key: String) -> Binding<String> {
        Binding(get: { model.store.settings[key]?.string ?? "" }, set: { model.store.setSetting(key, .string($0)) })
    }
}

// « Mes abonnements » : les plateformes du pays, cochées ou non
struct ProvidersView: View {
    @Environment(AppModel.self) private var model
    @State private var choices: [ProviderChoice] = []
    @State private var filter = ""
    @State private var error: String?

    var body: some View {
        let selected = Set(model.store.providers.map(\.id))
        let shown = filter.isEmpty ? choices : choices.filter { $0.name.localizedCaseInsensitiveContains(filter) }
        List {
            if let error {
                Text(error).foregroundStyle(.red)
            }
            ForEach(shown) { choice in
                Button {
                    toggle(choice, on: !selected.contains(choice.id))
                } label: {
                    HStack(spacing: 12) {
                        PlatformLogo(path: choice.logo, size: 36)
                        Text(choice.name).foregroundStyle(.primary)
                        Spacer()
                        if selected.contains(choice.id) {
                            Image(systemName: "checkmark").font(.body.weight(.semibold)).foregroundStyle(Color.accentColor)
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.appBackground)
        .overlay { if choices.isEmpty, error == nil { ProgressView() } }
        .searchable(text: $filter, prompt: "Rechercher une plateforme")
        .navigationTitle("Mes abonnements")
        .task {
            do {
                choices = try await model.tmdb.providers()
            } catch {
                self.error = error.localizedDescription
            }
        }
    }

    // Cocher Canal+ Ciné Séries coche aussi les plateformes de l'offre ; la décocher ne retire que l'offre
    private func toggle(_ choice: ProviderChoice, on: Bool) {
        var list = model.store.providers
        let add = { (c: ProviderChoice) in
            if !list.contains(where: { $0.id == c.id }) { list.append(Provider(id: c.id, name: c.name, logo: c.logo)) }
        }
        if on {
            add(choice)
            if choice.id == Platforms.cineSeriesID {
                for id in Platforms.cineSeriesIncludes { if let c = choices.first(where: { $0.id == id }) { add(c) } }
            }
        } else {
            list.removeAll { $0.id == choice.id }
        }
        model.store.setProviders(list)
    }
}

// Premier lancement : code de synchronisation du site, ou clé TMDB
struct WelcomeView: View {
    @Environment(AppModel.self) private var model
    @State private var code = ""
    @State private var key = ""
    @State private var busy = false
    @State private var message: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                Image(.welcomeIcon)
                    .resizable()
                    .frame(width: 96, height: 96)
                    .clipShape(.rect(cornerRadius: 22))
                    .padding(.top, 60)
                VStack(spacing: 8) {
                    Text("Bienvenue dans StreamHub").font(.title.weight(.bold)).multilineTextAlignment(.center)
                    Text("Tous tes films et séries, toutes tes plateformes, au même endroit.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }
                VStack(alignment: .leading, spacing: 12) {
                    Text("Tu utilises déjà StreamHub sur le web ?").font(.headline)
                    Text("Colle ton code de synchronisation (Réglages → Synchronisation sur le site) : tout revient.")
                        .font(.subheadline).foregroundStyle(.secondary)
                    TextField("ABCD-EFGH-JKLM-NPQR-STUV", text: $code)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .font(.body.monospaced())
                        .padding(12)
                        .background(Color.appSurface, in: .rect(cornerRadius: 12))
                    Button {
                        Task { await join() }
                    } label: {
                        HStack {
                            if busy { ProgressView() }
                            Text("Utiliser ce code").frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.glassProminent)
                    .controlSize(.large)
                    .disabled(busy || code.isEmpty)
                }
                VStack(alignment: .leading, spacing: 12) {
                    Text("Sinon").font(.headline)
                    Text("Colle ta clé TMDB : gratuite, sur themoviedb.org → Paramètres → API.")
                        .font(.subheadline).foregroundStyle(.secondary)
                    SecureField("Clé TMDB", text: $key)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding(12)
                        .background(Color.appSurface, in: .rect(cornerRadius: 12))
                    Button("Continuer") {
                        model.store.setSetting("tmdbKey", .string(key.trimmingCharacters(in: .whitespaces)))
                    }
                    .buttonStyle(.glass)
                    .controlSize(.large)
                    .disabled(key.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                if let message {
                    Text(message).foregroundStyle(.red).font(.footnote).multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 24)
        }
        .background(Color.appBackground)
    }

    private func join() async {
        busy = true
        message = nil
        do {
            try await model.sync.join(code)
            if !model.isConfigured { message = "Synchronisé, mais aucune clé TMDB dans ces données : colle-la ci-dessous." }
        } catch {
            message = error.localizedDescription
        }
        busy = false
    }
}

// Réglages → Accueil : titre à l'affiche et rangées (affichées ou non, dans l'ordre voulu), synchronisés avec le site
struct HomeSettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var rows: [HomeChoice] = []

    var body: some View {
        List {
            Section {
                LabeledContent("À l’affiche", value: model.store.homeHero.map { "« \($0.title) »" } ?? "Automatique")
                if model.store.homeHero != nil {
                    Button("Revenir au n° 1 du Top 50") { model.store.setHome(rows: rows, hero: nil) }
                }
            } footer: {
                Text("Pour choisir un titre, ouvre sa fiche et appuie sur « À l’affiche ». Automatique : le n° 1 du Top 50 du moment.")
            }
            Section {
                ForEach($rows) { $row in
                    Toggle(HomeRow.named(row.key)?.title ?? row.key, isOn: $row.on)
                }
                .onMove { rows.move(fromOffsets: $0, toOffset: $1) }
            } header: {
                Text("Rangées")
            } footer: {
                Text("Coche les rangées à afficher et fais-les glisser pour changer leur ordre.")
            }
        }
        .environment(\.editMode, .constant(.active))
        .scrollContentBackground(.hidden)
        .background(Color.appBackground)
        .navigationTitle("Accueil")
        .onAppear { rows = model.store.homeLayout }
        .onChange(of: rows) { _, value in model.store.setHome(rows: value, hero: model.store.homeHero) }
    }
}
