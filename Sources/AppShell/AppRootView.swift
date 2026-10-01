import SwiftUI
import DesignSystem

// MARK: - AppRootView

/// Decides first-launch vs. returning-user flow.
///
/// First launch → ``OnboardingView`` (no account, no paywall — straight
/// into the app). Afterwards → ``MainTabView``. Deep links are handled on
/// the tab view via the shared ``MFRouter`` (owned by ``AppServices``).
///
/// Issue #12 integration: the service graph (`DataStore`, tracking
/// environment, watch/snapshot/notification wiring) is built once in a
/// launch `.task`; while it builds, the branded launch screen shows. If the
/// store can't be created, a retry screen appears instead of a crash.
public struct AppRootView: View {
    @AppStorage("mf.hasCompletedOnboarding")
    private var hasCompletedOnboarding = false

    @State private var services: AppServices?
    @State private var launchFailed = false
    @Environment(\.scenePhase) private var scenePhase

    public init() {}

    public var body: some View {
        Group {
            if let services {
                if hasCompletedOnboarding {
                    MainTabView(router: services.router, services: services)
                } else {
                    OnboardingView {
                        hasCompletedOnboarding = true
                    }
                }
            } else if launchFailed {
                launchErrorView
            } else {
                MFLaunchScreen()
            }
        }
        .mfThemed()
        .onOpenURL { url in
            // Deep links only make sense once inside the app.
            guard hasCompletedOnboarding, let services else { return }
            services.router.handle(url: url)
        }
        .task {
            if services == nil && !launchFailed {
                if let built = AppServices.build() {
                    services = built
                } else {
                    launchFailed = true
                }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { services?.didBecomeActive() }
        }
    }

    private var launchErrorView: some View {
        VStack(spacing: MFSpacing.lg) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 44))
                .foregroundColor(MFColor.warning)
                .accessibilityHidden(true)
            Text("Couldn't open your data")
                .font(MFFont.title2)
                .foregroundColor(MFColor.textPrimary)
            Text("The app couldn't access its local database. Your data is still on this device — try again.")
                .font(MFFont.body)
                .foregroundColor(MFColor.textSecondary)
                .multilineTextAlignment(.center)
            MFButton("Try again", style: .primary) {
                if let built = AppServices.build() {
                    services = built
                }
            }
        }
        .padding(MFSpacing.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(MFColor.background)
    }
}

#Preview("App root — tabs") {
    AppRootView()
}
