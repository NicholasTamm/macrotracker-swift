//  MFWatchSync.swift
//  EngagementFeature — two-way iPhone ↔ Apple Watch sync (issue #10).
//
//  Architecture:
//  - Reads (watch → phone data): the watch renders `MFSharedSnapshot` from
//    the App Group container, kept fresh by `updateApplicationContext`
//    pushes from the iPhone after every publish.
//  - Writes (watch → phone): the watch sends `MFWatchMessage` values via
//    WatchConnectivity; the iPhone applies them to the repositories through
//    the normal DataLayer protocols, then republishes the snapshot.
//
//  The iOS side (`MFWatchBridge`) compiles under `#if os(iOS)`; the watch
//  side (`MFWatchClient`) under `#if os(watchOS)`. Both live in this one
//  module so the message contract can't drift between targets.

import Foundation
import WatchConnectivity
import DataLayer

// MARK: - MFWatchMessage

/// Typed messages exchanged between the iPhone app and the watch app.
///
/// Manual `Codable` conformance (Swift doesn't synthesize it for enums
/// with associated values): a `kind` discriminator plus per-case payload
/// keys. The schema is versioned implicitly — both sides ship in this
/// module, so they can't drift.
public enum MFWatchMessage: Sendable {
    /// Watch → phone: "send me the latest snapshot".
    case requestSnapshot
    /// Phone → watch: the latest snapshot payload.
    case snapshot(MFSharedSnapshot)
    /// Watch → phone: log a quick-add entry (macros in grams).
    case quickAdd(calories: Double, proteinGrams: Double, fatGrams: Double, carbsGrams: Double)
    /// Watch → phone: log a weigh-in (kilograms, always).
    case weighIn(weightKg: Double, date: Date)

    // MARK: Transport

    func encoded() throws -> Data {
        try JSONEncoder().encode(self)
    }

    static func decoded(from data: Data) throws -> MFWatchMessage {
        try JSONDecoder().decode(MFWatchMessage.self, from: data)
    }
}

// MARK: - MFWatchMessage Codable

extension MFWatchMessage: Codable {
    private enum Kind: String, Codable {
        case requestSnapshot
        case snapshot
        case quickAdd
        case weighIn
    }

    private enum CodingKeys: String, CodingKey {
        case kind
        case snapshot
        case calories
        case proteinGrams
        case fatGrams
        case carbsGrams
        case weightKg
        case date
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Kind.self, forKey: .kind) {
        case .requestSnapshot:
            self = .requestSnapshot
        case .snapshot:
            self = .snapshot(try container.decode(MFSharedSnapshot.self, forKey: .snapshot))
        case .quickAdd:
            self = .quickAdd(
                calories: try container.decode(Double.self, forKey: .calories),
                proteinGrams: try container.decode(Double.self, forKey: .proteinGrams),
                fatGrams: try container.decode(Double.self, forKey: .fatGrams),
                carbsGrams: try container.decode(Double.self, forKey: .carbsGrams)
            )
        case .weighIn:
            self = .weighIn(
                weightKg: try container.decode(Double.self, forKey: .weightKg),
                date: try container.decode(Date.self, forKey: .date)
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .requestSnapshot:
            try container.encode(Kind.requestSnapshot, forKey: .kind)
        case .snapshot(let snapshot):
            try container.encode(Kind.snapshot, forKey: .kind)
            try container.encode(snapshot, forKey: .snapshot)
        case .quickAdd(let calories, let proteinGrams, let fatGrams, let carbsGrams):
            try container.encode(Kind.quickAdd, forKey: .kind)
            try container.encode(calories, forKey: .calories)
            try container.encode(proteinGrams, forKey: .proteinGrams)
            try container.encode(fatGrams, forKey: .fatGrams)
            try container.encode(carbsGrams, forKey: .carbsGrams)
        case .weighIn(let weightKg, let date):
            try container.encode(Kind.weighIn, forKey: .kind)
            try container.encode(weightKg, forKey: .weightKg)
            try container.encode(date, forKey: .date)
        }
    }
}

// MARK: - Transport keys

enum MFWatchTransport {
    /// userInfo / applicationContext dictionary key for an encoded message.
    static let messageKey = "com.macrofactor.clone.watchMessage"
    /// applicationContext key for the latest encoded snapshot.
    static let snapshotKey = "com.macrofactor.clone.snapshot"
}

// MARK: - iOS side

#if os(iOS)

/// iPhone-side WatchConnectivity endpoint.
///
/// AppShell wiring: create ONE bridge alongside the DataStore/publishers at
/// launch, call `activate()`, and set the publisher's `onPublish` to
/// `bridge.pushSnapshot(_:)` so the watch stays fresh after every change.
@MainActor
public final class MFWatchBridge: NSObject {
    private let logs: any LogRepository
    private let weights: any WeightRepository
    private let publisher: MFSnapshotPublisher

    private var session: WCSession? { WCSession.isSupported() ? WCSession.default : nil }

    public init(
        logs: any LogRepository,
        weights: any WeightRepository,
        publisher: MFSnapshotPublisher
    ) {
        self.logs = logs
        self.weights = weights
        self.publisher = publisher
    }

    /// Starts the WatchConnectivity session. Safe to call when no watch is
    /// paired (the session simply stays inactive).
    public func activate() {
        guard let session, session.delegate == nil else { return }
        session.delegate = self
        session.activate()
    }

    /// Pushes the latest snapshot to the watch via the application context
    /// (last-write-wins; delivered even when the watch app isn't running).
    public func pushSnapshot(_ snapshot: MFSharedSnapshot) {
        guard let session, session.isPaired, session.isWatchAppInstalled else { return }
        do {
            try session.updateApplicationContext(
                [MFWatchTransport.snapshotKey: MFWatchMessage.snapshot(snapshot).encoded()]
            )
        } catch {
            // Application-context updates are best-effort; the watch also
            // reads the shared container directly as a fallback.
        }
    }

    // MARK: Message handling

    /// Applies one decoded message; returns the reply payload for
    /// `sendMessage`-style requests (nil when there is no reply).
    private func handle(_ message: MFWatchMessage) -> MFWatchMessage? {
        switch message {
        case .requestSnapshot:
            guard let snapshot = try? publisher.buildSnapshot() else { return nil }
            return .snapshot(snapshot)

        case .quickAdd(let calories, let protein, let fat, let carbs):
            do {
                try logs.quickAdd(
                    calories: calories,
                    proteinGrams: protein,
                    fatGrams: fat,
                    carbsGrams: carbs,
                    mealSlot: .snack,
                    timestamp: Date(),
                    note: nil
                )
                _ = publisher.publishToday()
            } catch {
                return nil
            }
            return nil

        case .weighIn(let weightKg, let date):
            do {
                try weights.logWeight(weightKg, timestamp: date, note: nil, source: .manual)
                _ = publisher.publishToday()
            } catch {
                return nil
            }
            return nil

        case .snapshot:
            // The phone never expects snapshots from the watch.
            return nil
        }
    }
}

// MARK: WCSessionDelegate (iOS)

extension MFWatchBridge: WCSessionDelegate {
    // Delegate callbacks may arrive off the main actor; hop back before
    // touching repositories.
    nonisolated public func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {}

    nonisolated public func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated public func sessionDidDeactivate(_ session: WCSession) {}

    /// Queued writes from the watch (quick-add / weigh-in), delivered even
    /// when the phone app is in the background.
    nonisolated public func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        guard let data = userInfo[MFWatchTransport.messageKey] as? Data,
              let message = try? MFWatchMessage.decoded(from: data)
        else { return }
        Task { @MainActor [weak self] in _ = self?.handle(message) }
    }

    /// Interactive requests from the watch (snapshot refresh while open).
    nonisolated public func session(
        _ session: WCSession,
        didReceiveMessageData messageData: Data,
        replyHandler: @escaping (Data) -> Void
    ) {
        Task { @MainActor [weak self] in
            guard
                let message = try? MFWatchMessage.decoded(from: messageData),
                let reply = self?.handle(message),
                let replyData = try? reply.encoded()
            else { return } // no reply → the watch falls back to the container
            replyHandler(replyData)
        }
    }
}

#endif

// MARK: - watchOS side

#if os(watchOS)

/// Watch-side WatchConnectivity endpoint, owned by the watch app.
///
/// The client keeps `snapshot` fresh from three sources (in priority
/// order): live application-context pushes, `sendMessage` replies while the
/// phone is reachable, and the App Group container as a fallback.
@MainActor
@Observable
public final class MFWatchClient: NSObject {
    /// Latest snapshot; nil until the first successful read.
    public var snapshot: MFSharedSnapshot?
    /// Human-readable description of the last sync failure, if any.
    public var lastError: String?

    private var session: WCSession? { WCSession.isSupported() ? WCSession.default : nil }

    public override init() {
        super.init()
    }

    /// Starts the session and performs an initial snapshot read.
    public func activate() {
        guard let session else { return }
        if session.delegate == nil {
            session.delegate = self
            session.activate()
        }
        // Fastest path: whatever the phone last published.
        if let stored = MFSharedSnapshotStore.read() {
            snapshot = stored
        }
        let context = session.applicationContext
        if let data = context[MFWatchTransport.snapshotKey] as? Data,
           let message = try? MFWatchMessage.decoded(from: data),
           case .snapshot(let pushed) = message
        {
            snapshot = pushed
        }
    }

    /// Asks the phone for a fresh snapshot. Falls back to the shared
    /// container when the phone isn't reachable.
    public func requestSnapshot() {
        guard let session, session.isReachable else {
            snapshot = MFSharedSnapshotStore.read() ?? snapshot
            return
        }
        do {
            let payload = try MFWatchMessage.requestSnapshot.encoded()
            session.sendMessageData(payload) { [weak self] replyData in
                Task { @MainActor [weak self] in
                    guard
                        let reply = try? MFWatchMessage.decoded(from: replyData),
                        case .snapshot(let fresh) = reply
                    else { return }
                    self?.snapshot = fresh
                    self?.lastError = nil
                }
            } errorHandler: { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.snapshot = MFSharedSnapshotStore.read() ?? self?.snapshot
                }
            }
        } catch {
            snapshot = MFSharedSnapshotStore.read() ?? snapshot
        }
    }

    /// Queues a quick-add on the phone (delivered in the background even
    /// when the phone app isn't running).
    public func sendQuickAdd(
        calories: Double,
        proteinGrams: Double,
        fatGrams: Double,
        carbsGrams: Double
    ) {
        send(.quickAdd(
            calories: calories,
            proteinGrams: proteinGrams,
            fatGrams: fatGrams,
            carbsGrams: carbsGrams
        ))
    }

    /// Queues a weigh-in on the phone. `weightKg` is always kilograms.
    public func sendWeighIn(weightKg: Double, date: Date = Date()) {
        send(.weighIn(weightKg: weightKg, date: date))
    }

    // MARK: Private

    private func send(_ message: MFWatchMessage) {
        guard let session else {
            lastError = "Watch session unavailable."
            return
        }
        do {
            let data = try message.encoded()
            // transferUserInfo queues reliably; the phone applies it on
            // delivery and republishes the snapshot.
            session.transferUserInfo([MFWatchTransport.messageKey: data])
            lastError = nil
        } catch {
            lastError = "Couldn't queue that entry. Try again."
        }
    }
}

// MARK: WCSessionDelegate (watchOS)

extension MFWatchClient: WCSessionDelegate {
    nonisolated public func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        Task { @MainActor [weak self] in
            if activationState == .activated {
                self?.requestSnapshot()
            } else if let error {
                self?.lastError = error.localizedDescription
            }
        }
    }

    /// Live snapshot pushes from the phone.
    nonisolated public func session(
        _ session: WCSession,
        didReceiveApplicationContext applicationContext: [String: Any]
    ) {
        guard
            let data = applicationContext[MFWatchTransport.snapshotKey] as? Data,
            let message = try? MFWatchMessage.decoded(from: data),
            case .snapshot(let pushed) = message
        else { return }
        Task { @MainActor [weak self] in
            self?.snapshot = pushed
            self?.lastError = nil
        }
    }
}

#endif
