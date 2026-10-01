import SwiftUI
import DesignSystem
import DataLayer

// MARK: - PlateSheetView

/// "Your Plate": stage multiple foods, review the macro header and the
/// Calories & Macros cards (Plate/Day scope), then log everything at once.
///
/// Macro letters trail the values in the plate header ("56 / 52 F") —
/// see `MFMacroBadgePosition`.
public struct PlateSheetView: View {
    @Binding var items: [PlateItem]
    private let goals: MFDayMacroGoals
    private let dayTotals: MFDayTotals
    @State private var scope: PlateScope = .plate
    @Environment(\.dismiss) private var dismiss

    private let onLogPlate: ([PlateItem]) -> Void
    private let onSearch: () -> Void
    private let onQuickAdd: () -> Void
    private let onLibrary: () -> Void
    private let onScan: () -> Void

    public init(
        items: Binding<[PlateItem]>,
        goals: MFDayMacroGoals,
        dayTotals: MFDayTotals,
        onLogPlate: @escaping ([PlateItem]) -> Void,
        onSearch: @escaping () -> Void = {},
        onQuickAdd: @escaping () -> Void = {},
        onLibrary: @escaping () -> Void = {},
        onScan: @escaping () -> Void = {}
    ) {
        self._items = items
        self.goals = goals
        self.dayTotals = dayTotals
        self.onLogPlate = onLogPlate
        self.onSearch = onSearch
        self.onQuickAdd = onQuickAdd
        self.onLibrary = onLibrary
        self.onScan = onScan
    }

    private enum PlateScope: String, CaseIterable {
        case plate = "Plate"
        case day = "Day"
    }

    private var plateTotals: MFDayTotals {
        var totals: [NutrientKey: Double] = [:]
        for item in items {
            for (key, value) in item.nutrients { totals[key, default: 0] += value }
        }
        return MFDayTotals(entryCount: items.count, totals: totals)
    }

    /// The values the stat cards show, depending on the Plate/Day scope.
    private var scopedTotals: MFDayTotals {
        scope == .plate ? plateTotals : plateTotals + dayTotals
    }

    private var timeLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h a"
        return formatter.string(from: Date())
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: MFSpacing.lg) {
                    MFPlateMacroHeader(
                        time: timeLabel,
                        kcalEaten: scopedTotals.calories,
                        kcalTarget: goals.calories,
                        proteinEaten: scopedTotals.protein,
                        proteinTarget: goals.protein,
                        fatEaten: scopedTotals.fat,
                        fatTarget: goals.fat,
                        carbsEaten: scopedTotals.carbs,
                        carbsTarget: goals.carbs,
                        plateCount: items.count,
                        onClose: { dismiss() },
                        onTimeTap: {}
                    )

                    Text("Your Plate")
                        .font(MFFont.title2)
                        .foregroundColor(MFColor.textPrimary)

                    if items.isEmpty {
                        emptyPlate
                    } else {
                        VStack(spacing: MFSpacing.sm) {
                            ForEach(items) { item in
                                plateRow(for: item)
                            }
                        }
                    }

                    HStack {
                        Text("Calories & Macros")
                            .font(MFFont.title3)
                            .foregroundColor(MFColor.textPrimary)
                        Spacer()
                        MFSegmentedControl(
                            options: PlateScope.allCases,
                            selection: $scope,
                            titleFor: { $0.rawValue }
                        )
                        .frame(width: 160)
                    }

                    LazyVGrid(
                        columns: [GridItem(.flexible()), GridItem(.flexible())],
                        spacing: MFSpacing.sm
                    ) {
                        MFMacroStatCard(
                            title: "Calories",
                            subtitle: "\(MFFormat.kcal(scopedTotals.calories)) kcal in \(scope.rawValue.lowercased())",
                            value: scopedTotals.calories, target: goals.calories, color: MFColor.calories
                        )
                        MFMacroStatCard(
                            title: "Protein",
                            subtitle: "\(MFFormat.grams(scopedTotals.protein)) g in \(scope.rawValue.lowercased())",
                            value: scopedTotals.protein, target: goals.protein, color: MFColor.protein
                        )
                        MFMacroStatCard(
                            title: "Fat",
                            subtitle: "\(MFFormat.grams(scopedTotals.fat)) g in \(scope.rawValue.lowercased())",
                            value: scopedTotals.fat, target: goals.fat, color: MFColor.fat
                        )
                        MFMacroStatCard(
                            title: "Carbs",
                            subtitle: "\(MFFormat.grams(scopedTotals.carbs)) g in \(scope.rawValue.lowercased())",
                            value: scopedTotals.carbs, target: goals.carbs, color: MFColor.carbs
                        )
                    }

                    HStack {
                        Spacer()
                        MFButton("Log Foods", style: .primary, size: .medium) {
                            onLogPlate(items)
                        }
                        .frame(width: 170)
                        .disabled(items.isEmpty)
                    }

                    MFPlateActionBar { action in
                        switch action {
                        case .scan: onScan()
                        case .search: onSearch()
                        case .quickAdd: onQuickAdd()
                        case .library: onLibrary()
                        }
                    }
                }
                .padding()
            }
            .background(MFColor.background)
            .navigationTitle("Your Plate")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private var emptyPlate: some View {
        VStack(spacing: MFSpacing.md) {
            Text("Your plate is empty")
                .font(MFFont.headline)
                .foregroundColor(MFColor.textPrimary)
            Text("Search for foods or quick-add macros to start building this meal.")
                .font(MFFont.subheadline)
                .foregroundColor(MFColor.textSecondary)
                .multilineTextAlignment(.center)
            MFButton("Search foods", style: .secondary, size: .medium, action: onSearch)
                .frame(width: 200)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, MFSpacing.xl)
    }

    private func plateRow(for item: PlateItem) -> some View {
        let nutrients = item.nutrients
        return MFPlateFoodRow(
            name: item.food.displayName,
            openmojiHex: MFFoodIconMapper.hex(forName: item.food.name) ?? MFFoodIconAsset.bread,
            kcal: nutrients[.calories] ?? 0,
            protein: nutrients[.protein] ?? 0,
            fat: nutrients[.fat] ?? 0,
            carbs: nutrients[.carbs] ?? 0,
            gramsText: "\(MFFormat.grams(item.grams)) g",
            servingAmount: servingAmountText(for: item),
            servingUnit: servingUnitText(for: item)
        )
        .contextMenu {
            Button("Remove", role: .destructive) {
                items.removeAll { $0.id == item.id }
            }
        }
        .accessibilityLabel("\(item.food.displayName)")
    }

    private func servingAmountText(for item: PlateItem) -> String {
        guard item.food.servingSizeGrams > 0 else { return MFFormat.grams(item.grams) }
        return MFFormat.grams(item.grams / item.food.servingSizeGrams)
    }

    private func servingUnitText(for item: PlateItem) -> String {
        let description = item.food.servingDescription
        if description.isEmpty { return "srv" }
        return String(description.prefix(18))
    }
}
