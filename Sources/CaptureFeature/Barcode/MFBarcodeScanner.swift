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

    public init(onScan: @escaping (String) -> Void) {
        self.onScan = onScan
    }

    public var body: some View {
        if DataScannerViewController.isSupported {
            MFDataScannerRepresentable(onScan: onScan)
        } else {
            MFAVCaptureBarcodeView(onScan: onScan)
        }
    }
}

// MARK: - VisionKit wrapper

private struct MFDataScannerRepresentable: UIViewControllerRepresentable {
    var onScan: (String) -> Void

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
        guard !context.coordinator.didFire else { return }
        try? controller.startScanning()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onScan: onScan)
    }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        var didFire = false
        private let onScan: (String) -> Void

        init(onScan: @escaping (String) -> Void) {
            self.onScan = onScan
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
        ) {}
    }
}

// MARK: - AVFoundation fallback

/// Metadata-output barcode scanner for hardware without DataScanner
/// support. Same `onScan` contract as the VisionKit path.
private struct MFAVCaptureBarcodeView: UIViewRepresentable {
    var onScan: (String) -> Void

    func makeUIView(context: Context) -> MFPreviewView {
        let view = MFPreviewView()
        let session = AVCaptureSession()
        session.sessionPreset = .high

        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input)
        else { return view }
        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else { return view }
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
