//  MFNotificationSettings.swift
//  EngagementFeature — reminder configuration model (issue #10).
//
//  Persisted as JSON in the shared App Group defaults so the settings
//  survive reinstalls of any single target and stay visible to the watch.

import Foundation

// MARK: - MFReminderKind

/// The reminders this app can schedule. All copy is original to this project.
public enum MFReminderKind: String, Codable, CaseIterable, Sendable {
    case breakfast
    case lunch
    case dinner
    case snack
    case weighIn
    case weeklyCheckIn

    /// Stable identifier for the pending UNNotificationRequest.
    public var notificationIdentifier: String {
        "com.macrofactor.clone.reminder.\(rawValue)"
    }

    public var title: String {
        switch self {
        case .breakfast: return "Breakfast"
        case .lunch: return "Lunch"
        case .dinner: return "Dinner"
        case .snack: return "Snacks"
        case .weighIn: return "Weigh-in"
        case .weeklyCheckIn: return "Weekly check-in"
        }
    }

    public var subtitle: String {
        switch self {
        case .breakfast, .lunch, .dinner: return "Meal log reminder"
        case .snack: return "Snack log reminder"
        case .weighIn: return "Daily weigh-in reminder"
        case .weeklyCheckIn: return "Weekly review reminder"
        }
    }

    /// `mfclone://` deep link opened when the notification is tapped.
    /// (MFRouter in AppShell handles these; see MODULE_MAP.md.)
    public var deepLink: String {
        switch self {
        case .breakfast, .lunch, .dinner, .snack: return "mfclone://quicklog"
        case .weighIn: return "mfclone://weighin"
        case .weeklyCheckIn: return "mfclone://strategy"
        }
    }

    var defaultConfig: MFReminderConfig {
        switch self {
        case .breakfast: return MFReminderConfig(isEnabled: true, hour: 8, minute: 30)
        case .lunch: return MFReminderConfig(isEnabled: true, hour: 12, minute: 30)
        case .dinner: return MFReminderConfig(isEnabled: true, hour: 19, minute: 0)
        case .snack: return MFReminderConfig(isEnabled: false, hour: 21, minute: 0)
        case .weighIn: return MFReminderConfig(isEnabled: true, hour: 7, minute: 30)
        // Monday 9:00 (weekday 1 = Sunday per ProgramRepository convention).
        case .weeklyCheckIn:
            return MFReminderConfig(isEnabled: true, hour: 9, minute: 0, weekday: 2)
        }
    }
}

// MARK: - MFReminderConfig

/// Schedule for one reminder kind. `weekday` nil = every day.
public struct MFReminderConfig: Codable, Sendable, Equatable {
    public var isEnabled: Bool
    public var hour: Int
    public var minute: Int
    public var weekday: Int?

    public init(isEnabled: Bool, hour: Int, minute: Int, weekday: Int? = nil) {
        self.isEnabled = isEnabled
        self.hour = hour
        self.minute = minute
        self.weekday = weekday
    }

    /// 12-hour display, e.g. "7:30 AM".
    public var timeLabel: String {
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        let date = Calendar.current.date(from: components) ?? Date()
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - MFNotificationSettings

/// The user's full reminder configuration.
public struct MFNotificationSettings: Codable, Sendable, Equatable {
    public var reminders: [MFReminderKind: MFReminderConfig]

    public init(reminders: [MFReminderKind: MFReminderConfig]? = nil) {
        if let reminders {
            self.reminders = reminders
        } else {
            self.reminders = Dictionary(
                uniqueKeysWithValues: MFReminderKind.allCases.map { ($0, $0.defaultConfig) }
            )
        }
    }

    public static var `default`: MFNotificationSettings { MFNotificationSettings() }

    // MARK: Persistence (shared App Group defaults)

    private static let storageKey = "com.macrofactor.clone.notificationSettings.v1"

    /// Loads persisted settings, falling back to defaults.
    public static func load() -> MFNotificationSettings {
        guard
            let defaults = MFAppGroup.sharedDefaults,
            let data = defaults.data(forKey: storageKey),
            let decoded = try? JSONDecoder().decode(MFNotificationSettings.self, from: data)
        else { return .default }
        // Merge with defaults so new reminder kinds appear after updates.
        var merged = MFNotificationSettings.default.reminders
        for (kind, config) in decoded.reminders { merged[kind] = config }
        return MFNotificationSettings(reminders: merged)
    }

    /// Persists the settings to the shared container.
    public func save() {
        guard
            let defaults = MFAppGroup.sharedDefaults,
            let data = try? JSONEncoder().encode(self)
        else { return }
        defaults.set(data, forKey: Self.storageKey)
    }
}
