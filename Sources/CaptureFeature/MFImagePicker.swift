import SwiftUI
import UIKit

// MARK: - MFImagePicker

/// Camera / photo-library picker used by the label, photo, and cookbook
/// flows. Callers must have already gated on camera / photo-library
/// permission via `MFPermissionCenter`.
public struct MFImagePicker: UIViewControllerRepresentable {
    public enum Source {
        case camera
        case library

        /// False on simulators and devices without a camera.
        public static var isCameraAvailable: Bool {
            UIImagePickerController.isSourceTypeAvailable(.camera)
        }
    }

    private let source: Source
    private let onPick: (UIImage) -> Void
    private let onCancel: () -> Void

    public init(
        source: Source,
        onPick: @escaping (UIImage) -> Void,
        onCancel: @escaping () -> Void = {}
    ) {
        self.source = source
        self.onPick = onPick
        self.onCancel = onCancel
    }

    public func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = source == .camera ? .camera : .photoLibrary
        picker.delegate = context.coordinator
        return picker
    }

    public func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    public func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick, onCancel: onCancel)
    }

    public final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        private let onPick: (UIImage) -> Void
        private let onCancel: () -> Void

        init(onPick: @escaping (UIImage) -> Void, onCancel: @escaping () -> Void) {
            self.onPick = onPick
            self.onCancel = onCancel
        }

        public func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                onPick(image)
            } else {
                onCancel()
            }
        }

        public func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onCancel()
        }
    }
}
