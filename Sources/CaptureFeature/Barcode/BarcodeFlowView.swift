import SwiftUI
import DataLayer
import DesignSystem

// MARK: - BarcodeFlowView

/// Scan → resolve (local DB → Open Food Facts cache → live OFF lookup) →
/// found (confirm + log) or graceful "not found → create custom" flow.
///
/// Acceptance: a scan always ends in a logged food or a custom-food draft —
/// never a dead end.
public struct BarcodeFlowView: View {
    private let deps: CaptureDependencies

    @StateObject private var permissions = MFPermissionCenter()
    @State private var phase: Phase = .checking
    @State private var grams: Double = 100
    @State private var mealSlot: MealSlot = .other
    @State private var isWorking = false
    @State private var errorMessage: String?
    /// Editable draft for the "not found → create custom" flow.
    @State private var customDraft: CaptureDraft?

    private enum Phase: Equatable {
        case checking
        case scanning
        case resolving(code: String)
        case found(FoodSearchResult)
        case notFound(code: String)
    }

    public init(deps: CaptureDependencies) {
        self.deps = deps
    }

    public var body: some View {
        Group {
            switch phase {
            case .checking:
                ProgressView()
                    .onAppear { checkCamera() }
            case .scanning:
                MFPermissionGate(
                    state: permissions.camera,
                    icon: "barcode.viewfinder",
                    title: "Camera access needed",
                    message: "Allow camera access to scan product barcodes.",
                    requestTitle: "Allow camera",
                    onRequest: { Task { await permissions.requestCamera() } }
                ) {
                    ZStack {
                        MFBarcodeScannerView(onScan: resolve)
                            .ignoresSafeArea()
                        scanHint
                    }
                }
            case .resolving(let code):
                resolvingView(code: code)
            case .found(let result):
                foundView(result: result)
            case .notFound(let code):
                notFoundView(code: code)
            }
        }
        .navigationTitle("Scan barcode")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $customDraft) { draft in
            NavigationStack {
                NutritionDraftEditorView(
                    draft: Binding(
                        get: { draft },
                        set: { customDraft = $0 }
                    ),
                    deps: deps,
                    onDone: {
                        customDraft = nil
                        phase = .scanning
                    }
                )
            }
        }
    }

    // MARK: Phases

    private func checkCamera() {
        permissions.refresh()
        switch permissions.camera {
        case .granted:
            phase = .scanning
        case .notDetermined:
            // MFPermissionGate renders the request prompt; after the user
            // answers, the denial state renders there too if needed.
            Task {
                _ = await permissions.requestCamera()
                await MainActor.run { phase = .scanning }
            }
        case .denied, .restricted:
            phase = .scanning // MFPermissionGate renders the denial state
        }
    }

    private func resolve(_ code: String) {
        phase = .resolving(code: code)
        errorMessage = nil
        Task {
            do {
                let result = try await deps.search.lookupBarcode(code)
                await MainActor.run {
                    if let result {
                        grams = 100
                        mealSlot = .other
                        phase = .found(result)
                    } else {
                        phase = .notFound(code: code)
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    phase = .notFound(code: code)
                }
            }
        }
    }

    // MARK: Views

    private var scanHint: some View {
        VStack {
            Spacer()
            Text("Point the camera at a barcode")
                .font(MFFont.subheadline.weight(.semibold))
                .foregroundColor(.white)
                .padding(.horizontal, MFSpacing.lg)
                .padding(.vertical, MFSpacing.sm)
                .background(Color.black.opacity(0.6))
                .clipShape(Capsule())
                .padding(.bottom, MFSpacing.xxl)
        }
        .accessibilityHidden(true)
    }

    private func resolvingView(code: String) -> some View {
        VStack(spacing: MFSpacing.md) {
            ProgressView()
            Text("Looking up \(code)…")
                .font(MFFont.subheadline)
                .foregroundColor(MFColor.textSecondary)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(MFColor.background)
    }

    private func foundView(result: FoodSearchResult) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MFSpacing.lg) {
                if let errorMessage {
                    MFBanner(kind: .danger, title: "Couldn't log", message: errorMessage)
                }
                VStack(alignment: .leading, spacing: MFSpacing.xs) {
                    Text(result.displayName)
                        .font(MFFont.title3)
                        .foregroundColor(MFColor.textPrimary)
                    HStack(spacing: MFSpacing.sm) {
                        Text(sourceLabel(for: result.source))
                            .font(MFFont.caption.weight(.semibold))
                            .foregroundColor(MFColor.accent)
                            .padding(.horizontal, MFSpacing.sm)
                            .padding(.vertical, 4)
                            .background(MFColor.accentSoft)
                            .clipShape(Capsule())
                        if let barcode = result.barcode {
                            Text(barcode)
                                .font(MFFont.caption)
                                .foregroundColor(MFColor.textSecondary)
                                .monospacedDigit()
                        }
                    }
                }
                HStack(spacing: MFSpacing.xl) {
                    macroStat(value: result.caloriesPer100g, unit: "kcal", label: "Calories")
                    macroStat(value: result.proteinPer100g, unit: "g", label: "Protein")
                    Spacer()
                    Text("per 100 g")
                        .font(MFFont.caption)
                        .foregroundColor(MFColor.textSecondary)
                }
                .padding(MFSpacing.md)
                .background(MFColor.surfaceSunken)
                .clipShape(RoundedRectangle(cornerRadius: MFRadii.md))

                MFStepper(value: $grams, step: 10, range: 1...10_000, unit: "g", label: "Amount")
                    .frame(maxWidth: .infinity, alignment: .center)
                MFSegmentedControl(options: MealSlot.allCases, selection: $mealSlot) {
                    $0.displayName
                }

                MFButton("Log food", style: .primary, icon: "plus", isLoading: isWorking) {
                    logFound(result)
                }
                MFButton("Scan another", style: .secondary, size: .medium) {
                    phase = .scanning
                }
            }
            .padding(MFSpacing.lg)
        }
        .background(MFColor.background)
    }

    private func macroStat(value: Double, unit: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(MFFormat.grams(value)) \(unit)")
                .font(MFFont.bodyBold)
                .monospacedDigit()
                .foregroundColor(MFColor.textPrimary)
            Text(label)
                .font(MFFont.caption)
                .foregroundColor(MFColor.textSecondary)
        }
    }

    private func notFoundView(code: String) -> some View {
        VStack(spacing: MFSpacing.lg) {
            if let errorMessage {
                MFBanner(kind: .warning, title: "Lookup had trouble", message: errorMessage)
            }
            MFEmptyState(
                icon: "barcode.viewfinder",
                title: "No match for this barcode",
                message: "Barcode \(code) isn't in your foods or Open Food Facts yet. Create it as a custom food and it'll be here next time.",
                actionTitle: "Create custom food",
                onAction: {
                    customDraft = CaptureDraft(
                        barcode: code,
                        servingDescription: "",
                        servingSizeGrams: 100,
                        source: .custom,
                        entrySource: .barcode
                    )
                }
            )
            MFButton("Scan again", style: .secondary, size: .medium) {
                phase = .scanning
            }
            .frame(maxWidth: 240)
        }
        .padding(MFSpacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(MFColor.background)
    }

    // MARK: Actions

    private func sourceLabel(for source: FoodSource) -> String {
        switch source {
        case .seedDatabase: return "Food database"
        case .openFoodFacts: return "Open Food Facts"
        case .custom: return "Custom food"
        case .recipe: return "Recipe"
        case .labelScan: return "Label scan"
        case .photoEstimate: return "Photo estimate"
        case .voiceEstimate: return "Voice estimate"
        }
    }

    private func logFound(_ result: FoodSearchResult) {
        errorMessage = nil
        isWorking = true
        let gramsToLog = grams
        let slot = mealSlot
        Task {
            do {
                let food: FoodItem = try await MainActor.run {
                    if let id = result.localFoodID,
                       let existing = try deps.foods.food(id: id)
                    {
                        return existing
                    }
                    guard let product = result.offProduct else {
                        throw MFCaptureError.unexpected("This result has no local food or product data.")
                    }
                    return try deps.search.importOFFProduct(product)
                }
                try await MainActor.run {
                    try deps.log.logFood(food, grams: gramsToLog, mealSlot: slot, source: .barcode)
                    deps.noteFoodLogged()
                }
                await MainActor.run {
                    isWorking = false
                    phase = .scanning
                }
            } catch {
                await MainActor.run {
                    isWorking = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - MFCaptureError

/// Capture-flow errors surfaced to the user.
public enum MFCaptureError: Error, LocalizedError {
    case unexpected(String)

    public var errorDescription: String? {
        switch self {
        case .unexpected(let message): return message
        }
    }
}
