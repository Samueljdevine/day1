#if canImport(SwiftUI)
import SwiftUI

public extension Color {
    /// "#RRGGBB"
    init(hex: String) {
        var value: UInt64 = 0
        let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        Scanner(string: cleaned).scanHexInt64(&value)
        let r = Double((value >> 16) & 0xFF) / 255
        let g = Double((value >> 8) & 0xFF) / 255
        let b = Double(value & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }
}

public extension Category {
    func fill(for scheme: ColorScheme) -> Color {
        Color(hex: scheme == .dark ? style.darkFill : style.lightFill)
    }

    func text(for scheme: ColorScheme) -> Color {
        Color(hex: scheme == .dark ? style.darkText : style.lightText)
    }
}

public extension Block {
    /// Card fill. The Sleep block is always near-black regardless of theme.
    func fill(for scheme: ColorScheme) -> Color {
        isSleep ? Color(hex: "#0A0A0A") : category.fill(for: scheme)
    }

    /// Card text. The Sleep block is always low-contrast grey.
    func text(for scheme: ColorScheme) -> Color {
        isSleep ? Color(hex: "#6A6A6A") : category.text(for: scheme)
    }
}
#endif
