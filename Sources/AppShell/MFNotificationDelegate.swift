import Foundation
import UserNotifications
import EngagementFeature

// MARK: - MFNotificationDelegate

/// `UNUserNotificationCenterDelegate` (issue #12 integration).
///
/// Routes notification taps through the shared `MFRouter`:
/// - The scheduler stores an `mfclone://` deep link in
///   `userInfo["mfDeepLink"]` (`MFNotificationScheduler.deepLinkUserInfoKey`);
///   taps open that URL through the router.
/// - The "Quick Log" notification action
///   (`MFNotificationScheduler.quickLogAction`) maps to `mfclone://quicklog`.
///
/// While the app is in the foreground, notifications still present as a
/// banner + sound so reminders aren't silently swallowed.
///
/// Isolation: the delegate itself is non-isolated (UIKit calls it on the
/// main thread); it hops to the `@MainActor` router with a `Task`.
public final class MFNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    private weak var router: MFRouter?

    public init(router: MFRouter) {
        self.router = router
    }

    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        let actionIdentifier = response.actionIdentifier
        Task { @MainActor [weak self] in
            defer { completionHandler() }
            guard let router = self?.router else { return }
            if actionIdentifier == MFNotificationScheduler.quickLogAction {
                guard let url = URL(string: "mfclone://quicklog") else { return }
                router.handle(url: url)
            } else if
                let link = userInfo[MFNotificationScheduler.deepLinkUserInfoKey] as? String,
                let url = URL(string: link)
            {
                router.handle(url: url)
            }
        }
    }

    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
