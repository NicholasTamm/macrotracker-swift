//  MFAppGroup.swift
//  EngagementFeature — App Group shared container (issue #10).
//
//  The iOS app, the WidgetKit extension, and the watchOS app all read and
//  write through this container. The snapshot file is the single source of
//  truth for widgets and the watch; SwiftData stays in the app's own
//  container and is never touched directly from an extension.

import Foundation

// MARK: - MFAppGroup

/// Shared container identifiers and accessors.
///
/// Xcode wiring (SETUP.md): enable the App Group capability with
/// `group.com.macrofactor.clone` on the iOS app target, the WidgetKit
/// extension target, and the watchOS app target.
public enum MFAppGroup {
    /// Must match the App Group in the entitlements of every target.
    public static let identifier = "group.com.macrofactor.clone"

    /// Shared user defaults (notification settings, lightweight flags).
    /// Nil in previews / when the group isn't provisioned.
    public static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: identifier)
    }

    /// Root of the shared container. Nil when the group isn't provisioned.
    public static var containerURL: URL? {
        FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: identifier
        )
    }
}

// MARK: - MFSharedSnapshotStore

/// File-backed read/write for ``MFSharedSnapshot``.
///
/// Widgets and the watch app only ever call `read()`; the iOS app calls
/// `write(_:)` via ``MFSnapshotPublisher`` after log/weigh-in changes.
public enum MFSharedSnapshotStore {
    private static let fileName = "mf-shared-snapshot.json"

    static var fileURL: URL? {
        MFAppGroup.containerURL?
            .appendingPathComponent("Library/Caches/\(fileName)", isDirectory: false)
    }

    /// Atomically writes the snapshot to the shared container.
    public static func write(_ snapshot: MFSharedSnapshot) throws {
        guard let url = fileURL else { throw MFEngagementError.appGroupUnavailable }
        let data = try JSONEncoder().encode(snapshot)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: url, options: .atomic)
    }

    /// Reads the latest snapshot, or nil when none has been published yet
    /// (e.g. first launch) or the group isn't provisioned.
    public static func read() -> MFSharedSnapshot? {
        guard
            let url = fileURL,
            let data = try? Data(contentsOf: url)
        else { return nil }
        return try? JSONDecoder().decode(MFSharedSnapshot.self, from: data)
    }
}

// MARK: - MFEngagementError

public enum MFEngagementError: Error, LocalizedError {
    case appGroupUnavailable

    public var errorDescription: String? {
        switch self {
        case .appGroupUnavailable:
            return "The shared app group (group.com.macrofactor.clone) isn't available. "
                + "Enable the App Group capability on this target (see SETUP.md)."
        }
    }
}
