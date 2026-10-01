import SwiftUI
import UIKit

// MARK: - MFShareSheet

/// `UIActivityViewController` wrapper for sharing one or more files
/// (issue #12: CSV export). `ShareLink` only shares a single item cleanly;
/// the export produces two files, so the activity controller is the right
/// tool.
public struct MFShareSheet: UIViewControllerRepresentable {
    public var items: [Any]
    public var onDismiss: (() -> Void)?

    public init(items: [Any], onDismiss: (() -> Void)? = nil) {
        self.items = items
        self.onDismiss = onDismiss
    }

    public func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: items,
            applicationActivities: nil
        )
        controller.completionWithItemsHandler = { _, _, _, _ in
            onDismiss?()
        }
        return controller
    }

    public func updateUIViewController(
        _ uiViewController: UIActivityViewController,
        context: Context
    ) {}
}
