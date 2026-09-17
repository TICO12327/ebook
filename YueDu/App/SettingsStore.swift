import Foundation
import Observation
import SwiftUI

@Observable
final class SettingsStore {
    var readerSettings: ReaderSettings {
        didSet { persist() }
    }

    var catalogs: [OPDSCatalog] {
        didSet { persist() }
    }

    private let defaults: UserDefaults
    private var isLoaded = false

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.readerSettings = ReaderSettings()
        self.catalogs = OPDSCatalog.defaults
    }

    func prepare() async {
        guard !isLoaded else { return }
        isLoaded = true

        if let data = defaults.data(forKey: Keys.readerSettings),
           let decoded = try? JSONDecoder().decode(ReaderSettings.self, from: data) {
            readerSettings = decoded
        }

        if let data = defaults.data(forKey: Keys.catalogs),
           let decoded = try? JSONDecoder().decode([OPDSCatalog].self, from: data),
           !decoded.isEmpty {
            catalogs = decoded
        }
    }

    func resetReaderSettings() {
        readerSettings = ReaderSettings()
    }

    func addCatalog(name: String, urlString: String) -> Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedURL = urlString.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedName.isEmpty, let url = URL(string: trimmedURL), url.scheme != nil else {
            return false
        }

        catalogs.append(OPDSCatalog(name: trimmedName, url: url))
        return true
    }

    func removeCatalog(_ catalog: OPDSCatalog) {
        catalogs.removeAll { $0 == catalog }
    }

    private func persist() {
        guard isLoaded else { return }

        if let data = try? JSONEncoder().encode(readerSettings) {
            defaults.set(data, forKey: Keys.readerSettings)
        }

        if let data = try? JSONEncoder().encode(catalogs) {
            defaults.set(data, forKey: Keys.catalogs)
        }
    }

    private enum Keys {
        static let readerSettings = "reader.settings"
        static let catalogs = "opds.catalogs"
    }
}
