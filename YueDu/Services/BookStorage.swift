import Foundation

enum BookStorage {
    private static let directoryName = "Books"

    static var rootDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let directory = base.appendingPathComponent(directoryName, isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    static func localURL(for fileName: String) -> URL {
        rootDirectory.appendingPathComponent(fileName, isDirectory: false)
    }

    static func makeFileName(title: String, extension ext: String = "epub") -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        var buffer = ""
        for scalar in title.unicodeScalars {
            if allowed.contains(scalar) {
                buffer.unicodeScalars.append(scalar)
            } else {
                buffer.append("-")
            }
        }

        let sanitized = buffer
            .replacingOccurrences(of: "-+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
            .prefix(60)
        let unique = UUID().uuidString.prefix(8)
        return "\(sanitized.isEmpty ? "book" : String(sanitized))-\(unique).\(ext)"
    }

    static func save(data: Data, fileName: String) throws -> URL {
        let url = localURL(for: fileName)
        try data.write(to: url, options: .atomic)
        return url
    }

    static func remove(fileName: String) {
        try? FileManager.default.removeItem(at: localURL(for: fileName))
    }

    static func cacheDirectory(for bookID: UUID) -> URL {
        let directory = rootDirectory
            .appendingPathComponent("Extracted", isDirectory: true)
            .appendingPathComponent(bookID.uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    static func removeCache(for bookID: UUID) {
        try? FileManager.default.removeItem(at: cacheDirectory(for: bookID))
    }

    static func saveCover(data: Data, bookID: UUID) -> URL? {
        let directory = rootDirectory.appendingPathComponent("Covers", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("\(bookID.uuidString).jpg", isDirectory: false)
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }
}
