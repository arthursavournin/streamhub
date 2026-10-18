import CommonCrypto
import CryptoKit
import Foundation
import Observation

// Synchronisation avec le site et les autres appareils, compatible avec sync.js : mêmes codes, même chiffrement
// (identifiant = SHA-256 de « streamhub-sync:id:<code> », clé AES-GCM 256 bits tirée du code par PBKDF2-SHA256,
// 200 000 tours, sel « streamhub-sync:key »), même relais, même règle de fusion. Le relais ne voit qu'un contenu
// illisible.
nonisolated enum SyncCrypto {
    static let alphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789") // sans 0/O ni 1/I, faciles à confondre
    static let codeLength = 20

    static func normalize(_ code: String) -> String {
        code.uppercased().filter { ("A"..."Z").contains($0) || ("0"..."9").contains($0) }
    }

    static func isValid(_ code: String) -> Bool {
        code.count == codeLength && code.allSatisfy(alphabet.contains)
    }

    static func format(_ code: String) -> String {
        stride(from: 0, to: code.count, by: 4).map { i in
            let start = code.index(code.startIndex, offsetBy: i)
            return String(code[start..<(code.index(start, offsetBy: 4, limitedBy: code.endIndex) ?? code.endIndex)])
        }.joined(separator: "-")
    }

    static func newCode() -> String {
        var bytes = [UInt8](repeating: 0, count: codeLength)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return String(bytes.map { alphabet[Int($0) % alphabet.count] }) // 256 = 8 × 32 : tirage uniforme
    }

    static func hex(_ bytes: some Sequence<UInt8>) -> String {
        bytes.map { String(format: "%02x", $0) }.joined()
    }

    static func storageID(_ code: String) -> String {
        hex(SHA256.hash(data: Data("streamhub-sync:id:\(code)".utf8)))
    }

    static func sha256(_ data: Data) -> String {
        hex(SHA256.hash(data: data))
    }

    // 200 000 tours : à appeler hors du fil principal
    static func key(_ code: String) -> Data {
        let password = Array(code.utf8)
        let salt = Array("streamhub-sync:key".utf8)
        var derived = [UInt8](repeating: 0, count: 32)
        _ = CCKeyDerivationPBKDF(
            CCPBKDFAlgorithm(kCCPBKDF2), password.map { Int8(bitPattern: $0) }, password.count,
            salt, salt.count, CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256), 200_000, &derived, derived.count
        )
        return Data(derived)
    }

    // WebCrypto range l'étiquette d'authentification (16 octets) à la fin des données chiffrées
    static func encrypt(_ plain: Data, key: Data) throws -> (iv: String, data: String) {
        let box = try AES.GCM.seal(plain, using: SymmetricKey(data: key), nonce: AES.GCM.Nonce())
        return (Data(box.nonce).base64EncodedString(), (box.ciphertext + box.tag).base64EncodedString())
    }

    static func decrypt(iv: String, data: String, key: Data) throws -> Data {
        guard let nonce = Data(base64Encoded: iv), let sealed = Data(base64Encoded: data), sealed.count >= 16 else {
            throw SyncError("Données de synchronisation illisibles.")
        }
        let box = try AES.GCM.SealedBox(nonce: AES.GCM.Nonce(data: nonce), ciphertext: sealed.dropLast(16), tag: sealed.suffix(16))
        return try AES.GCM.open(box, using: SymmetricKey(data: key))
    }
}

struct SyncError: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}

@Observable
final class SyncService {
    // Propres à chaque appareil : jamais synchronisés (comme DEVICE_SETTINGS du site)
    static let deviceSettings: Set<String> = ["desktopApps", "primeApp", "glass"]
    // Téléchargements et questions en attente : sur l'appareil
    static let syncedLibrary = ["likes", "watchlist", "history", "platformLikes"]

    private let store: AppStore
    private(set) var isRunning = false
    @ObservationIgnored private var keys: [String: Data] = [:]
    @ObservationIgnored private var running: Task<Bool, Error>?
    @ObservationIgnored private var again = false
    @ObservationIgnored private var debounce: Task<Void, Never>?
    @ObservationIgnored var onPulled: (() -> Void)?

    init(store: AppStore) {
        self.store = store
        store.onChange = { [weak self] in self?.schedule(after: 2) }
    }

    var code: String? { store.syncMeta.code.map(SyncCrypto.format) }

    // ---------- Données synchronisées ----------

    private func localPayload() -> [String: JSON] {
        var settings = store.settings
        for key in Self.deviceSettings { settings[key] = nil }
        var library: [String: JSON] = [:]
        for key in Self.syncedLibrary {
            library[key] = store.library[key] ?? (key == "platformLikes" ? .object([:]) : .array([]))
        }
        return ["settings": .object(settings), "library": .object(library)]
    }

    private func applyPayload(_ payload: [String: JSON]) {
        let incoming = payload["settings"]?.object ?? [:]
        store.updateSettings(quiet: true) { settings in
            for (key, value) in incoming where !Self.deviceSettings.contains(key) { settings[key] = value }
        }
        let lists = payload["library"]?.object ?? [:]
        store.updateLibrary(quiet: true) { library in
            for (key, value) in lists { library[key] = value }
        }
    }

    private func hashes(_ payload: [String: JSON]) -> SyncMeta.Hashes {
        SyncMeta.Hashes(
            settings: SyncCrypto.sha256((payload["settings"] ?? .null).canonicalData),
            library: SyncCrypto.sha256((payload["library"] ?? .null).canonicalData)
        )
    }

    // Réunit deux listes d'entrées { key, at } : une entrée par titre, la plus récente, triées du plus récent
    private func unionByKey(_ a: JSON?, _ b: JSON?, max: Int = .max) -> JSON {
        var byKey: [String: JSON] = [:]
        for entry in (a?.array ?? []) + (b?.array ?? []) {
            guard let key = entry["key"]?.string else { continue }
            if let previous = byKey[key], (entry["at"]?.double ?? 0) <= (previous["at"]?.double ?? 0) { continue }
            byKey[key] = entry
        }
        let sorted = byKey.values.sorted { ($0["at"]?.double ?? 0) > ($1["at"]?.double ?? 0) }
        return .array(Array(sorted.prefix(max)))
    }

    private func mergePlatformLikes(_ a: JSON?, _ b: JSON?) -> JSON {
        var out = b?.object ?? [:]
        let id = { (p: JSON) in "\(p["service"]?.string ?? "")|\(p["platform"]?.string ?? "")" }
        for (key, list) in a?.object ?? [:] {
            let existing = out[key]?.array ?? []
            let seen = Set(existing.map(id))
            out[key] = .array(existing + (list.array ?? []).filter { !seen.contains(id($0)) })
        }
        return .object(out)
    }

    private func merge(local: [String: JSON], remote: [String: JSON], settingsChanged: Bool, libraryChanged: Bool) -> [String: JSON] {
        let mine = local["library"]
        let theirs = remote["library"]
        let library: JSON = libraryChanged
            ? .object([
                "likes": unionByKey(mine?["likes"], theirs?["likes"]),
                "watchlist": unionByKey(mine?["watchlist"], theirs?["watchlist"]),
                "history": unionByKey(mine?["history"], theirs?["history"], max: AppStore.historyMax),
                "platformLikes": mergePlatformLikes(mine?["platformLikes"], theirs?["platformLikes"]),
            ])
            : (theirs ?? .object([:]))
        return [
            "settings": settingsChanged ? (local["settings"] ?? .object([:])) : (remote["settings"] ?? .object([:])),
            "library": library,
        ]
    }

    // ---------- Échanges avec le relais ----------

    private struct Remote: Decodable {
        let updatedAt: Double
        let iv: String
        let data: String
    }

    private func endpoint(_ code: String) async -> (url: URL, key: Data) {
        let key: Data
        if let cached = keys[code] {
            key = cached
        } else {
            key = await Task.detached { SyncCrypto.key(code) }.value
            keys[code] = key
        }
        return (URL(string: "\(store.relayURL)/sync/\(SyncCrypto.storageID(code))")!, key)
    }

    private func fetchRemote(_ url: URL) async throws -> Remote? {
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        guard let (data, response) = try? await URLSession.shared.data(for: request), let http = response as? HTTPURLResponse else {
            throw SyncError("Relais injoignable (hors ligne ?).")
        }
        if http.statusCode == 404 { return nil }
        guard http.statusCode == 200 else { throw SyncError("Relais : erreur \(http.statusCode).") }
        return try JSONDecoder().decode(Remote.self, from: data)
    }

    private func push(_ url: URL, key: Data, payload: [String: JSON]) async throws -> Double {
        let sealed = try SyncCrypto.encrypt(try JSONEncoder().encode(payload), key: key)
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.httpBody = try JSONEncoder().encode(["iv": sealed.iv, "data": sealed.data])
        guard let (data, response) = try? await URLSession.shared.data(for: request), let http = response as? HTTPURLResponse else {
            throw SyncError("Relais injoignable (hors ligne ?).")
        }
        guard http.statusCode == 200 else { throw SyncError("Relais : erreur \(http.statusCode).") }
        struct Answer: Decodable { let updatedAt: Double }
        return try JSONDecoder().decode(Answer.self, from: data).updatedAt
    }

    // Une synchronisation : récupère les changements des autres appareils, envoie ceux d'ici.
    // Renvoie true si des données sont arrivées.
    private func run() async throws -> Bool {
        var meta = store.syncMeta
        guard let code = meta.code else { return false }
        let (url, key) = await endpoint(code)
        let local = localPayload()
        let now = hashes(local)
        let settingsChanged = now.settings != meta.hashes?.settings
        let libraryChanged = now.library != meta.hashes?.library
        let localChanged = settingsChanged || libraryChanged

        let remote = try await fetchRemote(url)
        var pulled = false
        var toPush: [String: JSON]?
        if let remote, remote.updatedAt != meta.syncedAt {
            let plain = try SyncCrypto.decrypt(iv: remote.iv, data: remote.data, key: key)
            let theirs = try JSONDecoder().decode([String: JSON].self, from: plain)
            let next = localChanged ? merge(local: local, remote: theirs, settingsChanged: settingsChanged, libraryChanged: libraryChanged) : theirs
            applyPayload(next)
            pulled = true
            meta.syncedAt = remote.updatedAt
            if localChanged { toPush = next }
        } else if remote == nil || localChanged {
            toPush = local
        }
        if let toPush { meta.syncedAt = try await push(url, key: key, payload: toPush) }
        meta.hashes = hashes(localPayload())
        meta.lastSyncAt = Date().timeIntervalSince1970 * 1000
        meta.error = nil
        store.syncMeta = meta
        return pulled
    }

    // Une seule synchronisation à la fois ; une demande pendant qu'une tourne en relance une juste après
    @discardableResult
    func syncNow() async throws -> Bool {
        if let running {
            again = true
            return try await running.value
        }
        let task = Task { try await run() }
        running = task
        isRunning = true
        defer {
            running = nil
            isRunning = false
            if again {
                again = false
                schedule(after: 0)
            }
        }
        do {
            let pulled = try await task.value
            if pulled { onPulled?() }
            return pulled
        } catch {
            if store.syncMeta.code != nil { store.syncMeta.error = error.localizedDescription }
            throw error
        }
    }

    // ---------- Actions des réglages ----------

    // Nouveau code pour cet appareil : ses données deviennent la référence
    func createCode() async throws {
        store.syncMeta = SyncMeta(code: SyncCrypto.newCode())
        try await syncNow()
    }

    // Code créé sur un autre appareil (ou sur le site) : on récupère ses données. Si cet appareil a déjà des listes,
    // elles sont ajoutées ; ses réglages sont remplacés.
    func join(_ input: String) async throws {
        let code = SyncCrypto.normalize(input)
        guard SyncCrypto.isValid(code) else {
            throw SyncError("Code invalide : 20 lettres et chiffres (ex. ABCD-EFGH-JKLM-NPQR-STUV).")
        }
        let (url, _) = await endpoint(code)
        guard try await fetchRemote(url) != nil else {
            throw SyncError("Aucune donnée pour ce code. Vérifie-le, ou crée un nouveau code.")
        }
        let local = localPayload()
        let now = hashes(local)
        let hasLibrary = Self.syncedLibrary.contains { key in
            let value = local["library"]?[key]
            return !(value?.array?.isEmpty ?? true) || !(value?.object?.isEmpty ?? true)
        }
        // Empreintes « déjà synchronisées » = ce côté n'a rien à imposer : les données distantes s'appliquent
        store.syncMeta = SyncMeta(code: code, hashes: .init(settings: now.settings, library: hasLibrary ? nil : now.library))
        try await syncNow()
    }

    func leave() {
        debounce?.cancel()
        store.syncMeta = SyncMeta()
    }

    // ---------- Synchronisation automatique ----------

    func schedule(after seconds: Double) {
        guard store.syncMeta.code != nil else { return }
        debounce?.cancel()
        debounce = Task { [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            self?.debounce = nil
            _ = try? await self?.syncNow() // erreur gardée dans l'état et affichée dans les réglages
        }
    }

    // Retour dans l'appli : on reprend les changements des autres appareils (au plus toutes les 30 s)
    func appBecameActive() {
        let last = (store.syncMeta.lastSyncAt ?? 0) / 1000
        if Date().timeIntervalSince1970 - last > 30 { schedule(after: 0) }
    }

    // On quitte l'appli : une modification en attente part tout de suite
    func appWentToBackground() {
        if debounce != nil { schedule(after: 0) }
    }
}
