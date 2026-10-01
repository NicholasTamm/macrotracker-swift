import SwiftUI

/// Spacing scale on a 4pt base unit.
public enum MFSpacing {
    public static let xs: CGFloat = 4
    public static let sm: CGFloat = 8
    public static let md: CGFloat = 12
    public static let lg: CGFloat = 16
    public static let xl: CGFloat = 20
    public static let xxl: CGFloat = 24
    public static let xxxl: CGFloat = 32
}

/// Corner radii.
public enum MFRadii {
    public static let sm: CGFloat = 8
    public static let md: CGFloat = 12
    public static let lg: CGFloat = 16
    public static let xl: CGFloat = 24
}

/// Compact number formatting shared by stat displays.
public enum MFFormat {
    /// "150" for whole numbers, "1.5" otherwise.
    public static func grams(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(value))"
            : String(format: "%.1f", value)
    }

    /// Rounded whole kilocalories: "1,842".
    public static func kcal(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value.rounded())) ?? "\(Int(value.rounded()))"
    }
}

public extension View {
    /// Subtle resting shadow for cards.
    func mfCardShadow() -> some View {
        shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
    }

    /// Stronger shadow for raised surfaces (sheets, toasts, FABs).
    func mfRaisedShadow() -> some View {
        shadow(color: Color.black.opacity(0.16), radius: 16, x: 0, y: 6)
    }

    /// Standard card container: padded surface with rounded corners and shadow.
    func mfCard(padding: CGFloat = MFSpacing.lg) -> some View {
        self
            .padding(padding)
            .background(MFColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: MFRadii.lg))
            .mfCardShadow()
    }
}
