import SwiftUI

// MARK: - MFFoodIconAsset

/// OpenMoji hex codes for the bundled food artwork used by ``MFFoodIcon``
/// and ``MFFoodThumbnail``.
///
/// Artwork: OpenMoji (https://openmoji.org), licensed CC BY-SA 4.0
/// (https://creativecommons.org/licenses/by-sa/4.0/). See
/// `app/Scripts/fetch_food_icons.sh` for the download pipeline and
/// attribution requirements. Asset catalog names are
/// `"openmoji-<HEX>"`, e.g. `"openmoji-1F357"`.
public enum MFFoodIconAsset {
    public static let chickenLeg = "1F357"
    public static let carrot = "1F955"
    public static let bread = "1F35E"
    public static let potato = "1F954"
    public static let olive = "1FAD2"
    public static let butter = "1F9C8"
    public static let friedEgg = "1F373"
    public static let coffee = "2615"
    public static let avocado = "1F951"
    public static let tomato = "1F345"
    public static let blueberries = "1FAD0"
    public static let strawberry = "1F353"
}

// MARK: - MFPlateMacroHeader

/// "Your Plate" sheet header: close button, time pill, 2×2 macro mini-bar
/// grid (flame + calories, then F / P / C with trailing letters and colored
/// bars — matching the real plate sheet 1:1), and the plate "+N" icon.
public struct MFPlateMacroHeader: View {
    private let time: String
    private let kcalEaten: Double
    private let kcalTarget: Double
    private let proteinEaten: Double
    private let proteinTarget: Double
    private let fatEaten: Double
    private let fatTarget: Double
    private let carbsEaten: Double
    private let carbsTarget: Double
    private let plateCount: Int
    private let plateIconHex: String
    private let onClose: () -> Void
    private let onTimeTap: () -> Void

    public init(
        time: String,
        kcalEaten: Double,
        kcalTarget: Double,
        proteinEaten: Double,
        proteinTarget: Double,
        fatEaten: Double,
        fatTarget: Double,
        carbsEaten: Double,
        carbsTarget: Double,
        plateCount: Int,
        plateIconHex: String = MFFoodIconAsset.butter,
        onClose: @escaping () -> Void,
        onTimeTap: @escaping () -> Void
    ) {
        self.time = time
        self.kcalEaten = kcalEaten
        self.kcalTarget = kcalTarget
        self.proteinEaten = proteinEaten
        self.proteinTarget = proteinTarget
        self.fatEaten = fatEaten
        self.fatTarget = fatTarget
        self.carbsEaten = carbsEaten
        self.carbsTarget = carbsTarget
        self.plateCount = plateCount
        self.plateIconHex = plateIconHex
        self.onClose = onClose
        self.onTimeTap = onTimeTap
    }

    public var body: some View {
        HStack(spacing: MFSpacing.sm) {
            MFIconButton(icon: "xmark", label: "Close plate") { onClose() }

            Button(action: onTimeTap) {
                Text(time)
                    .font(MFFont.bodyBold)
                    .foregroundColor(MFColor.textPrimary)
                    .padding(.horizontal, MFSpacing.lg)
                    .padding(.vertical, MFSpacing.md)
                    .background(MFColor.surfaceSunken)
                    .clipShape(Capsule())
            }
            .accessibilityLabel("Log time, \(time)")

            // 2×2 macro grid: calories | fat / protein | carbs,
            // letters trail the macro values, bars in macro colors.
            VStack(spacing: MFSpacing.xs) {
                HStack(spacing: MFSpacing.md) {
                    MFMacroMiniBar(eaten: kcalEaten, target: kcalTarget, color: MFColor.calories, badge: .flame, isKcal: true)
                    MFMacroMiniBar(eaten: fatEaten, target: fatTarget, color: MFColor.fat, badge: .letter("F"))
                }
                HStack(spacing: MFSpacing.md) {
                    MFMacroMiniBar(eaten: proteinEaten, target: proteinTarget, color: MFColor.protein, badge: .letter("P"))
                    MFMacroMiniBar(eaten: carbsEaten, target: carbsTarget, color: MFColor.carbs, badge: .letter("C"))
                }
            }

            HStack(spacing: MFSpacing.xs) {
                MFFoodIcon(openmojiHex: plateIconHex)
                    .frame(width: 32, height: 32)
                Text("+\(plateCount)")
                    .font(MFFont.bodyBold)
                    .foregroundColor(MFColor.textPrimary)
            }
            .padding(.horizontal, MFSpacing.md)
            .padding(.vertical, MFSpacing.sm)
            .background(MFColor.surfaceSunken)
            .clipShape(Capsule())
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(plateCount) foods on plate")
        }
    }
}

// MARK: - MFPlateFoodRow

/// A food row inside the "Your Plate" sheet: circular OpenMoji icon, name,
/// flame + P/F/C macro summary line, and the gray serving box on the right.
public struct MFPlateFoodRow: View {
    private let name: String
    private let openmojiHex: String
    private let kcal: Double
    private let protein: Double
    private let fat: Double
    private let carbs: Double
    private let gramsText: String
    private let servingAmount: String
    private let servingUnit: String

    public init(
        name: String,
        openmojiHex: String,
        kcal: Double,
        protein: Double,
        fat: Double,
        carbs: Double,
        gramsText: String,
        servingAmount: String,
        servingUnit: String
    ) {
        self.name = name
        self.openmojiHex = openmojiHex
        self.kcal = kcal
        self.protein = protein
        self.fat = fat
        self.carbs = carbs
        self.gramsText = gramsText
        self.servingAmount = servingAmount
        self.servingUnit = servingUnit
    }

    public var body: some View {
        HStack(spacing: MFSpacing.md) {
            MFFoodIcon(openmojiHex: openmojiHex)
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(MFFont.bodyBold)
                    .foregroundColor(MFColor.textPrimary)
                    .lineLimit(1)
                // Macro summary: "122 flame 23P 3F 0C • 113.33 g"
                // (zeros shown, matching the real rows).
                Text("\(MFFormat.kcal(kcal)) \(MFFlameGlyph(size: 11)) \(MFFormat.grams(protein))P \(MFFormat.grams(fat))F \(MFFormat.grams(carbs))C • \(gramsText)")
                    .font(MFFont.caption)
                    .monospacedDigit()
                    .foregroundColor(MFColor.textSecondary)
                    .lineLimit(1)
            }
            Spacer()
            MFServingBox(amount: servingAmount, unit: servingUnit)
        }
        .padding(MFSpacing.md)
        .background(MFColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: MFRadii.lg))
        .mfCardShadow()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(name), \(MFFormat.kcal(kcal)) calories")
    }
}

// MARK: - MFMacroStatCard

/// "Calories & Macros" stat card: title, "X in plate" subtitle, and a
/// target-ticked progress bar in the macro color.
public struct MFMacroStatCard: View {
    private let title: String
    private let subtitle: String
    private let value: Double
    private let target: Double
    private let color: Color

    public init(title: String, subtitle: String, value: Double, target: Double, color: Color) {
        self.title = title
        self.subtitle = subtitle
        self.value = value
        self.target = target
        self.color = color
    }

    private var progress: Double {
        guard target > 0 else { return 0 }
        return min(value / target, 1)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: MFSpacing.sm) {
            Text(title)
                .font(MFFont.headline)
                .foregroundColor(MFColor.textPrimary)
            Text(subtitle)
                .font(MFFont.subheadline)
                .foregroundColor(MFColor.textSecondary)
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(MFColor.ringTrack)
                    Capsule()
                        .fill(color)
                        .frame(width: geometry.size.width * CGFloat(progress))
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(MFColor.textPrimary)
                        .frame(width: 3, height: 12)
                        .offset(x: geometry.size.width - 1.5)
                        .accessibilityHidden(true)
                }
            }
            .frame(height: 6)
            .accessibilityHidden(true)
        }
        .padding(MFSpacing.md)
        .background(MFColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: MFRadii.lg))
        .mfCardShadow()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(subtitle)")
    }
}

// MARK: - MFPlateActionBar

/// Bottom action ribbon of the logging sheet: Scan / Search / Quick Add /
/// Library.
public struct MFPlateActionBar: View {
    public enum Action: String, CaseIterable {
        case scan = "Scan"
        case search = "Search"
        case quickAdd = "Quick Add"
        case library = "Library"
    }

    private let onAction: (Action) -> Void

    public init(onAction: @escaping (Action) -> Void) {
        self.onAction = onAction
    }

    private func icon(for action: Action) -> String {
        switch action {
        case .scan: "barcode.viewfinder"
        case .search: "magnifyingglass"
        case .quickAdd: "wand.and.stars"
        case .library: "books.vertical"
        }
    }

    public var body: some View {
        HStack(spacing: MFSpacing.lg) {
            ForEach(Action.allCases, id: \.self) { action in
                Button {
                    onAction(action)
                } label: {
                    HStack(spacing: MFSpacing.xs) {
                        Image(systemName: icon(for: action))
                            .font(.body)
                        Text(action.rawValue)
                            .font(MFFont.subheadline.weight(.semibold))
                    }
                    .foregroundColor(MFColor.textPrimary)
                }
                .accessibilityLabel(action.rawValue)
            }
        }
        .padding(.vertical, MFSpacing.md)
    }
}

#Preview("Plate sheet") {
    struct Demo: View {
        @State private var scope = "Plate"

        var body: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: MFSpacing.lg) {
                    MFPlateMacroHeader(
                        time: "7 PM",
                        kcalEaten: 1431, kcalTarget: 1573,
                        proteinEaten: 93, proteinTarget: 106,
                        fatEaten: 56, fatTarget: 52,
                        carbsEaten: 140, carbsTarget: 168,
                        plateCount: 5,
                        onClose: {}, onTimeTap: {}
                    )

                    Text("Your Plate")
                        .font(MFFont.title2)
                        .foregroundColor(MFColor.textPrimary)

                    VStack(spacing: MFSpacing.sm) {
                        MFPlateFoodRow(name: "Chicken Breast Boneless Skinless", openmojiHex: MFFoodIconAsset.chickenLeg, kcal: 122, protein: 23, fat: 3, carbs: 0, gramsText: "113.33 g", servingAmount: "4", servingUnit: "oz")
                        MFPlateFoodRow(name: "Carrots, Cooked From Fresh", openmojiHex: MFFoodIconAsset.carrot, kcal: 23, protein: 1, fat: 0, carbs: 5, gramsText: "66 g", servingAmount: "1", servingUnit: "large - 7 1/4\"")
                        MFPlateFoodRow(name: "Homemade Dinner Rolls", openmojiHex: MFFoodIconAsset.bread, kcal: 90, protein: 2, fat: 2, carbs: 15, gramsText: "28.35 g", servingAmount: "1", servingUnit: "oz")
                        MFPlateFoodRow(name: "Baked Potato With Skin And Salt", openmojiHex: MFFoodIconAsset.potato, kcal: 278, protein: 7, fat: 0, carbs: 63, gramsText: "299 g", servingAmount: "1", servingUnit: "potato large")
                        MFPlateFoodRow(name: "Olive Oil", openmojiHex: MFFoodIconAsset.olive, kcal: 119, protein: 0, fat: 14, carbs: 0, gramsText: "13.5 g", servingAmount: "1", servingUnit: "tbsp")
                        MFPlateFoodRow(name: "Butter, Whipped, Salted", openmojiHex: MFFoodIconAsset.butter, kcal: 68, protein: 0, fat: 7, carbs: 0, gramsText: "9.44 g", servingAmount: "1", servingUnit: "tbsp")
                    }

                    HStack {
                        Text("Calories & Macros")
                            .font(MFFont.title3)
                            .foregroundColor(MFColor.textPrimary)
                        Spacer()
                        MFSegmentedControl(options: ["Plate", "Day"], selection: $scope) { $0 }
                            .frame(width: 160)
                    }

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: MFSpacing.sm) {
                        MFMacroStatCard(title: "Calories", subtitle: "700 kcal in plate", value: 700, target: 1573, color: MFColor.calories)
                        MFMacroStatCard(title: "Protein", subtitle: "33.5 g in plate", value: 33.5, target: 106, color: MFColor.protein)
                        MFMacroStatCard(title: "Fat", subtitle: "22.0 g in plate", value: 22, target: 52, color: MFColor.fat)
                        MFMacroStatCard(title: "Carbs", subtitle: "84.1 g in plate", value: 84.1, target: 168, color: MFColor.carbs)
                    }

                    HStack {
                        Spacer()
                        MFButton("Log Foods", style: .primary, size: .medium) {}
                            .frame(width: 170)
                    }

                    MFPlateActionBar { _ in }
                }
                .padding()
            }
            .background(MFColor.background)
        }
    }
    return Demo()
}
