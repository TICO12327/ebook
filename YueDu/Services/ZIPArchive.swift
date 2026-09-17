import Foundation
import Compression

/// Minimal read-only ZIP reader for EPUB files.
/// Supports stored (0) and deflate (8) entries, which covers virtually all EPUBs.
struct ZIPArchive {
    struct Entry {
        let path: String
        let compressionMethod: UInt16
        let compressedSize: Int
        let uncompressedSize: Int
        let localHeaderOffset: Int
    }

    private let data: Data
    private let entries: [String: Entry]

    init(data: Data) throws {
        self.data = data
        self.entries = try Self.readDirectory(in: data)
    }

    var paths: [String] {
        Array(entries.keys)
    }

    func contains(_ path: String) -> Bool {
        entries[path] != nil
    }

    func data(for path: String) throws -> Data {
        guard let entry = entries[path] else {
            throw ZIPError.entryNotFound(path)
        }

        return try read(entry)
    }

    // MARK: - Central directory

    private static func readDirectory(in data: Data) throws -> [String: Entry] {
        guard let endOffset = findEndOfCentralDirectory(in: data) else {
            throw ZIPError.invalidArchive
        }

        let entryCount = Int(data.uint16(at: endOffset + 10))
        let directoryOffset = Int(data.uint32(at: endOffset + 16))

        guard entryCount > 0, directoryOffset >= 0, directoryOffset < data.count else {
            throw ZIPError.invalidArchive
        }

        var entries: [String: Entry] = [:]
        var cursor = directoryOffset

        for _ in 0..<entryCount {
            guard cursor + 46 <= data.count else { break }
            guard data.uint32(at: cursor) == 0x0201_4B50 else {
                throw ZIPError.invalidArchive
            }

            let flags = data.uint16(at: cursor + 8)
            let method = data.uint16(at: cursor + 10)
            let compressedSize = Int(data.uint32(at: cursor + 20))
            let uncompressedSize = Int(data.uint32(at: cursor + 24))
            let nameLength = Int(data.uint16(at: cursor + 28))
            let extraLength = Int(data.uint16(at: cursor + 30))
            let commentLength = Int(data.uint16(at: cursor + 32))
            let localOffset = Int(data.uint32(at: cursor + 42))

            let nameStart = cursor + 46
            let nameEnd = nameStart + nameLength
            guard nameEnd <= data.count else { break }

            _ = flags
            let name = String(data: data.subdata(in: nameStart..<nameEnd), encoding: .utf8)
                ?? String(data: data.subdata(in: nameStart..<nameEnd), encoding: .isoLatin1)
                ?? ""

            if !name.isEmpty, !name.hasSuffix("/") {
                entries[normalize(name)] = Entry(
                    path: name,
                    compressionMethod: method,
                    compressedSize: compressedSize,
                    uncompressedSize: uncompressedSize,
                    localHeaderOffset: localOffset
                )
            }

            cursor = nameEnd + extraLength + commentLength
        }

        guard !entries.isEmpty else {
            throw ZIPError.invalidArchive
        }

        return entries
    }

    private static func findEndOfCentralDirectory(in data: Data) -> Int? {
        guard data.count >= 22 else { return nil }

        let minimumOffset = max(0, data.count - 65_557)
        var offset = data.count - 22

        while offset >= minimumOffset {
            if data.uint32(at: offset) == 0x0605_4B50 {
                return offset
            }
            offset -= 1
        }

        return nil
    }

    // MARK: - Entry data

    private func read(_ entry: Entry) throws -> Data {
        let headerOffset = entry.localHeaderOffset
        guard headerOffset + 30 <= data.count,
              data.uint32(at: headerOffset) == 0x0403_4B50 else {
            throw ZIPError.invalidArchive
        }

        let nameLength = Int(data.uint16(at: headerOffset + 26))
        let extraLength = Int(data.uint16(at: headerOffset + 28))
        let payloadStart = headerOffset + 30 + nameLength + extraLength
        let payloadEnd = payloadStart + entry.compressedSize

        guard payloadStart <= payloadEnd, payloadEnd <= data.count else {
            throw ZIPError.invalidArchive
        }

        let payload = data.subdata(in: payloadStart..<payloadEnd)

        switch entry.compressionMethod {
        case 0:
            return payload
        case 8:
            return try inflate(payload, expectedSize: entry.uncompressedSize)
        default:
            throw ZIPError.unsupportedCompression(entry.compressionMethod)
        }
    }

    private func inflate(_ payload: Data, expectedSize: Int) throws -> Data {
        guard expectedSize > 0 else { return Data() }

        // ZIP deflate streams are raw; wrap with a valid zlib header so libcompression accepts them.
        // CMF 0x78 is legal for a 32K window, FLG 0x9C makes the header checksum valid.
        var wrapped = Data([0x78, 0x9C])
        wrapped.append(payload)

        var output = Data(count: expectedSize + 64)
        let decodedSize: Int = output.withUnsafeMutableBytes { destinationBuffer in
            guard let destinationPointer = destinationBuffer.bindMemory(to: UInt8.self).baseAddress else {
                return 0
            }

            return wrapped.withUnsafeBytes { sourceBuffer in
                guard let sourcePointer = sourceBuffer.bindMemory(to: UInt8.self).baseAddress else {
                    return 0
                }

                return compression_decode_buffer(
                    destinationPointer,
                    output.count,
                    sourcePointer,
                    wrapped.count,
                    nil,
                    COMPRESSION_ZLIB
                )
            }
        }

        guard decodedSize > 0 else {
            throw ZIPError.decompressionFailed
        }

        return Data(output.prefix(decodedSize))
    }

    private func normalize(_ path: String) -> String {
        var normalized = path
        while normalized.hasPrefix("./") {
            normalized.removeFirst(2)
        }
        return normalized.removingPercentEncoding ?? normalized
    }
}

enum ZIPError: LocalizedError {
    case invalidArchive
    case entryNotFound(String)
    case unsupportedCompression(UInt16)
    case decompressionFailed

    var errorDescription: String? {
        switch self {
        case .invalidArchive:
            "EPUB 文件结构无效"
        case .entryNotFound(let path):
            "EPUB 中缺少文件：\(path)"
        case .unsupportedCompression(let method):
            "EPUB 使用了不支持的压缩方式：\(method)"
        case .decompressionFailed:
            "EPUB 内容解压失败"
        }
    }
}

private extension Data {
    func uint16(at offset: Int) -> UInt16 {
        guard offset >= 0, offset + 2 <= count else { return 0 }
        return withUnsafeBytes { pointer in
            pointer.loadUnaligned(fromByteOffset: offset, as: UInt16.self)
        }
    }

    func uint32(at offset: Int) -> UInt32 {
        guard offset >= 0, offset + 4 <= count else { return 0 }
        return withUnsafeBytes { pointer in
            pointer.loadUnaligned(fromByteOffset: offset, as: UInt32.self)
        }
    }
}
