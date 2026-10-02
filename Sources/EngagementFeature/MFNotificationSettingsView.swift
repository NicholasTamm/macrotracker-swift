//  MFNotificationSettingsView.swift
//  EngagementFeature — notification settings screen (issue #10).
//
//  AppShell wiring: add a "Notifications" row in SettingsView (More tab)
//  that navigates to this view. This module owns the screen; AppShell owns
//  the UNUserNotificationCenter delegate that routes taps via MFRouter.

import SwiftUI
import UserNotifications
import DesignSystem

// MARK: - MFNotificationSettingsModel

/// View model for the notification settings screen.
@MainActor
@Observable
public final class MFNotificationSettingsModel {
    public var settings: MFNotificationSettings
    public var authorizationStatus: UNAuthorizationStatus = .notDetermined
    public var isApplying = false

    private let scheduler: MFNotificationScheduler

    public init(
        settings: MFNotificationSettings = .load(),
        scheduler: MFNotificationScheduler = .shared
    ) {
        self.settings = settings
        self.scheduler = scheduler
    }

    public func refreshStatus() async {
        authorizationStatus = await scheduler.authorizationStatus()
    }

    public func requestAuthorization() async {
        _ = await scheduler.requestAuthorization()
        await refreshStatus()
        if authorizationStatus == .authorized {
            await apply()
        }
    }

    /// Persists the settings and rebuilds the scheduled reminders.
    public func apply() async {
        isApplying = true
        defer { isApplying = false }
        settings.save()
        await scheduler.apply(settings)
    }

    public var isAuthorized: Bool { authorizationStatus == .authorized }
    public var isDenied: Bool { authorizationStatus == .denied }
}

// MARK: - MFNotificationSettingsView

/// Lets the user toggle each reminder and pick its time. Shown from the
/// More tab's Settings (wired by AppShell).
@MainActor
public struct MFNotificationSettingsView: View {
    @State private var model: MFNotificationSettingsModel

    public init(model: MFNotificationSettingsModel? = nil) {
        _model = State(initialValue: model ?? MFNotificationSettingsModel())
    }

    public var body: some View {
        List {
            if !model.isAuthorized {
                authorizationSection
            }

            Section("Meal reminders") {
                ForEach(mealKinds, id: \.self) { kind in
                    reminderRow(kind)
                }
            }

            Section("Tracking reminders") {
                ForEach(trackingKinds, id: \.self) { kind in
                    reminderRow(kind)
                }
            }

            Section {
                Text("Reminders are delivered on this device only — nothing is sent to a server.")
                    .font(MFFont.footnote)
                    .foregroundColor(MFColor.textSecondary)
            }
        }
        .navigationTitle("Notifications")
        .task { await model.refreshStatus() }
        .disabled(model.isApplying)
    }

    // MARK: Sections

    private var authorizationSection: some View {
        Section {
            VStack(alignment: .leading, spacing: MFSpacing.sm) {
                Text("Notifications are \(model.isDenied ? "turned off" : "not enabled")")
                    .font(MFFont.headline)
                    .foregroundColor(MFColor.textPrimary)
                Text(model.isDenied
                     ? "Enable notifications in system Settings to receive reminders."
                     : "Allow notifications to get meal, weigh-in, and check-in reminders.")
                    .font(MFFont.subheadline)
                    .foregroundColor(MFColor.textSecondary)
                Button(model.isDenied ? "Open Settings" : "Enable Notifications") {
                    Task { await enableTapped() }
                }
                .buttonStyle(.borderedProminent)
                .tint(MFColor.buttonPrimary)
            }
            .padding(.vertical, MFSpacing.sm)
        }
    }

    private func reminderRow(_ kind: MFReminderKind) -> some View {
        let binding = Binding<MFReminderConfig>(
            get: { model.settings.reminders[kind] ?? kind.defaultConfig },
            set: { newValue in
                model.settings.reminders[kind] = newValue
                Task { await model.apply() }
            }
        )
        return VStack(alignment: .leading, spacing: MFSpacing.xs) {
            Toggle(isOn: Binding(
                get: { binding.wrappedValue.isEnabled },
                set: { newValue in
                    var config = binding.wrappedValue
                    config.isEnabled = newValue
                    binding.wrappedValue = config
                }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(kind.title).foregroundColor(MFColor.textPrimary)
                    Text(kind.subtitle)
                        .font(MFFont.caption)
                        .foregroundColor(MFColor.textSecondary)
                }
            }
            if binding.wrappedValue.isEnabled {
                HStack {
                    DatePicker(
                        "Time",
                        selection: timeBinding(for: binding),
                        displayedComponents: .hourAndMinute
                    )
                    .labelsHidden()
                    if kind == .weeklyCheckIn {
                        Picker("Day", selection: Binding(
                            get: { binding.wrappedValue.weekday ?? 2 },
                            set: { newValue in
                                var config = binding.wrappedValue
                                config.weekday = newValue
                                binding.wrappedValue = config
                            }
                        )) {
                            ForEach(1...7, id: \.self) { weekday in
                                Text(weekdayName(weekday)).tag(weekday)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    Spacer()
                    Text(binding.wrappedValue.timeLabel)
                        .font(MFFont.subheadline)
                        .foregroundColor(MFColor.textSecondary)
                }
                .padding(.leading, MFSpacing.xl)
            }
        }
        .padding(.vertical, MFSpacing.xs)
    }

    // MARK: Helpers

    private var mealKinds: [MFReminderKind] { [.breakfast, .lunch, .dinner, .snack] }
    private var trackingKinds: [MFReminderKind] { [.weighIn, .weeklyCheckIn] }

    private func timeBinding(for config: Binding<MFReminderConfig>) -> Binding<Date> {
        Binding(
            get: {
                var components = DateComponents()
                components.hour = config.wrappedValue.hour
                components.minute = config.wrappedValue.minute
                return Calendar.current.date(from: components) ?? Date()
            },
            set: { newDate in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                var updated = config.wrappedValue
                updated.hour = parts.hour ?? updated.hour
                updated.minute = parts.minute ?? updated.minute
                config.wrappedValue = updated
            }
        )
    }

    private func weekdayName(_ weekday: Int) -> String {
        // 1 = Sunday … 7 = Saturday.
        Calendar.current.weekdaySymbols[(weekday - 1 + 7) % 7].capitalized
    }

    private func enableTapped() async {
        if model.isDenied {
            openSystemSettings()
        } else {
            await model.requestAuthorization()
        }
    }

    private func openSystemSettings() {
        #if os(iOS)
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
        #endif
    }
}

// MARK: - Previews

#Preview("Notification Settings") {
    NavigationStack {
        MFNotificationSettingsView()
    }
}
