import SwiftUI
import DesignSystem
import DataLayer
import FoodLogFeature
import HealthKitSync
import EngagementFeature

// MARK: - SettingsView (More tab)

/// The More tab: app settings, data management, and About.
///
/// Issue #12 integration: real rows replace the stubs —
/// - Notifications → `MFNotificationSettingsView` (#10)
/// - Health → `MFHealthSyncSection` (#9)
/// - Calendar Week Banner → `FoodLogPreferences` binding (#4)
/// - Export data → real CSV export of log + weight history (#12)
/// - Delete all data → real destructive reset via `DataStore` (#12)
///
/// The About section carries the OpenMoji attribution required by the
/// CC BY-SA 4.0 license.
public struct SettingsView: View {
    let services: AppServices

    @AppStorage(MFTheme.appearanceKey)
    private var appearanceRaw = MFTheme.Appearance.system.rawValue

    @State private var weekBannerMode = FoodLogPreferences.weekBannerMode
    @State private var shareURLs: [URL] = []
    @State private var showingShare = false
    @State private var confirmingDelete = false
    @State private var actionError: String?

    public init(services: AppServices) {
        self.services = services
    }

    public var body: some View {
        List {
            Section("Appearance") {
                Picker("Appearance", selection: $appearanceRaw) {
                    ForEach(MFTheme.Appearance.allCases, id: \.rawValue) { mode in
                        Text(mode.label).tag(mode.rawValue)
                    }
                }
            }

            Section("Food Log") {
                Picker("Calendar Week Banner", selection: $weekBannerMode) {
                    ForEach(MFWeekBannerMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .onChange(of: weekBannerMode) { _, new in
                    FoodLogPreferences.weekBannerMode = new
                }
                Text(weekBannerMode.description)
                    .font(MFFont.caption)
                    .foregroundColor(MFColor.textSecondary)
            }

            Section("Reminders") {
                NavigationLink {
                    MFNotificationSettingsView()
                } label: {
                    SettingsRowContent(
                        icon: "bell",
                        title: "Notifications",
                        detail: "Meal, weigh-in, and check-in reminders"
                    )
                }
            }

            Section("Health") {
                MFHealthSyncSection(store: MFHealthKitStore.shared)
            }

            Section("Data") {
                Button {
                    exportData()
                } label: {
                    SettingsRowContent(
                        icon: "square.and.arrow.up",
                        title: "Export data",
                        detail: "Food log and weight history as CSV"
                    )
                }
                Button(role: .destructive) {
                    confirmingDelete = true
                } label: {
                    SettingsRowContent(
                        icon: "trash",
                        title: "Delete all data",
                        detail: "Erases everything on this device",
                        destructive: true
                    )
                }
            }

            Section("About") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("1.0.0")
                        .foregroundColor(MFColor.textSecondary)
                }
                if let last = MFCrashReporter.lastDiagnosticDelivery {
                    HStack {
                        Text("Diagnostics")
                        Spacer()
                        Text("Last report \(last, style: .date)")
                            .foregroundColor(MFColor.textSecondary)
                    }
                }
                VStack(alignment: .leading, spacing: MFSpacing.xs) {
                    Text("Food icons")
                        .foregroundColor(MFColor.textPrimary)
                    Text("Food icons by OpenMoji (https://openmoji.org) — CC BY-SA 4.0")
                        .font(MFFont.caption)
                        .foregroundColor(MFColor.textSecondary)
                }
                .padding(.vertical, MFSpacing.xs)
            }
        }
        .navigationTitle("More")
        .confirmationDialog(
            "Delete all data?",
            isPresented: $confirmingDelete,
            titleVisibility: .visible
        ) {
            Button("Delete everything", role: .destructive) {
                deleteAllData()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently erases your food log, weigh-ins, measurements, photos, habits, and settings on this device. The built-in food database stays.")
        }
        .sheet(isPresented: $showingShare) {
            MFShareSheet(items: shareURLs) {
                showingShare = false
            }
        }
        .alert("Couldn't complete that", isPresented: Binding(
            get: { actionError != nil },
            set: { if !$0 { actionError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(actionError ?? "")
        }
    }

    // MARK: Actions

    private func exportData() {
        Task {
            do {
                let entries = try services.store.logs.entries(
                    from: .distantPast,
                    to: .distantFuture
                )
                let weights = try services.store.weights.weights(
                    from: .distantPast,
                    to: .distantFuture
                )
                shareURLs = try MFCSVExporter.writeFiles(
                    foodLogCSV: MFCSVExporter.foodLogCSV(entries),
                    weightsCSV: MFCSVExporter.weightsCSV(weights)
                )
                showingShare = true
            } catch {
                actionError = error.localizedDescription
            }
        }
    }

    private func deleteAllData() {
        do {
            try services.store.resetAllData()
            _ = services.tracking.ensureSystemHabits()
            services.publishSnapshot()
        } catch {
            actionError = error.localizedDescription
        }
    }
}

private struct SettingsRowContent: View {
    let icon: String
    let title: String
    let detail: String
    var destructive = false

    var body: some View {
        HStack(spacing: MFSpacing.md) {
            Image(systemName: icon)
                .foregroundColor(destructive ? MFColor.danger : MFColor.accent)
                .frame(width: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .foregroundColor(destructive ? MFColor.danger : MFColor.textPrimary)
                Text(detail)
                    .font(MFFont.caption)
                    .foregroundColor(MFColor.textSecondary)
            }
        }
    }
}

private extension MFTheme.Appearance {
    var label: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
}

#Preview("Settings") {
    @MainActor
    struct Demo: View {
        var body: some View {
            if let services = try? AppServices(store: DataStore(inMemory: true, seed: false)) {
                NavigationStack {
                    SettingsView(services: services)
                }
                .mfThemed()
            } else {
                Text("Preview unavailable")
            }
        }
    }
    return Demo()
}
