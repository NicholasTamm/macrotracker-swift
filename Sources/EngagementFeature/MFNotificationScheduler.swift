//  MFNotificationScheduler.swift
//  EngagementFeature — local reminder scheduling via UserNotifications
//  (issue #10).
//
//  Reminders are LOCAL only (no push server). Taps deep-link into the app
//  through `mfclone://` URLs; AppShell must (a) set itself as the
//  UNUserNotificationCenter delegate and (b) route `response.notification`
//  taps through MFRouter using the `mfDeepLink` user-info value.

import Foundation
import UserNotifications

// MARK: - MFNotificationScheduler

/// Schedules and cancels the app's local reminders.
///
/// All scheduling is idempotent: `apply(_:)` removes every request this
/// scheduler owns and re-creates them from the settings, so it is safe to
/// call after any settings change, on launch, and after a timezone change.
@MainActor
public final class MFNotificationScheduler {
    public static let shared = MFNotificationScheduler()

    /// userInfo key carrying the `mfclone://` deep link for a tap.
    public static let deepLinkUserInfoKey = "mfDeepLink"

    /// Category for meal reminders (offers a "Quick log" action).
    public static let logReminderCategory = "com.macrofactor.clone.category.logReminder"
    /// Action identifier for the "Quick log" notification action.
    public static let quickLogAction = "com.macrofactor.clone.action.quickLog"

    private let center: UNUserNotificationCenter

    public init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    // MARK: Authorization

    public func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    /// Requests alert+badge+sound authorization. Returns true when granted.
    @discardableResult
    public func requestAuthorization() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .badge, .sound])
        } catch {
            return false
        }
    }

    // MARK: Scheduling

    /// Registers the notification categories/actions. Call once at launch.
    public func registerCategories() {
        let quickLog = UNNotificationAction(
            identifier: Self.quickLogAction,
            title: "Quick Log",
            options: .foreground
        )
        let logCategory = UNNotificationCategory(
            identifier: Self.logReminderCategory,
            actions: [quickLog],
            intentIdentifiers: [],
            options: []
        )
        center.setNotificationCategories([logCategory])
    }

    /// Rebuilds all pending reminders owned by this scheduler from the
    /// given settings. No-ops (after cancelling) when not authorized, so
    /// callers don't need to check authorization first.
    public func apply(_ settings: MFNotificationSettings) async {
        await cancelAll()
        guard await authorizationStatus() == .authorized else { return }
        for kind in MFReminderKind.allCases {
            guard let config = settings.reminders[kind], config.isEnabled else { continue }
            schedule(kind: kind, config: config)
        }
    }

    /// Cancels every reminder this scheduler owns.
    public func cancelAll() async {
        center.removePendingNotificationRequests(
            withIdentifiers: MFReminderKind.allCases.map(\.notificationIdentifier)
        )
    }

    // MARK: Private

    private func schedule(kind: MFReminderKind, config: MFReminderConfig) {
        let content = UNMutableNotificationContent()
        content.title = notificationTitle(for: kind)
        content.body = notificationBody(for: kind)
        content.sound = .default
        content.userInfo = [Self.deepLinkUserInfoKey: kind.deepLink]
        if kind.isMealReminder {
            content.categoryIdentifier = Self.logReminderCategory
        }

        var components = DateComponents()
        components.hour = config.hour
        components.minute = config.minute
        components.weekday = config.weekday // nil = daily
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)

        let request = UNNotificationRequest(
            identifier: kind.notificationIdentifier,
            content: content,
            trigger: trigger
        )
        center.add(request)
    }

    // MARK: Copy (original to this project)

    private func notificationTitle(for kind: MFReminderKind) -> String {
        switch kind {
        case .breakfast: return "Breakfast check-in"
        case .lunch: return "Lunch check-in"
        case .dinner: return "Dinner check-in"
        case .snack: return "Snack check-in"
        case .weighIn: return "Time to weigh in"
        case .weeklyCheckIn: return "Weekly check-in"
        }
    }

    private func notificationBody(for kind: MFReminderKind) -> String {
        switch kind {
        case .breakfast:
            return "Log your breakfast to keep today's numbers on track."
        case .lunch:
            return "Take a minute to log lunch while it's fresh."
        case .dinner:
            return "Log dinner before the day wraps up."
        case .snack:
            return "Log any snacks so your totals stay accurate."
        case .weighIn:
            return "Step on the scale and log your weight to keep your trend honest."
        case .weeklyCheckIn:
            return "Review your week and see whether your targets need a tune-up."
        }
    }
}

// MARK: - Helpers

private extension MFReminderKind {
    var isMealReminder: Bool {
        switch self {
        case .breakfast, .lunch, .dinner, .snack: return true
        case .weighIn, .weeklyCheckIn: return false
        }
    }
}
