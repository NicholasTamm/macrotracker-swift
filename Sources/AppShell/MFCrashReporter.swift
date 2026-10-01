import Foundation
import MetricKit

// MARK: - MFCrashReporter

/// Crash/diagnostic reporting hookup (issue #12, TestFlight prep).
///
/// Deliberate choice: **MetricKit only — no third-party crash SDK.** The app
/// has a data-never-sold, no-ads, no-tracking posture (see PRIVACY.md), so
/// shipping a third-party crash SDK would contradict the privacy story.
/// MetricKit is first-party: iOS collects crash and diagnostic payloads and
/// delivers them to App Store Connect / Xcode Organizer automatically once
/// the app is distributed (TestFlight included). This subscriber exists so
/// the app can also note locally that diagnostics arrived (surfaced as a
/// "last diagnostic report" line for support), without sending anything
/// anywhere itself.
///
/// What the developer gets without any extra code: symbolicated crash
/// reports in Xcode → Organizer → Crashes for every TestFlight build.
public final class MFCrashReporter: NSObject, MXMetricManagerSubscriber {
    private static let lastReportKey = "mf.diagnostics.lastReportDate"

    public override init() {
        super.init()
    }

    /// Subscribes to MetricKit delivery. Call once at launch.
    public func start() {
        MXMetricManager.shared.add(self)
    }

    public func stop() {
        MXMetricManager.shared.remove(self)
    }

    // MARK: MXMetricManagerSubscriber

    public func didReceive(_ payloads: [MXMetricPayload]) {
        // Metric payloads (launch times, hang rates) are delivered daily;
        // the system forwards them to App Store Connect. We just note the
        // delivery time for the local diagnostics line.
        UserDefaults.standard.set(Date(), forKey: Self.lastReportKey)
    }

    public func didReceive(_ payloads: [MXDiagnosticPayload]) {
        // Crash / hang / disk-write diagnostics. Again: the OS handles
        // upload to App Store Connect; we record the delivery time only.
        UserDefaults.standard.set(Date(), forKey: Self.lastReportKey)
    }

    // MARK: Local status

    /// When diagnostics were last delivered to this device, if ever.
    public static var lastDiagnosticDelivery: Date? {
        UserDefaults.standard.object(forKey: lastReportKey) as? Date
    }
}
