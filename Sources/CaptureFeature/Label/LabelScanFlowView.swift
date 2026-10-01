import SwiftUI
import UIKit
import DataLayer
import DesignSystem

// MARK: - LabelScanFlowView

/// Nutrition-label capture: photo → Vision OCR → `NutritionLabelParser` →
/// editable `CaptureDraft` (source `.labelScan`) → save + log.
///
/// Acceptance: a label photo always produces an editable nutrition draft.
public struct LabelScanFlowView: View {
    private let deps: CaptureDependencies

    @StateObject private var permissions = MFPermissionCenter()
    @State private var phase: Phase = .capture
    @State private var pickerSource: PickerSource?
    @State private var capturedImage: UIImage?
    @State private var draft = CaptureDraft()
    @State private var errorMessage: String?

    private enum Phase: Equatable {
        case capture
        case recognizing
        case review
    }

    /// Identifiable wrapper so the image picker can ride `.sheet(item:)`.
    private struct PickerSource: Identifiable {
        let id = UUID()
        let value: MFImagePicker.Source
    }

    public init(deps: CaptureDependencies) {
        self.deps = deps
    }

    public var body: some View {
        Group {
            switch phase {
            case .capture:
                captureView
            case .recognizing:
                recognizingView
            case .review:
                NutritionDraftEditorView(
                    draft: $draft,
                    deps: deps,
                    onDone: reset
                )
            }
        }
        .navigationTitle("Scan nutrition label")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $pickerSource) { source in
            MFImagePicker(
                source: source.value,
                onPick: { image in
                    pickerSource = nil
                    recognize(image)
                },
                onCancel: { pickerSource = nil }
            )
        }
    }

    // MARK: Views

    private var captureView: some View {
        VStack(spacing: MFSpacing.lg) {
            if let errorMessage {
                MFBanner(kind: .danger, title: "Couldn't read the label", message: errorMessage)
            }
            MFPermissionGate(
                state: permissions.camera,
                icon: "text.viewfinder",
                title: "Camera access needed",
                message: "Allow camera access to photograph nutrition labels.",
                requestTitle: "Allow camera",
                onRequest: { Task { await permissions.requestCamera() } }
            ) {
                VStack(spacing: MFSpacing.md) {
                    MFEmptyState(
                        icon: "text.viewfinder",
                        title: "Photograph the label",
                        message: "Hold the nutrition facts panel square in the frame. You'll review every value before saving."
                    )
                    if MFImagePicker.Source.isCameraAvailable {
                        MFButton("Take photo", style: .primary, icon: "camera") {
                            pickerSource = PickerSource(value: .camera)
                        }
                    }
                    MFButton(
                        "Choose from library",
                        style: MFImagePicker.Source.isCameraAvailable ? .secondary : .primary,
                        size: .medium,
                        icon: "photo"
                    ) {
                        pickerSource = PickerSource(value: .library)
                    }
                }
                .padding(MFSpacing.lg)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(MFColor.background)
        .onAppear { permissions.refresh() }
    }

    private var recognizingView: some View {
        VStack(spacing: MFSpacing.md) {
            if let capturedImage {
                Image(uiImage: capturedImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 240)
                    .clipShape(RoundedRectangle(cornerRadius: MFRadii.md))
            }
            ProgressView()
            Text("Reading the label…")
                .font(MFFont.subheadline)
                .foregroundColor(MFColor.textSecondary)
        }
        .padding(MFSpacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(MFColor.background)
    }

    // MARK: Actions

    private func recognize(_ image: UIImage) {
        capturedImage = image
        errorMessage = nil
        phase = .recognizing
        Task {
            do {
                let lines = try await MFVisionOCR.recognizeText(in: image)
                let parsed = NutritionLabelParser.parse(lines: lines)
                guard !parsed.nutrientsPer100g.isEmpty else {
                    throw MFCaptureError.unexpected(
                        "No nutrition values were found. Try a straighter, better-lit photo."
                    )
                }
                let draft = CaptureDraft(
                    servingDescription: parsed.servingDescription,
                    servingSizeGrams: parsed.servingSizeGrams,
                    nutrientsPer100g: parsed.nutrientsPer100g,
                    source: .labelScan,
                    entrySource: .labelScan,
                    note: parsed.assumedServingSize
                        ? "Serving size not found on label — assumed 100 g. Check the values."
                        : nil
                )
                await MainActor.run {
                    self.draft = draft
                    self.phase = .review
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    phase = .capture
                }
            }
        }
    }

    private func reset() {
        draft = CaptureDraft()
        capturedImage = nil
        errorMessage = nil
        phase = .capture
    }
}
