import Foundation

struct EPUBBook {
    let title: String
    let author: String
    let language: String
    let coverData: Data?
    let chapters: [EPUBChapter]
    let resourceBaseURL: URL
}

struct EPUBChapter: Identifiable, Hashable {
    let id: String
    let title: String
    let href: String
    let html: String
    let plainText: String
    let index: Int
}
