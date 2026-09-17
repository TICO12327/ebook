import Foundation
import SwiftData

@Model
final class Book {
    @Attribute(.unique) var id: UUID
    var title: String
    var author: String
    var summary: String
    var coverURL: URL?
    var sourceURL: URL?
    var localFileName: String?
    var addedAt: Date
    var lastOpenedAt: Date?
    var progressCharacterOffset: Int
    var progressChapterIndex: Int
    var progressChapterOffset: Double

    init(
        id: UUID = UUID(),
        title: String,
        author: String = "未知作者",
        summary: String = "",
        coverURL: URL? = nil,
        sourceURL: URL? = nil,
        localFileName: String? = nil,
        addedAt: Date = .now,
        lastOpenedAt: Date? = nil,
        progressCharacterOffset: Int = 0,
        progressChapterIndex: Int = 0,
        progressChapterOffset: Double = 0
    ) {
        self.id = id
        self.title = title
        self.author = author
        self.summary = summary
        self.coverURL = coverURL
        self.sourceURL = sourceURL
        self.localFileName = localFileName
        self.addedAt = addedAt
        self.lastOpenedAt = lastOpenedAt
        self.progressCharacterOffset = progressCharacterOffset
        self.progressChapterIndex = progressChapterIndex
        self.progressChapterOffset = progressChapterOffset
    }
}

extension Book {
    var isDownloaded: Bool {
        guard let localFileName else { return false }
        return FileManager.default.fileExists(
            atPath: BookStorage.localURL(for: localFileName).path
        )
    }
}
