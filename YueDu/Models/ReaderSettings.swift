import Foundation
import SwiftUI

enum ReaderTheme: String, CaseIterable, Identifiable, Codable {
    case light
    case sepia
    case dark
    case black

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .light: "白纸"
        case .sepia: "羊皮纸"
        case .dark: "夜间"
        case .black: "纯黑"
        }
    }

    var backgroundColor: Color {
        switch self {
        case .light: Color(red: 0.98, green: 0.97, blue: 0.95)
        case .sepia: Color(red: 0.94, green: 0.89, blue: 0.79)
        case .dark: Color(red: 0.12, green: 0.13, blue: 0.15)
        case .black: .black
        }
    }

    var textColor: Color {
        switch self {
        case .light, .sepia: Color(red: 0.16, green: 0.15, blue: 0.14)
        case .dark, .black: Color(red: 0.88, green: 0.88, blue: 0.86)
        }
    }

    var secondaryTextColor: Color {
        textColor.opacity(0.55)
    }
}

struct ReaderSettings: Codable, Equatable {
    var theme: ReaderTheme = .light
    var fontScale: Double = 1.0
    var lineSpacing: Double = 8
    var paragraphSpacing: Double = 14
    var horizontalPadding: Double = 22
    var fontFamily: ReaderFontFamily = .serif

    static let minimumFontScale = 0.7
    static let maximumFontScale = 2.2

    func fontSize(for width: CGFloat) -> CGFloat {
        let base = min(max(width * 0.052, 16), 22)
        return base * fontScale
    }
}

enum ReaderFontFamily: String, CaseIterable, Identifiable, Codable {
    case serif
    case sans
    case monospaced

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .serif: "宋体"
        case .sans: "黑体"
        case .monospaced: "等宽"
        }
    }

    func font(size: CGFloat) -> Font {
        switch self {
        case .serif: .system(size: size, design: .serif)
        case .sans: .system(size: size, design: .default)
        case .monospaced: .system(size: size, design: .monospaced)
        }
    }
}
