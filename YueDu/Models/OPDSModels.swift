import Foundation

struct OPDSCatalog: Codable, Hashable {
    var name: String
    var url: URL
}

struct OPDSFeed {
    let title: String
    let entries: [OPDSEntry]
}

struct OPDSEntry: Identifiable, Hashable {
    let id: String
    let title: String
    let author: String
    let summary: String
    let coverURL: URL?
    let acquisitionURL: URL?
    let language: String
}

extension OPDSCatalog {
    static let projectGutenberg = OPDSCatalog(
        name: "Project Gutenberg",
        url: URL(string: "https://www.gutenberg.org/ebooks/search.opds/?sort_order=downloads")!
    )

    static let standardEbooks = OPDSCatalog(
        name: "Standard Ebooks",
        url: URL(string: "https://standardebooks.org/feeds/opds")!
    )

    static let defaults: [OPDSCatalog] = [
        .projectGutenberg,
        .standardEbooks
    ]
}
