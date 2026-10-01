import UIKit
import Vision

// MARK: - MFVisionOCR

/// Thin async wrapper over Vision's `VNRecognizeTextRequest`, shared by the
/// nutrition-label and cookbook-photo flows. Runs off the main actor so OCR
/// never blocks the UI.
public enum MFVisionOCR {
    public enum Error: Swift.Error, LocalizedError {
        case noImageData
        case recognitionFailed(String)

        public var errorDescription: String? {
            switch self {
            case .noImageData: return "Couldn't read that photo."
            case .recognitionFailed(let detail): return "Text recognition failed: \(detail)"
            }
        }
    }

    /// Returns the recognized text lines, in reading order.
    public static func recognizeText(in image: UIImage) async throws -> [String] {
        guard let cgImage = image.cgImage else { throw Error.noImageData }
        let orientation = cgOrientation(image.imageOrientation)
        return try await Task.detached(priority: .userInitiated) {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            let handler = VNImageRequestHandler(
                cgImage: cgImage,
                orientation: orientation,
                options: [:]
            )
            do {
                try handler.perform([request])
            } catch {
                throw Error.recognitionFailed(error.localizedDescription)
            }
            return request.results?
                .compactMap { $0.topCandidates(1).first?.string } ?? []
        }.value
    }

    private static func cgOrientation(_ orientation: UIImage.Orientation) -> CGImagePropertyOrientation {
        switch orientation {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        case .upMirrored: return .upMirrored
        case .downMirrored: return .downMirrored
        case .leftMirrored: return .leftMirrored
        case .rightMirrored: return .rightMirrored
        @unknown default: return .up
        }
    }
}
