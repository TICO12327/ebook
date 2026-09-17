import Foundation

enum HTMLTextExtractor {
    static func plainText(from html: String) -> String {
        var text = html

        text = text.replacingOccurrences(
            of: #"<(script|style|head)\b[^>]*>[\s\S]*?</\1>"#,
            with: " ",
            options: [.regularExpression, .caseInsensitive]
        )

        text = text.replacingOccurrences(
            of: #"<br\s*/?>"#,
            with: "\n",
            options: [.regularExpression, .caseInsensitive]
        )

        text = text.replacingOccurrences(
            of: #"</(p|div|section|article|h[1-6]|li|blockquote)>"#,
            with: "\n\n",
            options: [.regularExpression, .caseInsensitive]
        )

        text = text.replacingOccurrences(
            of: #"<[^>]+>"#,
            with: "",
            options: .regularExpression
        )

        text = decodeEntities(in: text)

        text = text.replacingOccurrences(
            of: #"[ \t\u{00A0}]+"#,
            with: " ",
            options: .regularExpression
        )

        text = text.replacingOccurrences(
            of: #"\n{3,}"#,
            with: "\n\n",
            options: .regularExpression
        )

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func decodeEntities(in text: String) -> String {
        var result = text
        let entities: [String: String] = [
            "&nbsp;": " ",
            "&amp;": "&",
            "&lt;": "<",
            "&gt;": ">",
            "&quot;": "\"",
            "&#39;": "'",
            "&apos;": "'",
            "&mdash;": "—",
            "&ndash;": "–",
            "&hellip;": "…",
            "&ldquo;": "“",
            "&rdquo;": "”",
            "&lsquo;": "‘",
            "&rsquo;": "’"
        ]

        for (entity, replacement) in entities {
            result = result.replacingOccurrences(of: entity, with: replacement)
        }

        result = decodeNumericEntities(in: result)
        return result
    }

    private static func decodeNumericEntities(in text: String) -> String {
        let pattern = #"&#(x?[0-9A-Fa-f]+);"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }

        let nsText = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))

        var result = text
        for match in matches.reversed() {
            guard let range = Range(match.range(at: 1), in: text),
                  let fullRange = Range(match.range, in: result) else { continue }

            let raw = String(text[range])
            let value: UInt32?

            if raw.lowercased().hasPrefix("x") {
                value = UInt32(raw.dropFirst(), radix: 16)
            } else {
                value = UInt32(raw)
            }

            if let value, let scalar = UnicodeScalar(value) {
                result.replaceSubrange(fullRange, with: String(Character(scalar)))
            }
        }

        return result
    }
}

enum XMLText {
    static func firstTagValue(in xml: String, tag: String) -> String? {
        let escapedTag = NSRegularExpression.escapedPattern(for: tag)
        let pattern = #"<\#(escapedTag)\b[^>]*>([\s\S]*?)</\#(escapedTag)>"#
        guard let raw = firstMatch(in: xml, pattern: pattern, group: 1) else { return nil }
        return decodeEntities(in: raw).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func firstHeading(in html: String) -> String? {
        for level in 1...6 {
            if let value = firstTagValue(in: html, tag: "h\(level)"), !value.isEmpty {
                return HTMLTextExtractor.plainText(from: value)
            }
        }
        return nil
    }

    static func firstMatch(in text: String, pattern: String, group: Int = 1) -> String? {
        guard let regex = try? NSRegularExpression(
            pattern: pattern,
            options: [.caseInsensitive, .dotMatchesLineSeparators]
        ) else { return nil }

        let nsText = text as NSString
        guard let match = regex.firstMatch(
            in: text,
            range: NSRange(location: 0, length: nsText.length)
        ), match.numberOfRanges > group else {
            return nil
        }

        let range = match.range(at: group)
        guard range.location != NSNotFound else { return nil }
        return nsText.substring(with: range)
    }

    static func allMatches(in text: String, pattern: String) -> [String] {
        guard let regex = try? NSRegularExpression(
            pattern: pattern,
            options: [.caseInsensitive, .dotMatchesLineSeparators]
        ) else { return [] }

        let nsText = text as NSString
        return regex.matches(
            in: text,
            range: NSRange(location: 0, length: nsText.length)
        ).map {
            nsText.substring(with: $0.range)
        }
    }

    static func attributes(in tag: String) -> [String: String] {
        let pattern = #"([A-Za-z_:][-A-Za-z0-9_:.]*)\s*=\s*["']([^"']*)["']"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [:] }

        let nsTag = tag as NSString
        var result: [String: String] = [:]

        for match in regex.matches(in: tag, range: NSRange(location: 0, length: nsTag.length)) {
            guard match.numberOfRanges >= 3 else { continue }
            let key = nsTag.substring(with: match.range(at: 1)).lowercased()
            let value = nsTag.substring(with: match.range(at: 2))
            result[key] = value
        }

        return result
    }

    static func decodeEntities(in text: String) -> String {
        HTMLTextExtractor.decodeEntities(in: text)
    }
}
