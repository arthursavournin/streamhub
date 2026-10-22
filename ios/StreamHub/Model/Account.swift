import CommonCrypto
import CryptoKit
import Foundation
import Observation
import Security

// Comptes StreamHub (version 2.0), compatibles avec account.js du site : même Supabase, même coffre, mêmes clés.
//
// Une clé de coffre aléatoire (AES-GCM 256) chiffre les données synchronisées. Supabase la garde deux fois, fermée à
// clé (table vaults) : par une clé tirée du mot de passe (ou du mot de passe du coffre, comptes Google / GitHub) et
// par une clé tirée de la clé de secours. Le vrai mot de passe ne quitte jamais l'appareil : PBKDF2 puis HKDF en
// tirent un « mot de passe de connexion » envoyé à Supabase Auth et une clé qui ouvre le coffre.
// Secrets (session, clé du coffre) dans le trousseau iOS ; le reste dans UserDefaults.

nonisolated enum AccountCrypto {
    static let kdfIterations = 600_000 // mot de passe
    static let recoveryIterations = 200_000 // clé de secours : 100 bits au hasard, impossible à deviner

    static func pbkdf2(_ secret: String, salt: String, iterations: Int) -> Data {
        let password = Array(secret.utf8)
        let salt = Array(salt.utf8)
        var derived = [UInt8](repeating: 0, count: 32)
        _ = CCKeyDerivationPBKDF(
            CCPBKDFAlgorithm(kCCPBKDF2), password.map { Int8(bitPattern: $0) }, password.count,
            salt, salt.count, CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256), UInt32(iterations), &derived, derived.count
        )
        return Data(derived)
    }

    // HKDF-SHA256, sel de 32 octets nuls (comme crypto.subtle côté site)
    static func expand(_ master: Data, info: String) -> Data {
        let key = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: SymmetricKey(data: master), salt: Data(count: 32), info: Data(info.utf8), outputByteCount: 32
        )
        return key.withUnsafeBytes { Data($0) }
    }

    static func base64URL(_ data: Data) -> String {
        data.base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    static func normalizeEmail(_ email: String) -> String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    // Compte e-mail : sel = l'adresse (il faut pouvoir le calculer avant d'être connecté). 600 000 tours : hors du
    // fil principal.
    static func passwordSecrets(email: String, password: String) -> (login: String, unlock: Data) {
        let master = pbkdf2(password, salt: "streamhub-account:\(normalizeEmail(email))", iterations: kdfIterations)
        return (base64URL(expand(master, info: "streamhub:login")), expand(master, info: "streamhub:vault"))
    }

    // Mot de passe du coffre (Google, GitHub) : sel aléatoire gardé dans le coffre
    static func vaultPasswordKey(_ password: String, salt: String) -> Data {
        expand(pbkdf2(password, salt: salt, iterations: kdfIterations), info: "streamhub:vault")
    }

    static func recoveryUnlock(_ key: String, salt: String) -> Data {
        expand(pbkdf2(key, salt: salt, iterations: recoveryIterations), info: "streamhub:recovery")
    }

    static func lock(_ vault: Data, with key: Data) throws -> VaultLock {
        let sealed = try SyncCrypto.encrypt(vault, key: key)
        return VaultLock(iv: sealed.iv, data: sealed.data)
    }

    // nil : mauvais mot de passe ou mauvaise clé
    static func unlock(_ lock: VaultLock, with key: Data) -> Data? {
        try? SyncCrypto.decrypt(iv: lock.iv, data: lock.data, key: key)
    }

    static func random(_ count: Int) -> Data {
        var bytes = [UInt8](repeating: 0, count: count)
        _ = SecRandomCopyBytes(kSecRandomDefault, count, &bytes)
        return Data(bytes)
    }

    static func randomSalt() -> String { random(16).base64EncodedString() }
}

// ---------- Coffre (table vaults) ----------

nonisolated struct VaultLock: Codable, Sendable {
    var salt: String?
    var iv: String
    var data: String
}

nonisolated struct VaultKDF: Codable, Sendable {
    var v: Int
    var mode: String // 'login' (mot de passe du compte) | 'vault' (mot de passe du coffre)
    var iterations: Int
    var salt: String?
}

nonisolated struct VaultRow: Codable, Sendable {
    var kdf: VaultKDF
    var password_lock: VaultLock
    var recovery_lock: VaultLock
}

// ---------- État sur cet appareil ----------

// Ce que l'utilisateur doit encore faire une fois connecté
enum AccountNeed: String, Codable {
    case unlock // entrer son mot de passe (du coffre)
    case create // créer son coffre (compte Google / GitHub ouvert sur le site sans coffre)
}

struct AccountMeta: Codable, Equatable {
    var email: String?
    var userId: String?
    var provider: String?
    var vaultMode: String?
    var needs: AccountNeed?
    var pendingEmail: String? // inscription en attente de la confirmation de l'adresse
    var joining = false // coffre d'un compte qui a peut-être déjà des données : ses réglages s'appliquent ici
    // Synchronisation : syncedAt = version de sync_data
    var syncedAt: Double?
    var hashes: SyncHashes?
    var lastSyncAt: Double?
    var error: String?
}

struct AccountSecrets: Codable, Equatable {
    var access: String?
    var refresh: String?
    var expiresAt: Double? // secondes
    var vaultKey: String? // base64
    var recoveryKey: String? // à montrer une fois
    var pendingLogin: String? // inscription : secrets tirés du mot de passe, en attendant la confirmation
    var pendingUnlock: String?
}

nonisolated enum Keychain {
    private static let service = "io.github.arthursavournin.streamhub.account"

    static func read(_ account: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
            kSecAttrAccount as String: account, kSecReturnData as String: true,
        ]
        var item: CFTypeRef?
        return SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess ? item as? Data : nil
    }

    static func write(_ account: String, _ data: Data?) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
        guard let data else { return }
        var add = query
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(add as CFDictionary, nil)
    }
}

struct AccountError: LocalizedError {
    let message: String
    var code = ""
    var status = 0
    var errorDescription: String? { message }
}

struct SyncConflict: Error {}

// ---------- Service ----------

@Observable
final class AccountService {
    nonisolated static let supabaseURL = "https://bfcmqdvztmkpqwamwejp.supabase.co"
    nonisolated static let supabaseKey = "sb_publishable_RB_4r6Da9y2SLQPjavQXVA_w2Brn3LI" // clé publique

    private(set) var meta: AccountMeta { didSet { saveMeta() } }
    private(set) var secrets: AccountSecrets { didSet { saveSecrets() } }
    @ObservationIgnored private var refreshing: Task<String, Error>?
    @ObservationIgnored var onVaultOpen: (() -> Void)?

    private let server: (url: String, key: String)

    init() {
        meta = UserDefaults.standard.data(forKey: "streamhub:account").flatMap { try? JSONDecoder().decode(AccountMeta.self, from: $0) } ?? AccountMeta()
        secrets = Keychain.read("secrets").flatMap { try? JSONDecoder().decode(AccountSecrets.self, from: $0) } ?? AccountSecrets()
        #if DEBUG
        // Tests dans le simulateur : Supabase local (Docker)
        let env = ProcessInfo.processInfo.environment
        if let url = env["STREAMHUB_SUPABASE_URL"], let key = env["STREAMHUB_SUPABASE_KEY"] {
            server = (url, key)
            return
        }
        #endif
        server = (Self.supabaseURL, Self.supabaseKey)
    }

    private func saveMeta() {
        UserDefaults.standard.set(try? JSONEncoder().encode(meta), forKey: "streamhub:account")
    }

    private func saveSecrets() {
        Keychain.write("secrets", secrets == AccountSecrets() ? nil : try? JSONEncoder().encode(secrets))
    }

    var signedIn: Bool { secrets.refresh != nil }
    var isOpen: Bool { signedIn && secrets.vaultKey != nil }
    var email: String { meta.email ?? "" }
    var recoveryKey: String? { secrets.recoveryKey.map(SyncCrypto.format) }
    var vaultKey: Data? { secrets.vaultKey.flatMap { Data(base64Encoded: $0) } }

    // ---------- Supabase : appels HTTP ----------

    private static let messages = [
        "invalid_credentials": "E-mail ou mot de passe incorrect.",
        "email_not_confirmed": "Adresse pas encore confirmée : ouvre le lien de l’e-mail reçu.",
        "user_already_exists": "Un compte existe déjà avec cette adresse : connecte-toi.",
        "email_exists": "Un compte existe déjà avec cette adresse : connecte-toi.",
        "over_email_send_rate_limit": "Trop d’e-mails envoyés : réessaie dans quelques minutes.",
        "over_request_rate_limit": "Trop de tentatives : réessaie dans quelques minutes.",
        "email_address_invalid": "Adresse e-mail invalide.",
        "validation_failed": "Adresse e-mail invalide.",
        "weak_password": "Mot de passe trop faible.",
        "same_password": "Le nouveau mot de passe est identique à l’ancien.",
        "refresh_token_not_found": "Session expirée : reconnecte-toi.",
        "refresh_token_already_used": "Session expirée : reconnecte-toi.",
        "session_not_found": "Session fermée (mot de passe changé sur un autre appareil ?) : reconnecte-toi.",
        "user_not_found": "Compte introuvable (supprimé ?) : tu es déconnecté.",
    ]

    private func call(_ path: String, method: String = "GET", body: JSON? = nil, token: String? = nil, prefer: String? = nil) async throws -> JSON {
        var request = URLRequest(url: URL(string: server.url + path)!)
        request.httpMethod = method
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue(server.key, forHTTPHeaderField: "apikey")
        request.setValue("streamhub-ios", forHTTPHeaderField: "x-client-info")
        if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "authorization") }
        if let prefer { request.setValue(prefer, forHTTPHeaderField: "prefer") }
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "content-type")
            request.httpBody = try JSONEncoder().encode(body)
        }
        guard let (data, response) = try? await URLSession.shared.data(for: request), let http = response as? HTTPURLResponse else {
            throw AccountError(message: "Compte : serveur injoignable (hors ligne ?).", code: "offline")
        }
        let json = data.isEmpty ? JSON.null : (try? JSONDecoder().decode(JSON.self, from: data)) ?? .null
        guard (200..<300).contains(http.statusCode) else {
            let code = json["error_code"]?.string ?? json["code"]?.string ?? json["error"]?.string ?? ""
            // Session fermée par le serveur (mot de passe changé sur un autre appareil, compte supprimé) : déconnecté
            // ici, les données restent sur l'appareil
            if token != nil, ["session_not_found", "user_not_found", "bad_jwt"].contains(code) { forget() }
            throw AccountError(message: Self.messages[code] ?? "Compte : erreur \(http.statusCode).", code: code, status: http.statusCode)
        }
        return json
    }

    private func keepSession(_ data: JSON) {
        let user = data["user"]
        if let email = user?["email"]?.string { meta.email = email }
        meta.userId = user?["id"]?.string ?? meta.userId
        meta.provider = user?["app_metadata"]?["provider"]?.string ?? meta.provider ?? "email"
        secrets.access = data["access_token"]?.string
        secrets.refresh = data["refresh_token"]?.string
        secrets.expiresAt = data["expires_at"]?.double ?? Date().timeIntervalSince1970 + (data["expires_in"]?.double ?? 3600)
    }

    // Jeton d'accès valable (renouvelé une minute avant expiration)
    private func accessToken() async throws -> String {
        guard let refresh = secrets.refresh else { throw AccountError(message: "Pas connecté.", code: "signed_out", status: 401) }
        if let access = secrets.access, Date().timeIntervalSince1970 < (secrets.expiresAt ?? 0) - 60 { return access }
        if let refreshing { return try await refreshing.value }
        let task = Task { () -> String in
            do {
                let data = try await call("/auth/v1/token?grant_type=refresh_token", method: "POST", body: .object(["refresh_token": .string(refresh)]))
                keepSession(data)
                return secrets.access ?? ""
            } catch let error as AccountError {
                // Session refusée par le serveur (pas une coupure réseau) : déconnecté, les données restent ici
                if (400..<500).contains(error.status), error.status != 429 { forget() }
                throw error
            }
        }
        refreshing = task
        defer { refreshing = nil }
        return try await task.value
    }

    private func forget() {
        meta = AccountMeta()
        secrets = AccountSecrets()
    }

    private func rest(_ path: String, method: String = "GET", body: JSON? = nil, prefer: String? = nil) async throws -> JSON {
        try await call("/rest/v1/\(path)", method: method, body: body, token: try await accessToken(), prefer: prefer)
    }

    private func fetchVault() async throws -> VaultRow? {
        try await rest("vaults?select=kdf,password_lock,recovery_lock").array?.first?.decode(VaultRow.self)
    }

    private func patchVault(_ body: JSON) async throws {
        _ = try await rest("vaults?user_id=eq.\(meta.userId ?? "")", method: "PATCH", body: body, prefer: "return=minimal")
    }

    // ---------- Coffre ----------

    private func opened(_ raw: Data, joining: Bool = true) {
        secrets.vaultKey = raw.base64EncodedString()
        meta.needs = nil
        meta.error = nil
        meta.joining = joining
        onVaultOpen?()
    }

    private func checkPassword(_ password: String) throws {
        if password.count < 8 { throw AccountError(message: "Mot de passe trop court : 8 caractères au moins.") }
    }

    // Crée le coffre, avec une nouvelle clé de secours (à montrer une seule fois)
    private func createVault(mode: String, unlock: Data, salt: String? = nil) async throws {
        let raw = AccountCrypto.random(32)
        let recoveryKey = SyncCrypto.newCode()
        let recoverySalt = AccountCrypto.randomSalt()
        let recoveryUnlock = await Task.detached { AccountCrypto.recoveryUnlock(recoveryKey, salt: recoverySalt) }.value
        var recoveryLock = try AccountCrypto.lock(raw, with: recoveryUnlock)
        recoveryLock.salt = recoverySalt
        let kdf = VaultKDF(v: 1, mode: mode, iterations: AccountCrypto.kdfIterations, salt: salt)
        _ = try await rest("vaults", method: "POST", body: .object([
            "user_id": .string(meta.userId ?? ""),
            "kdf": JSON.from(kdf),
            "password_lock": JSON.from(try AccountCrypto.lock(raw, with: unlock)),
            "recovery_lock": JSON.from(recoveryLock),
        ]), prefer: "return=minimal")
        secrets.recoveryKey = recoveryKey
        meta.syncedAt = nil
        meta.hashes = nil
        meta.vaultMode = mode
        opened(raw, joining: false)
    }

    // Après la connexion : ouvrir le coffre si on a de quoi, sinon dire ce qui manque
    private func afterSignIn(unlock: Data?) async throws {
        guard let vault = try await fetchVault() else {
            if let unlock { return try await createVault(mode: "login", unlock: unlock) }
            meta.needs = .create
            meta.vaultMode = "vault"
            return
        }
        meta.vaultMode = vault.kdf.mode
        if let unlock, vault.kdf.mode == "login", let raw = AccountCrypto.unlock(vault.password_lock, with: unlock) {
            return opened(raw)
        }
        meta.needs = .unlock
    }

    private func openWith(_ vault: VaultRow, password: String) async -> Data? {
        let email = self.email
        let key: Data = await Task.detached {
            vault.kdf.mode == "vault"
                ? AccountCrypto.vaultPasswordKey(password, salt: vault.kdf.salt ?? "")
                : AccountCrypto.passwordSecrets(email: email, password: password).unlock
        }.value
        return AccountCrypto.unlock(vault.password_lock, with: key)
    }

    // ---------- Actions ----------

    // Inscription : avec la confirmation d'adresse (réglage Supabase), pas de session tout de suite. Les secrets tirés
    // du mot de passe attendent ici (trousseau) : au retour, « J'ai confirmé » termine sans redemander le mot de passe.
    // Renvoie true si le compte est ouvert tout de suite.
    func signUp(email rawEmail: String, password: String) async throws -> Bool {
        try checkPassword(password)
        let email = AccountCrypto.normalizeEmail(rawEmail)
        let derived = await Task.detached { AccountCrypto.passwordSecrets(email: email, password: password) }.value
        let site = AppStore.site.absoluteString.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? ""
        let data = try await call("/auth/v1/signup?redirect_to=\(site)", method: "POST", body: .object([
            "email": .string(email), "password": .string(derived.login),
        ]))
        if data["access_token"]?.string != nil {
            keepSession(data)
            try await afterSignIn(unlock: derived.unlock)
            return true
        }
        // Adresse déjà inscrite et confirmée : Supabase répond comme si de rien n'était, sans identité
        if let identities = data["identities"]?.array, identities.isEmpty {
            throw AccountError(message: Self.messages["user_already_exists"]!)
        }
        meta = AccountMeta(email: email, pendingEmail: email)
        secrets = AccountSecrets(pendingLogin: derived.login, pendingUnlock: derived.unlock.base64EncodedString())
        return false
    }

    // Retour après le lien de confirmation (ouvert dans Safari)
    func finishSignUp() async throws {
        guard let email = meta.pendingEmail, let login = secrets.pendingLogin else { return }
        let data = try await call("/auth/v1/token?grant_type=password", method: "POST", body: .object([
            "email": .string(email), "password": .string(login),
        ]))
        let unlock = secrets.pendingUnlock.flatMap { Data(base64Encoded: $0) }
        meta.pendingEmail = nil
        secrets.pendingLogin = nil
        secrets.pendingUnlock = nil
        keepSession(data)
        try await afterSignIn(unlock: unlock)
    }

    func resendConfirmation() async throws {
        guard let email = meta.pendingEmail else { return }
        let site = AppStore.site.absoluteString.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? ""
        _ = try await call("/auth/v1/resend?redirect_to=\(site)", method: "POST", body: .object(["type": "signup", "email": .string(email)]))
    }

    func cancelPending() {
        if !signedIn { forget() }
    }

    func signIn(email rawEmail: String, password: String) async throws {
        let email = AccountCrypto.normalizeEmail(rawEmail)
        let derived = await Task.detached { AccountCrypto.passwordSecrets(email: email, password: password) }.value
        let data = try await call("/auth/v1/token?grant_type=password", method: "POST", body: .object([
            "email": .string(email), "password": .string(derived.login),
        ]))
        meta = AccountMeta(email: email)
        secrets = AccountSecrets()
        keepSession(data)
        try await afterSignIn(unlock: derived.unlock)
    }

    // Coffre fermé (mot de passe changé ailleurs, compte Google / GitHub) : mot de passe (du coffre)
    func unlockVault(_ password: String) async throws {
        guard let vault = try await fetchVault() else { return }
        guard let raw = await openWith(vault, password: password) else {
            throw AccountError(message: vault.kdf.mode == "vault" ? "Mot de passe du coffre incorrect." : "Mot de passe incorrect.")
        }
        opened(raw)
    }

    // Compte Google / GitHub dont le coffre n'existe pas encore : mot de passe du coffre choisi
    func createVaultWith(_ password: String) async throws {
        try checkPassword(password)
        let salt = AccountCrypto.randomSalt()
        let key = await Task.detached { AccountCrypto.vaultPasswordKey(password, salt: salt) }.value
        try await createVault(mode: "vault", unlock: key, salt: salt)
    }

    // Le lien de l'e-mail ouvre le site, où l'on choisit le nouveau mot de passe avec la clé de secours
    func requestReset(email: String) async throws {
        let site = AppStore.site.absoluteString.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? ""
        _ = try await call("/auth/v1/recover?redirect_to=\(site)", method: "POST", body: .object(["email": .string(AccountCrypto.normalizeEmail(email))]))
    }

    // Mot de passe (du coffre) oublié, une fois connecté : la clé de secours rouvre le coffre, que le nouveau mot de
    // passe referme
    func resetWithRecovery(_ input: String, newPassword: String) async throws {
        try checkPassword(newPassword)
        let recoveryKey = SyncCrypto.normalize(input)
        guard SyncCrypto.isValid(recoveryKey) else {
            throw AccountError(message: "Clé de secours invalide : 20 lettres et chiffres (ex. ABCD-EFGH-JKLM-NPQR-STUV).")
        }
        guard let vault = try await fetchVault() else { throw AccountError(message: "Aucun coffre pour ce compte.") }
        let salt = vault.recovery_lock.salt ?? ""
        let key = await Task.detached { AccountCrypto.recoveryUnlock(recoveryKey, salt: salt) }.value
        guard let raw = AccountCrypto.unlock(vault.recovery_lock, with: key) else { throw AccountError(message: "Clé de secours incorrecte.") }
        try await setPassword(vault, raw: raw, password: newPassword)
        opened(raw)
    }

    func changePassword(current: String, new: String) async throws {
        try checkPassword(new)
        guard let vault = try await fetchVault(), let raw = await openWith(vault, password: current) else {
            throw AccountError(message: "Mot de passe actuel incorrect.")
        }
        try await setPassword(vault, raw: raw, password: new)
    }

    // Mode « login » : le mot de passe de connexion change aussi chez Supabase (d'abord : si la suite échoue, le
    // nouveau mot de passe permet de recommencer avec la clé de secours)
    private func setPassword(_ vault: VaultRow, raw: Data, password: String) async throws {
        var kdf = vault.kdf
        if kdf.mode == "vault" {
            let salt = AccountCrypto.randomSalt()
            let key = await Task.detached { AccountCrypto.vaultPasswordKey(password, salt: salt) }.value
            kdf.salt = salt
            try await patchVault(.object(["kdf": JSON.from(kdf), "password_lock": JSON.from(try AccountCrypto.lock(raw, with: key))]))
            return
        }
        let email = self.email
        let derived = await Task.detached { AccountCrypto.passwordSecrets(email: email, password: password) }.value
        _ = try await call("/auth/v1/user", method: "PUT", body: .object(["password": .string(derived.login)]), token: try await accessToken())
        kdf.iterations = AccountCrypto.kdfIterations
        try await patchVault(.object(["kdf": JSON.from(kdf), "password_lock": JSON.from(try AccountCrypto.lock(raw, with: derived.unlock))]))
    }

    // Nouvelle clé de secours (l'ancienne ne marche plus)
    func newRecovery() async throws {
        guard let raw = vaultKey else { throw AccountError(message: "Coffre fermé.") }
        let recoveryKey = SyncCrypto.newCode()
        let salt = AccountCrypto.randomSalt()
        let key = await Task.detached { AccountCrypto.recoveryUnlock(recoveryKey, salt: salt) }.value
        var lock = try AccountCrypto.lock(raw, with: key)
        lock.salt = salt
        try await patchVault(.object(["recovery_lock": JSON.from(lock)]))
        secrets.recoveryKey = recoveryKey
    }

    func recoveryNoted() { secrets.recoveryKey = nil }

    // Déconnexion : les données restent sur cet appareil, elles ne suivent simplement plus
    func signOut() async {
        let token = secrets.access
        forget()
        if let token { _ = try? await call("/auth/v1/logout?scope=local", method: "POST", token: token) }
    }

    func deleteAccount() async throws {
        _ = try await rest("rpc/delete_my_account", method: "POST", body: .object([:]))
        await signOut()
    }

    // ---------- Pour la synchronisation ----------

    func updateSync(_ change: (inout AccountMeta) -> Void) { change(&meta) }

    // { version, iv, data } ou nil
    func fetchData() async throws -> (version: Double, iv: String, data: String)? {
        guard let row = try await rest("sync_data?select=iv,data,version").array?.first,
              let version = row["version"]?.double, let iv = row["iv"]?.string, let data = row["data"]?.string else { return nil }
        return (version, iv, data)
    }

    // Écrit seulement si la version lue est encore la dernière (sinon SyncConflict : relire, fusionner, renvoyer)
    func pushData(iv: String, data: String, version: Double?) async throws -> Double {
        let userID = meta.userId ?? ""
        guard let version else {
            do {
                _ = try await rest("sync_data", method: "POST", body: .object([
                    "user_id": .string(userID), "iv": .string(iv), "data": .string(data), "version": 1,
                ]), prefer: "return=minimal")
                return 1
            } catch let error as AccountError where error.status == 409 {
                throw SyncConflict() // un autre appareil a écrit le premier
            }
        }
        let rows = try await rest("sync_data?user_id=eq.\(userID)&version=eq.\(Int64(version))", method: "PATCH", body: .object([
            "iv": .string(iv), "data": .string(data), "version": .int(Int64(version) + 1),
        ]), prefer: "return=representation")
        guard !(rows.array ?? []).isEmpty else { throw SyncConflict() }
        return version + 1
    }
}
