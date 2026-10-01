import SwiftUI
import DesignSystem
import TrackingFeature

// MARK: - MoreRootView

/// The More tab's menu. Hosts the tracking home (`TrackingHubView`,
/// moved here from the Strategy tab in issue #14) and Settings.
/// AppShell wraps this in the tab's `NavigationStack`.
public struct MoreRootView: View {
    let services: AppServices

    public init(services: AppServices) {
        self.services = services
    }

    public var body: some View {
        List {
            Section {
                NavigationLink {
                    TrackingHubView()
                } label: {
                    Label("Tracking", systemImage: "chart.line.uptrend.xyaxis")
                }
                .accessibilityLabel("Tracking")
            }
            Section {
                NavigationLink {
                    SettingsView(services: services)
                } label: {
                    Label("Settings", systemImage: "gear")
                }
                .accessibilityLabel("Settings")
            }
        }
        .navigationTitle("More")
    }
}
