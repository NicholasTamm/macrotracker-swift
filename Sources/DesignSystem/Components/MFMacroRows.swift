import SwiftUI

// MARK: - MFNutrientProgressRow

/// Single nutrient row: name, eaten/target readout, and a thin progress bar
/// with a target tick mark (as on the real dashboard widgets).
public struct MFNutrientProgressRow: View {
    private let name: String
    private let unit: String
    private let eaten: Double
    private let target: Double
    private let color: Color

    public init(name: String, unit: String, eaten: Double, target: Double, color: Color) {
        self.name = name
        self.unit = unit
        self.eaten = eaten
        self.target = target
        self.color = color
    }

    private var progress: Double {
        guard target > 0 else { return 0 }
        return min(eaten / target, 1)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: MFSpacing.xs) {
            HStack {
                Text(name)
                    .font(MFFont.body)
                    .foregroundColor(MFColor.textPrimary)
                Spacer()
                Text("\(MFFormat.grams(eaten)) / \(MFFormat.grams(target)) \(unit)")
                    .font(MFFont.subheadline)
                    .monospacedDigit()
                    .foregroundColor(MFColor.textSecondary)
            }
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(MFColor.ringTrack)
                    Capsule()
                        .fill(color)
                        .frame(width: geometry.size.width * CGFloat(progress))
                        .animation(.easeOut(duration: 0.4), value: progress)
                    // Target tick.
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(MFColor.textPrimary)
                        .frame(width: 3, height: 10)
                        .offset(x: geometry.size.width - 1.5)
                        .accessibilityHidden(true)
                }
            }
            .frame(height: 6)
            .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(name): \(MFFormat.grams(eaten)) of \(MFFormat.grams(target)) \(unit)")
    }
}

// MARK: - MFMacroTargetEditor

/// Editable daily macro targets with live calorie total.
public struct MFMacroTargetEditor: View {
    @Binding private var protein: Double
    @Binding private var carbs: Double
    @Binding private var fat: Double

    public init(protein: Binding<Double>, carbs: Binding<Double>, fat: Binding<Double>) {
        self._protein = protein
        self._carbs = carbs
        self._fat = fat
    }

    private var totalKcal: Double { protein * 4 + carbs * 4 + fat * 9 }

    public var body: some View {
        VStack(spacing: MFSpacing.md) {
            editorRow(dot: MFColor.protein, name: "Protein", value: $protein)
            editorRow(dot: MFColor.carbs, name: "Carbs", value: $carbs)
            editorRow(dot: MFColor.fat, name: "Fat", value: $fat)
            Divider().background(MFColor.separator)
            HStack {
                Text("Daily calories")
                    .font(MFFont.subheadline)
                    .foregroundColor(MFColor.textSecondary)
                Spacer()
                Text("\(MFFormat.kcal(totalKcal)) kcal")
                    .font(MFFont.statMedium)
                    .monospacedDigit()
                    .foregroundColor(MFColor.textPrimary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Daily calories: \(MFFormat.kcal(totalKcal))")
        }
    }

    private func editorRow(dot: Color, name: String, value: Binding<Double>) -> some View {
        HStack {
            Circle()
                .fill(dot)
                .frame(width: 10, height: 10)
                .accessibilityHidden(true)
            Text(name)
                .font(MFFont.body)
                .foregroundColor(MFColor.textPrimary)
            Spacer()
            MFStepper(value: value, step: 5, range: 0...1000, unit: "g", label: name)
        }
    }
}

// MARK: - MFFoodIcon

/// Circular food icon. Uses OpenMoji food artwork (CC BY-SA 4.0 — see
/// ``MFFoodIconAsset`` and `app/Scripts/fetch_food_icons.sh` for the asset
/// pipeline and attribution) when `openmojiHex` is supplied, rendered from
/// the asset catalog as `openmoji-<HEX>`; falls back to an SF symbol on a
/// soft tinted well when no artwork is bundled yet.
public struct MFFoodIcon: View {
    private let openmojiHex: String?
    private let symbol: String
    private let tint: Color

    public init(openmojiHex: String? = nil, symbol: String = "fork.knife", tint: Color = MFColor.accentSoft) {
        self.openmojiHex = openmojiHex
        self.symbol = symbol
        self.tint = tint
    }

    public var body: some View {
        Group {
            if let hex = openmojiHex {
                Image("openmoji-\(hex)")
                    .resizable()
                    .scaledToFit()
                    .padding(6)
                    .accessibilityHidden(true)
            } else {
                Image(systemName: symbol)
                    .font(.title3)
                    .foregroundColor(MFColor.textSecondary)
                    .accessibilityHidden(true)
            }
        }
        .frame(width: 44, height: 44)
        .background(tint)
        .clipShape(Circle())
    }
}

// MARK: - MFFoodSearchRow

/// A food-database search result card: icon, name, macro summary, and a
/// gray serving box — matching the real "Your Plate" / search rows.
public struct MFFoodSearchRow: View {
    private let name: String
    private let brand: String?
    private let kcal: Double
    private let protein: Double
    private let carbs: Double
    private let fat: Double
    private let servingText: String
    private let unitText: String
    private let isVerified: Bool
    private let openmojiHex: String?
    private let onAdd: () -> Void

    public init(
        name: String,
        brand: String? = nil,
        kcal: Double,
        protein: Double,
        carbs: Double,
        fat: Double,
        servingText: String = "1",
        unitText: String = "serving",
        isVerified: Bool = false,
        openmojiHex: String? = nil,
        onAdd: @escaping () -> Void
    ) {
        self.name = name
        self.brand = brand
        self.kcal = kcal
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.servingText = servingText
        self.unitText = unitText
        self.isVerified = isVerified
        self.openmojiHex = openmojiHex
        self.onAdd = onAdd
    }

    public var body: some View {
        HStack(spacing: MFSpacing.md) {
            MFFoodIcon(openmojiHex: openmojiHex)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: MFSpacing.xs) {
                    Text(name)
                        .font(MFFont.bodyBold)
                        .foregroundColor(MFColor.textPrimary)
                        .lineLimit(1)
                    if isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.caption)
                            .foregroundColor(MFColor.success)
                            .accessibilityLabel("Verified food")
                    }
                }
                if let brand {
                    Text(brand)
                        .font(MFFont.caption)
                        .foregroundColor(MFColor.textSecondary)
                        .lineLimit(1)
                }
                Text("\(MFFormat.kcal(kcal)) kcal · \(MFFormat.grams(protein))P \(MFFormat.grams(carbs))C \(MFFormat.grams(fat))F")
                    .font(MFFont.caption)
                    .monospacedDigit()
                    .foregroundColor(MFColor.textTertiary)
            }
            Spacer()
            MFServingBox(amount: servingText, unit: unitText)
            MFIconButton(icon: "plus", label: "Add \(name)") { onAdd() }
        }
        .padding(MFSpacing.md)
        .background(MFColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: MFRadii.lg))
        .mfCardShadow()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(name), \(brand ?? ""), \(MFFormat.kcal(kcal)) calories")
        .accessibilityHint("Double tap the add button to log this food")
    }
}

// MARK: - MFFoodLogEntryRow

/// A logged food entry: icon, name, serving detail, macro summary.
public struct MFFoodLogEntryRow: View {
    private let name: String
    private let detail: String
    private let kcal: Double
    private let protein: Double
    private let carbs: Double
    private let fat: Double

    public init(name: String, detail: String, kcal: Double, protein: Double, carbs: Double, fat: Double) {
        self.name = name
        self.detail = detail
        self.kcal = kcal
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
    }

    public var body: some View {
        HStack(spacing: MFSpacing.md) {
            MFFoodIcon()
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(MFFont.body)
                    .foregroundColor(MFColor.textPrimary)
                    .lineLimit(1)
                Text(detail)
                    .font(MFFont.caption)
                    .foregroundColor(MFColor.textSecondary)
                    .lineLimit(1)
                Text("\(MFFormat.kcal(kcal)) kcal · \(MFFormat.grams(protein))P \(MFFormat.grams(carbs))C \(MFFormat.grams(fat))F")
                    .font(MFFont.caption)
                    .monospacedDigit()
                    .foregroundColor(MFColor.textTertiary)
            }
            Spacer()
        }
        .padding(.vertical, MFSpacing.sm)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(name), \(detail), \(MFFormat.kcal(kcal)) calories")
    }
}

// MARK: - MFMealHeader

/// Meal section header with macro totals and an add button.
public struct MFMealHeader: View {
    private let meal: String
    private let kcal: Double
    private let protein: Double
    private let carbs: Double
    private let fat: Double
    private let onAdd: () -> Void

    public init(meal: String, kcal: Double, protein: Double, carbs: Double, fat: Double, onAdd: @escaping () -> Void) {
        self.meal = meal
        self.kcal = kcal
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.onAdd = onAdd
    }

    public var body: some View {
        HStack(spacing: MFSpacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                Text(meal)
                    .font(MFFont.headline)
                    .foregroundColor(MFColor.textPrimary)
                Text("\(MFFormat.kcal(kcal)) kcal · \(MFFormat.grams(protein))P \(MFFormat.grams(carbs))C \(MFFormat.grams(fat))F")
                    .font(MFFont.caption)
                    .monospacedDigit()
                    .foregroundColor(MFColor.textSecondary)
            }
            Spacer()
            MFIconButton(icon: "plus", label: "Add food to \(meal)") { onAdd() }
        }
        .padding(.vertical, MFSpacing.xs)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(meal), \(MFFormat.kcal(kcal)) calories")
    }
}

// MARK: - MFMacroLetterBadge

/// Small P / F / C letter badge used in timeline totals.
public struct MFMacroLetterBadge: View {
    private let letter: String
    private let color: Color

    public init(_ letter: String, color: Color) {
        self.letter = letter
        self.color = color
    }

    public var body: some View {
        Text(letter)
            .font(.caption2.weight(.bold))
            .foregroundColor(.white)
            .frame(width: 20, height: 20)
            .background(color)
            .clipShape(Circle())
            .accessibilityHidden(true)
    }
}

// MARK: - MFTimeBlockHeader

/// Timeline time-block header: time pill, "+" button, and block totals with
/// letter badges — matching the real food-log timeline.
public struct MFTimeBlockHeader: View {
    private let time: String
    private let isNow: Bool
    private let kcal: Double
    private let protein: Double
    private let fat: Double
    private let carbs: Double
    private let onAdd: () -> Void

    public init(
        time: String,
        isNow: Bool = false,
        kcal: Double,
        protein: Double,
        fat: Double,
        carbs: Double,
        onAdd: @escaping () -> Void
    ) {
        self.time = time
        self.isNow = isNow
        self.kcal = kcal
        self.protein = protein
        self.fat = fat
        self.carbs = carbs
        self.onAdd = onAdd
    }

    public var body: some View {
        HStack(spacing: MFSpacing.sm) {
            HStack(spacing: MFSpacing.xs) {
                Text(time)
                    .font(MFFont.subheadline.weight(.semibold))
                    .foregroundColor(MFColor.textPrimary)
                if isNow {
                    Circle()
                        .fill(MFColor.calories)
                        .frame(width: 6, height: 6)
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, MFSpacing.md)
            .padding(.vertical, MFSpacing.sm)
            .background(MFColor.surfaceSunken)
            .clipShape(Capsule())

            MFIconButton(icon: "plus", label: "Log food at \(time)") { onAdd() }

            Spacer()

            HStack(spacing: MFSpacing.md) {
                HStack(spacing: MFSpacing.xs) {
                    Text(MFFormat.kcal(kcal))
                        .font(MFFont.statSmall)
                        .monospacedDigit()
                        .foregroundColor(MFColor.textPrimary)
                    MFFlameGlyph(size: 11)
                }
                HStack(spacing: MFSpacing.xs) {
                    Text(MFFormat.grams(protein))
                        .font(MFFont.statSmall).monospacedDigit()
                        .foregroundColor(MFColor.textPrimary)
                    MFMacroLetterBadge("P", color: MFColor.protein)
                }
                HStack(spacing: MFSpacing.xs) {
                    Text(MFFormat.grams(fat))
                        .font(MFFont.statSmall).monospacedDigit()
                        .foregroundColor(MFColor.textPrimary)
                    MFMacroLetterBadge("F", color: MFColor.fat)
                }
                HStack(spacing: MFSpacing.xs) {
                    Text(MFFormat.grams(carbs))
                        .font(MFFont.statSmall).monospacedDigit()
                        .foregroundColor(MFColor.textPrimary)
                    MFMacroLetterBadge("C", color: MFColor.carbs)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(time), \(MFFormat.kcal(kcal)) calories")
    }
}

// MARK: - MFFoodThumbnail

/// Circular food-photo thumbnail used in the timeline. Uses OpenMoji food
/// artwork (CC BY-SA 4.0 — see ``MFFoodIconAsset``) when `openmojiHex` is
/// supplied, falling back to an SF symbol.
public struct MFFoodThumbnail: View {
    private let openmojiHex: String?
    private let symbol: String

    public init(openmojiHex: String? = nil, symbol: String = "fork.knife") {
        self.openmojiHex = openmojiHex
        self.symbol = symbol
    }

    public var body: some View {
        Group {
            if let hex = openmojiHex {
                Image("openmoji-\(hex)")
                    .resizable()
                    .scaledToFit()
                    .padding(8)
                    .accessibilityHidden(true)
            } else {
                Image(systemName: symbol)
                    .font(.title3)
                    .foregroundColor(MFColor.textTertiary)
                    .accessibilityHidden(true)
            }
        }
        .frame(width: 56, height: 56)
        .background(MFColor.surfaceSunken)
        .clipShape(Circle())
        .overlay(Circle().stroke(MFColor.separator, lineWidth: 1))
    }
}

// MARK: - MFDayPill

/// Week-strip day capsule: day letter + date, blue ring when the day has
/// logged food, filled highlight when selected.
public struct MFDayPill: View {
    private let dayLetter: String
    private let dateNumber: String
    private let hasLogged: Bool
    private let isSelected: Bool
    private let action: () -> Void

    public init(dayLetter: String, dateNumber: String, hasLogged: Bool = false, isSelected: Bool = false, action: @escaping () -> Void) {
        self.dayLetter = dayLetter
        self.dateNumber = dateNumber
        self.hasLogged = hasLogged
        self.isSelected = isSelected
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(dayLetter)
                    .font(MFFont.caption)
                    .foregroundColor(isSelected ? MFColor.textOnSelection : MFColor.textSecondary)
                Text(dateNumber)
                    .font(MFFont.bodyBold)
                    .monospacedDigit()
                    .foregroundColor(isSelected ? MFColor.textOnSelection : MFColor.textPrimary)
            }
            .padding(.vertical, MFSpacing.sm)
            .padding(.horizontal, MFSpacing.md)
            .background(isSelected ? MFColor.selectionFill : MFColor.surfaceSunken)
            .clipShape(Capsule())
            .overlay {
                if hasLogged && !isSelected {
                    Capsule().stroke(MFColor.calories, lineWidth: 2)
                }
            }
        }
        .accessibilityLabel("\(dayLetter) \(dateNumber)\(hasLogged ? ", logged" : "")")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - MFMacroBadgePosition

/// Where the ``MFMacroBadge`` sits relative to a mini-bar's value.
///
/// Research against the reference screenshots (2026-09-28):
/// - The food-log timeline's day-totals strip **prefixes** letters —
///   "P 29 / 107", "F 45 / 81", "C 56 / 168"
///   (`ref-timeline-light-micronutrients.png`,
///   `ref-timeline-log.png`, and the palette showcase's collapsing-header
///   demo all agree).
/// - The "Your Plate" sheet header **trails** them —
///   "56 / 52 F", "93 / 106 P", "140 / 168 C"
///   (`ref-your-plate-help.png`).
/// Per-food macro summaries ("23P 3F 0C") trail in both surfaces.
public enum MFMacroBadgePosition {
    case leading
    case trailing
}

// MARK: - MFMacroMiniBar

/// Thin labeled progress bar from the food-log header ("770 / 2446").
public struct MFMacroMiniBar: View {
    private let badge: MFMacroBadge?
    private let badgePosition: MFMacroBadgePosition
    private let eaten: Double
    private let target: Double
    private let color: Color
    private let isKcal: Bool

    public init(
        eaten: Double,
        target: Double,
        color: Color,
        badge: MFMacroBadge? = nil,
        badgePosition: MFMacroBadgePosition = .trailing,
        isKcal: Bool = false
    ) {
        self.eaten = eaten
        self.target = target
        self.color = color
        self.badge = badge
        self.badgePosition = badgePosition
        self.isKcal = isKcal
    }

    private var progress: Double {
        guard target > 0 else { return 0 }
        return min(eaten / target, 1)
    }

    private var valueText: String {
        isKcal
            ? "\(MFFormat.kcal(eaten)) / \(MFFormat.kcal(target))"
            : "\(MFFormat.grams(eaten)) / \(MFFormat.grams(target))"
    }

    private var badgeLabel: String? {
        switch badge {
        case .letter(let letter): return letter
        default: return nil
        }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: MFSpacing.xs) {
                if badgePosition == .leading { badgeView }
                Text(valueText)
                    .font(MFFont.caption.weight(.semibold))
                    .monospacedDigit()
                    .foregroundColor(MFColor.textPrimary)
                if badgePosition == .trailing { badgeView }
            }
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(MFColor.ringTrack)
                    Capsule()
                        .fill(color)
                        .frame(width: geometry.size.width * CGFloat(progress))
                }
            }
            .frame(height: 4)
            .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(valueText)\(badgeLabel.map { " \($0)" } ?? "")")
    }

    @ViewBuilder
    private var badgeView: some View {
        switch badge {
        case .flame:
            MFFlameGlyph(size: 11)
        case .letter(let letter):
            Text(letter)
                .font(MFFont.caption.weight(.semibold))
                .foregroundColor(MFColor.textSecondary)
        case nil:
            EmptyView()
        }
    }
}

// MARK: - MFMacroPill

/// Pastel macro pill from the program grid ("118 P"): soft tinted fill with
/// the macro color's darker text.
public struct MFMacroPill: View {
    private let value: String
    private let color: Color

    public init(value: String, color: Color) {
        self.value = value
        self.color = color
    }

    public var body: some View {
        Text(value)
            .font(MFFont.caption.weight(.semibold))
            .monospacedDigit()
            .foregroundColor(color)
            .padding(.horizontal, MFSpacing.sm)
            .padding(.vertical, MFSpacing.xs)
            .background(color.opacity(0.18))
            .clipShape(Capsule())
            .accessibilityLabel(value)
    }
}

// MARK: - MFServingBox

/// Static gray serving box from food rows ("4 / oz").
public struct MFServingBox: View {
    private let amount: String
    private let unit: String

    public init(amount: String, unit: String) {
        self.amount = amount
        self.unit = unit
    }

    public var body: some View {
        VStack(spacing: 1) {
            Text(amount)
                .font(MFFont.bodyBold)
                .monospacedDigit()
                .foregroundColor(MFColor.textPrimary)
            Text(unit)
                .font(MFFont.caption2)
                .foregroundColor(MFColor.textSecondary)
                .lineLimit(1)
        }
        .frame(width: 72)
        .padding(.vertical, MFSpacing.sm)
        .background(MFColor.surfaceSunken)
        .clipShape(RoundedRectangle(cornerRadius: MFRadii.sm))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(amount) \(unit)")
    }
}

// MARK: - MFServingStepper

/// Serving-amount stepper used when logging a food.
public struct MFServingStepper: View {
    @Binding private var servings: Double
    private let unit: String
    private let step: Double

    public init(servings: Binding<Double>, unit: String = "servings", step: Double = 0.5) {
        self._servings = servings
        self.unit = unit
        self.step = step
    }

    public var body: some View {
        HStack {
            Text("Servings")
                .font(MFFont.body)
                .foregroundColor(MFColor.textPrimary)
            Spacer()
            MFStepper(value: $servings, step: step, range: 0.25...50, unit: unit, label: "Servings")
        }
        .padding(MFSpacing.md)
        .background(MFColor.surfaceSunken)
        .clipShape(RoundedRectangle(cornerRadius: MFRadii.md))
    }
}

#Preview("Macro rows") {
    struct Demo: View {
        @State private var protein = 150.0
        @State private var carbs = 250.0
        @State private var fat = 70.0
        @State private var servings = 1.5

        var body: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: MFSpacing.lg) {
                    MFMacroTargetEditor(protein: $protein, carbs: $carbs, fat: $fat)
                        .mfCard()

                    VStack(alignment: .leading, spacing: MFSpacing.md) {
                        MFNutrientProgressRow(name: "Calories", unit: "kcal", eaten: 1995, target: 2280, color: MFColor.calories)
                        MFNutrientProgressRow(name: "Protein", unit: "g", eaten: 174, target: 150, color: MFColor.protein)
                        MFNutrientProgressRow(name: "Fat", unit: "g", eaten: 70.8, target: 80, color: MFColor.fat)
                        MFNutrientProgressRow(name: "Carbs", unit: "g", eaten: 184.5, target: 250, color: MFColor.carbs)
                        MFNutrientProgressRow(name: "Sodium", unit: "mg", eaten: 2400, target: 2300, color: MFColor.micro)
                    }
                    .mfCard()

                    VStack(spacing: MFSpacing.sm) {
                        MFFoodSearchRow(name: "Chicken breast, grilled", brand: "Common foods", kcal: 165, protein: 31, carbs: 0, fat: 3.6, servingText: "4", unitText: "oz", isVerified: true, openmojiHex: MFFoodIconAsset.chickenLeg, onAdd: {})
                        MFFoodSearchRow(name: "Protein bar", brand: "Example brand", kcal: 210, protein: 20, carbs: 22, fat: 7, servingText: "1", unitText: "bar", openmojiHex: MFFoodIconAsset.bread, onAdd: {})
                    }

                    VStack(alignment: .leading, spacing: MFSpacing.sm) {
                        MFTimeBlockHeader(time: "8 AM", kcal: 381, protein: 10, fat: 23, carbs: 41, onAdd: {})
                        HStack(spacing: MFSpacing.md) {
                            MFFoodThumbnail(openmojiHex: MFFoodIconAsset.coffee)
                            MFFoodThumbnail(openmojiHex: MFFoodIconAsset.avocado)
                            MFFoodThumbnail(openmojiHex: MFFoodIconAsset.tomato)
                            MFFoodThumbnail(openmojiHex: MFFoodIconAsset.bread)
                        }
                        .padding(.leading, MFSpacing.xxl)
                        MFTimeBlockHeader(time: "1 PM", isNow: true, kcal: 305, protein: 18, fat: 21, carbs: 13, onAdd: {})
                    }
                    .mfCard()

                    HStack(spacing: MFSpacing.sm) {
                        MFDayPill(dayLetter: "M", dateNumber: "26", hasLogged: true, action: {})
                        MFDayPill(dayLetter: "T", dateNumber: "27", hasLogged: true, action: {})
                        MFDayPill(dayLetter: "W", dateNumber: "28", hasLogged: true, action: {})
                        MFDayPill(dayLetter: "T", dateNumber: "29", hasLogged: true, action: {})
                        MFDayPill(dayLetter: "F", dateNumber: "30", hasLogged: true, action: {})
                        MFDayPill(dayLetter: "S", dateNumber: "31", hasLogged: true, isSelected: true, action: {})
                        MFDayPill(dayLetter: "S", dateNumber: "1", action: {})
                    }

                    HStack(spacing: MFSpacing.lg) {
                        MFMacroMiniBar(eaten: 770, target: 2446, color: MFColor.calories, badge: .flame, badgePosition: .leading, isKcal: true)
                        MFMacroMiniBar(eaten: 29, target: 107, color: MFColor.protein, badge: .letter("P"), badgePosition: .leading)
                        MFMacroMiniBar(eaten: 45, target: 81, color: MFColor.fat, badge: .letter("F"), badgePosition: .leading)
                        MFMacroMiniBar(eaten: 75, target: 320, color: MFColor.carbs, badge: .letter("C"), badgePosition: .leading)
                    }
                    .mfCard()

                    HStack(spacing: MFSpacing.sm) {
                        MFMacroPill(value: "2050", color: MFColor.calories)
                        MFMacroPill(value: "118 P", color: MFColor.protein)
                        MFMacroPill(value: "69 F", color: MFColor.fat)
                        MFMacroPill(value: "237 C", color: MFColor.carbs)
                    }

                    MFServingStepper(servings: $servings)
                }
                .padding()
            }
            .background(MFColor.background)
        }
    }
    return Demo()
}
