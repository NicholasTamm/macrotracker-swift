import SwiftUI
import DesignSystem
import FoodLogFeature
import CaptureFeature

// MARK: - QuickLogSheet

/// Sheet presented by the center (+) tab action.
///
/// Issue #12 integration: every row now routes to a real destination with
/// live repositories —
/// - Search foods → `FoodLogFeature.FoodSearchView` (selecting a result logs
///   it at its default serving and closes the sheet; the full editor path
///   lives on the Food Log tab)
/// - Quick add → `FoodLogFeature.QuickAddView`
/// - Everything else → `CaptureFeature.CaptureMenuView(deps:)` with live
///   repos (barcode, label OCR, photo, voice, recipe import).
///
/// Capture flows log through `LogRepository` themselves; the sheet publishes
/// a fresh widget/watch snapshot on dismiss so those surfaces stay current.
public struct QuickLogSheet: View {
    let services: AppServices

    @Environment(\.dismiss) private var dismiss
    @State private var flowSheet: QuickLogFlowSheet?

    public init(services: AppServices) {
        self.services = services
    }

    private var captureDeps: CaptureDependencies {
        CaptureDependencies(
            foods: services.store.foods,
            search: services.store.foodSearch,
            log: services.store.logs,
            onFoodLogged: { services.noteFoodLogged() }
        )
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                fastLogSection
                Divider()
                    .padding(.horizontal, MFSpacing.lg)
                CaptureMenuView(deps: captureDeps)
            }
            .background(MFColor.background)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .sheet(item: $flowSheet) { sheet in
            flowSheetView(for: sheet)
        }
        .onDisappear {
            // Capture flows log via the repos directly; refresh the
            // widget/watch snapshot so it reflects anything logged here.
            services.publishSnapshot()
        }
    }

    // MARK: Fast rows

    private var fastLogSection: some View {
        VStack(alignment: .leading, spacing: MFSpacing.sm) {
            Text("Log")
                .font(MFFont.caption.weight(.semibold))
                .foregroundColor(MFColor.textSecondary)
                .textCase(.uppercase)
                .padding(.horizontal, MFSpacing.lg)
            VStack(spacing: 0) {
                fastRow(
                    icon: "magnifyingglass",
                    tint: MFColor.accent,
                    title: "Search foods",
                    subtitle: "Food database, recents, and favorites"
                ) { flowSheet = .search }
                Divider().padding(.leading, 60)
                fastRow(
                    icon: "wand.and.stars",
                    tint: MFColor.calories,
                    title: "Quick add",
                    subtitle: "Calories and macros by hand"
                ) { flowSheet = .quickAdd }
            }
            .background(MFColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: MFRadii.md))
            .padding(.horizontal, MFSpacing.lg)
            .padding(.bottom, MFSpacing.md)
        }
        .padding(.top, MFSpacing.md)
    }

    private func fastRow(
        icon: String,
        tint: Color,
        title: String,
        subtitle: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: MFSpacing.md) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(tint)
                    .clipShape(RoundedRectangle(cornerRadius: MFRadii.sm))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(MFFont.body)
                        .foregroundColor(MFColor.textPrimary)
                    Text(subtitle)
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
        .accessibilityLabel(title)
    }

    // MARK: Flow sheets

    @ViewBuilder
    private func flowSheetView(for sheet: QuickLogFlowSheet) -> some View {
        switch sheet {
        case .search:
            FoodSearchView(
                searchService: services.store.foodSearch,
                foods: services.store.foods,
                onSelectFood: { food in
                    // Fast path: log at the food's default serving.
                    try? services.store.logs.logFood(
                        food,
                        grams: food.servingSizeGrams,
                        source: .manualSearch
                    )
                    services.noteFoodLogged()
                    flowSheet = nil
                    dismiss()
                },
                onQuickAdd: { replaceFlowSheet(with: .quickAdd) },
                onCreateCustomFood: { replaceFlowSheet(with: .customFood) },
                onCreateRecipe: { replaceFlowSheet(with: .recipe) }
            )
        case .quickAdd:
            QuickAddView { calories, protein, fat, carbs, mealSlot in
                try? services.store.logs.quickAdd(
                    calories: calories,
                    proteinGrams: protein,
                    fatGrams: fat,
                    carbsGrams: carbs,
                    mealSlot: mealSlot
                )
                services.noteFoodLogged()
                flowSheet = nil
                dismiss()
            }
        case .customFood:
            CustomFoodEditorView(food: nil, foods: services.store.foods) { _ in
                flowSheet = nil
            }
        case .recipe:
            RecipeBuilderView(
                recipe: nil,
                foods: services.store.foods,
                searchService: services.store.foodSearch
            ) { _ in
                flowSheet = nil
            }
        }
    }

    /// SwiftUI's `.sheet(item:)` doesn't reliably swap sheets in place, so
    /// the replacement is deferred until the dismissal lands.
    private func replaceFlowSheet(with sheet: QuickLogFlowSheet) {
        flowSheet = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            flowSheet = sheet
        }
    }
}

private enum QuickLogFlowSheet: Identifiable {
    case search
    case quickAdd
    case customFood
    case recipe

    var id: String {
        switch self {
        case .search: return "search"
        case .quickAdd: return "quickAdd"
        case .customFood: return "customFood"
        case .recipe: return "recipe"
        }
    }
}

#Preview("Quick log") {
    @MainActor
    struct Demo: View {
        var body: some View {
            if let services = try? AppServices(store: DataStore(inMemory: true, seed: false)) {
                QuickLogSheet(services: services)
                    .mfThemed()
            } else {
                Text("Preview unavailable")
            }
        }
    }
    return Demo()
}
