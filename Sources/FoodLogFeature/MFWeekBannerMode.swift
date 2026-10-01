import SwiftUI

// MARK: - MFWeekBannerMode

/// Calendar Week Banner display mode for the food-log timeline.
///
/// Semantics (from the official behavior + the palette showcase demo):
/// - `show` (default): the full banner (date nav, week strip, macro
///   summary) is shown and collapses into a compact summary strip as the
///   timeline scrolls; scrolling back to the top expands it again.
/// - `showAndPin`: the full banner stays visible while scrolling.
/// - `hide`: the banner is removed to maximize timeline space.
public enum MFWeekBannerMode: String, CaseIterable, Sendable {
    case show
    case showAndPin
    case hide

    public var displayName: String {
        switch self {
        case .show: return "Show"
        case .showAndPin: return "Show & Pin"
        case .hide: return "Hide"
        }
    }

    public var description: String {
        switch self {
        case .show:
            return "Displays the full banner and collapses it while the food timeline scrolls."
        case .showAndPin:
            return "Keeps the complete week and summary banner visible while scrolling."
        case .hide:
            return "Removes the week banner to maximize timeline space."
        }
    }
}

// MARK: - FoodLogPreferences

/// Food-log display preferences, persisted in UserDefaults via AppStorage.
///
/// Kept in FoodLogFeature (not DataLayer) because it is pure UI
/// presentation state. AppShell's Settings screen can bind to
/// `FoodLogPreferences.weekBannerModeBinding()` when it builds the
/// "Calendar Week Banner" row.
public enum FoodLogPreferences {
    @AppStorage("mf.foodLog.weekBannerMode")
    private static var weekBannerModeRaw: String = MFWeekBannerMode.show.rawValue

    public static var weekBannerMode: MFWeekBannerMode {
        get { MFWeekBannerMode(rawValue: weekBannerModeRaw) ?? .show }
        set { weekBannerModeRaw = newValue.rawValue }
    }

    public static func weekBannerModeBinding() -> Binding<MFWeekBannerMode> {
        Binding(
            get: { weekBannerMode },
            set: { weekBannerMode = $0 }
        )
    }
}
