//  MFHealthKitStore.swift
//  HealthKitSync — Apple Health authorization, 30-day historical import, and
//  background delivery (issue #9). All writes go through DataLayer's
//  WeightRepository / StepRepository — never around them.
//
//  AppShell integration (issue #2 owns AppShell; this is the contract):
//    1. On launch:  MFHealthKitStore.shared.configure(weights: store.weights,
//                     steps: store.steps)
//                     MFHealthKitStore.shared.startObserving()
//    2. Settings:   embed MFHealthSyncSection(store: .shared)
//    3. Weigh-in (#7), after a manual log:
//                     Task { try? await MFHealthKitStore.shared.writeWeighIn(kg, date:) }
//    4. On foreground: Task { await MFHealthKitStore.shared.refreshAuthorizationStatus() }
//
//  Xcode target requirements — DOCUMENTED ONLY, owned by AppShell:
//    - Info.plist: NSHealthShareUsageDescription, NSHealthUpdateUsageDescription
//      (exact keys + strings are listed in issues/09-healthkit-sync.md's
//      progress log).
//    - Entitlements: com.apple.developer.healthkit = YES
//    - Background modes: `healthkit` (required for silent background delivery)

import Combine
import Foundation
import HealthKit
import UIKit
import DataLayer

/// Central manager for the Apple Health integration.
///
/// Threading: HKHealthStore callbacks arrive on arbitrary queues; every
/// method that touches repositories or @Published state is @MainActor, and
/// callbacks hop there via `Task { @MainActor … }`.
public final class MFHealthKitStore: ObservableObject {
    public static let shared = MFHealthKitStore()

    // MARK: - Published state (mutated on the main actor only)

    @Published public private(set) var connectionState: MFHealthConnectionState = .notConnected
    @Published public private(set) var isSyncing = false
    @Published public private(set) var lastSyncDate: Date?
    @Published public private(set) var lastSummary: MFHealthSyncSummary?
    @Published public private(set) var lastErrorMessage: String?

    // MARK: - Private

    private let healthStore = HKHealthStore()
    private var weightsRepo: (any WeightRepository)?
    private var stepsRepo: (any StepRepository)?
    private var observerQueries: [HKObserverQuery] = []
    private let defaults: UserDefaults

    private enum Keys {
        static let connected = "MFHealthKit.connected"
        static let lastSync = "MFHealthKit.lastSyncDate"
        static let weightAnchor = "MFHealthKit.weightAnchor"
    }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.lastSyncDate = defaults.object(forKey: Keys.lastSync) as? Date
        // connectionState starts .notConnected; refreshAuthorizationStatus()
        // corrects it on launch / foreground.
    }

    public var isHealthDataAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    /// Inject the DataLayer repositories. Must be called before any sync work.
    public func configure(weights: any WeightRepository, steps: any StepRepository) {
        self.weightsRepo = weights
        self.stepsRepo = steps
    }

    /// Opens the system Settings app so the user can re-enable Health access.
    public func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString),
              UIApplication.shared.canOpenURL(url)
        else { return }
        UIApplication.shared.open(url)
    }

    // MARK: - Authorization

    /// Re-reads HealthKit's authorization state and updates `connectionState`.
    /// Call on launch and whenever the app foregrounds — this is how revoked
    /// permissions are detected so the UI can degrade gracefully.
    @MainActor
    public func refreshAuthorizationStatus() {
        guard isHealthDataAvailable else {
            connectionState = .unsupported
            return
        }
        let stepStatus = healthStore.authorizationStatus(for: MFHealthKitTypes.stepCount)
        let massStatus = healthStore.authorizationStatus(for: MFHealthKitTypes.bodyMass)
        if stepStatus == .sharingAuthorized || massStatus == .sharingAuthorized {
            connectionState = .connected
        } else if stepStatus == .sharingDenied || massStatus == .sharingDenied {
            connectionState = .denied
        } else {
            connectionState = .notConnected
        }
    }

    /// Presents the system HealthKit authorization sheet. Returns true when
    /// weight and/or steps are authorized for reading.
    @MainActor
    public func requestAuthorization() async throws -> Bool {
        guard isHealthDataAvailable else { throw MFHealthSyncError.healthKitUnavailable }
        do {
            try await healthStore.requestAuthorization(
                toShare: MFHealthKitTypes.writeTypes,
                read: MFHealthKitTypes.readTypes
            )
        } catch {
            lastErrorMessage = error.localizedDescription
            throw MFHealthSyncError.queryFailed(underlying: error)
        }
        refreshAuthorizationStatus()
        if connectionState == .connected {
            defaults.set(true, forKey: Keys.connected)
        }
        return connectionState == .connected
    }

    /// Full first-connect flow: authorize → import 30 days of history →
    /// register background delivery. Background registration is best-effort:
    /// a failure doesn't fail the connect (it's retried on next launch).
    @MainActor
    public func connect() async throws -> MFHealthSyncSummary {
        do {
            let authorized = try await requestAuthorization()
            guard authorized else { throw MFHealthSyncError.authorizationDenied }
            let summary = try await importHistory(days: 30)
            try? await enableBackgroundDelivery()
            return summary
        } catch {
            lastErrorMessage = (error as? LocalizedError)?.errorDescription
                ?? error.localizedDescription
            throw error
        }
    }

    // MARK: - Historical import

    /// Imports up to `days` of weight + step history. Applies the
    /// manual-wins conflict rule throughout.
    @MainActor
    public func importHistory(days: Int = 30) async throws -> MFHealthSyncSummary {
        guard isHealthDataAvailable else { throw MFHealthSyncError.healthKitUnavailable }
        guard let weightsRepo, let stepsRepo else { throw MFHealthSyncError.notConfigured }
        isSyncing = true
        defer { isSyncing = false }
        var summary = MFHealthSyncSummary()
        do {
            for sample in try await fetchWeightHistory(days: days) {
                switch try applyWeightSample(sample, weightsRepo: weightsRepo) {
                case .imported: summary.weightsImported += 1
                case .manualConflict: summary.manualConflictsKept += 1
                case .duplicate: break
                }
            }
            for stat in try await fetchDailyStepStatistics(days: days) {
                switch try applyStepStatistic(stat, stepsRepo: stepsRepo) {
                case .updated: summary.stepDaysUpdated += 1
                case .manualConflict: summary.manualConflictsKept += 1
                case .skipped: break
                }
            }
        } catch {
            lastErrorMessage = (error as? LocalizedError)?.errorDescription
                ?? error.localizedDescription
            throw error
        }
        recordSyncCompleted(summary: summary)
        return summary
    }

    /// Manual "Sync now": pulls recent weight changes (anchored) and the last
    /// few days of steps, applying the manual-wins rule.
    @MainActor
    public func syncNow() async throws -> MFHealthSyncSummary {
        guard isHealthDataAvailable else { throw MFHealthSyncError.healthKitUnavailable }
        guard connectionState == .connected else { throw MFHealthSyncError.authorizationDenied }
        guard let weightsRepo, let stepsRepo else { throw MFHealthSyncError.notConfigured }
        isSyncing = true
        defer { isSyncing = false }
        var summary = MFHealthSyncSummary()
        do {
            let (samples, anchor) = try await fetchWeightChanges()
            for sample in samples {
                switch try applyWeightSample(sample, weightsRepo: weightsRepo) {
                case .imported: summary.weightsImported += 1
                case .manualConflict: summary.manualConflictsKept += 1
                case .duplicate: break
                }
            }
            saveAnchor(anchor, forKey: Keys.weightAnchor)
            for stat in try await fetchDailyStepStatistics(days: 3) {
                switch try applyStepStatistic(stat, stepsRepo: stepsRepo) {
                case .updated: summary.stepDaysUpdated += 1
                case .manualConflict: summary.manualConflictsKept += 1
                case .skipped: break
                }
            }
        } catch {
            lastErrorMessage = (error as? LocalizedError)?.errorDescription
                ?? error.localizedDescription
            throw error
        }
        recordSyncCompleted(summary: summary)
        return summary
    }

    // MARK: - Conflict handling (manual entries win)

    private enum WeightSampleOutcome { case imported, duplicate, manualConflict }
    private enum StepDayOutcome { case updated, manualConflict, skipped }

    /// Applies one HealthKit weight sample. A manual weigh-in on the same log
    /// day always wins — the synced sample is discarded and counted.
    @MainActor
    private func applyWeightSample(
        _ sample: HKQuantitySample,
        weightsRepo: any WeightRepository
    ) throws -> WeightSampleOutcome {
        let dayStart = MFDates.startOfDay(sample.endDate)
        let dayEnd = Calendar.current.date(byAdding: .day, value: 1, to: dayStart)
            ?? Date.distantFuture
        let existing = try weightsRepo.weights(from: dayStart, to: dayEnd)
        if existing.contains(where: { $0.source == .manual }) {
            return .manualConflict
        }
        // De-duplicate re-deliveries of the same HealthKit sample.
        if existing.contains(where: {
            $0.source == .healthKit
                && abs($0.timestamp.timeIntervalSince(sample.endDate)) < 120
        }) {
            return .duplicate
        }
        let kg = sample.quantity.doubleValue(for: .gramUnit(with: .kilo))
        guard kg.isFinite, kg > 0 else { return .duplicate }
        try weightsRepo.logWeight(kg, timestamp: sample.endDate, source: .healthKit)
        return .imported
    }

    /// Applies one day of HealthKit step totals. A manual step entry for the
    /// day always wins — the synced total is discarded and counted (only when
    /// it actually differs, so identical re-deliveries stay quiet).
    @MainActor
    private func applyStepStatistic(
        _ stat: HKStatistics,
        stepsRepo: any StepRepository
    ) throws -> StepDayOutcome {
        let dayStart = stat.startDate
        guard let sum = stat.sumQuantity() else { return .skipped }
        let count = sum.doubleValue(for: .count())
        guard count.isFinite, count >= 0 else { return .skipped }
        let existing = try stepsRepo.steps(from: dayStart, to: dayStart).first
        if let existing, existing.source == .manual {
            return abs(existing.steps - count) > 0.5 ? .manualConflict : .skipped
        }
        try stepsRepo.setSteps(count, for: dayStart, source: .healthKit)
        return .updated
    }

    // MARK: - Background delivery

    /// Registers background delivery (steps hourly, weight immediate) and
    /// installs the observer queries. Call once after first connect; call
    /// `startObserving()` on every launch so silent updates keep flowing.
    public func enableBackgroundDelivery() async throws {
        guard isHealthDataAvailable else { throw MFHealthSyncError.healthKitUnavailable }
        try await setBackgroundDelivery(for: MFHealthKitTypes.stepCount, frequency: .hourly)
        try await setBackgroundDelivery(for: MFHealthKitTypes.bodyMass, frequency: .immediate)
        await startObserving()
    }

    private func setBackgroundDelivery(for type: HKObjectType, frequency: HKUpdateFrequency) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            self.healthStore.enableBackgroundDelivery(for: type, frequency: frequency) { success, error in
                if let error {
                    continuation.resume(throwing: MFHealthSyncError.queryFailed(underlying: error))
                } else if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: MFHealthSyncError.queryFailed(underlying:
                        NSError(domain: "MFHealthKit", code: -1,
                                userInfo: [NSLocalizedDescriptionKey: "Background delivery registration failed."])))
                }
            }
        }
    }

    /// Installs HKObserverQueries for weight + steps. Safe to call on every
    /// launch; existing queries are reused. Requires the `healthkit`
    /// background mode + HealthKit entitlement in the Xcode target for the
    /// system to wake the app while it's not running.
    @MainActor
    public func startObserving() {
        guard isHealthDataAvailable, observerQueries.isEmpty else { return }
        let stepQuery = HKObserverQuery(sampleType: MFHealthKitTypes.stepCount, predicate: nil) {
            [weak self] _, completion, error in
            guard let self else { completion?(); return }
            Task { @MainActor [weak self] in
                if error == nil { await self?.handleBackgroundSteps() }
                completion?()
            }
        }
        let weightQuery = HKObserverQuery(sampleType: MFHealthKitTypes.bodyMass, predicate: nil) {
            [weak self] _, completion, error in
            guard let self else { completion?(); return }
            Task { @MainActor [weak self] in
                if error == nil { await self?.handleBackgroundWeight() }
                completion?()
            }
        }
        observerQueries = [stepQuery, weightQuery]
        observerQueries.forEach(healthStore.execute)
    }

    /// Stops background delivery and observers. Local data is kept.
    @MainActor
    public func disconnect() async {
        for query in observerQueries { healthStore.stop(query) }
        observerQueries = []
        for type: HKObjectType in [MFHealthKitTypes.stepCount, MFHealthKitTypes.bodyMass] {
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                healthStore.disableBackgroundDelivery(for: type) { _, _ in
                    continuation.resume()
                }
            }
        }
        defaults.set(false, forKey: Keys.connected)
        connectionState = .notConnected
    }

    @MainActor
    private func handleBackgroundSteps() async {
        guard let stepsRepo else { return }
        var summary = lastSummary ?? MFHealthSyncSummary()
        do {
            // Recompute the last few days — late-arriving samples can land on
            // an earlier day. The manual-wins rule is applied per day.
            for stat in try await fetchDailyStepStatistics(days: 3) {
                switch try applyStepStatistic(stat, stepsRepo: stepsRepo) {
                case .updated: summary.stepDaysUpdated += 1
                case .manualConflict: summary.manualConflictsKept += 1
                case .skipped: break
                }
            }
            recordSyncCompleted(summary: summary)
        } catch {
            lastErrorMessage = (error as? LocalizedError)?.errorDescription
                ?? error.localizedDescription
        }
    }

    @MainActor
    private func handleBackgroundWeight() async {
        guard let weightsRepo else { return }
        var summary = lastSummary ?? MFHealthSyncSummary()
        do {
            let (samples, anchor) = try await fetchWeightChanges()
            for sample in samples {
                switch try applyWeightSample(sample, weightsRepo: weightsRepo) {
                case .imported: summary.weightsImported += 1
                case .manualConflict: summary.manualConflictsKept += 1
                case .duplicate: break
                }
            }
            saveAnchor(anchor, forKey: Keys.weightAnchor)
            recordSyncCompleted(summary: summary)
        } catch {
            lastErrorMessage = (error as? LocalizedError)?.errorDescription
                ?? error.localizedDescription
        }
    }

    // MARK: - Weigh-in write-back

    /// Writes a manual in-app weigh-in back to the Health app so both stay in
    /// sync. Called by the weigh-in flow (#7) after logging.
    ///
    /// Note: the write triggers our own weight observer, but the resulting
    /// sample is discarded by the manual-wins rule (the in-app manual entry
    /// already exists for that day), so no duplicate is created.
    @MainActor
    public func writeWeighIn(weightKg: Double, date: Date = Date()) async throws {
        guard isHealthDataAvailable else { throw MFHealthSyncError.healthKitUnavailable }
        guard healthStore.authorizationStatus(for: MFHealthKitTypes.bodyMass) == .sharingAuthorized
        else { throw MFHealthSyncError.authorizationDenied }
        let sample = HKQuantitySample(
            type: MFHealthKitTypes.bodyMass,
            quantity: HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: weightKg),
            start: date,
            end: date,
            metadata: [HKMetadataKeyWasUserEntered: true]
        )
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            self.healthStore.save(sample) { success, error in
                if let error {
                    continuation.resume(throwing: MFHealthSyncError.queryFailed(underlying: error))
                } else if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: MFHealthSyncError.queryFailed(underlying:
                        NSError(domain: "MFHealthKit", code: -2,
                                userInfo: [NSLocalizedDescriptionKey: "Couldn't save the weigh-in to Apple Health."])))
                }
            }
        }
    }

    // MARK: - Queries

    private func fetchWeightHistory(days: Int) async throws -> [HKQuantitySample] {
        let start = Calendar.current.date(byAdding: .day, value: -days, to: Date())
            ?? Date.distantPast
        let predicate = HKQuery.predicateForSamples(
            withStart: start, end: nil, options: .strictStartDate)
        return try await fetchQuantitySamples(type: MFHealthKitTypes.bodyMass, predicate: predicate)
    }

    /// Incremental weight fetch via an anchored query. When no anchor exists
    /// yet, falls back to the last 3 days (the 30-day import covers the rest).
    private func fetchWeightChanges() async throws -> (samples: [HKQuantitySample], anchor: HKQueryAnchor?) {
        let anchor = loadAnchor(forKey: Keys.weightAnchor)
        let predicate: NSPredicate? = anchor == nil
            ? HKQuery.predicateForSamples(
                withStart: Date().addingTimeInterval(-3 * 86_400),
                end: nil, options: .strictStartDate)
            : nil
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKAnchoredObjectQuery(
                type: MFHealthKitTypes.bodyMass,
                predicate: predicate,
                anchor: anchor,
                limit: HKObjectQueryNoLimit
            ) { _, samples, _, newAnchor, error in
                if let error {
                    continuation.resume(throwing: MFHealthSyncError.queryFailed(underlying: error))
                } else {
                    continuation.resume(returning: ((samples as? [HKQuantitySample]) ?? [], newAnchor))
                }
            }
            self.healthStore.execute(query)
        }
    }

    private func fetchQuantitySamples(
        type: HKQuantityType,
        predicate: NSPredicate?
    ) async throws -> [HKQuantitySample] {
        try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: true)]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: MFHealthSyncError.queryFailed(underlying: error))
                } else {
                    continuation.resume(returning: (samples as? [HKQuantitySample]) ?? [])
                }
            }
            self.healthStore.execute(query)
        }
    }

    /// Daily step totals for the last `days` days via HKStatisticsCollectionQuery.
    private func fetchDailyStepStatistics(days: Int) async throws -> [HKStatistics] {
        let calendar = Calendar.current
        let end = Date()
        let start = calendar.date(byAdding: .day, value: -days, to: calendar.startOfDay(for: end)) ?? end
        let anchorDate = calendar.startOfDay(for: start)
        let predicate = HKQuery.predicateForSamples(
            withStart: start, end: end, options: .strictStartDate)
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: MFHealthKitTypes.stepCount,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum,
                anchorDate: anchorDate,
                intervalComponents: DateComponents(day: 1)
            )
            query.initialResultsHandler = { _, collection, error in
                if let error {
                    continuation.resume(throwing: MFHealthSyncError.queryFailed(underlying: error))
                    return
                }
                var out: [HKStatistics] = []
                collection?.enumerateStatistics(from: start, to: end) { stats, _ in
                    out.append(stats)
                }
                continuation.resume(returning: out)
            }
            self.healthStore.execute(query)
        }
    }

    // MARK: - Persistence helpers

    private func loadAnchor(forKey key: String) -> HKQueryAnchor? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: data)
    }

    private func saveAnchor(_ anchor: HKQueryAnchor?, forKey key: String) {
        guard let anchor else {
            defaults.removeObject(forKey: key)
            return
        }
        if let data = try? NSKeyedArchiver.archivedData(
            withRootObject: anchor, requiringSecureCoding: true) {
            defaults.set(data, forKey: key)
        }
    }

    @MainActor
    private func recordSyncCompleted(summary: MFHealthSyncSummary) {
        var summary = summary
        summary.completedAt = Date()
        lastSummary = summary
        lastSyncDate = summary.completedAt
        lastErrorMessage = nil
        defaults.set(summary.completedAt, forKey: Keys.lastSync)
    }
}
