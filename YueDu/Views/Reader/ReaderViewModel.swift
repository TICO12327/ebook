import Foundation
import SwiftData
import SwiftUI

@Observable
@MainActor
final class ReaderViewModel {
    enum State: Equatable {
        case loading
        case ready
        case failed(String)
    }

    private(set) var state: State = .loading
    private(set) var chapters: [EPUBChapter] = []
    var currentChapterIndex: Int = 0

    private let book: Book
    private var chapterOffsets: [Int: Double] = [:]
    private var restoredChapters: Set<Int> = []

    init(book: Book) {
        self.book = book
        self.currentChapterIndex = book.progressChapterIndex
    }

    var currentChapter: EPUBChapter? {
        guard chapters.indices.contains(currentChapterIndex) else { return nil }
        return chapters[currentChapterIndex]
    }

    func load(force: Bool = false) async {
        if !force, state == .ready { return }

        state = .loading

        guard let fileName = book.localFileName else {
            state = .failed("这本书没有下载到本地")
            return
        }

        let fileURL = BookStorage.localURL(for: fileName)
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            state = .failed("本地文件已丢失，请重新下载")
            return
        }

        do {
            let bookID = book.id
            let parsed = try await Task.detached(priority: .userInitiated) {
                try EPUBParser().parse(fileURL: fileURL, cacheID: bookID)
            }.value

            chapters = parsed.chapters
            currentChapterIndex = min(
                max(book.progressChapterIndex, 0),
                max(parsed.chapters.count - 1, 0)
            )
            chapterOffsets[currentChapterIndex] = book.progressChapterOffset
            state = .ready
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func chapterDidChange() {
        guard chapters.indices.contains(currentChapterIndex) else { return }
    }

    func goToPreviousChapter() {
        guard currentChapterIndex > 0 else { return }
        currentChapterIndex -= 1
        chapterDidChange()
    }

    func goToNextChapter() {
        guard currentChapterIndex < chapters.count - 1 else { return }
        currentChapterIndex += 1
        chapterDidChange()
    }

    func jumpToChapter(_ index: Int) {
        guard chapters.indices.contains(index) else { return }
        currentChapterIndex = index
        chapterDidChange()
    }

    func updateScrollPosition(chapterIndex: Int, offset: Double) {
        chapterOffsets[chapterIndex] = offset
    }

    func paragraphIndex(for chapterIndex: Int, paragraphCount: Int) -> Int {
        guard paragraphCount > 0 else { return 0 }
        guard !restoredChapters.contains(chapterIndex) else { return 0 }
        restoredChapters.insert(chapterIndex)

        let offset = chapterOffsets[chapterIndex]
            ?? (chapterIndex == book.progressChapterIndex ? book.progressChapterOffset : 0)
        guard offset > 0 else { return 0 }

        return min(Int(Double(paragraphCount) * offset), paragraphCount)
    }

    func persistProgress(in context: ModelContext) {
        guard !chapters.isEmpty else { return }
        book.progressChapterIndex = currentChapterIndex
        book.progressChapterOffset = chapterOffsets[currentChapterIndex] ?? book.progressChapterOffset
        book.lastOpenedAt = .now
        try? context.save()
    }
}
