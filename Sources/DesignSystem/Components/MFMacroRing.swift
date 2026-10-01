import SwiftUI

// MARK: - MFMacroRing

/// Signature calorie ring: outer arc tracks calories vs. target, the inner
/// segmented arc tracks protein / carbs / fat progress, and the center shows
/// remaining calories. All artwork is original to this project.
public struct MFMacroRing: View {
    public struct Macro: Identifiable {
        public let id = UUID()
        public let name: String
        public let eaten: Double      // grams
        public let target: Double     // grams
        public let kcalPerGram: Double
        public let color: Color

        public init(name: String, eaten: Double, target: Double, kcalPerGram: Double, color: Color) {
            self.name = name
            self.eaten = eaten
            self.target = target
            self.kcalPerGram = kcalPerGram
            self.color = color
        }

        public var targetKcal: Double { target * kcalPerGram }
        public var progress: Double {
            guard target > 0 else { return 0 }
            return min(eaten / target, 1)
        }
    }

    private let caloriesEaten: Double
    private let calorieTarget: Double
    private let macros: [Macro]
    private let diameter: CGFloat

    public init(
        caloriesEaten: Double,
        calorieTarget: Double,
        macros: [Macro],
        diameter: CGFloat = 208
    ) {
        self.caloriesEaten = caloriesEaten
        self.calorieTarget = calorieTarget
        self.macros = macros
        self.diameter = diameter
    }

    private var calorieProgress: Double {
        guard calorieTarget > 0 else { return 0 }
        return min(caloriesEaten / calorieTarget, 1)
    }

    private var remaining: Double { calorieTarget - caloriesEaten }

    private var totalMacroKcal: Double {
        macros.reduce(0) { $0 + $1.targetKcal }
    }

    public var body: some View {
        ZStack {
            // Outer calorie track + progress.
            Circle()
                .stroke(MFColor.ringTrack, lineWidth: 18)
            Circle()
                .trim(from: 0, to: CGFloat(calorieProgress))
                .stroke(
                    MFColor.calories,
                    style: StrokeStyle(lineWidth: 18, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.6), value: calorieProgress)

            // Inner macro segments.
            macroSegments
                .padding(30)

            // Center readout.
            VStack(spacing: 2) {
                Text(MFFormat.kcal(abs(remaining)))
                    .font(MFFont.statLarge)
                    .monospacedDigit()
                    .foregroundColor(MFColor.textPrimary)
                Text(remaining >= 0 ? "remaining" : "over target")
                    .font(MFFont.caption)
                    .foregroundColor(remaining >= 0 ? MFColor.textSecondary : MFColor.danger)
            }
            .accessibilityHidden(true)
        }
        .frame(width: diameter, height: diameter)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
    }

    @ViewBuilder
    private var macroSegments: some View {
        ZStack {
            ForEach(Array(macros.enumerated()), id: \.element.id) { index, macro in
                let (start, end) = angles(for: index)
                // Unfilled portion of the segment.
                Circle()
                    .trim(from: start, to: end)
                    .stroke(macro.color.opacity(0.22), style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                // Filled portion.
                Circle()
                    .trim(from: start, to: start + (end - start) * CGFloat(macro.progress))
                    .stroke(macro.color, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.6), value: macro.progress)
            }
        }
    }

    /// Start/end fractions (0…1) of the macro's segment, sized by its share of target calories.
    private func angles(for index: Int) -> (CGFloat, CGFloat) {
        let gap: CGFloat = 0.02
        var cursor: CGFloat = 0
        for i in macros.indices {
            let share: CGFloat = totalMacroKcal > 0
                ? CGFloat(macros[i].targetKcal / totalMacroKcal)
                : 0
            if i == index {
                let start = cursor + gap / 2
                let end = max(start, cursor + share - gap / 2)
                return (start, end)
            }
            cursor += share
        }
        return (0, 0)
    }

    private var accessibilitySummary: String {
        let macroText = macros.map {
            "\($0.name) \(MFFormat.grams($0.eaten)) of \(MFFormat.grams($0.target)) grams"
        }.joined(separator: ", ")
        return "\(MFFormat.kcal(caloriesEaten)) of \(MFFormat.kcal(calorieTarget)) calories. \(macroText)."
    }
}

// MARK: - MFMacroBar

/// Horizontal stacked macro bar with a legend.
public struct MFMacroBar: View {
    public struct Segment: Identifiable {
        public let id = UUID()
        public let label: String
        public let eatenGrams: Double
        public let targetGrams: Double
        public let kcalPerGram: Double
        public let color: Color

        public init(label: String, eatenGrams: Double, targetGrams: Double, kcalPerGram: Double, color: Color) {
            self.label = label
            self.eatenGrams = eatenGrams
            self.targetGrams = targetGrams
            self.kcalPerGram = kcalPerGram
            self.color = color
        }

        public var progress: Double {
            guard targetGrams > 0 else { return 0 }
            return min(eatenGrams / targetGrams, 1)
        }
    }

    private let segments: [Segment]
    private let height: CGFloat

    public init(segments: [Segment], height: CGFloat = 10) {
        self.segments = segments
        self.height = height
    }

    private var totalTargetKcal: Double {
        segments.reduce(0) { $0 + $1.targetGrams * $1.kcalPerGram }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: MFSpacing.sm) {
            GeometryReader { geometry in
                HStack(spacing: 3) {
                    ForEach(segments) { segment in
                        let share = totalTargetKcal > 0
                            ? CGFloat(segment.targetGrams * segment.kcalPerGram / totalTargetKcal)
                            : 0
                        ZStack(alignment: .leading) {
                            Capsule().fill(segment.color.opacity(0.22))
                            Capsule()
                                .fill(segment.color)
                                .frame(width: max(0, geometry.size.width * share * CGFloat(segment.progress)))
                        }
                        .frame(width: max(0, geometry.size.width * share - 3))
                    }
                }
            }
            .frame(height: height)
            .accessibilityHidden(true)

            HStack(spacing: MFSpacing.lg) {
                ForEach(segments) { segment in
                    HStack(spacing: MFSpacing.xs) {
                        Circle()
                            .fill(segment.color)
                            .frame(width: 8, height: 8)
                            .accessibilityHidden(true)
                        Text("\(segment.label) \(MFFormat.grams(segment.eatenGrams))g")
                            .font(MFFont.caption)
                            .foregroundColor(MFColor.textSecondary)
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(segments.map {
            "\($0.label): \(MFFormat.grams($0.eatenGrams)) of \(MFFormat.grams($0.targetGrams)) grams"
        }.joined(separator: ", "))
    }
}

#Preview("Macro ring + bar") {
    VStack(spacing: MFSpacing.xxl) {
        MFMacroRing(
            caloriesEaten: 1640,
            calorieTarget: 2280,
            macros: PreviewData.macros
        )
        MFMacroBar(segments: PreviewData.barSegments)
            .padding(.horizontal)
    }
    .padding()
    .background(MFColor.background)
}

#Preview("Macro ring — Dark") {
    MFMacroRing(
        caloriesEaten: 2410,
        calorieTarget: 2280,
        macros: PreviewData.macros,
        diameter: 180
    )
    .padding()
    .background(MFColor.background)
    .preferredColorScheme(.dark)
}
