import SwiftUI
import UIKit

struct BookCoverView: View {
    let coverURL: URL?
    let title: String

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(coverGradient)

            if let coverURL, coverURL.isFileURL {
                if let localImage {
                    Image(uiImage: localImage)
                        .resizable()
                        .scaledToFill()
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                } else {
                    placeholder
                }
            } else if let coverURL {
                AsyncImage(url: coverURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        placeholder
                    case .empty:
                        ProgressView()
                            .tint(.white)
                    @unknown default:
                        placeholder
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            } else {
                placeholder
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.black.opacity(0.08), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.14), radius: 10, y: 5)
    }

    private var localImage: UIImage? {
        guard let coverURL, coverURL.isFileURL else { return nil }
        return UIImage(contentsOfFile: coverURL.path)
    }

    private var placeholder: some View {
        VStack(spacing: 12) {
            Image(systemName: "book.closed.fill")
                .font(.system(size: 28))
                .foregroundStyle(.white.opacity(0.9))

            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(.white)
                .lineLimit(4)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 14)
        }
    }

    private var coverGradient: LinearGradient {
        let palettes: [[Color]] = [
            [Color(red: 0.20, green: 0.35, blue: 0.55), Color(red: 0.10, green: 0.20, blue: 0.36)],
            [Color(red: 0.52, green: 0.24, blue: 0.22), Color(red: 0.28, green: 0.11, blue: 0.12)],
            [Color(red: 0.18, green: 0.42, blue: 0.36), Color(red: 0.08, green: 0.22, blue: 0.20)],
            [Color(red: 0.42, green: 0.32, blue: 0.18), Color(red: 0.22, green: 0.15, blue: 0.08)],
            [Color(red: 0.35, green: 0.28, blue: 0.48), Color(red: 0.17, green: 0.13, blue: 0.26)]
        ]

        let index = abs(title.hashValue) % palettes.count
        return LinearGradient(
            colors: palettes[index],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
