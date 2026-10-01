import SwiftUI
import AVFoundation
import Speech
import DesignSystem

// MARK: - MFPermissionState

/// Camera / microphone / speech-recognition authorization state.
public enum MFPermissionState: Equatable {
    case notDetermined
    case granted
    case denied
    case restricted

    public var isGranted: Bool { self == .granted }
    public var needsRequest: Bool { self == .notDetermined }
}

// MARK: - MFPermissionCenter

/// Central permission state for the capture flows. Views observe the
/// published states; requests are explicit so the system prompt only ever
/// appears from a user tap or a clearly-labeled "continue" step.
///
/// Required Info.plist keys (owned by the AppShell target — see README.md):
/// - NSCameraUsageDescription
/// - NSMicrophoneUsageDescription
/// - NSSpeechRecognitionUsageDescription
/// - NSPhotoLibraryUsageDescription
@MainActor
public final class MFPermissionCenter: ObservableObject {
    @Published public private(set) var camera: MFPermissionState = .notDetermined
    @Published public private(set) var microphone: MFPermissionState = .notDetermined
    @Published public private(set) var speech: MFPermissionState = .notDetermined

    public init() {
        refresh()
    }

    /// Re-reads the current system states (call on appear / after returning
    /// from Settings).
    public func refresh() {
        camera = Self.avState(for: .video)
        microphone = Self.avState(for: .audio)
        speech = Self.speechState(SFSpeechRecognizer.authorizationStatus())
    }

    @discardableResult
    public func requestCamera() async -> MFPermissionState {
        let granted: Bool = await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .video) { continuation.resume(returning: $0) }
        }
        camera = granted ? .granted : .denied
        return camera
    }

    @discardableResult
    public func requestMicrophone() async -> MFPermissionState {
        let granted: Bool = await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .audio) { continuation.resume(returning: $0) }
        }
        microphone = granted ? .granted : .denied
        return microphone
    }

    @discardableResult
    public func requestSpeechRecognition() async -> MFPermissionState {
        let status: SFSpeechRecognizerAuthorizationStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }
        speech = Self.speechState(status)
        return speech
    }

    /// Voice logging needs both microphone and speech recognition.
    public func requestVoicePermissions() async {
        _ = await requestMicrophone()
        _ = await requestSpeechRecognition()
    }

    // MARK: Mapping

    private static func avState(for mediaType: AVMediaType) -> MFPermissionState {
        switch AVCaptureDevice.authorizationStatus(for: mediaType) {
        case .notDetermined: return .notDetermined
        case .restricted: return .restricted
        case .denied: return .denied
        case .authorized: return .granted
        @unknown default: return .notDetermined
        }
    }

    private static func speechState(_ status: SFSpeechRecognizerAuthorizationStatus) -> MFPermissionState {
        switch status {
        case .notDetermined: return .notDetermined
        case .restricted: return .restricted
        case .denied: return .denied
        case .authorized: return .granted
        @unknown default: return .notDetermined
        }
    }
}

// MARK: - MFPermissionDeniedView

/// Graceful denial state: explains why the permission is needed and offers
/// a one-tap jump to Settings. Built from design-system components.
public struct MFPermissionDeniedView: View {
    private let icon: String
    private let title: String
    private let message: String

    public init(icon: String, title: String, message: String) {
        self.icon = icon
        self.title = title
        self.message = message
    }

    public var body: some View {
        MFEmptyState(
            icon: icon,
            title: title,
            message: message,
            actionTitle: "Open Settings",
            onAction: openSettings
        )
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

// MARK: - MFPermissionGate

/// Shows `content` when `isGranted` is true, a request prompt when
/// `.notDetermined`, and `MFPermissionDeniedView` for denied/restricted.
public struct MFPermissionGate<Content: View>: View {
    private let state: MFPermissionState
    private let icon: String
    private let title: String
    private let message: String
    private let requestTitle: String
    private let onRequest: () -> Void
    private let content: Content

    public init(
        state: MFPermissionState,
        icon: String,
        title: String,
        message: String,
        requestTitle: String,
        onRequest: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.state = state
        self.icon = icon
        self.title = title
        self.message = message
        self.requestTitle = requestTitle
        self.onRequest = onRequest
        self.content = content()
    }

    public var body: some View {
        switch state {
        case .granted:
            content
        case .notDetermined:
            MFEmptyState(
                icon: icon,
                title: title,
                message: message,
                actionTitle: requestTitle,
                onAction: onRequest
            )
        case .denied, .restricted:
            MFPermissionDeniedView(icon: icon, title: title, message: message)
        }
    }
}

#Preview("Permission denied") {
    MFPermissionDeniedView(
        icon: "camera.viewfinder",
        title: "Camera access needed",
        message: "Allow camera access to scan barcodes and nutrition labels."
    )
    .background(MFColor.background)
}
