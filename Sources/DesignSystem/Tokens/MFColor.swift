import SwiftUI

/// Central color tokens for the MacroFactor clone design system.
///
/// Matched against real MacroFactor app screenshots (App Store listing,
/// official press kit, help articles): warm near-black dark mode, white
/// light mode, macro colors blue (calories) / coral (protein) /
/// yellow (fat) / green (carbs), black/white selection pills.
/// Every token resolves automatically per color scheme; components never
/// hardcode colors. All values are original interpretations.
public enum MFColor {

    // MARK: - App surfaces

    /// Main app background: white in light mode, warm near-black in dark.
    public static let background = Color.mfToken(light: 0xFFFFFF, dark: 0x1A1B1E)
    /// Card / grouped content surfaces.
    public static let surface = Color.mfToken(light: 0xFFFFFF, dark: 0x26272C)
    /// Raised surfaces (sheets, menus, popovers).
    public static let surfaceElevated = Color.mfToken(light: 0xFFFFFF, dark: 0x2F3036)
    /// Sunken wells (text fields, search bars, serving boxes).
    public static let surfaceSunken = Color.mfToken(light: 0xF0F0F2, dark: 0x2E2F35)

    // MARK: - Text

    public static let textPrimary = Color.mfToken(light: 0x111214, dark: 0xF5F5F6)
    public static let textSecondary = Color.mfToken(light: 0x6E6E73, dark: 0xA7A7AD)
    /// Tertiary text (hints, timestamps, placeholders). Darkened 2026-09-28
    /// (issue #12 accessibility audit): the previous values (0x9A9AA0 /
    /// 0x6E6E74) measured 2.80:1 / 3.40:1 against the backgrounds — below
    /// WCAG AA. These measure ≥4.5:1 on background/surface in both modes
    /// (≈4.1:1 on sunken wells, accepted for placeholder text).
    public static let textTertiary = Color.mfToken(light: 0x74747A, dark: 0x8E8E93)

    // MARK: - Selection & primary actions

    /// Pill behind a selected segmented item: black in light mode, white in dark.
    public static let selectionFill = Color.mfToken(light: 0x111214, dark: 0xFFFFFF)
    /// Text drawn on top of the selection pill.
    public static let textOnSelection = Color.mfToken(light: 0xFFFFFF, dark: 0x111214)
    /// Primary buttons ("Log Foods", "Done"): black in light mode, white in dark.
    public static let buttonPrimary = Color.mfToken(light: 0x111214, dark: 0xFFFFFF)
    /// Text drawn on the primary button.
    public static let textOnButtonPrimary = Color.mfToken(light: 0xFFFFFF, dark: 0x111214)

    // MARK: - Macros (verified against real screenshots)

    /// Calories: blue.
    public static let calories = Color.mfToken(light: 0x4A8DFF, dark: 0x5B8DEF)
    /// Protein: coral orange-red.
    public static let protein = Color.mfToken(light: 0xEE7A52, dark: 0xF07E5C)
    /// Fat: yellow.
    public static let fat = Color.mfToken(light: 0xF2BE3A, dark: 0xF5C344)
    /// Carbs: green.
    public static let carbs = Color.mfToken(light: 0x3FB97F, dark: 0x4ECB8D)

    // MARK: - Chart & nutrient accents

    /// Expenditure line + flux band: orange-red.
    public static let expenditure = Color.mfToken(light: 0xE8763B, dark: 0xEC7F45)
    /// Weight-trend line: purple.
    public static let weightTrend = Color.mfToken(light: 0x8F6FE0, dark: 0x9B7EDE)
    /// Micronutrients (sodium, magnesium, …): pink.
    public static let micro = Color.mfToken(light: 0xF06292, dark: 0xF2739C)
    /// Water: same blue as calories.
    public static let water = calories

    // MARK: - Brand / accent

    /// Rarely-used blue accent (links, focus states). Selection uses
    /// selectionFill instead; calories uses `calories`.
    public static let accent = Color.mfToken(light: 0x4A8DFF, dark: 0x5B8DEF)
    /// Tinted fill for icon wells and badges.
    public static let accentSoft = Color.mfToken(light: 0xDCE8FF, dark: 0x233048)
    /// Text drawn on top of the accent color.
    public static let textOnAccent = Color.mfToken(light: 0xFFFFFF, dark: 0xFFFFFF)

    // MARK: - Semantic

    public static let success = Color.mfToken(light: 0x0E9F6E, dark: 0x34D399)
    public static let warning = Color.mfToken(light: 0xD97706, dark: 0xFBBF24)
    public static let danger = Color.mfToken(light: 0xE5484D, dark: 0xFF6B6B)

    // MARK: - Chrome

    public static let separator = Color.mfToken(light: 0xE8E8EB, dark: 0x33343B)
    /// Unfilled portion of rings and progress bars.
    public static let ringTrack = Color.mfToken(light: 0xE6E6E9, dark: 0x33343B)
}

// MARK: - Private helpers

private extension Color {
    /// Builds a color that resolves differently in light vs. dark mode
    /// without requiring an asset catalog.
    static func mfToken(light: UInt32, dark: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            UIColor(mfHex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

private extension UIColor {
    convenience init(mfHex: UInt32, alpha: CGFloat = 1) {
        let red = CGFloat((mfHex >> 16) & 0xFF) / 255
        let green = CGFloat((mfHex >> 8) & 0xFF) / 255
        let blue = CGFloat(mfHex & 0xFF) / 255
        self.init(red: red, green: green, blue: blue, alpha: alpha)
    }
}
