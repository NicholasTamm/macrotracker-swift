import SwiftUI
import VisionKit
import AVFoundation

// MARK: - MFBarcodeScannerView

/// Barcode capture entry point: VisionKit `DataScannerViewController` where
/// the hardware supports it (iOS 16+, A12+), with an AVFoundation
/// metadata-output fallback for older devices. Fires `onScan` once per
/// scan with the raw payload string.
public struct MFBarcodeScannerView: View {
    private let onScan: (String) -> Void
    @State private var errorMessage: String?

    public init(onScan: @escaping (String) -> Void) {
        self.onScan = onScan
    }

    public var body: some View {
        ZStack {
            if DataScannerViewController.isSupported {
                MFDataScannerRepresentable(onScan: onScan, onError: reportError)
            } else {
                MFAVCaptureBarcodeView(onScan: onScan, onError: reportError)
            }
            if let errorMessage {
                VStack {
                    Spacer()
                    Text(errorMessage)
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.black.opacity(0.78))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding()
                }
            }
        }
    }

    private func reportError(_ message: String) {
        // Called from representable update/make paths; hop off the view-update
        // cycle before touching state.
        DispatchQueue.main.async { errorMessage = message }
    }
}

// MARK: - VisionKit wrapper

private struct MFDataScannerRepresentable: UIViewControllerRepresentable {
    var onScan: (String) -> Void
    var onError: (String) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let controller = DataScannerViewController(
            recognizedDataTypes: [.barcode()],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: true,
            isHighlightingEnabled: true
        )
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: DataScannerViewController, context: Context) {
        guard !context.coordinator.didFire, !context.coordinator.didReportStartError else { return }
        do {
            try controller.startScanning()
        } catch {
            context.coordinator.didReportStartError = true
            onError("Couldn't start the barcode scanner. \(error.localizedDescription)")
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onScan: onScan, onError: onError)
    }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        var didFire = false
        var didReportStartError = false
        private let onScan: (String) -> Void
        private let onError: (String) -> Void

        init(onScan: @escaping (String) -> Void, onError: @escaping (String) -> Void) {
            self.onScan = onScan
            self.onError = onError
        }

        func dataScanner(
            _ dataScanner: DataScannerViewController,
            didAdd addedItems: [RecognizedItem],
            allItems: [RecognizedItem]
        ) {
            guard !didFire else { return }
            for item in addedItems {
                guard case .barcode(let code) = item,
                      let payload = code.payloadStringValue,
                      !payload.isEmpty
                else { continue }
                didFire = true
                dataScanner.stopScanning()
                onScan(payload)
                return
            }
        }

        func dataScanner(
            _ dataScanner: DataScannerViewController,
            didRemove removedItems: [RecognizedItem],
            allItems: [RecognizedItem]
        ) {}

        func dataScanner(
            _ dataScanner: DataScannerViewController,
            becameUnavailableWithError error: DataScannerViewController.ScanningUnavailable
        ) {
            onError("Barcode scanning became unavailable. \(error.localizedDescription)")
        }
    }
}

// MARK: - AVFoundation fallback

/// Metadata-output barcode scanner for hardware without DataScanner
/// support. Same `onScan` contract as the VisionKit path.
private struct MFAVCaptureBarcodeView: UIViewRepresentable {
    var onScan: (String) -> Void
    var onError: (String) -> Void

    func makeUIView(context: Context) -> MFPreviewView {
        let view = MFPreviewView()
        let session = AVCaptureSession()
        session.sessionPreset = .high

        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input)
        else {
            onError("Couldn't access the camera for barcode scanning.")
            return view
        }
        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else {
            onError("Couldn't access the camera for barcode scanning.")
            return view
        }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(context.coordinator, queue: .main)
        output.metadataObjectTypes = [.ean13, .ean8, .upce, .code128, .code39, .qr]

        context.coordinator.session = session
        view.previewLayer.session = session
        session.startRunning()
        return view
    }

    func updateUIView(_ uiView: MFPreviewView, context: Context) {}

    static func dismantleUIView(_ uiView: MFPreviewView, coordinator: Coordinator) {
        coordinator.session?.stopRunning()
        coordinator.session = nil
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onScan: onScan)
    }

    final class MFPreviewView: UIView {
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }

        override class var layerClass: AnyClass {
            AVCaptureVideoPreviewLayer.self
        }
    }

    final class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
        var session: AVCaptureSession?
        private var didFire = false
        private let onScan: (String) -> Void

        init(onScan: @escaping (String) -> Void) {
            self.onScan = onScan
        }

        func metadataOutput(
            _ output: AVCaptureMetadataOutput,
            didOutput metadataObjects: [AVMetadataObject],
            from connection: AVCaptureConnection
        ) {
            guard !didFire else { return }
            guard let code = metadataObjects.lazy
                .compactMap({ $0 as? AVMetadataMachineReadableCodeObject })
                .first,
                let value = code.stringValue,
                !value.isEmpty
            else { return }
            didFire = true
            session?.stopRunning()
            onScan(value)
        }
    }
}
