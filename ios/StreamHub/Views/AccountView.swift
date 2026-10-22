import AuthenticationServices
import SwiftUI
import UIKit

// Compte, comme sur le site (account-ui.js) : carte de connexion (e-mail, Google, GitHub), coffre à ouvrir, carte de
// profil, actions en liste, clé de secours. Sert dans Réglages → Compte et au premier lancement (onboarding : avec
// l'accueil et « Continuer sans compte »). Les liens des e-mails (confirmation, mot de passe oublié) ouvrent le site.
struct AccountScreen: View {
    var onboarding = false
    @Environment(AppModel.self) private var model
    @Environment(\.webAuthenticationSession) private var webAuth

    // Ce qui est affiché : signin, signup, forgot (invité) ; unlock, recover (coffre fermé) ; open, password, delete
    @State private var mode = "signin"
    @State private var email = ""
    @State private var password = ""
    @State private var password2 = ""
    @State private var current = ""
    @State private var recovery = ""
    @State private var busy = false
    @State private var message: (text: String, ok: Bool)?
    @State private var providers: [String] = []
    @State private var oauthBusy = false // pas de roue sur « Se connecter » pendant la connexion Google / GitHub

    private var account: AccountService { model.account }

    var body: some View {
        VStack(spacing: 16) {
            if account.isOpen {
                openContent
            } else if account.signedIn {
                profile
                lockedCard
                ActionList { ActionRow(icon: "rectangle.portrait.and.arrow.right", title: "Se déconnecter") { signOut() } }
            } else if let pending = account.meta.pendingEmail {
                pendingCard(pending)
            } else {
                guestContent
            }
            StatusText(message: message)
        }
        .task { providers = await account.enabledProviders() }
        .onChange(of: account.isOpen) { _, open in mode = open ? "open" : "signin" }
    }

    // ---------- Invité : connexion, création de compte ----------

    @ViewBuilder private var guestContent: some View {
        if onboarding {
            VStack(spacing: 8) {
                Image(.welcomeIcon).resizable().frame(width: 76, height: 76).clipShape(.rect(cornerRadius: 18))
                    .shadow(color: Color.appAccent.opacity(0.4), radius: 18, y: 8)
                    .padding(.bottom, 6)
                Text("Bienvenue sur StreamHub").font(.title2.weight(.bold))
                Text("Tous tes films et séries, toutes tes plateformes, au même endroit.")
                    .font(.subheadline).foregroundStyle(Color.appMuted).multilineTextAlignment(.center)
            }
            .padding(.vertical, 8)
        } else {
            Text("Tu es en invité : tes données restent sur cet iPhone. Connecte-toi pour les retrouver partout, chiffrées de bout en bout.")
                .font(.subheadline).foregroundStyle(Color.mine)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.appAccent.opacity(0.1), in: .rect(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.appAccent.opacity(0.3)))
        }
        if mode == "forgot" {
            Card {
                title("Mot de passe oublié", "Tu recevras un lien qui ouvre StreamHub sur le web : choisis-y le nouveau mot de passe, avec ta clé de secours, puis reviens te connecter ici.")
                FieldBox(label: "Adresse e-mail", text: $email, placeholder: "toi@exemple.fr", content: .username, keyboard: .emailAddress)
                Button("Envoyer le lien") { run { try await account.requestReset(email: try checkedEmail()); mode = "signin"; return "Si un compte existe pour \(email), un e-mail vient de partir." } }
                    .buttonStyle(WideButtonStyle()).disabled(busy)
                switchLine(nil, "← Retour à la connexion", to: "signin")
            }
        } else {
            let signup = mode == "signup"
            Card {
                title(signup ? "Créer un compte" : "Se connecter", signup ? "Tes réglages et tes listes, sur tous tes appareils." : "Retrouve tes réglages et tes listes.")
                FieldBox(label: "Adresse e-mail", text: $email, placeholder: "toi@exemple.fr", content: .username, keyboard: .emailAddress)
                if signup {
                    FieldBox(label: "Mot de passe", text: $password, placeholder: "\(AccountService.minPassword) caractères au moins", secure: true, content: .newPassword)
                    FieldBox(label: "Confirme le mot de passe", text: $password2, secure: true, content: .newPassword)
                } else {
                    FieldBox(label: "Mot de passe", text: $password, secure: true, content: .password) {
                        Button("Oublié ?") { mode = "forgot" }.font(.subheadline.weight(.semibold)).tint(Color.mine)
                    }
                }
                Button {
                    run {
                        if signup {
                            let open = try await account.signUp(email: try checkedEmail(), password: try newPassword())
                            return open ? "Compte créé." : nil
                        }
                        try await account.signIn(email: try checkedEmail(), password: password)
                        return account.isOpen ? "Connecté." : nil
                    }
                } label: {
                    HStack { if busy && !oauthBusy { ProgressView().tint(.white) }; Text(signup ? "Créer mon compte" : "Se connecter") }
                }
                .buttonStyle(WideButtonStyle())
                .disabled(busy || email.isEmpty || password.isEmpty)
                if !providers.isEmpty {
                    OrDivider()
                    ForEach(providers, id: \.self) { provider in
                        SocialButton(provider: provider) { oauth(provider) }.disabled(busy)
                    }
                }
                switchLine(signup ? "Déjà un compte ?" : "Pas encore de compte ?", signup ? "Se connecter" : "Créer un compte", to: signup ? "signin" : "signup")
                if onboarding {
                    Divider().overlay(Color.appBorder)
                    VStack(spacing: 6) {
                        Button("Continuer sans compte") { account.guest = true }.buttonStyle(WideButtonStyle(kind: .secondary))
                        Text("Tes données resteront sur cet iPhone. Tu pourras créer un compte plus tard dans les réglages.")
                            .font(.caption).foregroundStyle(Color.appMuted).multilineTextAlignment(.center)
                    }
                }
                legal
            }
        }
    }

    private func pendingCard(_ pending: String) -> some View {
        Card {
            iconBadge("envelope")
            title("Vérifie ta boîte mail", "Ouvre le lien envoyé à \(pending) (regarde aussi dans les indésirables), puis reviens ici.")
            Button("J’ai confirmé mon adresse") { run { try await account.finishSignUp(); return account.isOpen ? "Compte créé." : nil } }
                .buttonStyle(WideButtonStyle()).disabled(busy)
            Button("Renvoyer l’e-mail") { run { try await account.resendConfirmation(); return "E-mail renvoyé." } }
                .buttonStyle(WideButtonStyle(kind: .secondary)).disabled(busy)
            HStack { Spacer(); Button("Utiliser une autre adresse") { account.cancelPending() }.font(.subheadline.weight(.semibold)).tint(Color.mine); Spacer() }
        }
    }

    // ---------- Connecté, coffre fermé ----------

    @ViewBuilder private var lockedCard: some View {
        let vault = account.meta.vaultMode == "vault"
        let word = vault ? "mot de passe du coffre" : "mot de passe"
        Card {
            if mode == "recover" {
                title("Nouveau \(word)", "Ta clé de secours rouvre tes données ; le nouveau \(word) les referme.")
                FieldBox(label: "Clé de secours", text: $recovery, placeholder: "ABCD-EFGH-JKLM-NPQR-STUV", monospaced: true)
                FieldBox(label: "Nouveau \(word)", text: $password, placeholder: "\(AccountService.minPassword) caractères au moins", secure: true, content: .newPassword)
                FieldBox(label: "Confirme le mot de passe", text: $password2, secure: true, content: .newPassword)
                Button("Enregistrer") { run { try await account.resetWithRecovery(recovery, newPassword: try newPassword()); return "Nouveau mot de passe enregistré." } }
                    .buttonStyle(WideButtonStyle()).disabled(busy || recovery.isEmpty || password.isEmpty)
                switchLine(nil, "← Retour", to: "unlock")
            } else if account.meta.needs == .create {
                title("Choisis un mot de passe du coffre", "Il chiffre tes données sur l’iPhone, avant l’envoi. Tu le taperas une fois sur chaque nouvel appareil. Il ne sert qu’à StreamHub.")
                FieldBox(label: "Mot de passe du coffre", text: $password, placeholder: "\(AccountService.minPassword) caractères au moins", secure: true, content: .newPassword)
                FieldBox(label: "Confirme le mot de passe", text: $password2, secure: true, content: .newPassword)
                Button("Créer mon coffre") { run { try await account.createVaultWith(try newPassword()); return nil } }
                    .buttonStyle(WideButtonStyle()).disabled(busy || password.isEmpty)
            } else {
                iconBadge("lock")
                title("Ouvre tes données", "Entre ton \(word) pour ouvrir tes données sur cet iPhone.")
                FieldBox(label: vault ? "Mot de passe du coffre" : "Mot de passe", text: $password, secure: true, content: .password) {
                    Button("Oublié ?") { mode = "recover" }.font(.subheadline.weight(.semibold)).tint(Color.mine)
                }
                Button("Ouvrir") { run { try await account.unlockVault(password); return "Coffre ouvert : synchronisation…" } }
                    .buttonStyle(WideButtonStyle()).disabled(busy || password.isEmpty)
            }
        }
    }

    // ---------- Connecté, coffre ouvert ----------

    @ViewBuilder private var openContent: some View {
        let word = account.meta.vaultMode == "vault" ? "mot de passe du coffre" : "mot de passe"
        profile
        if let key = account.recoveryKey { recoveryCard(key) }
        if mode == "password" {
            Card {
                title("Changer de \(word)", "Tes autres appareils seront déconnectés : reconnecte-les avec le nouveau mot de passe (leurs données restent).")
                FieldBox(label: "\(word.prefix(1).uppercased())\(word.dropFirst()) actuel", text: $current, secure: true, content: .password)
                FieldBox(label: "Nouveau \(word)", text: $password, placeholder: "\(AccountService.minPassword) caractères au moins", secure: true, content: .newPassword)
                FieldBox(label: "Confirme le mot de passe", text: $password2, secure: true, content: .newPassword)
                Button("Enregistrer") {
                    run { try await account.changePassword(current: current, new: try newPassword()); mode = "open"; return "Mot de passe changé." }
                }
                .buttonStyle(WideButtonStyle()).disabled(busy || current.isEmpty || password.isEmpty)
                switchLine(nil, "Annuler", to: "open")
            }
        } else if mode == "delete" {
            Card {
                title("Supprimer ton compte ?", "Ton compte, ton coffre et tes données synchronisées seront effacés. Tes données restent sur cet iPhone (en invité). Impossible d’annuler.")
                FieldBox(label: "\(word.prefix(1).uppercased())\(word.dropFirst())", text: $current, secure: true, content: .password)
                Button("Supprimer définitivement") {
                    run { try await account.deleteAccount(password: current); mode = "signin"; return "Compte supprimé. Tes données restent sur cet iPhone." }
                }
                .buttonStyle(WideButtonStyle(kind: .danger)).disabled(busy || current.isEmpty)
                switchLine(nil, "Annuler", to: "open")
            }
            .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(Color.appDanger.opacity(0.45)))
        } else {
            ActionList {
                ActionRow(icon: "arrow.triangle.2.circlepath", title: "Synchroniser maintenant", busy: model.sync.isRunning) {
                    run { try await model.sync.syncNow(); return nil }
                }
                ActionRow(icon: "key", title: "Changer de \(word)", chevron: true) { mode = "password" }
                ActionRow(icon: "checkmark.shield", title: "Nouvelle clé de secours") {
                    run { try await account.newRecovery(); return "Nouvelle clé de secours : l’ancienne ne marche plus." }
                }
                ActionRow(icon: "rectangle.portrait.and.arrow.right", title: "Se déconnecter") { signOut() }
            }
            ActionList {
                ActionRow(icon: "trash", title: "Supprimer mon compte", danger: true, chevron: true) { mode = "delete" }
            }
        }
    }

    // Carte de profil : initiale (et logo du fournisseur), adresse, façon de se connecter, état de la synchro
    private var profile: some View {
        let provider = account.meta.provider ?? "email"
        return HStack(spacing: 16) {
            ZStack(alignment: .bottomTrailing) {
                Circle().fill(LinearGradient.accent).frame(width: 56, height: 56)
                    .overlay(Text(String(account.email.prefix(1)).uppercased()).font(.title2.weight(.bold)).foregroundStyle(.white))
                if provider == "google" || provider == "github" {
                    Group {
                        if provider == "google" { Image(.googleLogo).resizable() } else { Image(.gitHubLogo).resizable().renderingMode(.template) }
                    }
                    .frame(width: 13, height: 13)
                    .foregroundStyle(.white)
                    .frame(width: 24, height: 24)
                    .background(provider == "google" ? Color.white : Color.black, in: .circle)
                    .overlay(Circle().strokeBorder(Color.appSurface, lineWidth: 2))
                    .offset(x: 4, y: 4)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(account.email).font(.body.weight(.semibold)).lineLimit(1).truncationMode(.middle)
                Text(provider == "email" ? "Compte e-mail" : "Connecté avec \(AccountService.providers[provider] ?? provider)")
                    .font(.subheadline).foregroundStyle(Color.appMuted)
                if account.isOpen {
                    if let error = account.meta.error {
                        Text("Synchronisation impossible : \(error)").font(.footnote).foregroundStyle(Color.appDanger)
                    } else if let last = account.meta.lastSyncAt {
                        Text("✓ Synchronisé \(Date(timeIntervalSince1970: last / 1000).formatted(.relative(presentation: .named)))")
                            .font(.footnote).foregroundStyle(Color.mine)
                    } else {
                        Text("Synchronisation…").font(.footnote).foregroundStyle(Color.appMuted)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(18)
        .background(Color.appSurface, in: .rect(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(Color.appBorder))
    }

    private func recoveryCard(_ key: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Ta clé de secours", systemImage: "checkmark.shield").font(.headline).foregroundStyle(Color.mine)
            Text("Note-la dans ton gestionnaire de mots de passe. Si tu oublies ton mot de passe, elle seule permet de retrouver tes données : personne, pas même StreamHub, ne peut les rouvrir sans elle.")
                .font(.subheadline).foregroundStyle(Color.appMuted)
            HStack {
                Text(key).font(.title3.monospaced()).textSelection(.enabled).minimumScaleFactor(0.7).lineLimit(1)
                Spacer()
                Button("Copier") {
                    UIPasteboard.general.string = key
                    message = ("Clé copiée.", true)
                }
                .buttonStyle(.bordered)
            }
            .padding(12)
            .background(Color.appBackground, in: .rect(cornerRadius: 12))
            Button("Je l’ai notée") { account.recoveryNoted() }.buttonStyle(WideButtonStyle())
        }
        .padding(18)
        .background(Color.appAccent.opacity(0.1), in: .rect(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(Color.appAccent))
    }

    // ---------- Petits morceaux ----------

    private func title(_ text: String, _ subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(text).font(.title3.weight(.bold))
            Text(subtitle).font(.subheadline).foregroundStyle(Color.appMuted)
        }
    }

    private func iconBadge(_ name: String) -> some View {
        Image(systemName: name).font(.system(size: 22, weight: .medium)).foregroundStyle(Color.mine)
            .frame(width: 52, height: 52).background(Color.appAccent.opacity(0.16), in: .rect(cornerRadius: 16))
    }

    private func switchLine(_ lead: String?, _ action: String, to target: String) -> some View {
        HStack(spacing: 4) {
            Spacer()
            if let lead { Text(lead).foregroundStyle(Color.appMuted) }
            Button(action) { mode = target; message = nil }.fontWeight(.semibold).tint(Color.mine)
            Spacer()
        }
        .font(.subheadline)
    }

    // Information au moment de la collecte (recommandation de la CNIL) : conditions et confidentialité
    private var legal: some View {
        Text("En créant un compte ou en te connectant, tu acceptes les [conditions d’utilisation](https://arthursavournin.github.io/streamhub/conditions.html) et la [politique de confidentialité](https://arthursavournin.github.io/streamhub/confidentialite.html).")
            .font(.caption).foregroundStyle(Color.appMuted).tint(Color.appMuted).multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }

    private func checkedEmail() throws -> String {
        let value = email.trimmingCharacters(in: .whitespaces)
        guard value.wholeMatch(of: /[^\s@]+@[^\s@]+\.[^\s@]+/) != nil else { throw AccountError(message: "Adresse e-mail invalide.") }
        return value
    }

    private func newPassword() throws -> String {
        guard password == password2 else { throw AccountError(message: "Les deux mots de passe ne sont pas identiques.") }
        return password
    }

    private func signOut() {
        Task {
            await account.signOut()
            mode = "signin"
            message = ("Déconnecté. Tes données restent sur cet iPhone.", true)
        }
    }

    // Google / GitHub : fenêtre de connexion d'Apple (navigateur intégré), retour sur streamhub://auth-callback
    private func oauth(_ provider: String) {
        oauthBusy = true
        run {
            defer { oauthBusy = false }
            let start = account.oauthStart(provider)
            let callback: URL
            do {
                callback = try await webAuth.authenticate(using: start.url, callbackURLScheme: AccountService.callbackScheme, preferredBrowserSession: .shared)
            } catch let error as ASWebAuthenticationSessionError where error.code == .canceledLogin {
                return nil // fenêtre fermée par l'utilisateur
            }
            try await account.finishOAuth(callback, verifier: start.verifier)
            return account.isOpen ? "Connecté avec \(AccountService.providers[provider] ?? provider)." : nil
        }
    }

    private func run(_ action: @escaping () async throws -> String?) {
        busy = true
        message = nil
        Task {
            do {
                if let text = try await action() { message = (text, true) }
                password = ""
                password2 = ""
                current = ""
                recovery = ""
            } catch {
                message = (error.localizedDescription, false)
            }
            busy = false
        }
    }
}

// Premier lancement : seulement la connexion / création de compte (ou « Continuer sans compte »)
struct OnboardingView: View {
    var body: some View {
        ScrollView {
            AccountScreen(onboarding: true)
                .frame(maxWidth: 460)
                .padding(.horizontal, 20)
                .padding(.vertical, 32)
                .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color.appBackground)
    }
}

// Après la connexion (ou en invité), s'il manque encore la clé TMDB : dernière étape
struct KeySetupView: View {
    @Environment(AppModel.self) private var model
    @State private var key = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(spacing: 8) {
                    Image(.welcomeIcon).resizable().frame(width: 64, height: 64).clipShape(.rect(cornerRadius: 16))
                    Text("Dernière étape").font(.title2.weight(.bold))
                    Text("Colle ta clé TMDB : elle donne le catalogue. Elle est gratuite, sur themoviedb.org → Paramètres → API.")
                        .font(.subheadline).foregroundStyle(Color.appMuted).multilineTextAlignment(.center)
                }
                if model.account.isOpen && model.sync.isRunning {
                    HStack(spacing: 8) { ProgressView(); Text("Récupération de tes réglages…").foregroundStyle(Color.appMuted) }
                }
                Card {
                    FieldBox(label: "Clé API TMDB", text: $key, placeholder: "Clé API (v3) ou jeton d’accès (v4)", secure: true)
                    Button("Continuer") { model.store.setSetting("tmdbKey", .string(key.trimmingCharacters(in: .whitespaces))) }
                        .buttonStyle(WideButtonStyle())
                        .disabled(key.trimmingCharacters(in: .whitespaces).isEmpty)
                    Link("Obtenir une clé gratuite", destination: URL(string: "https://www.themoviedb.org/settings/api")!)
                        .font(.subheadline.weight(.semibold)).tint(Color.mine).frame(maxWidth: .infinity)
                }
                if model.account.guest && !model.account.signedIn {
                    Button("Me connecter plutôt") { model.account.guest = false }
                        .font(.subheadline.weight(.semibold)).tint(Color.mine)
                }
            }
            .frame(maxWidth: 460)
            .padding(.horizontal, 20)
            .padding(.vertical, 40)
            .frame(maxWidth: .infinity)
        }
        .background(Color.appBackground)
    }
}
