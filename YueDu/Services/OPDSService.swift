import Foundation

struct OPDSService {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func loadFeed(from url: URL) async throws -> OPDSFeed {
        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              200..<300 ~= httpResponse.statusCode else {
            throw OPDSError.invalidResponse
        }

        let parser = OPDSXMLParser()
        return try parser.parse(data: data, baseURL: url)
    }

    func search(query: String, in catalog: OPDSCatalog) async throws -> OPDSFeed {
        let baseURL: URL

        if catalog.url.absoluteString.contains("gutenberg.org") {
            baseURL = URL(string: "https://www.gutenberg.org/ebooks/search.opds/") ?? catalog.url
        } else {
            baseURL = catalog.url
        }

        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        var items = components?.queryItems ?? []
        items.append(URLQueryItem(name: "query", value: query))
        components?.queryItems = items

        guard let url = components?.url else {
            throw OPDSError.invalidURL
        }

        return try await loadFeed(from: url)
    }
}

enum OPDSError: LocalizedError {
    case invalidURL
    case invalidResponse
    case parseFailed

    var errorDescription: String? {
        switch self {
        case .invalidURL: "书源地址无效"
        case .invalidResponse: "书源响应异常"
        case .parseFailed: "书源内容无法解析"
        }
    }
}

private final class OPDSXMLParser: NSObject, XMLParserDelegate {
    private var feedTitle = ""
    private var entries: [OPDSEntry] = []
    private var currentEntry: EntryBuilder?
    private var elementStack: [String] = []
    private var textStack: [String] = []
    private var baseURL: URL?

    func parse(data: Data, baseURL: URL) throws -> OPDSFeed {
        self.baseURL = baseURL
        feedTitle = ""
        entries = []
        currentEntry = nil
        elementStack = []
        textStack = []

        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.shouldProcessNamespaces = true

        guard parser.parse() else {
            throw OPDSError.parseFailed
        }

        return OPDSFeed(title: feedTitle.isEmpty ? "在线书城" : feedTitle, entries: entries)
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        let name = localName(elementName, qualifiedName: qName)
        elementStack.append(name)
        textStack.append("")

        switch name {
        case "entry":
            currentEntry = EntryBuilder()
        case "link":
            guard currentEntry != nil else { break }
            let rel = attributeDict["rel"] ?? ""
            let type = attributeDict["type"] ?? ""
            let href = attributeDict["href"] ?? ""
            guard !href.isEmpty else { break }

            let url = URL(string: href, relativeTo: baseURL)?.absoluteURL
            if type.contains("image") || rel.contains("image") {
                if var entry = currentEntry, entry.coverURL == nil {
                    entry.coverURL = url
                    currentEntry = entry
                }
            } else if rel.contains("acquisition") || href.lowercased().hasSuffix(".epub") {
                if var entry = currentEntry, entry.acquisitionURL == nil {
                    entry.acquisitionURL = url
                    currentEntry = entry
                }
            }
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard !textStack.isEmpty else { return }
        textStack[textStack.count - 1] += string
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        let name = localName(elementName, qualifiedName: qName)
        let text = textStack.last?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let parent = elementStack.dropLast().last

        if var entry = currentEntry {
            switch name {
            case "id":
                if entry.id.isEmpty { entry.id = text }
            case "title":
                if parent == "entry", !text.isEmpty {
                    if entry.title.isEmpty {
                        entry.title = text
                    }
                }
            case "name":
                if parent == "author", !text.isEmpty {
                    entry.author = text
                }
            case "content", "summary":
                if !text.isEmpty {
                    entry.summary = text
                }
            case "language":
                if !text.isEmpty {
                    entry.language = text
                }
            case "entry":
                let built = entry.build()
                if !built.title.isEmpty {
                    entries.append(built)
                }
                currentEntry = nil
            default:
                break
            }

            if currentEntry != nil {
                currentEntry = entry
            }
        } else if name == "title", parent == "feed", feedTitle.isEmpty {
            feedTitle = text
        }

        if !elementStack.isEmpty {
            elementStack.removeLast()
        }
        if !textStack.isEmpty {
            textStack.removeLast()
        }
    }

    private func localName(_ elementName: String, qualifiedName: String?) -> String {
        let raw = qualifiedName ?? elementName
        if let colon = raw.lastIndex(of: ":") {
            return String(raw[raw.index(after: colon)...]).lowercased()
        }
        return raw.lowercased()
    }
}

private struct EntryBuilder {
    var id = ""
    var title = ""
    var author = ""
    var summary = ""
    var coverURL: URL?
    var acquisitionURL: URL?
    var language = ""

    func build() -> OPDSEntry {
        OPDSEntry(
            id: id.isEmpty ? UUID().uuidString : id,
            title: title,
            author: author.isEmpty ? "未知作者" : author,
            summary: summary,
            coverURL: coverURL,
            acquisitionURL: acquisitionURL,
            language: language
        )
    }
}
