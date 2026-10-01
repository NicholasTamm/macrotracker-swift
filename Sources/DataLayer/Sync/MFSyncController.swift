//  MFSyncController.swift
//  DataLayer — CloudKit sync toggle. The app ships LOCAL-FIRST; this type
//  designs the sync path so it can be enabled without a data migration.
//
//  Design notes:
//  - All user models use CloudKit-compatible attribute types (no
//    transformable properties — nutrients are flattened Doubles, enums are
//    raw strings, the OFF cache lives in a separate non-synced store).
//  - Enabling sync requires REBUILDING the ModelContainer with a
//    cloudKitDatabase (ModelContainer can't toggle CloudKit at runtime).
//    `setEnabled(_:)` persists the preference; AppShell recreates the
//    DataStore on next launch (or immediately, tearing down the scene's
//    container — see DataStore).
//  - Xcode target requirements (SETUP.md): enable the CloudKit capability,
//    add a container identifier, and pass it to
//    `MFModelContainerFactory.makeContainer(cloudKitIdentifier:)`.
//  - Progress-photo FILES are not synced (only their metadata rows are).
//    A future iteration can upload them as CKAssets via a background
//    URLSession or move them to iCloud Drive.

import Foundation

/// CloudKit sync preference + state. Local-first: disabled by default.
@MainActor
public final class MFSyncController {
    /// iCloud container identifier, e.g. "iCloud.com.example.macroclone".
    /// Set by AppShell from the app's entitlements at launch.
    public var cloudKitContainerIdentifier: String?

    private let defaults: UserDefaults
    private static let enabledKey = "MFCloudSyncEnabled"
    private static let lastSyncKey = "MFCloudSyncLastSyncDate"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Whether the user enabled iCloud sync.
    public var isEnabled: Bool {
        get { defaults.bool(forKey: Self.enabledKey) }
        set { defaults.set(newValue, forKey: Self.enabledKey) }
    }

    /// Whether sync can actually run (enabled + container configured +
    /// CloudKit capability present in the target).
    public var canSync: Bool {
        isEnabled && cloudKitContainerIdentifier != nil
    }

    public var lastSyncDate: Date? {
        defaults.object(forKey: Self.lastSyncKey) as? Date
    }

    /// Persists the preference. Returns true when the caller must rebuild
    /// the DataStore's ModelContainer for the change to take effect.
    @discardableResult
    public func setEnabled(_ enabled: Bool) -> Bool {
        let changed = (isEnabled != enabled)
        isEnabled = enabled
        return changed
    }

    public func recordSyncCompleted() {
        defaults.set(Date(), forKey: Self.lastSyncKey)
    }
}
