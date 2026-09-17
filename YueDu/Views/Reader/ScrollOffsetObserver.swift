import SwiftUI

/// Tracks normalized vertical scroll position using a preference key.
/// Works on iOS 17 without relying on iOS 18-only scroll geometry APIs.
struct ScrollPositionReporter: View {
    let coordinateSpaceName: String

    var body: some View {
        GeometryReader { proxy in
            Color.clear
                .preference(
                    key: ScrollOffsetPreferenceKey.self,
                    value: -proxy.frame(in: .named(coordinateSpaceName)).minY
                )
        }
        .frame(height: 0)
    }
}

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: Double = 0

    static func reduce(value: inout Double, nextValue: () -> Double) {
        value = nextValue()
    }
}
