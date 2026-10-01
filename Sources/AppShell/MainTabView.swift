import SwiftUI
import DesignSystem
import FoodLogFeature
import TrackingFeature
import AnalyticsFeature
import StrategyFeature

// MARK: - MFTab

/// The five top-level tabs, matching the real app's tab bar:
/// Dashboard / Food Log / (+) / Strategy / More.
///
/// Icons come from the approved ``MFIconCatalog``: Dashboard is the SF Symbol
/// `square.grid.2x2`, Food Log is the custom ``MFAppleGlyph``, the center
/// action is the SF Symbol `plus`, Strategy is the custom
/// ``MFStrategyGlyph``, and More is the SF Symbol `ellipsis.circle`.
/// No emoji is used as an icon anywhere.
public enum MFTab: String, CaseIterable, Identifiable, Hashable {
    case dashboard
    case foodLog
    case quickLog
    case strategy
    case more

    public var id: String { rawValue }

    /// Tab-bar label. The center action shows no label.
    public var title: String {
        switch self {
        case .dashboard: return "Dashboard"
        case .foodLog: return "Food Log"
        case .quickLog: return ""
        case .strategy: return "Strategy"
        case .more: return "More"
        }
    }

    public var isCenterAction: Bool { self == .quickLog }

    /// VoiceOver label. The center action shows no visible title.
    public var accessibilityLabel: String {
        isCenterAction ? "Log food" : title
    }
}

// MARK: - Tab icon

/// Renders a tab's icon with the right selected/unselected tint.
///
/// SF Symbols tint automatically via `foregroundStyle`; the custom vector
/// glyphs (apple, strategy) take an explicit color so they match the tab
/// bar's selected state exactly.
struct MFTabIcon: View {
    let tab: MFTab
    let isSelected: Bool

    private var tint: Color {
        isSelected ? MFColor.accent : MFColor.textSecondary
    }

    var body: some View {
        Group {
            switch tab {
            case .dashboard:
                Image(systemName: "square.grid.2x2")
                    .font(.system(size: 24))
            case .foodLog:
                MFAppleGlyph(size: 26, color: tint)
            case .quickLog:
                // Prominent center action: SF Symbol `plus` on a filled
                // disc, per MFIconCatalog ("Quick Log" tab-bar entry).
                ZStack {
                    Circle()
                        .fill(tint)
                        .frame(width: 52, height: 52)
                    Image(systemName: "plus")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(MFColor.background)
                }
                .padding(.bottom, 6)
            case .strategy:
                MFStrategyGlyph(size: 26, color: tint)
            case .more:
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 24))
            }
        }
        .foregroundStyle(tint)
        .accessibilityHidden(true)
    }
}

// MARK: - MainTabView

/// Root tab bar. Each tab hosts a `NavigationStack` owned by its feature
/// module; the center (+) action presents the quick-log sheet instead of
/// switching tabs.
///
/// Issue #12 integration: every placeholder is replaced with the real
/// feature view —
/// - Dashboard → `AnalyticsFeature.DashboardRootView`
/// - Food Log → `FoodLogFeature.FoodLogRootView` (with the `onFoodLogged`
///   hook feeding the "Log food" habit streak + widget/watch snapshots)
/// - Strategy → `StrategyFeature.StrategyRootView` (issue #14)
/// - More → `MoreRootView` (Tracking → `TrackingFeature.TrackingHubView`,
///   plus Settings)
/// - weigh-in sheet → `TrackingFeature.WeighInSheet`
public struct MainTabView: View {
    @Bindable var router: MFRouter
    let services: AppServices

    public init(router: MFRouter, services: AppServices) {
        self.router = router
        self.services = services
    }

    public var body: some View {
        TabView(selection: tabSelection) {
            ForEach(MFTab.allCases) { tab in
                tabContent(for: tab)
                    .tabItem {
                        MFTabIcon(tab: tab, isSelected: router.selectedTab == tab)
                        if !tab.isCenterAction { Text(tab.title) }
                    }
                    .tag(tab)
                    .accessibilityLabel(tab.accessibilityLabel)
            }
        }
        // TrackingEnvironment for TrackingHubView / WeighInSheet.
        .environment(services.tracking)
        .sheet(item: $router.presentedSheet) { sheet in
            switch sheet {
            case .quickLog: QuickLogSheet(services: services)
            case .weighIn: WeighInSheet(onSaved: { _ in services.publishSnapshot() })
            case .settings: SettingsView(services: services)
            }
        }
    }

    /// Intercepts the center action: tapping (+) opens the quick-log sheet
    /// and leaves the tab selection unchanged.
    private var tabSelection: Binding<MFTab> {
        Binding(
            get: { router.selectedTab },
            set: { newTab in
                if newTab.isCenterAction {
                    router.presentedSheet = .quickLog
                } else {
                    router.selectedTab = newTab
                }
            }
        )
    }

    @ViewBuilder
    private func tabContent(for tab: MFTab) -> some View {
        switch tab {
        case .dashboard:
            NavigationStack {
                DashboardRootView(dependencies: analyticsDependencies)
                    .navigationTitle("Dashboard")
            }
        case .foodLog:
            NavigationStack {
                FoodLogRootView(
                    logs: services.store.logs,
                    foods: services.store.foods,
                    foodSearch: services.store.foodSearch,
                    program: services.store.program,
                    onFoodLogged: { services.noteFoodLogged() }
                )
            }
        case .quickLog:
            // Never visible: the selection binding intercepts this tab and
            // presents the sheet instead.
            Color.clear
        case .strategy:
            // Issue #14: dedicated strategy surface (program, targets,
            // expenditure, weekly check-in). TrackingHubView moved to
            // More → Tracking.
            NavigationStack {
                StrategyRootView(dependencies: strategyDependencies)
            }
        case .more:
            NavigationStack { MoreRootView(services: services) }
        }
    }

    private var strategyDependencies: StrategyDependencies {
        StrategyDependencies(
            logs: services.store.logs,
            weights: services.store.weights,
            steps: services.store.steps,
            program: services.store.program
        )
    }

    private var analyticsDependencies: AnalyticsDependencies {
        AnalyticsDependencies(
            logs: services.store.logs,
            weights: services.store.weights,
            program: services.store.program,
            foods: services.store.foods,
            habits: services.store.habits,
            steps: services.store.steps
        )
    }
}

#Preview("Main tabs") {
    @MainActor
    struct Demo: View {
        var body: some View {
            if let services = try? AppServices(store: DataStore(inMemory: true, seed: false)) {
                MainTabView(router: services.router, services: services)
                    .mfThemed()
            } else {
                Text("Preview unavailable")
            }
        }
    }
    return Demo()
}
