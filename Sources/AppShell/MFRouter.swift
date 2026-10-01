import SwiftUI
import Observation
import DesignSystem

// MARK: - MFDeepLink

/// Deep-link routes for the `mfclone://` URL scheme.
///
/// Central entry point for notification taps (issue #10), widgets
/// (issue #10), Siri/App Intents, and `onOpenURL`. The router translates a
/// URL into a ``MFTab`` selection plus an optional presented sheet, so every
/// entry point lands on the same navigation state.
public enum MFDeepLink: Equatable {
    case dashboard
    case foodLog
    case quickLog
    case strategy
    case more
    case settings
    case weighIn
    case addFood(query: String?)

    /// Parses `mfclone://<host>[?query=<q>]` URLs. Returns nil for anything
    /// else — unknown links are ignored, never crash.
    public init?(url: URL) {
        guard url.scheme == "mfclone", let host = url.host else { return nil }
        let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first(where: { $0.name == "query" })?.value
        switch host {
        case "dashboard": self = .dashboard
        case "foodlog": self = .foodLog
        case "quicklog": self = .quickLog
        case "strategy": self = .strategy
        case "more": self = .more
        case "settings": self = .settings
        case "weighin": self = .weighIn
        case "addfood": self = .addFood(query: query)
        default: return nil
        }
    }
}

// MARK: - MFRouter

/// Observable navigation state owned by the app root.
///
/// Feature screens push onto their tab's `NavigationStack` via the
/// `navigationPath` bindings exposed here, so deep links and notification
/// actions can drive navigation from anywhere. Tabs other than More keep
/// their own stacks inside the feature modules (issue #4/#6/#8); the router
/// only owns tab selection and app-level sheets.
@MainActor
@Observable
public final class MFRouter {
    /// Currently selected tab.
    public var selectedTab: MFTab = .dashboard
    /// App-level sheet presented over the tab bar (quick log, weigh-in).
    public var presentedSheet: MFSheet? = nil

    public init() {}

    /// Routes a deep link: selects the tab and presents any sheet.
    public func handle(_ link: MFDeepLink) {
        switch link {
        case .dashboard: selectedTab = .dashboard
        case .foodLog: selectedTab = .foodLog
        case .quickLog:
            selectedTab = .foodLog
            presentedSheet = .quickLog
        case .strategy: selectedTab = .strategy
        case .more: selectedTab = .more
        case .settings:
            selectedTab = .more
            presentedSheet = .settings
        case .weighIn:
            selectedTab = .dashboard
            presentedSheet = .weighIn
        case .addFood:
            selectedTab = .foodLog
            presentedSheet = .quickLog
        }
    }

    /// Routes a raw URL; no-ops when it isn't a valid `mfclone://` link.
    public func handle(url: URL) {
        if let link = MFDeepLink(url: url) { handle(link) }
    }
}

/// App-level sheets presented over the tab bar.
public enum MFSheet: Identifiable, Equatable {
    case quickLog
    case weighIn
    case settings

    public var id: String {
        switch self {
        case .quickLog: return "quickLog"
        case .weighIn: return "weighIn"
        case .settings: return "settings"
        }
    }
}
