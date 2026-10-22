import CryptoKit
import Foundation
import Observation

// Synchronisation avec le site et les autres appareils par le compte StreamHub (Account.swift), compatible avec
// sync.js : même chiffrement (AES-GCM avec la clé du coffre), même règle de fusion. Supabase ne voit qu'un contenu
// illisible. (Avant la version 2.1.0, un code de synchronisation passait par le relais StreamHub : retiré à la
// demande de l'utilisateur, c'est le compte ou rien.)
nonisolated enum SyncCrypto {
    // Clés de secours : 20 caractères (100 bits) sans 0/O ni 1/I, faciles à confondre
    static let alphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
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

    static func sha256(_ data: Data) -> String {
        hex(SHA256.hash(data: data))
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
    let account: AccountService
    private(set) var isRunning = false
    @ObservationIgnored private var running: Task<Bool, Error>?
    @ObservationIgnored private var again = false
    @ObservationIgnored private var debounce: Task<Void, Never>?
    @ObservationIgnored var onPulled: (() -> Void)?

    init(store: AppStore, account: AccountService) {
        self.store = store
        self.account = account
        store.onChange = { [weak self] in self?.schedule(after: 2) }
        account.onVaultOpen = { [weak self] in self?.schedule(after: 0) } // compte ouvert : première synchro
    }

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

    private func hashes(_ payload: [String: JSON]) -> SyncHashes {
        SyncHashes(
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

    private func hasLibrary(_ payload: [String: JSON]) -> Bool {
        Self.syncedLibrary.contains { key in
            let value = payload["library"]?[key]
            return !(value?.array?.isEmpty ?? true) || !(value?.object?.isEmpty ?? true)
        }
    }

    // ---------- Une synchronisation ----------
    // État dans le compte (AccountMeta) : syncedAt (version de sync_data reçue ou envoyée), hashes, lastSyncAt, error

    // Récupère les changements des autres appareils, envoie ceux d'ici. Renvoie true si des données sont arrivées.
    private func run() async throws -> Bool {
        guard account.isOpen, let key = account.vaultKey else { return false }
        if account.meta.joining {
            // Coffre ouvert sur cet appareil (compte existant) : les réglages du compte s'appliquent et les listes
            // d'ici s'y ajoutent
            let local = localPayload()
            let now = hashes(local)
            let keepLists = hasLibrary(local)
            account.updateSync {
                $0.joining = false
                $0.syncedAt = nil
                $0.hashes = .init(settings: now.settings, library: keepLists ? nil : now.library)
            }
        }
        var pulled = false
        var attempt = 0
        do {
            while true {
                let meta = account.meta
                let remote = try await account.fetchData()
                // Données d'ici lues après la réponse du serveur : une modification faite pendant l'échange n'est pas
                // écrasée
                let local = localPayload()
                let now = hashes(local)
                let settingsChanged = now.settings != meta.hashes?.settings
                let libraryChanged = now.library != meta.hashes?.library
                let localChanged = settingsChanged || libraryChanged

                var syncedAt = meta.syncedAt
                var toPush: [String: JSON]?
                var server = local // ce que le serveur a maintenant (ses empreintes sont gardées)
                if let remote, remote.version != syncedAt {
                    let plain = try SyncCrypto.decrypt(iv: remote.iv, data: remote.data, key: key)
                    let theirs = try JSONDecoder().decode([String: JSON].self, from: plain)
                    let next = localChanged ? merge(local: local, remote: theirs, settingsChanged: settingsChanged, libraryChanged: libraryChanged) : theirs
                    applyPayload(next)
                    pulled = true
                    syncedAt = remote.version
                    server = next
                    if localChanged { toPush = next }
                } else if remote == nil || localChanged {
                    toPush = local
                }
                do {
                    if let toPush {
                        let sealed = try SyncCrypto.encrypt(try JSONEncoder().encode(toPush), key: key)
                        syncedAt = try await account.pushData(iv: sealed.iv, data: sealed.data, version: remote?.version)
                        server = toPush
                    }
                } catch is SyncConflict where attempt < 4 {
                    // Un autre appareil a écrit entre la lecture et l'écriture : on relit et on fusionne (ce qui vient
                    // d'être appliqué compte comme un changement d'ici, puisque les empreintes n'ont pas bougé)
                    attempt += 1
                    account.updateSync { $0.syncedAt = syncedAt }
                    continue
                }
                // Empreintes de ce qui a été envoyé ou reçu, pas des données d'ici relues maintenant : une modification
                // faite pendant l'envoi reste « à envoyer »
                let done = hashes(server)
                account.updateSync {
                    $0.syncedAt = syncedAt
                    $0.hashes = done
                    $0.lastSyncAt = Date().timeIntervalSince1970 * 1000
                    $0.error = nil
                }
                if pulled { onPulled?() }
                return pulled
            }
        } catch {
            if account.signedIn { account.updateSync { $0.error = error.localizedDescription } }
            if pulled { onPulled?() } // des données sont déjà arrivées : l'appli se redessine
            throw error
        }
    }

    // Une seule synchronisation à la fois ; une demande pendant qu'une tourne en relance une juste après.
    // Erreur gardée dans l'état du compte et affichée dans les réglages.
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
        return try await task.value
    }

    // ---------- Synchronisation automatique ----------

    func schedule(after seconds: Double) {
        guard account.isOpen else { return }
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
        let last = (account.meta.lastSyncAt ?? 0) / 1000
        if Date().timeIntervalSince1970 - last > 30 { schedule(after: 0) }
    }

    // On quitte l'appli : une modification en attente part tout de suite
    func appWentToBackground() {
        if debounce != nil { schedule(after: 0) }
    }
}
