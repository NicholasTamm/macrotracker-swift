//  MFHealthSyncStatusView.swift
//  HealthKitSync — sync-status UI (issue #9).
//
//  Embeddable "Apple Health" section for AppShell's Settings. Consumes the
//  DesignSystem only (MFBanner, MFButton, MFColor, MFFont, MFSpacing) —
//  nothing is duplicated here. AppShell places it; see
//  MFHealthKitStore.swift's header for the integration contract.

import SwiftUI
import DesignSystem

/// Settings section showing Apple Health connection state, last sync,
/// conflict notices, and denied-permission guidance with re-prompt help.
public struct MFHealthSyncSection: View {
    @ObservedObject private var store: MFHealthKitStore

    public init(store: MFHealthKitStore) {
        self.store = store
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: MFSpacing.md) {
            headerRow

            switch store.connectionState {
            case .unsupported:
                MFBanner(
                    kind: .info,
                    title: "Apple Health isn't available",
                    message: "This device doesn't support Apple Health, so syncing is turned off. You can still log weight and steps by hand."
                )
            case .notConnected:
                notConnectedBody
            case .denied:
                MFBanner(
                    kind: .warning,
                    title: "Apple Health access is off",
                    message: "Turn access back on in Settings to sync weight and steps. Anything you log by hand always takes priority over synced data.",
                    actionTitle: "Open Settings",
                    onAction: { store.openSystemSettings() }
                )
            case .connected:
                connectedBody
            }

            Text("We never import calorie estimates from watches or other apps — only weight and steps.")
                .font(MFFont.caption2)
                .foregroundColor(MFColor.textTertiary)
        }
        .task {
            await store.refreshAuthorizationStatus()
        }
    }

    // MARK: - Header

    private var headerRow: some View {
        HStack(spacing: MFSpacing.sm) {
            Image(systemName: "heart.fill")
                .foregroundColor(MFColor.danger)
                .font(.title3)
                .accessibilityHidden(true)
            Text("Apple Health")
                .font(MFFont.headline)
                .foregroundColor(MFColor.textPrimary)
            Spacer()
            statusPill
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Apple Health, \(statusText)")
    }

    private var statusText: String {
        switch store.connectionState {
        case .connected: return "connected"
        case .denied: return "access off"
        case .notConnected: return "not connected"
        case .unsupported: return "unavailable"
        }
    }

    private var statusPill: some View {
        let color: Color = switch store.connectionState {
        case .connected: MFColor.success
        case .denied: MFColor.danger
        default: MFColor.textSecondary
        }
        return Text(statusText.capitalized)
            .font(MFFont.footnote.weight(.semibold))
            .foregroundColor(color)
            .padding(.horizontal, MFSpacing.sm)
            .padding(.vertical, MFSpacing.xs)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }

    // MARK: - Not connected

    private var notConnectedBody: some View {
        VStack(alignment: .leading, spacing: MFSpacing.sm) {
            Text("Sync your weight and step history so your trends and coaching stay current — even on days you don't open the app.")
                .font(MFFont.footnote)
                .foregroundColor(MFColor.textSecondary)
            MFButton(
                "Connect Apple Health",
                style: .primary,
                size: .medium,
                icon: "heart.fill",
                isLoading: store.isSyncing
            ) {
                Task {
                    do { _ = try await store.connect() } catch { /* surfaced via lastErrorMessage */ }
                }
            }
            if let message = store.lastErrorMessage {
                Text(message)
                    .font(MFFont.footnote)
                    .foregroundColor(MFColor.danger)
            }
        }
    }

    // MARK: - Connected

    private var connectedBody: some View {
        VStack(alignment: .leading, spacing: MFSpacing.sm) {
            if let lastSync = store.lastSyncDate {
                Text("Last synced \(lastSync, style: .relative)")
                    .font(MFFont.footnote)
                    .foregroundColor(MFColor.textSecondary)
            }
            if let kept = store.lastSummary?.manualConflictsKept, kept > 0 {
                MFBanner(
                    kind: .info,
                    title: "Kept your manual entries",
                    message: "\(kept) synced \(kept == 1 ? "value" : "values") matched something you logged by hand, so we kept yours."
                )
            }
            MFButton(
                "Sync now",
                style: .secondary,
                size: .medium,
                isLoading: store.isSyncing
            ) {
                Task {
                    do { _ = try await store.syncNow() } catch { /* surfaced via lastErrorMessage */ }
                }
            }
            if let message = store.lastErrorMessage {
                Text(message)
                    .font(MFFont.footnote)
                    .foregroundColor(MFColor.danger)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    MFHealthSyncSection(store: MFHealthKitStore())
        .padding()
}
