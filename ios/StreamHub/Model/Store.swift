import Foundation
import Observation

nonisolated enum MediaType: String, Codable, Hashable, Sendable {
    case movie, tv
}

// Une plateforme cochée dans « Mes abonnements » : { id, name, logo } comme sur le site
nonisolated struct Provider: Codable, Hashable, Identifiable, Sendable {
    let id: Int
    var name: String
    var logo: String?
}

// Une rangée de l'accueil : affichée ou non (Réglages → Accueil)
nonisolated struct HomeChoice: Codable, Hashable, Identifiable, Sendable {
    let key: String
    var on: Bool
    var id: String { key }
}

// Les listes de la bibliothèque synchronisées avec le site
enum LibraryList: String, CaseIterable, Identifiable {
    case watchlist, likes, history
    var id: String { rawValue }
    var title: String {
        switch self {
        case .watchlist: "Ma liste"
        case .likes: "J’aime"
        case .history: "Historique"
        }
    }
}

// Une entrée de la bibliothèque, telle que le site l'écrit :
// { key, type, id, title, poster, date, platform, service, href, season, episode, episodeName, at }
struct LibraryEntry: Identifiable, Hashable {
    var raw: [String: JSON]

    var id: String { key }
    var key: String { raw["key"]?.string ?? "" }
    var type: MediaType { MediaType(rawValue: raw["type"]?.string ?? "") ?? .movie }
    var tmdbID: Int { raw["id"]?.int ?? 0 }
    var title: String { raw["title"]?.string ?? "" }
    var poster: String? { raw["poster"]?.string }
    var platform: String? { raw["platform"]?.string }
    var season: Int? { raw["season"]?.int }
    var episode: Int? { raw["episode"]?.int }
    var at: Double { raw["at"]?.double ?? 0 }

    var ref: TitleRef { TitleRef(type: type, id: tmdbID, title: title, poster: poster) }

    static func key(_ type: MediaType, _ id: Int) -> String { "\(type.rawValue):\(id)" }

    init(raw: [String: JSON]) { self.raw = raw }

    init(ref: TitleRef, date: String? = nil) {
        var raw: [String: JSON] = [
            "key": .string(Self.key(ref.type, ref.id)),
            "type": .string(ref.type.rawValue),
            "id": .int(Int64(ref.id)),
            "title": .string(ref.title),
        ]
        if let poster = ref.poster { raw["poster"] = .string(poster) }
        if let date { raw["date"] = .string(date) }
        self.raw = raw
    }
}

// État de la synchronisation sur cet appareil (comme loadSyncMeta du site)
struct SyncMeta: Codable, Equatable {
    var code: String?
    var syncedAt: Double?
    var hashes: Hashes?
    var lastSyncAt: Double?
    var error: String?

    struct Hashes: Codable, Equatable {
        var settings: String?
        var library: String?
    }
}

// Réglages et bibliothèque de l'appareil, enregistrés dans UserDefaults. Chaque modification est signalée
// (onChange) pour que la synchronisation l'envoie aux autres appareils.
@Observable
final class AppStore {
    nonisolated static let defaultRelay = "https://streamhub-relay.arthursavournin.workers.dev"
    nonisolated static let site = URL(string: "https://arthursavournin.github.io/streamhub/")!
    nonisolated static let historyMax = 30

    private(set) var settings: [String: JSON]
    private(set) var library: [String: JSON]
    var syncMeta: SyncMeta { didSet { save(syncMeta, as: Keys.sync) } }

    @ObservationIgnored var onChange: (() -> Void)?

    private enum Keys {
        static let settings = "streamhub:settings"
        static let library = "streamhub:library"
        static let sync = "streamhub:sync"
    }

    init() {
        let defaults = UserDefaults.standard
        let read = { (key: String) -> [String: JSON] in
            defaults.data(forKey: key).flatMap { try? JSONDecoder().decode([String: JSON].self, from: $0) } ?? [:]
        }
        settings = read(Keys.settings)
        library = read(Keys.library)
        syncMeta = defaults.data(forKey: Keys.sync).flatMap { try? JSONDecoder().decode(SyncMeta.self, from: $0) } ?? SyncMeta()
    }

    private func save<T: Encodable>(_ value: T, as key: String) {
        UserDefaults.standard.set(try? JSONEncoder().encode(value), forKey: key)
    }

    // quiet : écriture venant de la synchronisation elle-même (pas besoin de la renvoyer)
    func updateSettings(quiet: Bool = false, _ change: (inout [String: JSON]) -> Void) {
        change(&settings)
        save(settings, as: Keys.settings)
        if !quiet { onChange?() }
    }

    func updateLibrary(quiet: Bool = false, _ change: (inout [String: JSON]) -> Void) {
        change(&library)
        save(library, as: Keys.library)
        if !quiet { onChange?() }
    }

    // ---------- Réglages ----------

    var tmdbKey: String { settings["tmdbKey"]?.string?.trimmingCharacters(in: .whitespaces) ?? "" }
    var saKey: String { settings["saKey"]?.string?.trimmingCharacters(in: .whitespaces) ?? "" }
    var region: String { settings["region"]?.string.flatMap { $0.isEmpty ? nil : $0 } ?? "FR" }
    var language: String { settings["language"]?.string.flatMap { $0.isEmpty ? nil : $0 } ?? "fr-FR" }
    var relayURL: String {
        let relay = settings["relay"]?.string ?? ""
        return (relay.isEmpty ? Self.defaultRelay : relay).replacingOccurrences(of: #"/+$"#, with: "", options: .regularExpression)
    }
    var providers: [Provider] { settings["providers"]?.decode([Provider].self) ?? [] }

    func setSetting(_ key: String, _ value: JSON) {
        updateSettings { $0[key] = value }
    }

    // ---------- Accueil (réglage synchronisé, même forme que le site) ----------
    // home = { rows: [{ key, on }], hero: { type, id, title, poster } | null }

    // Rangées dans l'ordre choisi ; les rangées absentes de l'enregistrement (ajoutées depuis) à la fin, affichées
    var homeLayout: [HomeChoice] {
        let known = HomeRow.home.map(\.key)
        let saved = (settings["home"]?["rows"]?.decode([HomeChoice].self) ?? []).filter { known.contains($0.key) }
        let seen = Set(saved.map(\.key))
        return saved + known.filter { !seen.contains($0) }.map { HomeChoice(key: $0, on: true) }
    }

    var homeHero: TitleRef? { settings["home"]?["hero"]?.decode(TitleRef.self) }

    func setHome(rows: [HomeChoice], hero: TitleRef?) {
        updateSettings { $0["home"] = .object(["rows": JSON.from(rows), "hero": hero.map(JSON.from) ?? .null]) }
    }

    func setProviders(_ list: [Provider]) {
        updateSettings { $0["providers"] = JSON.from(list) }
    }

    // ---------- Bibliothèque ----------

    func entries(_ list: LibraryList) -> [LibraryEntry] {
        (library[list.rawValue]?.array ?? []).compactMap { $0.object.map(LibraryEntry.init(raw:)) }
    }

    func contains(_ list: LibraryList, _ ref: TitleRef) -> Bool {
        let key = LibraryEntry.key(ref.type, ref.id)
        return entries(list).contains { $0.key == key }
    }

    // Ajoute en tête de liste (en remplaçant l'éventuelle entrée existante)
    private func putFirst(_ list: LibraryList, _ entry: LibraryEntry, max: Int = .max) {
        var entry = entry
        entry.raw["at"] = .double((Date().timeIntervalSince1970 * 1000).rounded())
        let others = entries(list).filter { $0.key != entry.key }
        updateLibrary { $0[list.rawValue] = .array(([entry] + others).prefix(max).map { .object($0.raw) }) }
    }

    func remove(_ list: LibraryList, key: String) {
        updateLibrary { $0[list.rawValue] = .array(entries(list).filter { $0.key != key }.map { .object($0.raw) }) }
    }

    // Ajoute ou retire le titre ; renvoie true s'il est maintenant dans la liste
    @discardableResult
    func toggle(_ list: LibraryList, _ ref: TitleRef, date: String? = nil) -> Bool {
        let key = LibraryEntry.key(ref.type, ref.id)
        if contains(list, ref) {
            remove(list, key: key)
            return false
        }
        putFirst(list, LibraryEntry(ref: ref, date: date))
        return true
    }

    // Pour une série, une seule ligne par série : le dernier épisode lancé
    func recordWatch(_ entry: LibraryEntry) {
        putFirst(.history, entry, max: Self.historyMax)
    }
}
