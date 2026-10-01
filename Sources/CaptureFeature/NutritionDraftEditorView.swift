import SwiftUI
import DataLayer
import DesignSystem

// MARK: - NutritionDraftEditorView

/// The shared editable nutrition draft screen. Every capture flow funnels
/// into this: the parsed/scanned/estimated values arrive prefilled, the
/// user corrects them, then saves to the food database and/or logs.
///
/// Built entirely from design-system components (`MFTextField`,
/// `MFStepper`, `MFSegmentedControl`, `MFButton`, `MFBanner`).
public struct NutritionDraftEditorView: View {
    @Binding private var draft: CaptureDraft
    private let deps: CaptureDependencies
    /// Shown above the form when values are AI estimates (photo/voice).
    private let estimateBanner: String?
    private let onDone: () -> Void

    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showMicros = false

    public init(
        draft: Binding<CaptureDraft>,
        deps: CaptureDependencies,
        estimateBanner: String? = nil,
        onDone: @escaping () -> Void
    ) {
        self._draft = draft
        self.deps = deps
        self.estimateBanner = estimateBanner
        self.onDone = onDone
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MFSpacing.lg) {
                if let estimateBanner {
                    MFBanner(
                        kind: .warning,
                        title: "AI estimate",
                        message: estimateBanner
                    )
                }
                if let errorMessage {
                    MFBanner(kind: .danger, title: "Couldn't save", message: errorMessage)
                }

                macroPreview

                section("Food") {
                    MFTextField("Name", placeholder: "e.g. Greek yogurt", text: $draft.name)
                    MFTextField("Brand", placeholder: "Optional", text: $draft.brand)
                    MFTextField(
                        "Serving description",
                        placeholder: "e.g. 1 container (170 g)",
                        text: $draft.servingDescription
                    )
                    HStack {
                        MFTextField(
                            "Serving size",
                            placeholder: "100",
                            text: numberBinding(get: { draft.wrappedValue.servingSizeGrams },
                                                set: { draft.wrappedValue.servingSizeGrams = $0 }),
                            keyboard: .decimalPad
                        )
                        Text("g")
                            .font(MFFont.body)
                            .foregroundColor(MFColor.textSecondary)
                            .padding(.top, 18)
                    }
                    if let barcode = draft.barcode, !barcode.isEmpty {
                        HStack(spacing: MFSpacing.sm) {
                            Image(systemName: "barcode.viewfinder")
                                .foregroundColor(MFColor.textTertiary)
                            Text("Barcode \(barcode)")
                                .font(MFFont.footnote)
                                .foregroundColor(MFColor.textSecondary)
                                .monospacedDigit()
                        }
                    }
                }

                section("Amount to log") {
                    MFStepper(
                        value: $draft.gramsToLog,
                        step: 10,
                        range: 1...10_000,
                        unit: "g",
                        label: "Amount"
                    )
                    .frame(maxWidth: .infinity, alignment: .center)
                    MFSegmentedControl(
                        options: MealSlot.allCases,
                        selection: $draft.mealSlot
                    ) { $0.displayName }
                }

                section("Nutrition per 100 g") {
                    LazyVGrid(
                        columns: [GridItem(.flexible()), GridItem(.flexible())],
                        spacing: MFSpacing.md
                    ) {
                        ForEach(headlineKeys, id: \.self) { key in
                            MFTextField(
                                key.displayName,
                                placeholder: "0",
                                text: nutrientBinding(key),
                                keyboard: .decimalPad
                            )
                        }
                    }
                    DisclosureGroup(isExpanded: $showMicros) {
                        LazyVGrid(
                            columns: [GridItem(.flexible()), GridItem(.flexible())],
                            spacing: MFSpacing.md
                        ) {
                            ForEach(microKeys, id: \.self) { key in
                                MFTextField(
                                    "\(key.displayName) (\(key.unit))",
                                    placeholder: "0",
                                    text: nutrientBinding(key),
                                    keyboard: .decimalPad
                                )
                            }
                        }
                        .padding(.top, MFSpacing.sm)
                    } label: {
                        Text("More nutrients")
                            .font(MFFont.subheadline.weight(.semibold))
                            .foregroundColor(MFColor.accent)
                    }
                }

                VStack(spacing: MFSpacing.md) {
                    MFButton(
                        "Log food",
                        style: .primary,
                        icon: "plus",
                        isLoading: isSaving,
                        action: saveAndLog
                    )
                    .disabled(!draft.isValid || isSaving)
                    MFButton(
                        "Save without logging",
                        style: .secondary,
                        size: .medium,
                        isLoading: false,
                        action: saveOnly
                    )
                    .disabled(!draft.isValid || isSaving)
                }
                .padding(.top, MFSpacing.sm)
            }
            .padding(MFSpacing.lg)
        }
        .background(MFColor.background)
        .navigationTitle("Review food")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: Sections

    private var headlineKeys: [NutrientKey] {
        [.calories, .protein, .fat, .carbs]
    }

    private var microKeys: [NutrientKey] {
        NutrientKey.allCases.filter { !headlineKeys.contains($0) }
    }

    private func section<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: MFSpacing.md) {
            Text(title)
                .font(MFFont.headline)
                .foregroundColor(MFColor.textPrimary)
            content()
        }
    }

    private var macroPreview: some View {
        HStack(spacing: MFSpacing.lg) {
            HStack(spacing: MFSpacing.xs) {
                MFFlameGlyph(size: 16)
                Text(MFFormat.kcal(draft.scaledCalories))
                    .font(MFFont.bodyBold)
                    .monospacedDigit()
                    .foregroundColor(MFColor.textPrimary)
            }
            previewStat(letter: "P", color: MFColor.protein, value: draft.scaledProtein)
            previewStat(letter: "F", color: MFColor.fat, value: draft.scaledFat)
            previewStat(letter: "C", color: MFColor.carbs, value: draft.scaledCarbs)
            Spacer()
            Text("for \(MFFormat.grams(draft.gramsToLog)) g")
                .font(MFFont.caption)
                .foregroundColor(MFColor.textSecondary)
        }
        .padding(MFSpacing.md)
        .background(MFColor.surfaceSunken)
        .clipShape(RoundedRectangle(cornerRadius: MFRadii.md))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(MFFormat.kcal(draft.scaledCalories)) calories, "
                + "\(MFFormat.grams(draft.scaledProtein)) grams protein, "
                + "\(MFFormat.grams(draft.scaledFat)) grams fat, "
                + "\(MFFormat.grams(draft.scaledCarbs)) grams carbs"
        )
    }

    private func previewStat(letter: String, color: Color, value: Double) -> some View {
        HStack(spacing: MFSpacing.xs) {
            Text(letter)
                .font(MFFont.caption.weight(.bold))
                .foregroundColor(.white)
                .frame(width: 18, height: 18)
                .background(color)
                .clipShape(Circle())
                .accessibilityHidden(true)
            Text(MFFormat.grams(value))
                .font(MFFont.bodyBold)
                .monospacedDigit()
                .foregroundColor(MFColor.textPrimary)
        }
    }

    // MARK: Bindings

    /// String adapter over a Double so `MFTextField` can edit numbers.
    private func numberBinding(
        get: @escaping () -> Double,
        set: @escaping (Double) -> Void
    ) -> Binding<String> {
        Binding(
            get: {
                let value = get()
                return value.truncatingRemainder(dividingBy: 1) == 0
                    ? String(Int(value))
                    : String(format: "%.1f", value)
            },
            set: { text in
                let cleaned = text
                    .replacingOccurrences(of: ",", with: ".")
                    .trimmingCharacters(in: .whitespaces)
                if let parsed = Double(cleaned) {
                    set(max(0, parsed))
                } else if cleaned.isEmpty {
                    set(0)
                }
            }
        )
    }

    private func nutrientBinding(_ key: NutrientKey) -> Binding<String> {
        numberBinding(
            get: { draft.wrappedValue.nutrientsPer100g[key] ?? 0 },
            set: { draft.wrappedValue.nutrientsPer100g[key] = $0 }
        )
    }

    // MARK: Actions

    private func saveAndLog() {
        runSave { snapshot in
            try await MainActor.run {
                try snapshot.saveAndLog(using: deps)
                deps.noteFoodLogged()
            }
        }
    }

    private func saveOnly() {
        runSave { snapshot in
            try await MainActor.run { try snapshot.saveFood(using: deps) }
        }
    }

    private func runSave(_ work: @escaping (CaptureDraft) async throws -> Void) {
        errorMessage = nil
        let snapshot = draft.wrappedValue
        guard snapshot.isValid else {
            errorMessage = "Give the food a name and a valid amount first."
            return
        }
        isSaving = true
        Task {
            do {
                try await work(snapshot)
                await MainActor.run { onDone() }
            } catch {
                await MainActor.run {
                    isSaving = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

// (No canvas preview: the editor needs live repository dependencies,
// which are injected by AppShell at runtime.)
