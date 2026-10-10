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
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-issue4FoodTileFixture") {
            do {
                try seedFoodTileFixture(in: store)
            } catch {
                assertionFailure("Could not seed food tile UI test: \(error)")
            }
        }
        if ProcessInfo.processInfo.arguments.contains("-issue2FoodPasteFixture") {
            do {
                try seedFoodPasteFixture(in: store)
            } catch {
                assertionFailure("Could not seed food paste UI test: \(error)")
            }
        }
        if ProcessInfo.processInfo.arguments.contains("-issue3ServingFixture") {
            do {
                try seedServingFixture(in: store)
            } catch {
                assertionFailure("Could not seed serving UI test: \(error)")
            }
        }
        #endif
        let services = AppServices(store: store)
        services.launch()
        return services
    }

    #if DEBUG
    /// Disposable UI-test entries in the app's real store. Both names map to
    /// the same fallback thumbnail, with their distinguishing words last.
    private static func seedFoodTileFixture(in store: DataStore) throws {
        let now = Date()
        let existing = try store.logs.entries(forDay: MFDates.startOfDay(now))
        for (name, calories) in [
            ("QA4 Yogurt plain nonfat", 100.0),
            ("QA4 Yogurt plain whole", 180.0),
        ] where !existing.contains(where: { $0.foodName == name }) {
            let food = try store.foods.saveFood(
                name: name,
                brand: "",
                barcode: nil,
                servingDescription: "100 g",
                servingSizeGrams: 100,
                nutrientsPer100g: [.calories: calories],
                source: .custom
            )
            try store.logs.logFood(
                food,
                grams: 100,
                mealSlot: .snack,
                timestamp: now,
                note: nil,
                source: .manualSearch
            )
        }
    }

    /// Disposable source-day entries for exercising the production copy,
    /// date navigation, and paste controls in XCUITest. Idempotent on relaunch.
    private static func seedFoodPasteFixture(in store: DataStore) throws {
        let day = MFDates.startOfDay(Date())
        let existing = try store.logs.entries(forDay: day)
        let calendar = Calendar.current
        for (name, calories, minute, slot) in [
            ("QA2 Egg", 120.0, 5, MealSlot.breakfast),
            ("QA2 Oats", 120.0, 42, MealSlot.snack),
        ] where !existing.contains(where: { $0.foodName == name }) {
            let food = try store.foods.saveFood(
                name: name,
                brand: "",
                barcode: nil,
                servingDescription: "100 g",
                servingSizeGrams: 100,
                nutrientsPer100g: [.calories: calories, .protein: 10],
                source: .seedDatabase
            )
            let timestamp = calendar.date(bySettingHour: 11, minute: minute, second: 0, of: day) ?? day
            try store.logs.logFood(
                food,
                grams: 100,
                mealSlot: slot,
                timestamp: timestamp,
                note: nil,
                source: .manualSearch
            )
        }
    }

    private static func seedServingFixture(in store: DataStore) throws {
        if ProcessInfo.processInfo.arguments.contains("-issue3ResetLog") {
            for entry in try store.logs.entries(forDay: MFDates.startOfDay(Date()))
                where entry.foodName.hasPrefix("QA3") {
                try store.logs.deleteEntry(entry)
            }
        }
        if ProcessInfo.processInfo.arguments.contains("-issue3LegacyFixture") {
            let legacy: FoodItem
            if let existing = try store.foods.customFoods().first(where: { $0.name == "QA3 Legacy" }) {
                legacy = existing
            } else {
                legacy = try store.foods.saveFood(
                    name: "QA3 Legacy", brand: "", barcode: nil,
                    servingDescription: "bowl", servingSizeGrams: 100,
                    nutrientsPer100g: [.calories: 120, .protein: 10, .fat: 4, .carbs: 18], source: .custom
                )
            }
            if !(try store.logs.entries(forDay: MFDates.startOfDay(Date())))
                .contains(where: { $0.foodName == "QA3 Legacy" }) {
                try store.logs.logFood(legacy, grams: 37.555, mealSlot: .breakfast,
                                       timestamp: Date(), note: "Legacy precision fixture", source: .manualSearch)
            }
        }
        let food: FoodItem
        if let existing = try store.foods.customFoods().first(where: { $0.name == "QA3 Oats" }) {
            food = existing
        } else {
            food = try store.foods.saveFood(
                name: "QA3 Oats", brand: "", barcode: nil,
                servingDescription: "bowl", servingSizeGrams: 100,
                nutrientsPer100g: [.calories: 120, .protein: 10, .fat: 4, .carbs: 18],
                source: .custom
            )
            food.servingSizes = [
                ServingSize(name: "bowl", grams: 100),
                ServingSize(name: "scoop", grams: 25),
            ]
            try store.foods.updateFood(food)
        }
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        if !(try store.logs.entries(forDay: MFDates.startOfDay(yesterday))).contains(where: { $0.foodName == "QA3 Oats" }) {
            try store.logs.logFood(food, grams: 100, mealSlot: .breakfast,
                                   timestamp: yesterday, note: "Recents fixture", source: .manualSearch)
        }
        if let egg = try store.foods.searchFoods(query: "Egg", limit: 20)
            .first(where: { $0.source == .seedDatabase }),
           !(try store.logs.entries(forDay: MFDates.startOfDay(yesterday))).contains(where: { $0.food?.id == egg.id }) {
            try store.logs.logFood(egg, grams: egg.servingSizeGrams, mealSlot: .breakfast,
                                   timestamp: yesterday, note: "Recents fixture", source: .manualSearch)
        }
    }
    #endif

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
