import Foundation

actor DownloadService {
    static let shared = DownloadService()

    private let session: URLSession
    private var activeTasks: [URL: Task<URL, Error>] = [:]

    init(session: URLSession = .shared) {
        self.session = session
    }

    func download(from remoteURL: URL, suggestedTitle: String) async throws -> URL {
        if let existing = activeTasks[remoteURL] {
            return try await existing.value
        }

        let task = Task<URL, Error> {
            let (temporaryURL, response) = try await session.download(from: remoteURL)

            guard let httpResponse = response as? HTTPURLResponse,
                  200..<300 ~= httpResponse.statusCode else {
                throw DownloadError.invalidResponse
            }

            let fileName = BookStorage.makeFileName(title: suggestedTitle)
            let destination = BookStorage.localURL(for: fileName)
            try? FileManager.default.removeItem(at: destination)
            try FileManager.default.moveItem(at: temporaryURL, to: destination)
            return destination
        }

        activeTasks[remoteURL] = task

        do {
            let result = try await task.value
            activeTasks[remoteURL] = nil
            return result
        } catch {
            activeTasks[remoteURL] = nil
            throw error
        }
    }
}

enum DownloadError: LocalizedError {
    case invalidResponse
    case notAnEPUB

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            "网络响应异常"
        case .notAnEPUB:
            "该文件不是可用的 EPUB"
        }
    }
}
