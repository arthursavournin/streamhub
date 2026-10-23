import SwiftUI

// Réglages, au même dessin que la page du site : liste des sections (Compte en premier), puis chaque section sur sa
// propre page. Sur le site, c'est la barre latérale ; sur téléphone, la même liste.
struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 10) {
                    NavigationLink { page("Compte", "Tes réglages et tes listes sur tous tes appareils, chiffrés de bout en bout.") { AccountScreen() } } label: {
                        SettingsRowLabel(icon: "person", title: "Compte", summary: accountSummary)
                    }
                    .padding(.bottom, 8)
                    NavigationLink { ProvidersView() } label: {
                        SettingsRowLabel(icon: "tv", title: "Mes abonnements", summary: providersSummary)
                    }
                    NavigationLink { page("Clés API", "Les clés qui donnent le catalogue et les liens directs vers les vidéos.") { KeysView() } } label: {
                        SettingsRowLabel(icon: "key", title: "Clés API", summary: keysSummary)
                    }
                    NavigationLink { HomeSettingsView() } label: {
                        let shown = model.store.homeLayout.filter(\.on).count
                        SettingsRowLabel(icon: "house", title: "Accueil", summary: "\(shown) rangées sur \(model.store.homeLayout.count) · \(model.store.homeHero.map { "à l’affiche : \($0.title)" } ?? "affiche automatique")")
                    }
                    NavigationLink { page("Pays, langue et lecture", "Pays du catalogue, langue de l’appli et ouverture des titres. Le pays suit celui de ta connexion (wifi, VPN, voyage) ; tu peux le changer à la main.") { RegionView() } } label: {
                        SettingsRowLabel(icon: "globe", title: "Pays, langue et lecture", summary: "\(AppModel.countryName(model.store.region)) · \(model.uiLang == "en" ? "English" : "Français")")
                    }
                    NavigationLink { page("À propos", "Version, mentions légales et confidentialité.") { AboutView() } } label: {
                        SettingsRowLabel(icon: "info.circle", title: "À propos")
                    }
                }
                .buttonStyle(.plain)
                .padding(16)
                .id(model.uiLang) // langue changée feuille ouverte : lignes redessinées dans la nouvelle langue
            }
            .background(Color.appBackground)
            .navigationTitle(loc("Réglages"))
            // Ouverts par la roue de la barre du haut, par-dessus la page
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(loc("OK")) { dismiss() }
                }
            }
        }
    }

    // Une section : intro sous le titre (comme .panel-head du site), contenu, fond de l'appli
    private func page<Content: View>(_ title: String, _ intro: String, @ViewBuilder content: () -> Content) -> some View {
        SettingsPage(title: title, intro: intro, content: content())
    }

    private var accountSummary: String {
        let account = model.account
        if account.isOpen { return account.email }
        if account.signedIn { return "\(account.email) : coffre à ouvrir" }
        if account.meta.pendingEmail != nil { return "Adresse à confirmer" }
        return "Invité : données sur cet iPhone"
    }

    private var providersSummary: String {
        let list = model.store.providers
        return list.isEmpty ? "Aucune plateforme cochée" : "\(list.count) plateforme\(list.count > 1 ? "s" : "") : \(list.map(\.name).joined(separator: ", "))"
    }

    private var keysSummary: String {
        "\(model.store.tmdbKey.isEmpty ? "TMDB manquante" : "TMDB ✓") · \(model.store.saKey.isEmpty ? "Streaming Availability —" : "Streaming Availability ✓")"
    }

    // Liste de départ, avant la réponse de TMDB (tous les pays où il connaît les plateformes, version 2.8.0)
    static let regions = ["FR", "BE", "CH", "LU", "CA", "GB", "US", "DE", "ES", "IT"]
}

// Clés TMDB et Streaming Availability (enregistrées à chaque frappe, comme avant)
private struct KeysView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Card {
            FieldBox(label: "Clé API TMDB", text: binding("tmdbKey"), placeholder: "Clé API (v3) ou jeton d’accès (v4)", secure: true) {
                Link(loc("Obtenir"), destination: URL(string: "https://www.themoviedb.org/settings/api")!).font(.subheadline.weight(.semibold)).tint(Color.mine)
            }
            Text(loc("Obligatoire : catalogue, fiches, plateformes par pays.")).font(.footnote).foregroundStyle(Color.appMuted)
        }
        Card {
            FieldBox(label: "Clé Streaming Availability", text: binding("saKey"), placeholder: "Clé RapidAPI", secure: true) {
                Link(loc("Obtenir"), destination: URL(string: "https://rapidapi.com/movie-of-the-night-movie-of-the-night-default/api/streaming-availability")!)
                    .font(.subheadline.weight(.semibold)).tint(Color.mine)
            }
            Text(loc("Facultative : liens qui lancent directement le film, la série ou l’épisode.")).font(.footnote).foregroundStyle(Color.appMuted)
        }
        Text(loc("Enregistrées sur cet iPhone (et chiffrées dans ton compte). Elles ne sont jamais publiées."))
            .font(.footnote).foregroundStyle(Color.appMuted)
    }

    private func binding(_ key: String) -> Binding<String> {
        Binding(get: { model.store.settings[key]?.string ?? "" }, set: { model.store.setSetting(key, .string($0)) })
    }
}

// Pays du catalogue : une ligne par pays, coche sur celui choisi
private struct RegionView: View {
    @Environment(AppModel.self) private var model
    @State private var codes = SettingsView.regions

    // Par ordre alphabétique du nom français
    private var sorted: [(String, String)] {
        Set(codes + [model.store.region]).map { ($0, AppModel.countryName($0)) }
            .sorted { $0.1.localizedCompare($1.1) == .orderedAscending }
    }

    var body: some View {
        // Langue de l'appli (comme le site) : français ou anglais, propre à cet iPhone
        Text(loc("Langue")).font(.headline).frame(maxWidth: .infinity, alignment: .leading)
        ActionList {
            ForEach([("fr", "Français"), ("en", "English")], id: \.0) { code, name in
                Button {
                    model.setLanguage(code)
                } label: {
                    HStack {
                        Text(name).foregroundStyle(.primary)
                        Spacer()
                        if model.uiLang == code {
                            Image(systemName: "checkmark").font(.body.weight(.semibold)).foregroundStyle(Color.mine)
                        }
                    }
                    .padding(.horizontal, 18)
                    .frame(minHeight: 50)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
        }
        Text(loc("Pays")).font(.headline).frame(maxWidth: .infinity, alignment: .leading).padding(.top, 8)
        ActionList {
            ForEach(sorted, id: \.0) { code, name in
                Button {
                    model.store.setSetting("region", .string(code))
                } label: {
                    HStack {
                        Text(name).foregroundStyle(.primary)
                        Spacer()
                        if model.store.region == code {
                            Image(systemName: "checkmark").font(.body.weight(.semibold)).foregroundStyle(Color.mine)
                        }
                    }
                    .padding(.horizontal, 18)
                    .frame(minHeight: 50)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
        }
        .task {
            if let list = try? await model.tmdb.regions(), !list.isEmpty { codes = list }
        }
    }
}

// À propos : version, liens légaux (comme la section du site)
private struct AboutView: View {
    var body: some View {
        HStack(spacing: 16) {
            Image(.welcomeIcon).resizable().frame(width: 56, height: 56).clipShape(.rect(cornerRadius: 14))
            VStack(alignment: .leading, spacing: 2) {
                Text(loc("StreamHub")).font(.headline)
                Text(loc("Version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")"))
                    .font(.subheadline).foregroundStyle(Color.appMuted)
            }
            Spacer()
        }
        .padding(18)
        .background(Color.appSurface, in: .rect(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(Color.appBorder))
        ActionList {
            link("StreamHub sur le web", AppStore.site)
            link("Mentions légales", AppStore.site.appending(path: L10n.english ? "legal-notice.html" : "mentions-legales.html"))
            link("Politique de confidentialité", AppStore.site.appending(path: L10n.english ? "privacy.html" : "confidentialite.html"))
            link("Conditions d’utilisation", AppStore.site.appending(path: L10n.english ? "terms.html" : "conditions.html"))
        }
        Text(loc("Catalogue et images : TMDB (ce produit utilise l’API de TMDB mais n’est ni approuvé ni certifié par TMDB). Liens vers les plateformes : JustWatch et Streaming Availability."))
            .font(.footnote).foregroundStyle(Color.appMuted)
    }

    private func link(_ title: String, _ url: URL) -> some View {
        Link(destination: url) {
            HStack {
                Text(loc(title)).foregroundStyle(.primary)
                Spacer()
                Image(systemName: "arrow.up.right").font(.footnote.weight(.semibold)).foregroundStyle(Color.appMuted)
            }
            .padding(.horizontal, 18)
            .frame(minHeight: 50)
            .contentShape(.rect)
        }
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
            Section {
                if let error {
                    Text(loc(error)).foregroundStyle(Color.appDanger).listRowBackground(Color.appSurface)
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
                                Image(systemName: "checkmark").font(.body.weight(.semibold)).foregroundStyle(Color.mine)
                            }
                        }
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(selected.contains(choice.id) ? Color.appAccent.opacity(0.16) : Color.appSurface)
                    .listRowSeparatorTint(Color.appBorder)
                }
            } header: {
                PanelIntro(text: "Coche les plateformes auxquelles tu es abonné : StreamHub n’affiche que ce que tu peux regarder.")
                    .textCase(nil)
                    .padding(.bottom, 6)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.appBackground)
        .overlay { if choices.isEmpty, error == nil { ProgressView() } }
        .searchable(text: $filter, prompt: loc("Rechercher une plateforme"))
        .navigationTitle(loc("Mes abonnements"))
        .navigationBarTitleDisplayMode(.inline)
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

// Réglages → Accueil : titre à l'affiche et rangées (affichées ou non, dans l'ordre voulu), synchronisés avec le site
struct HomeSettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var rows: [HomeChoice] = []

    var body: some View {
        List {
            Section {
                LabeledContent(loc("À l’affiche"), value: model.store.homeHero.map { L10n.english ? "“\($0.title)”" : "« \($0.title) »" } ?? loc("Automatique"))
                    .listRowBackground(Color.appSurface)
                if model.store.homeHero != nil {
                    Button(loc("Revenir au n° 1 du Top 50")) { model.store.setHome(rows: rows, hero: nil) }
                        .tint(Color.mine)
                        .listRowBackground(Color.appSurface)
                }
            } header: {
                PanelIntro(text: "Les rangées de l’accueil et le titre à l’affiche.").textCase(nil).padding(.bottom, 6)
            } footer: {
                Text(loc("Pour choisir un titre, ouvre sa fiche et appuie sur « À l’affiche ». Automatique : le n° 1 du Top 50 du moment."))
            }
            .listRowSeparatorTint(Color.appBorder)
            Section {
                ForEach($rows) { $row in
                    Toggle(loc(HomeRow.named(row.key)?.title ?? row.key), isOn: $row.on)
                        .tint(Color.appAccent)
                        .foregroundStyle(row.on ? Color.primary : Color.appMuted)
                        .listRowBackground(Color.appSurface)
                }
                .onMove { rows.move(fromOffsets: $0, toOffset: $1) }
            } header: {
                Text(loc("Rangées"))
            } footer: {
                Text(loc("Active les rangées à afficher et fais-les glisser pour changer leur ordre."))
            }
            .listRowSeparatorTint(Color.appBorder)
        }
        .environment(\.editMode, .constant(.active))
        .scrollContentBackground(.hidden)
        .background(Color.appBackground)
        .navigationTitle(loc("Accueil"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { rows = model.store.homeLayout }
        .onChange(of: rows) { _, value in model.store.setHome(rows: value, hero: model.store.homeHero) }
    }
}

// Une section des réglages. Vue à part (pas une fonction) : elle lit la langue, donc se redessine quand on la change
// alors qu'elle est ouverte (Réglages → Pays, langue et lecture).
private struct SettingsPage<Content: View>: View {
    @Environment(AppModel.self) private var model
    let title: String
    let intro: String
    let content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                PanelIntro(text: intro)
                content
            }
            .padding(16)
            .id(model.uiLang)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color.appBackground)
        .navigationTitle(loc(title))
        .navigationBarTitleDisplayMode(.inline)
    }
}
