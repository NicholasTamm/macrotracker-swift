import SwiftUI
import DesignSystem

// MARK: - MFTheme

/// Global theme wiring: applies the design-system tokens to the whole app.
///
/// Usage: attach `.mfThemed()` once at the app root
/// (see ``MacroFactorCloneApp``). Everything below it inherits:
/// - background / foreground colors from ``MFColor``
/// - accent tint from ``MFColor/accent``
/// - Dynamic Type via the semantic ``MFFont`` roles (automatic — every
///   component uses `MFFont` roles, never hardcoded sizes)
///
/// Color-scheme (light/dark) is driven by the system setting; the user can
/// override it in Settings → Appearance (issue #12 ships the picker; the
/// environment value is defined here so it exists from day one).
public struct MFTheme {

    /// User's appearance preference: system, light, or dark.
    public enum Appearance: String, CaseIterable, Sendable {
        case system, light, dark

        public var colorScheme: ColorScheme? {
            switch self {
            case .system: return nil
            case .light: return .light
            case .dark: return .dark
            }
        }
    }

    /// AppStorage key backing the appearance preference.
    public static let appearanceKey = "mf.appearance"
}

// MARK: - View modifier

private struct MFThemedModifier: ViewModifier {
    @AppStorage(MFTheme.appearanceKey)
    private var appearanceRaw = MFTheme.Appearance.system.rawValue

    func body(content: Content) -> some View {
        content
            .tint(MFColor.accent)
            .background(MFColor.background)
            .foregroundColor(MFColor.textPrimary)
            .preferredColorScheme(
                MFTheme.Appearance(rawValue: appearanceRaw)?.colorScheme
            )
    }
}

public extension View {
    /// Applies the global MacroFactor-clone theme. Attach once at the root.
    func mfThemed() -> some View {
        modifier(MFThemedModifier())
    }
}

#Preview("Themed root") {
    Text("Themed")
        .font(MFFont.headline)
        .mfThemed()
}
