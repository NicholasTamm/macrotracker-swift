import SwiftUI
import UserNotifications
import DataLayer
import TrackingFeature
import EngagementFeature
import HealthKitSync

// MARK: - AppServices

/// AppShell's composition root (issue #12 integration).
///
/// Owns the single `DataStore`, the `TrackingEnvironment`, and every
/// launch-wired engagement service, and performs the cross-module wiring
/// that feature modules cannot do themselves (MODULE_MAP rule 1: features
/// never depend on each other):
///
/// - `MFSnapshotPublisher` + `MFWatchBridge`: created here, activated at
///   launch; `publisher.onPublish` forwards to `bridge.pushSnapshot(_:)`.
/// - `TrackingEnvironment.onManualWeighIn`: set to the HealthKit write-back
///   (`MFHealthKitStore.shared.writeWeighIn`), fire-and-forget so a Health
///   failure can never break the local save.
/// - `UNUserNotificationCenter` delegate: `MFNotificationDelegate` routes
///   notification taps through the shared `MFRouter` via the
///   `mfDeepLink` user-info value.
///
/// Publish points: `launch()` publishes on launch; views call
/// `publishSnapshot()` after food logs (via the food-log tab's
/// `onFoodLogged` wiring), weigh-ins (`WeighInSheet.onSaved`), and capture
/// flows (on quick-log sheet dismiss). Target changes surface through the
/// foreground refresh in `didBecomeActive()`.
@MainActor
public final class AppServices {
    public let store: DataStore
    public let router = MFRouter()
    public let tracking: TrackingEnvironment
    public let snapshotPublisher: MFSnapshotPublisher
    public let watchBridge: MFWatchBridge
    public let notificationDelegate: MFNotificationDelegate
    public let crashReporter = MFCrashReporter()

    public init(store: DataStore) {
        self.store = store
        self.tracking = TrackingEnvironment(store: store)
        self.snapshotPublisher = MFSnapshotPublisher(
            logs: store.logs,
            program: store.program,
            weights: store.weights
        )
        self.watchBridge = MFWatchBridge(
            logs: store.logs,
            weights: store.weights,
            publisher: snapshotPublisher
        )
        self.notificationDelegate = MFNotificationDelegate(router: router)

        // Engagement: every published snapshot also goes to the watch.
        snapshotPublisher.onPublish = { [weak watchBridge] snapshot in
            watchBridge?.pushSnapshot(snapshot)
        }
        // HealthKit write-back without a feature→feature dependency.
        tracking.onManualWeighIn = { weightKg, date in
            Task {
                try? await MFHealthKitStore.shared.writeWeighIn(
                    weightKg: weightKg,
                    date: date
                )
            }
        }
        _ = tracking.ensureSystemHabits()
    }

    /// Builds the full service graph. Returns nil when the persistent
    /// SwiftData store can't be created (AppRootView shows a retry screen).
    public static func build() -> AppServices? {
        guard let store = try? DataStore() else { return nil }
        let services = AppServices(store: store)
        services.launch()
        return services
    }

    /// One-time launch wiring. Idempotent.
    public func launch() {
        MFNotificationScheduler.shared.registerCategories()
        UNUserNotificationCenter.current().delegate = notificationDelegate
        watchBridge.activate()
        crashReporter.start()

        let health = MFHealthKitStore.shared
        health.configure(weights: store.weights, steps: store.steps)
        health.startObserving()

        snapshotPublisher.publishToday()
    }

    /// Call when the app returns to the foreground.
    public func didBecomeActive() {
        MFHealthKitStore.shared.refreshAuthorizationStatus()
        snapshotPublisher.publishToday()
    }

    /// Publish a fresh widget/watch snapshot after a data mutation.
    public func publishSnapshot() {
        snapshotPublisher.publishToday()
    }

    /// Feeds the "Log food" habit streak and refreshes engagement surfaces.
    /// Wired as the food-log tab's `onFoodLogged` hook.
    public func noteFoodLogged() {
        tracking.logTodayCompletion(kind: .foodLogging)
        publishSnapshot()
    }
}
