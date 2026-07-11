import SwiftUI

enum PopioFont {
    static func custom(size: CGFloat, weight: Font.Weight = .regular, relativeTo textStyle: Font.TextStyle = .body) -> Font {
        .system(size: size, weight: normalizedWeight(for: weight), design: .default)
    }

    static func textStyle(_ textStyle: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
        .system(textStyle, design: .default, weight: normalizedWeight(for: weight))
    }

    static func caption2(_ weight: Font.Weight = .regular) -> Font {
        textStyle(.caption2, weight: weight)
    }

    static func caption(_ weight: Font.Weight = .regular) -> Font {
        textStyle(.caption, weight: weight)
    }

    static func footnote(_ weight: Font.Weight = .regular) -> Font {
        textStyle(.footnote, weight: weight)
    }

    static func subheadline(_ weight: Font.Weight = .regular) -> Font {
        textStyle(.subheadline, weight: weight)
    }

    static func body(_ weight: Font.Weight = .regular) -> Font {
        textStyle(.body, weight: weight)
    }

    static func headline(_ weight: Font.Weight = .regular) -> Font {
        textStyle(.headline, weight: weight)
    }

    static func title3(_ weight: Font.Weight = .regular) -> Font {
        textStyle(.title3, weight: weight)
    }

    static func largeTitle(_ weight: Font.Weight = .regular) -> Font {
        textStyle(.largeTitle, weight: weight)
    }

    private static func normalizedWeight(for weight: Font.Weight) -> Font.Weight {
        if weight == .black || weight == .heavy {
            return .semibold
        }

        if weight == .bold {
            return .semibold
        }

        if weight == .semibold {
            return .medium
        }

        if weight == .medium {
            return .regular
        }

        return weight
    }
}

enum PopioFontRegistrar {
    static func registerFonts() {
        // SF Pro is the iOS system font, so no bundled font registration is needed.
    }
}
