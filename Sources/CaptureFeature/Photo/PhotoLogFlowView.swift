import SwiftUI
import UIKit
import DataLayer
import DesignSystem

// MARK: - PhotoLogFlowView

/// AI photo logging: capture → `PhotoLoggingService` (STUB — see
/// `PhotoLoggingService.swift`) → full local draft-review UI → save each
/// item as a `FoodItem` (source `.photoEstimate`) and log.
///
/// The network call is isolated behind the protocol; everything on screen
/// here is real, local, and shippable.
public struct PhotoLogFlowView: View {
    private let deps: CaptureDependencies

    @StateObject private var permissions = MFPermissionCenter()
    @State private var phase: Phase = .capture
    @State private var pickerSource: PickerSource?
    @State private var capturedImage: UIImage?
    @State private var items: [PhotoMealItem] = []
    @State private var estimateNote: String?
    @State private var mealSlot: MealSlot = .other
    @State private var isWorking = false
    @State private var errorMessage: String?

    private enum Phase: Equatable {
        case capture
        case analyzing
        case review
    }

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
            case .analyzing:
                analyzingView
            case .review:
                reviewView
            }
        }
        .navigationTitle("Log from photo")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $pickerSource) { source in
            MFImagePicker(
                source: source.value,
                onPick: { image in
                    pickerSource = nil
                    analyze(image)
                },
                onCancel: { pickerSource = nil }
            )
        }
    }

    // MARK: Capture

    private var captureView: some View {
        VStack(spacing: MFSpacing.lg) {
            MFPermissionGate(
                state: permissions.camera,
                icon: "camera.viewfinder",
                title: "Camera access needed",
                message: "Allow camera access to photograph your meals.",
                requestTitle: "Allow camera",
                onRequest: { Task { await permissions.requestCamera() } }
            ) {
                VStack(spacing: MFSpacing.md) {
                    MFEmptyState(
                        icon: "camera.viewfinder",
                        title: "Photograph your meal",
                        message: "Take a top-down photo of the whole plate. You'll review and correct every estimate before logging."
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

    // MARK: Analyzing

    private var analyzingView: some View {
        VStack(spacing: MFSpacing.md) {
            if let capturedImage {
                Image(uiImage: capturedImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 280)
                    .clipShape(RoundedRectangle(cornerRadius: MFRadii.md))
            }
            ProgressView()
            Text("Estimating your meal…")
                .font(MFFont.subheadline)
                .foregroundColor(MFColor.textSecondary)
        }
        .padding(MFSpacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(MFColor.background)
    }

    // MARK: Review

    private var reviewView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MFSpacing.lg) {
                if let errorMessage {
                    MFBanner(kind: .danger, title: "Couldn't log", message: errorMessage)
                }
                // The stub is always disclosed — never presented as real AI.
                MFBanner(
                    kind: .warning,
                    title: "Demo estimate",
                    message: estimateNote
                        ?? "Photo analysis runs on a stub backend right now. Correct every value below."
                )
                if let capturedImage {
                    Image(uiImage: capturedImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 200)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: MFRadii.md))
                }

                Text("Estimated items")
                    .font(MFFont.headline)
                    .foregroundColor(MFColor.textPrimary)

                ForEach($items) { $item in
                    itemEditor(item: $item)
                }

                MFButton("Add item", style: .secondary, size: .medium, icon: "plus") {
                    items.append(PhotoMealItem(
                        name: "",
                        estimatedGrams: 100,
                        estimatedCalories: 0,
                        confidence: 0.5,
                        isStubEstimate: items.allSatisfy(\.isStubEstimate)
                    ))
                }

                MFSegmentedControl(options: MealSlot.allCases, selection: $mealSlot) {
                    $0.displayName
                }

                MFButton(
                    "Log meal",
                    style: .primary,
                    icon: "plus",
                    isLoading: isWorking,
                    action: logMeal
                )
                .disabled(!canLog || isWorking)
            }
            .padding(MFSpacing.lg)
        }
        .background(MFColor.background)
    }

    private func itemEditor(item: Binding<PhotoMealItem>) -> some View {
        VStack(alignment: .leading, spacing: MFSpacing.sm) {
            HStack {
                MFTextField(
                    "Item name",
                    placeholder: "e.g. Chicken rice bowl",
                    text: item.name
                )
                Button {
                    items.removeAll { $0.id == item.wrappedValue.id }
                } label: {
                    Image(systemName: "trash")
                        .foregroundColor(MFColor.danger)
                }
                .accessibilityLabel("Remove item")
            }
            HStack(spacing: MFSpacing.md) {
                MFStepper(
                    value: item.estimatedGrams,
                    step: 10,
                    range: 1...5000,
                    unit: "g",
                    label: "Estimated amount"
                )
                VStack(alignment: .leading, spacing: 2) {
                    Text("≈ \(MFFormat.kcal(item.wrappedValue.estimatedCalories)) kcal")
                        .font(MFFont.bodyBold)
                        .monospacedDigit()
                        .foregroundColor(MFColor.textPrimary)
                    if item.wrappedValue.isStubEstimate {
                        Text("stub value")
                            .font(MFFont.caption)
                            .foregroundColor(MFColor.warning)
                    } else {
                        Text(confidenceText(item.wrappedValue.confidence))
                            .font(MFFont.caption)
                            .foregroundColor(MFColor.textSecondary)
                    }
                }
            }
        }
        .padding(MFSpacing.md)
        .background(MFColor.surfaceSunken)
        .clipShape(RoundedRectangle(cornerRadius: MFRadii.md))
    }

    private func confidenceText(_ confidence: Double) -> String {
        switch confidence {
        case 0.75...: return "High confidence"
        case 0.4..<0.75: return "Medium confidence"
        default: return "Low confidence — check carefully"
        }
    }

    private var canLog: Bool {
        !items.isEmpty && items.allSatisfy {
            !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && $0.estimatedGrams > 0
        }
    }

    // MARK: Actions

    private func analyze(_ image: UIImage) {
        capturedImage = image
        phase = .analyzing
        Task {
            do {
                guard let jpeg = image.jpegData(compressionQuality: 0.85) else {
                    throw MFCaptureError.unexpected("Couldn't read that photo.")
                }
                let service = deps.photoService
                let estimate = try await service.analyzeMeal(jpeg)
                await MainActor.run {
                    items = estimate.items
                    estimateNote = estimate.note
                    phase = .review
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    phase = .capture
                }
            }
        }
    }

    private func logMeal() {
        errorMessage = nil
        guard canLog else { return }
        isWorking = true
        let snapshot = items
        let slot = mealSlot
        Task {
            do {
                try await MainActor.run {
                    for item in snapshot {
                        let draft = CaptureDraft(
                            name: item.name,
                            servingDescription: "",
                            servingSizeGrams: item.estimatedGrams,
                            mealSlot: slot,
                            nutrientsPer100g: [.calories: item.impliedCaloriesPer100g],
                            source: .photoEstimate,
                            entrySource: .photo,
                            confidence: item.confidence,
                            note: item.isStubEstimate ? "Demo photo estimate (stub backend)" : nil
                        )
                        try draft.saveAndLog(using: deps)
                    }
                    // One user action = one hook fire, even when the meal
                    // has several items; the streak layer is per-day
                    // idempotent anyway.
                    deps.noteFoodLogged()
                }
                await MainActor.run { phase = .capture; resetReview() }
            } catch {
                await MainActor.run {
                    isWorking = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func resetReview() {
        capturedImage = nil
        items = []
        estimateNote = nil
        mealSlot = .other
        isWorking = false
        errorMessage = nil
    }
}
