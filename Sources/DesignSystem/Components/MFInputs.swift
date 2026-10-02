import SwiftUI

// MARK: - MFTextField

/// Labeled text field with optional icon and inline error state.
public struct MFTextField: View {
    private let title: String
    private let placeholder: String
    @Binding private var text: String
    private let icon: String?
    private let error: String?
    private let keyboard: UIKeyboardType

    public init(
        _ title: String,
        placeholder: String,
        text: Binding<String>,
        icon: String? = nil,
        error: String? = nil,
        keyboard: UIKeyboardType = .default
    ) {
        self.title = title
        self.placeholder = placeholder
        self._text = text
        self.icon = icon
        self.error = error
        self.keyboard = keyboard
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: MFSpacing.xs) {
            Text(title)
                .font(MFFont.caption)
                .foregroundColor(MFColor.textSecondary)
                .accessibilityHidden(true)

            HStack(spacing: MFSpacing.sm) {
                if let icon {
                    Image(systemName: icon)
                        .foregroundColor(MFColor.textTertiary)
                        .accessibilityHidden(true)
                }
                TextField(placeholder, text: $text)
                    .font(MFFont.body)
                    .foregroundColor(MFColor.textPrimary)
                    .keyboardType(keyboard)
            }
            .padding(MFSpacing.md)
            .background(MFColor.surfaceSunken)
            .clipShape(RoundedRectangle(cornerRadius: MFRadii.md))
            .overlay {
                RoundedRectangle(cornerRadius: MFRadii.md)
                    .stroke(error == nil ? Color.clear : MFColor.danger, lineWidth: 1.5)
            }
            .accessibilityLabel(title)

            if let error {
                Text(error)
                    .font(MFFont.caption)
                    .foregroundColor(MFColor.danger)
            }
        }
    }
}

// MARK: - MFStepper

/// Custom − / + stepper with a centered value readout.
public struct MFStepper: View {
    @Binding private var value: Double
    private let step: Double
    private let range: ClosedRange<Double>
    private let unit: String
    private let label: String

    public init(
        value: Binding<Double>,
        step: Double = 1,
        range: ClosedRange<Double> = 0...10_000,
        unit: String = "",
        label: String = "Value"
    ) {
        self._value = value
        self.step = step
        self.range = range
        self.unit = unit
        self.label = label
    }

    public var body: some View {
        HStack(spacing: MFSpacing.sm) {
            stepperButton(icon: "minus", label: "Decrease \(label)") {
                value = max(range.lowerBound, value - step)
            }
            Text("\(MFFormat.grams(value))\(unit.isEmpty ? "" : " \(unit)")")
                .font(MFFont.bodyBold)
                .monospacedDigit()
                .foregroundColor(MFColor.textPrimary)
                .frame(minWidth: 76)
            stepperButton(icon: "plus", label: "Increase \(label)") {
                value = min(range.upperBound, value + step)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(MFFormat.grams(value)) \(unit)")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: value = min(range.upperBound, value + step)
            case .decrement: value = max(range.lowerBound, value - step)
            @unknown default: break
            }
        }
    }

    private func stepperButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.body.weight(.semibold))
                .foregroundColor(MFColor.textPrimary)
                .frame(width: 32, height: 32)
                .background(MFColor.surfaceSunken)
                .clipShape(Circle())
        }
        .accessibilityHidden(true)
    }
}

// MARK: - MFToggle

/// Labeled switch row.
public struct MFToggle: View {
    private let title: String
    private let subtitle: String?
    @Binding private var isOn: Bool

    public init(_ title: String, subtitle: String? = nil, isOn: Binding<Bool>) {
        self.title = title
        self.subtitle = subtitle
        self._isOn = isOn
    }

    public var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(MFFont.body)
                    .foregroundColor(MFColor.textPrimary)
                if let subtitle {
                    Text(subtitle)
                        .font(MFFont.caption)
                        .foregroundColor(MFColor.textSecondary)
                }
            }
        }
        .tint(MFColor.accent)
    }
}

// MARK: - MFSegmentedControl

/// Pill-style segmented control with a sliding selection indicator.
public struct MFSegmentedControl<Option: Hashable>: View {
    private let options: [Option]
    private let titleFor: (Option) -> String
    @Binding private var selection: Option
    @Namespace private var capsule

    public init(
        options: [Option],
        selection: Binding<Option>,
        titleFor: @escaping (Option) -> String
    ) {
        self.options = options
        self._selection = selection
        self.titleFor = titleFor
    }

    public var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.self) { option in
                let isSelected = option == selection
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { selection = option }
                } label: {
                    Text(titleFor(option))
                        .font(MFFont.subheadline.weight(isSelected ? .semibold : .regular))
                        .foregroundColor(isSelected ? MFColor.textOnSelection : MFColor.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, MFSpacing.sm)
                        .background {
                            if isSelected {
                                Capsule()
                                    .fill(MFColor.selectionFill)
                                    .matchedGeometryEffect(id: "mf-segment", in: capsule)
                            }
                        }
                }
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(4)
        .background(MFColor.surfaceSunken)
        .clipShape(Capsule())
        .accessibilityElement(children: .contain)
    }
}

// MARK: - MFSlider

/// Labeled slider with a live value readout.
public struct MFSlider: View {
    private let title: String
    @Binding private var value: Double
    private let range: ClosedRange<Double>
    private let step: Double
    private let valueText: String

    public init(
        _ title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double = 1,
        valueText: String
    ) {
        self.title = title
        self._value = value
        self.range = range
        self.step = step
        self.valueText = valueText
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: MFSpacing.xs) {
            HStack {
                Text(title)
                    .font(MFFont.subheadline)
                    .foregroundColor(MFColor.textPrimary)
                Spacer()
                Text(valueText)
                    .font(MFFont.statSmall)
                    .monospacedDigit()
                    .foregroundColor(MFColor.accent)
            }
            Slider(value: $value, in: range, step: step)
                .tint(MFColor.accent)
                .accessibilityLabel(title)
                .accessibilityValue(valueText)
        }
    }
}

#Preview("Inputs") {
    struct Demo: View {
        @State private var name = ""
        @State private var weight = ""
        @State private var servings = 1.5
        @State private var reminders = true
        @State private var goal = "Cut"
        @State private var rate: Double = 0.5

        var body: some View {
            ScrollView {
                VStack(spacing: MFSpacing.lg) {
                    MFTextField("Food name", placeholder: "Search foods…", text: $name, icon: "magnifyingglass")
                    MFTextField("Weight", placeholder: "0", text: $weight, icon: "scalemass", error: "Enter a value above zero", keyboard: .decimalPad)
                    MFStepper(value: $servings, step: 0.5, range: 0.5...20, unit: "servings", label: "Servings")
                    MFToggle("Meal reminders", subtitle: "Nudge me at my usual meal times", isOn: $reminders)
                    MFSegmentedControl(options: ["Cut", "Maintain", "Bulk"], selection: $goal) { $0 }
                    MFSlider("Rate of loss", value: $rate, range: 0...1.5, step: 0.1, valueText: String(format: "%.1f lb/wk", rate))
                }
                .padding()
            }
            .background(MFColor.background)
        }
    }
    return Demo()
}
