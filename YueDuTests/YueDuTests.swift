import XCTest
@testable import YueDu

final class YueDuTests: XCTestCase {
    func testHTMLExtractionStripsTags() {
        let html = "<html><body><h1>第一章</h1><p>你好世界。</p><p>第二段。</p></body></html>"
        let text = HTMLTextExtractor.plainText(from: html)

        XCTAssertTrue(text.contains("第一章"))
        XCTAssertTrue(text.contains("你好世界。"))
        XCTAssertFalse(text.contains("<"))
    }

    func testHTMLEntitiesAreDecoded() {
        let html = "<p>A&nbsp;B &amp; C &#39;D&#39;</p>"
        let text = HTMLTextExtractor.plainText(from: html)

        XCTAssertEqual(text, "A B & C 'D'")
    }

    func testBookStorageFileNameSanitizesTitle() {
        let name = BookStorage.makeFileName(title: "三体 / 刘慈欣")

        XCTAssertTrue(name.hasSuffix(".epub"))
        XCTAssertFalse(name.contains("/"))
        XCTAssertFalse(name.contains(" "))
    }

    func testReaderFontScaleIsClampedBySettings() {
        let settings = ReaderSettings()
        let size = settings.fontSize(for: 390)

        XCTAssertGreaterThan(size, 0)
        XCTAssertLessThan(size, 40)
    }

    func testZIPArchiveReadsStoredEntries() throws {
        let payload = Data("hello epub".utf8)
        let archive = Data(makeStoredZIP(name: "mimetype", payload: payload))
        let zip = try ZIPArchive(data: archive)

        XCTAssertTrue(zip.contains("mimetype"))
        XCTAssertEqual(try zip.data(for: "mimetype"), payload)
    }

    private func makeStoredZIP(name: String, payload: Data) -> [UInt8] {
        let nameBytes = Array(name.utf8)
        let crc = crc32(payload)

        var bytes: [UInt8] = []

        func appendUInt16(_ value: UInt16) {
            bytes.append(UInt8(value & 0xFF))
            bytes.append(UInt8((value >> 8) & 0xFF))
        }

        func appendUInt32(_ value: UInt32) {
            bytes.append(UInt8(value & 0xFF))
            bytes.append(UInt8((value >> 8) & 0xFF))
            bytes.append(UInt8((value >> 16) & 0xFF))
            bytes.append(UInt8((value >> 24) & 0xFF))
        }

        // Local file header
        appendUInt32(0x0403_4B50)
        appendUInt16(20)
        appendUInt16(0)
        appendUInt16(0)
        appendUInt16(0)
        appendUInt16(0)
        appendUInt32(crc)
        appendUInt32(UInt32(payload.count))
        appendUInt32(UInt32(payload.count))
        appendUInt16(UInt16(nameBytes.count))
        appendUInt16(0)
        bytes.append(contentsOf: nameBytes)
        bytes.append(contentsOf: payload)

        let centralDirectoryOffset = UInt32(bytes.count)

        // Central directory
        appendUInt32(0x0201_4B50)
        appendUInt16(20)
        appendUInt16(0)
        appendUInt16(0)
        appendUInt16(0)
        appendUInt16(0)
        appendUInt32(crc)
        appendUInt32(UInt32(payload.count))
        appendUInt32(UInt32(payload.count))
        appendUInt16(UInt16(nameBytes.count))
        appendUInt16(0)
        appendUInt16(0)
        appendUInt16(0)
        appendUInt16(0)
        appendUInt32(0)
        appendUInt32(0)
        bytes.append(contentsOf: nameBytes)

        let centralDirectorySize = UInt32(bytes.count) - centralDirectoryOffset

        // End of central directory
        appendUInt32(0x0605_4B50)
        appendUInt16(0)
        appendUInt16(0)
        appendUInt16(1)
        appendUInt16(1)
        appendUInt32(centralDirectorySize)
        appendUInt32(centralDirectoryOffset)
        appendUInt16(0)

        return bytes
    }

    private func crc32(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFF_FFFF
        for byte in data {
            crc ^= UInt32(byte)
            for _ in 0..<8 {
                let mask = UInt32(bitPattern: -Int32(crc & 1))
                crc = (crc >> 1) ^ (0xEDB8_8320 & mask)
            }
        }
        return crc ^ 0xFFFF_FFFF
    }
}
