import SwiftUI
import DataLayer
import DesignSystem

// MARK: - CaptureFeature (issue #5)
//
// Fast-logging inputs: barcode scanning, nutrition-label OCR, AI photo
// logging (stub backend), voice logging, and recipe import (URL + cookbook
// photo). Every flow produces editable `CaptureDraft`s that save to
// `FoodItem` / `LogEntry` via the repository protocols — the log-entry UI
// itself stays in FoodLogFeature (#4).
//
// Public surface:
// - `CaptureMenuView` — the six-method capture hub, embedded by AppShell.
// - `BarcodeFlowView`, `LabelScanFlowView`, `PhotoLogFlowView`,
//   `VoiceLogFlowView`, `RecipeImportFlowView` — individual flows.
// - `CaptureDraft` — the editable food candidate every flow produces.
// - `CaptureDependencies` — repositories + photo service, injected by AppShell.
// - `PhotoLoggingService` / `StubPhotoLoggingService` — the clearly-marked
//   STUB seam for the future AI backend (see Photo/PhotoLoggingService.swift
//   and README.md).
//
// Required Info.plist keys (owned by the AppShell target; documented here,
// wired in the Xcode project — see README.md):
// - NSCameraUsageDescription
// - NSMicrophoneUsageDescription
// - NSSpeechRecognitionUsageDescription
// - NSPhotoLibraryUsageDescription

// MARK: - CaptureMethod

/// The six fast-logging inputs, with catalog icons (see `MFIconCatalog`).
public enum CaptureMethod: String, CaseIterable, Identifiable {
    case barcode
    case labelScan
    case photo
    case voice
    case recipeURL
    case cookbook

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .barcode: return "Barcode scanner"
        case .labelScan: return "Nutrition label"
        case .photo: return "Photo log"
        case .voice: return "Voice log"
        case .recipeURL: return "Recipe from link"
        case .cookbook: return "Cookbook photo"
        }
    }

    public var subtitle: String {
        switch self {
        case .barcode: return "Look up packaged foods by barcode"
        case .labelScan: return "Snap a label to build an editable food"
        case .photo: return "Estimate a meal from a photo (demo)"
        case .voice: return "Describe your meal out loud"
        case .recipeURL: return "Import ingredients from a recipe URL"
        case .cookbook: return "Scan a cookbook page for ingredients"
        }
    }

    /// SF Symbol names from `MFIconCatalog` ("Food log" section).
    public var icon: String {
        switch self {
        case .barcode: return "barcode.viewfinder"
        case .labelScan: return "text.viewfinder"
        case .photo: return "camera.viewfinder"
        case .voice: return "mic.fill"
        case .recipeURL: return "link"
        case .cookbook: return "book.pages"
        }
    }

    public var tint: Color {
        switch self {
        case .barcode: return MFColor.accent
        case .labelScan: return MFColor.protein
        case .photo: return MFColor.weightTrend
        case .voice: return MFColor.carbs
        case .recipeURL: return MFColor.fat
        case .cookbook: return MFColor.micro
        }
    }
}

// MARK: - CaptureDependencies

/// Everything the capture flows need, injected by AppShell. Features
/// program to the repository protocols, never to SwiftData directly.
/// `photoService` defaults to the clearly-marked stub; pass a real
/// `PhotoLoggingService` to swap in the AI backend later.
@MainActor
public struct CaptureDependencies {
    public var foods: any FoodRepository
    public var search: any FoodSearchService
    public var log: any LogRepository
    public var photoService: any PhotoLoggingService
    /// Hook fired after a capture flow successfully logs food. Wired by
    /// AppShell to the same streak feed as manual logging
    /// (`AppServices.noteFoodLogged`); nil when the streak feature is
    /// disabled/unavailable. CaptureFeature must not import FoodLogFeature
    /// or TrackingFeature (MODULE_MAP rule 1), so the hook stays a plain
    /// closure — the same callback pattern `FoodLogViewModel.onFoodLogged`
    /// uses. Flows fire it once per user action (not per entry), so a
    /// multi-item scan counts as a single logging action.
    public var onFoodLogged: (() -> Void)?

    public init(
        foods: any FoodRepository,
        search: any FoodSearchService,
        log: any LogRepository,
        photoService: any PhotoLoggingService = StubPhotoLoggingService(),
        onFoodLogged: (() -> Void)? = nil
    ) {
        self.foods = foods
        self.search = search
        self.log = log
        self.photoService = photoService
        self.onFoodLogged = onFoodLogged
    }

    /// Fires `onFoodLogged` only when the logged timestamp falls on the
    /// device's current day — mirroring `FoodLogViewModel`'s private
    /// helper, so backdated writes never feed today's streak. No-ops when
    /// no hook is wired. Call once per user logging action, after the
    /// writes succeed.
    public func noteFoodLogged(at timestamp: Date = Date()) {
        guard Calendar.current.isDateInToday(timestamp) else { return }
        onFoodLogged?()
    }
}

// MARK: - CaptureMenuView

/// The capture hub: six fast-logging methods. AppShell embeds this in the
/// QuickLogSheet / Food Log navigation; each row pushes its flow.
public struct CaptureMenuView: View {
    private let deps: CaptureDependencies

    public init(deps: CaptureDependencies) {
        self.deps = deps
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: MFSpacing.sm) {
                methodSection(title: "Scan", methods: [.barcode, .labelScan])
                methodSection(title: "Describe", methods: [.photo, .voice])
                methodSection(title: "Recipes", methods: [.recipeURL, .cookbook])
            }
            .padding(MFSpacing.lg)
        }
        .background(MFColor.background)
        .navigationTitle("Log food")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func methodSection(title: String, methods: [CaptureMethod]) -> some View {
        VStack(alignment: .leading, spacing: MFSpacing.sm) {
            Text(title)
                .font(MFFont.caption.weight(.semibold))
                .foregroundColor(MFColor.textSecondary)
                .textCase(.uppercase)
                .padding(.horizontal, MFSpacing.sm)
            VStack(spacing: 0) {
                ForEach(methods) { method in
                    NavigationLink {
                        destination(for: method)
                    } label: {
                        methodRow(method)
                    }
                    if method != methods.last {
                        Divider()
                            .padding(.leading, 60)
                    }
                }
            }
            .background(MFColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: MFRadii.md))
        }
    }

    private func methodRow(_ method: CaptureMethod) -> some View {
        HStack(spacing: MFSpacing.md) {
            Image(systemName: method.icon)
                .font(.title3)
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .background(method.tint)
                .clipShape(RoundedRectangle(cornerRadius: MFRadii.sm))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(method.title)
                    .font(MFFont.body)
                    .foregroundColor(MFColor.textPrimary)
                Text(method.subtitle)
                    .font(MFFont.caption)
                    .foregroundColor(MFColor.textSecondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundColor(MFColor.textTertiary)
                .accessibilityHidden(true)
        }
        .padding(MFSpacing.md)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func destination(for method: CaptureMethod) -> some View {
        switch method {
        case .barcode:
            BarcodeFlowView(deps: deps)
        case .labelScan:
            LabelScanFlowView(deps: deps)
        case .photo:
            PhotoLogFlowView(deps: deps)
        case .voice:
            VoiceLogFlowView(deps: deps)
        case .recipeURL:
            RecipeImportFlowView(deps: deps, focus: .url)
        case .cookbook:
            RecipeImportFlowView(deps: deps, focus: .cookbook)
        }
    }
}
