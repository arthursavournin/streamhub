import SwiftUI
import UIKit

// Réglages → Compte, comme sur le site : invité, inscription, connexion, coffre à ouvrir, clé de secours, mot de passe,
// déconnexion, suppression. Les liens des e-mails (confirmation, mot de passe oublié) s'ouvrent sur le site.
struct AccountSections: View {
    @Environment(AppModel.self) private var model
    @State private var signup = false
    @State private var email = ""
    @State private var password = ""
    @State private var password2 = ""
    @State private var busy = false
    @State private var message: (text: String, ok: Bool)?
    @State private var confirmDelete = false

    private var account: AccountService { model.account }

    var body: some View {
        if account.isOpen {
            if let key = account.recoveryKey { recoverySection(key) }
            openSection
        } else if account.signedIn {
            lockedSection
        } else if let pending = account.meta.pendingEmail {
            pendingSection(pending)
        } else {
            guestSection
        }
    }

    // ---------- Invité ----------

    private var guestSection: some View {
        Section {
            Picker("", selection: $signup) {
                Text("Se connecter").tag(false)
                Text("Créer un compte").tag(true)
            }
            .pickerStyle(.segmented)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
            TextField("Adresse e-mail", text: $email)
                .textContentType(.username)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            SecureField(signup ? "Mot de passe (8 caractères au moins)" : "Mot de passe", text: $password)
                .textContentType(signup ? .newPassword : .password)
            if signup {
                SecureField("Encore une fois", text: $password2).textContentType(.newPassword)
            }
            actionButton(signup ? "Créer mon compte" : "Se connecter", disabled: email.isEmpty || password.isEmpty) {
                if signup {
                    guard password == password2 else { throw AccountError(message: "Les deux mots de passe ne sont pas identiques.") }
                    let open = try await account.signUp(email: email, password: password)
                    return open ? "Compte créé." : nil
                }
                try await account.signIn(email: email, password: password)
                return account.isOpen ? "Connecté." : nil
            }
            if !signup {
                Button("Mot de passe oublié ?") {
                    run {
                        guard !email.isEmpty else { throw AccountError(message: "Entre d’abord ton adresse e-mail.") }
                        try await account.requestReset(email: email)
                        return "Si un compte existe pour \(email), un e-mail vient de partir. Son lien ouvre StreamHub sur le web : choisis-y le nouveau mot de passe (avec ta clé de secours), puis reviens te connecter ici."
                    }
                }
                .disabled(busy)
            }
            messageRow
        } header: {
            Text("Compte")
        } footer: {
            // Information au moment de la collecte (recommandation de la CNIL) : conditions et confidentialité
            Text("Avec un compte, tes réglages, clés, abonnements, J’aime, Ma liste et historique te suivent sur tous tes appareils, chiffrés sur l’iPhone avant l’envoi : personne d’autre que toi ne peut les lire. Sans compte, tu restes en invité : tout reste sur cet iPhone.\n\nEn créant un compte ou en te connectant, tu acceptes les [conditions d’utilisation](https://arthursavournin.github.io/streamhub/conditions.html). Ce que StreamHub fait de tes données : [politique de confidentialité](https://arthursavournin.github.io/streamhub/confidentialite.html).")
        }
    }

    private func pendingSection(_ pending: String) -> some View {
        Section {
            Text("Dernière étape : ouvre le lien envoyé à \(pending) (regarde aussi dans les indésirables), puis reviens ici.")
            actionButton("J’ai confirmé mon adresse") {
                try await account.finishSignUp()
                return account.isOpen ? "Compte créé." : nil
            }
            Button("Renvoyer l’e-mail") { run { try await account.resendConfirmation(); return "E-mail renvoyé." } }
                .disabled(busy)
            Button("Annuler", role: .destructive) { account.cancelPending() }
            messageRow
        } header: {
            Text("Compte")
        }
    }

    // ---------- Connecté, coffre fermé ----------

    private var lockedSection: some View {
        let vault = account.meta.vaultMode == "vault"
        let word = vault ? "mot de passe du coffre" : "mot de passe"
        return Section {
            LabeledContent("Connecté", value: account.email)
            if account.meta.needs == .create {
                Text("Choisis un mot de passe du coffre : il chiffre tes données sur l’iPhone, avant l’envoi. Tu le taperas une fois sur chaque nouvel appareil.")
                    .font(.footnote).foregroundStyle(.secondary)
                SecureField("Mot de passe du coffre", text: $password).textContentType(.newPassword)
                SecureField("Encore une fois", text: $password2).textContentType(.newPassword)
                actionButton("Créer mon coffre", disabled: password.isEmpty) {
                    guard password == password2 else { throw AccountError(message: "Les deux mots de passe ne sont pas identiques.") }
                    try await account.createVaultWith(password)
                    return nil
                }
            } else {
                Text("Entre ton \(word) pour ouvrir tes données sur cet iPhone.").font(.footnote).foregroundStyle(.secondary)
                SecureField(vault ? "Mot de passe du coffre" : "Mot de passe", text: $password).textContentType(.password)
                actionButton("Ouvrir", disabled: password.isEmpty) {
                    try await account.unlockVault(password)
                    return "Coffre ouvert : synchronisation…"
                }
                NavigationLink("\(vault ? "Mot de passe du coffre oublié" : "Mot de passe oublié") ?") { RecoveryView(word: word) }
            }
            Button("Se déconnecter", role: .destructive) { Task { await account.signOut() } }
            messageRow
        } header: {
            Text("Compte")
        }
    }

    // ---------- Connecté, coffre ouvert ----------

    private func recoverySection(_ key: String) -> some View {
        Section {
            Text(key).font(.title3.monospaced()).textSelection(.enabled)
            Button("Copier") {
                UIPasteboard.general.string = key
                message = ("Clé copiée.", true)
            }
            Button("Je l’ai notée") { account.recoveryNoted() }
                .fontWeight(.semibold)
        } header: {
            Text("Ta clé de secours")
        } footer: {
            Text("Note-la dans ton gestionnaire de mots de passe. Si tu oublies ton mot de passe, elle seule permet de retrouver tes données : personne, pas même StreamHub, ne peut les rouvrir sans elle.")
        }
    }

    private var openSection: some View {
        let word = account.meta.vaultMode == "vault" ? "mot de passe du coffre" : "mot de passe"
        return Section {
            LabeledContent("Connecté", value: account.email)
            if let error = account.meta.error {
                Text("Dernière synchronisation impossible : \(error)").foregroundStyle(.red).font(.footnote)
            } else if let last = account.meta.lastSyncAt {
                LabeledContent("Dernière synchro", value: Date(timeIntervalSince1970: last / 1000).formatted(.relative(presentation: .named)))
            }
            Button {
                run { try await model.sync.syncNow(); return nil }
            } label: {
                HStack {
                    Text("Synchroniser maintenant")
                    if busy || model.sync.isRunning { Spacer(); ProgressView() }
                }
            }
            .disabled(busy)
            NavigationLink("Changer de \(word)") { ChangePasswordView(word: word) }
            Button("Nouvelle clé de secours") {
                run { try await account.newRecovery(); return "Nouvelle clé de secours : l’ancienne ne marche plus." }
            }
            .disabled(busy)
            Button("Se déconnecter", role: .destructive) { Task { await account.signOut() } }
            Button("Supprimer mon compte", role: .destructive) { confirmDelete = true }
            messageRow
        } header: {
            Text("Compte")
        } footer: {
            Text("Réglages, clés, abonnements, J’aime, Ma liste et historique sont chiffrés sur l’iPhone puis synchronisés avec le site et tes autres appareils.")
        }
        // Sur la section, pas sur la ligne du bouton (SwiftUI n'affiche pas une alerte accrochée à une ligne de liste)
        .alert("Supprimer ton compte ?", isPresented: $confirmDelete) {
            Button("Supprimer définitivement", role: .destructive) {
                run { try await account.deleteAccount(); return "Compte supprimé. Tes données restent sur cet iPhone." }
            }
            Button("Annuler", role: .cancel) {}
        } message: {
            Text("Ton compte, ton coffre et tes données synchronisées seront effacés. Tes données restent sur cet iPhone (en invité). Impossible d’annuler.")
        }
    }

    // ---------- Outils ----------

    @ViewBuilder private var messageRow: some View {
        if let message {
            Text(message.text).font(.footnote).foregroundStyle(message.ok ? Color.mine : .red)
        }
    }

    private func actionButton(_ title: String, disabled: Bool = false, _ action: @escaping () async throws -> String?) -> some View {
        Button {
            run(action)
        } label: {
            HStack {
                Text(title).fontWeight(.semibold)
                if busy { Spacer(); ProgressView() }
            }
        }
        .disabled(busy || disabled)
    }

    private func run(_ action: @escaping () async throws -> String?) {
        busy = true
        message = nil
        Task {
            do {
                if let text = try await action() { message = (text, true) }
                password = ""
                password2 = ""
            } catch {
                message = (error.localizedDescription, false)
            }
            busy = false
        }
    }
}

// Mot de passe (du coffre) oublié, une fois connecté : clé de secours + nouveau mot de passe
private struct RecoveryView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let word: String
    @State private var key = ""
    @State private var password = ""
    @State private var password2 = ""
    @State private var busy = false
    @State private var error: String?

    var body: some View {
        Form {
            Section {
                TextField("Clé de secours (ABCD-EFGH-…)", text: $key)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .font(.body.monospaced())
                SecureField("Nouveau \(word) (8 caractères au moins)", text: $password).textContentType(.newPassword)
                SecureField("Encore une fois", text: $password2).textContentType(.newPassword)
                Button {
                    Task {
                        busy = true
                        error = nil
                        do {
                            guard password == password2 else { throw AccountError(message: "Les deux mots de passe ne sont pas identiques.") }
                            try await model.account.resetWithRecovery(key, newPassword: password)
                            dismiss()
                        } catch {
                            self.error = error.localizedDescription
                        }
                        busy = false
                    }
                } label: {
                    HStack { Text("Enregistrer").fontWeight(.semibold); if busy { Spacer(); ProgressView() } }
                }
                .disabled(busy || key.isEmpty || password.isEmpty)
                if let error { Text(error).foregroundStyle(.red).font(.footnote) }
            } footer: {
                Text("Ta clé de secours rouvre tes données, que le nouveau \(word) referme.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.appBackground)
        .navigationTitle("\(word.prefix(1).uppercased())\(word.dropFirst()) oublié")
    }
}

private struct ChangePasswordView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let word: String
    @State private var current = ""
    @State private var password = ""
    @State private var password2 = ""
    @State private var busy = false
    @State private var error: String?

    var body: some View {
        Form {
            Section {
                SecureField("\(word.prefix(1).uppercased())\(word.dropFirst()) actuel", text: $current).textContentType(.password)
                SecureField("Nouveau \(word) (8 caractères au moins)", text: $password).textContentType(.newPassword)
                SecureField("Encore une fois", text: $password2).textContentType(.newPassword)
                Button {
                    Task {
                        busy = true
                        error = nil
                        do {
                            guard password == password2 else { throw AccountError(message: "Les deux mots de passe ne sont pas identiques.") }
                            try await model.account.changePassword(current: current, new: password)
                            dismiss()
                        } catch {
                            self.error = error.localizedDescription
                        }
                        busy = false
                    }
                } label: {
                    HStack { Text("Enregistrer").fontWeight(.semibold); if busy { Spacer(); ProgressView() } }
                }
                .disabled(busy || current.isEmpty || password.isEmpty)
                if let error { Text(error).foregroundStyle(.red).font(.footnote) }
            } footer: {
                Text("Tes autres appareils seront déconnectés : reconnecte-les avec le nouveau mot de passe (leurs données restent).")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.appBackground)
        .navigationTitle("Changer de \(word)")
    }
}
