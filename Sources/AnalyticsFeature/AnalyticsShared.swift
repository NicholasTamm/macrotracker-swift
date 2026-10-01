import SwiftUI
import DesignSystem
import DataLayer

// MARK: - Shared analytics UI

/// Maps nutrients to their canonical chart color (macro colors per spec,
/// pink for everything past the macros, orange for expenditure, purple
/// for weight). Every color comes from MFColor tokens — never hardcoded.
public enum MFAnalyticsColor {
    public static func forNutrient(_ key: NutrientKey) -> Color {
        switch key {
        case .calories: return MFColor.calories
        case .protein: return MFColor.protein
        case .fat: return MFColor.fat
        case .carbs: return MFColor.carbs
        default: return MFColor.micro
        }
    }

    public static func forAccent(_ accent: InsightAccent) -> Color {
        switch accent {
        case .calories: return MFColor.calories
        case .protein: return MFColor.protein
        case .fat: return MFColor.fat
        case .carbs: return MFColor.carbs
        case .weight: return MFColor.weightTrend
        case .expenditure: return MFColor.expenditure
        case .micro: return MFColor.micro
        case .habit: return MFColor.accent
        }
    }

    /// SF Symbol used for a nutrient (micros use `pill.fill` per spec).
    public static func symbol(for key: NutrientKey) -> String {
        switch key {
        case .calories: return "flame.fill"
        case .protein: return "fish.fill"
        case .fat: return "drop.fill"
        case .carbs: return "leaf.fill"
        case .fiber: return "carrot.fill"
        case .sugar: return "cube.fill"
        default: return "pill.fill"
        }
    }
}

// MARK: - AnalyticsSectionHeader

/// Small section header used across dashboards.
public struct AnalyticsSectionHeader: View {
    private let title: String
    private let subtitle: String?

    public init(_ title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(MFFont.headline)
                .foregroundColor(MFColor.textPrimary)
            if let subtitle {
                Text(subtitle)
                    .font(MFFont.caption)
                    .foregroundColor(MFColor.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title + (subtitle.map { ", \($0)" } ?? ""))
    }
}

// MARK: - AnalyticsRangePicker

/// Segmented range picker (1M / 3M / 6M / 1Y) with the app's selection pill.
public struct AnalyticsRangePicker: View {
    @Binding private var range: AnalyticsRange

    public init(range: Binding<AnalyticsRange>) {
        self._range = range
    }

    public var body: some View {
        HStack(spacing: 4) {
            ForEach(AnalyticsRange.allCases) { option in
                Button {
                    withAnimation(.easeOut(duration: 0.2)) { range = option }
                } label: {
                    Text(option.rawValue)
                        .font(MFFont.subheadline.weight(.semibold))
                        .monospacedDigit()
                        .foregroundColor(range == option ? MFColor.textOnSelection : MFColor.textSecondary)
                        .padding(.vertical, MFSpacing.sm)
                        .frame(maxWidth: .infinity)
                        .background(range == option ? MFColor.selectionFill : Color.clear)
                        .clipShape(Capsule())
                }
                .accessibilityLabel("\(option.title) range")
                .accessibilityAddTraits(range == option ? .isSelected : [])
            }
        }
        .padding(4)
        .background(MFColor.surfaceSunken)
        .clipShape(Capsule())
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Time range")
    }
}

// MARK: - AnalyticsEmptyState

/// Empty state shown when a dashboard has no data yet.
public struct AnalyticsEmptyState: View {
    private let title: String
    private let body: String
    private let systemIcon: String

    public init(title: String, body: String, systemIcon: String) {
        self.title = title
        self.body = body
        self.systemIcon = systemIcon
    }

    public var body: some View {
        VStack(spacing: MFSpacing.md) {
            Image(systemName: systemIcon)
                .font(.largeTitle)
                .foregroundColor(MFColor.textTertiary)
                .accessibilityHidden(true)
            Text(title)
                .font(MFFont.headline)
                .foregroundColor(MFColor.textPrimary)
            Text(body)
                .font(MFFont.subheadline)
                .foregroundColor(MFColor.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, MFSpacing.xxl)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(body)")
    }
}

// MARK: - AnalyticsProgressBar

/// Thin labeled progress bar for nutrient rows (used where the design
/// system's nutrient row doesn't fit the dashboard layout).
public struct AnalyticsProgressBar: View {
    private let progress: Double
    private let color: Color

    public init(progress: Double, color: Color) {
        self.progress = progress
        self.color = color
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(MFColor.ringTrack)
                Capsule()
                    .fill(color)
                    .frame(width: geometry.size.width * CGFloat(min(max(progress, 0), 1)))
            }
        }
        .frame(height: 6)
        .accessibilityHidden(true)
    }
}

// MARK: - Formatting helpers

public enum MFAnalyticsFormat {
    /// "184.5 g" / "1,842 kcal" style nutrient amount.
    public static func amount(_ value: Double, key: NutrientKey) -> String {
        key == .calories
            ? "\(MFFormat.kcal(value)) \(key.unit)"
            : "\(MFFormat.grams(value)) \(key.unit)"
    }

    /// Short date for chart axes ("Sep 4").
    public static func shortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }

    /// Signed change with one decimal ("−2.3 lb").
    public static func signedChange(_ value: Double, unit: String) -> String {
        let sign = value < 0 ? "−" : (value > 0 ? "+" : "")
        return "\(sign)\(String(format: "%.1f", abs(value))) \(unit)"
    }

    /// Percent of a share ("38%").
    public static func percent(_ share: Double) -> String {
        "\(Int((share * 100).rounded()))%"
    }
}
