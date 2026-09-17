import Foundation

final class EPUBParser {
    func parse(fileURL: URL, cacheID: UUID) throws -> EPUBBook {
        let archive = try ZIPArchive(data: Data(contentsOf: fileURL))
        let containerXML = try string(from: archive, path: "META-INF/container.xml")
        guard let opfPath = XMLText.firstMatch(
            in: containerXML,
            pattern: #"full-path\s*=\s*"([^"]+)""#
        ) else {
            throw EPUBParserError.missingPackageDocument
        }

        let normalizedOPFPath = normalize(path: opfPath)
        let opfDirectory = directoryPath(for: normalizedOPFPath)
        let opfXML = try string(from: archive, path: normalizedOPFPath)

        let title = XMLText.firstTagValue(in: opfXML, tag: "dc:title") ?? fileURL.deletingPathExtension().lastPathComponent
        let author = XMLText.firstTagValue(in: opfXML, tag: "dc:creator") ?? "未知作者"
        let language = XMLText.firstTagValue(in: opfXML, tag: "dc:language") ?? "zh"

        let manifest = parseManifest(opfXML)
        let spine = parseSpine(opfXML)
        let coverData = parseCoverData(
            manifest: manifest,
            opfDirectory: opfDirectory,
            opfXML: opfXML,
            archive: archive
        )
        let chapters = try parseChapters(
            manifest: manifest,
            spine: spine,
            opfDirectory: opfDirectory,
            archive: archive
        )

        return EPUBBook(
            title: title,
            author: author,
            language: language,
            coverData: coverData,
            chapters: chapters,
            resourceBaseURL: fileURL
        )
    }

    private func string(from archive: ZIPArchive, path: String) throws -> String {
        let data = try archive.data(for: normalize(path: path))
        if let utf8 = String(data: data, encoding: .utf8) {
            return utf8
        }
        if let utf16 = String(data: data, encoding: .utf16) {
            return utf16
        }
        if let latin = String(data: data, encoding: .isoLatin1) {
            return latin
        }
        throw ZIPError.entryNotFound(path)
    }

    private func parseManifest(_ opfXML: String) -> [String: ManifestItem] {
        let pattern = #"<item\b([^>]+)/?>"#
        let matches = XMLText.allMatches(in: opfXML, pattern: pattern)
        var manifest: [String: ManifestItem] = [:]

        for match in matches {
            let attributes = XMLText.attributes(in: match)
            guard let id = attributes["id"], let href = attributes["href"] else { continue }
            manifest[id] = ManifestItem(
                id: id,
                href: href,
                mediaType: attributes["media-type"] ?? "",
                properties: attributes["properties"] ?? ""
            )
        }

        return manifest
    }

    private func parseSpine(_ opfXML: String) -> [String] {
        let pattern = #"<itemref\b([^>]+)/?>"#
        return XMLText.allMatches(in: opfXML, pattern: pattern).compactMap { match in
            XMLText.attributes(in: match)["idref"]
        }
    }

    private func parseCoverData(
        manifest: [String: ManifestItem],
        opfDirectory: String,
        opfXML: String,
        archive: ZIPArchive
    ) -> Data? {
        let coverID = XMLText.firstMatch(
            in: opfXML,
            pattern: #"<meta\b[^>]*name\s*=\s*"cover"[^>]*content\s*=\s*"([^"]+)""#
        )

        if let coverID, let item = manifest[coverID] {
            let path = join(directory: opfDirectory, relative: item.href)
            return try? archive.data(for: path)
        }

        if let coverItem = manifest.values.first(where: { $0.properties.contains("cover-image") }) {
            let path = join(directory: opfDirectory, relative: coverItem.href)
            return try? archive.data(for: path)
        }

        if let imageItem = manifest.values.first(where: { $0.mediaType.hasPrefix("image/") }) {
            let path = join(directory: opfDirectory, relative: imageItem.href)
            return try? archive.data(for: path)
        }

        return nil
    }

    private func parseChapters(
        manifest: [String: ManifestItem],
        spine: [String],
        opfDirectory: String,
        archive: ZIPArchive
    ) throws -> [EPUBChapter] {
        var chapters: [EPUBChapter] = []

        for (index, idref) in spine.enumerated() {
            guard let item = manifest[idref],
                  item.mediaType.contains("html") || item.mediaType.contains("xhtml") else {
                continue
            }

            let path = join(directory: opfDirectory, relative: item.href)
            guard let html = try? string(from: archive, path: path) else { continue }

            let title = XMLText.firstTagValue(in: html, tag: "title")?.trimmingCharacters(in: .whitespacesAndNewlines)
                ?? XMLText.firstHeading(in: html)?.trimmingCharacters(in: .whitespacesAndNewlines)
                ?? "第 \(index + 1) 章"
            let plainText = HTMLTextExtractor.plainText(from: html)

            chapters.append(
                EPUBChapter(
                    id: item.id,
                    title: title,
                    href: item.href,
                    html: html,
                    plainText: plainText,
                    index: index
                )
            )
        }

        guard !chapters.isEmpty else {
            throw EPUBParserError.noReadableChapters
        }

        return chapters
    }

    private func normalize(path: String) -> String {
        let decoded = path.removingPercentEncoding ?? path
        let unified = decoded.replacingOccurrences(of: "\\", with: "/")
        var components: [String] = []

        for component in unified.split(separator: "/", omittingEmptySubsequences: true) {
            switch component {
            case ".":
                continue
            case "..":
                if !components.isEmpty {
                    components.removeLast()
                }
            default:
                components.append(String(component))
            }
        }

        return components.joined(separator: "/")
    }

    private func directoryPath(for filePath: String) -> String {
        let normalized = normalize(path: filePath)
        guard let lastSlash = normalized.lastIndex(of: "/") else { return "" }
        return String(normalized[..<lastSlash])
    }

    private func join(directory: String, relative: String) -> String {
        let normalizedRelative = normalize(path: relative)
        guard !directory.isEmpty else { return normalizedRelative }
        return normalize(path: "\(directory)/\(normalizedRelative)")
    }
}

private struct ManifestItem {
    let id: String
    let href: String
    let mediaType: String
    let properties: String
}

enum EPUBParserError: LocalizedError {
    case missingPackageDocument
    case noReadableChapters

    var errorDescription: String? {
        switch self {
        case .missingPackageDocument:
            "EPUB 缺少 OPF 描述文件"
        case .noReadableChapters:
            "这本书没有可读取的章节"
        }
    }
}
