import SwiftUI

// MARK: - MFWeightTrendChartCard

/// Weight-trend card with a smoothed line chart, current value, and delta chip.
public struct MFWeightTrendChartCard: View {
    private let points: [Double]
    private let unit: String
    private let current: Double
    private let delta: Double
    private let deltaIsGood: Bool

    public init(points: [Double], unit: String = "lb", current: Double, delta: Double, deltaIsGood: Bool) {
        self.points = points
        self.unit = unit
        self.current = current
        self.delta = delta
        self.deltaIsGood = deltaIsGood
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: MFSpacing.md) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Weight trend")
                        .font(MFFont.subheadline)
                        .foregroundColor(MFColor.textSecondary)
                    HStack(alignment: .firstTextBaseline, spacing: MFSpacing.sm) {
                        Text("\(current, specifier: "%.1f")")
                            .font(MFFont.statLarge)
                            .monospacedDigit()
                            .foregroundColor(MFColor.textPrimary)
                        Text(unit)
                            .font(MFFont.caption)
                            .foregroundColor(MFColor.textSecondary)
                    }
                }
                Spacer()
                deltaChip
            }

            GeometryReader { geometry in
                ZStack {
                    // Average line.
                    let avg = points.reduce(0, +) / Double(max(points.count, 1))
                    Path { path in
                        let y = yPosition(for: avg, in: geometry.size)
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                    }
                    .stroke(MFColor.textTertiary.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .accessibilityHidden(true)

                    // Area fill.
                    chartPath(in: geometry.size)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [MFColor.weightTrend.opacity(0.28), MFColor.weightTrend.opacity(0.02)]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .background {
                            chartPath(in: geometry.size)
                                .stroke(MFColor.weightTrend, lineWidth: 2.5)
                        }
                        .accessibilityHidden(true)

                    // Data dots.
                    ForEach(Array(dotPositions(in: geometry.size).enumerated()), id: \.offset) { _, point in
                        Circle()
                            .fill(MFColor.weightTrend)
                            .frame(width: 9, height: 9)
                            .overlay(Circle().stroke(MFColor.surface, lineWidth: 2))
                            .position(point)
                            .accessibilityHidden(true)
                    }
                }
            }
            .frame(height: 140)

            HStack {
                Text("4 wks ago")
                Spacer()
                Text("Today")
            }
            .font(MFFont.caption2)
            .foregroundColor(MFColor.textTertiary)
            .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Weight trend: \(current, specifier: "%.1f") \(unit), \(delta >= 0 ? "up" : "down") \(abs(delta), specifier: "%.1f") \(unit) over 4 weeks")
    }

    private var deltaChip: some View {
        let tint = deltaIsGood ? MFColor.success : MFColor.warning
        return HStack(spacing: MFSpacing.xs) {
            Image(systemName: delta >= 0 ? "arrow.up.right" : "arrow.down.right")
                .font(.caption.weight(.bold))
            Text("\(abs(delta), specifier: "%.1f") \(unit)")
                .font(MFFont.statSmall)
                .monospacedDigit()
        }
        .foregroundColor(tint)
        .padding(.horizontal, MFSpacing.sm)
        .padding(.vertical, MFSpacing.xs)
        .background(tint.opacity(0.12))
        .clipShape(Capsule())
        .accessibilityHidden(true)
    }

    private func yPosition(for value: Double, in size: CGSize) -> CGFloat {
        guard let min = points.min(), let max = points.max(), max > min else {
            return size.height / 2
        }
        let padded = UIEdgeInsets(top: 8, left: 4, bottom: 8, right: 4)
        let usable = size.height - padded.top - padded.bottom
        return padded.top + usable * (1 - CGFloat((value - min) / (max - min)))
    }

    /// Center points of each data sample, for the dot markers.
    private func dotPositions(in size: CGSize) -> [CGPoint] {
        guard points.count > 1,
              let min = points.min(), let max = points.max(), max > min
        else { return [] }
        let padded = UIEdgeInsets(top: 8, left: 4, bottom: 8, right: 4)
        let usableHeight = size.height - padded.top - padded.bottom
        let usableWidth = size.width - padded.left - padded.right
        let stepX = usableWidth / CGFloat(points.count - 1)
        return points.enumerated().map { index, value in
            CGPoint(
                x: padded.left + CGFloat(index) * stepX,
                y: padded.top + usableHeight * (1 - CGFloat((value - min) / (max - min)))
            )
        }
    }

    private func chartPath(in size: CGSize) -> Path {
        var path = Path()
        guard points.count > 1,
              let min = points.min(), let max = points.max(), max > min
        else { return path }

        let padded = UIEdgeInsets(top: 8, left: 4, bottom: 8, right: 4)
        let usableHeight = size.height - padded.top - padded.bottom
        let usableWidth = size.width - padded.left - padded.right
        let stepX = usableWidth / CGFloat(points.count - 1)

        let coords = points.enumerated().map { index, value in
            CGPoint(
                x: padded.left + CGFloat(index) * stepX,
                y: padded.top + usableHeight * (1 - CGFloat((value - min) / (max - min)))
            )
        }

        // Line path (smoothed with quadratic midpoints).
        var line = Path()
        line.move(to: coords[0])
        for i in 1..<coords.count {
            let mid = CGPoint(x: (coords[i - 1].x + coords[i].x) / 2,
                              y: (coords[i - 1].y + coords[i].y) / 2)
            line.addQuadCurve(to: mid, control: CGPoint(x: mid.x, y: coords[i - 1].y))
            line.addQuadCurve(to: coords[i], control: CGPoint(x: mid.x, y: coords[i].y))
        }

        // Closed area path for the gradient fill.
        path.addPath(line)
        path.addLine(to: CGPoint(x: coords.last!.x, y: size.height))
        path.addLine(to: CGPoint(x: coords.first!.x, y: size.height))
        path.closeSubpath()
        return path
    }
}

// MARK: - MFExpenditureChartCard

/// Expenditure card: orange line with a shaded flux band and data dots,
/// matching the real expenditure chart.
public struct MFExpenditureChartCard: View {
    private let points: [Double]
    private let band: [(low: Double, high: Double)]
    private let average: Double
    private let unit: String

    public init(points: [Double], band: [(low: Double, high: Double)], average: Double, unit: String = "kcal") {
        self.points = points
        self.band = band
        self.average = average
        self.unit = unit
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: MFSpacing.md) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Expenditure")
                        .font(MFFont.subheadline)
                        .foregroundColor(MFColor.textSecondary)
                    HStack(alignment: .firstTextBaseline, spacing: MFSpacing.sm) {
                        Text(MFFormat.kcal(average))
                            .font(MFFont.statLarge)
                            .monospacedDigit()
                            .foregroundColor(MFColor.textPrimary)
                        Text(unit)
                            .font(MFFont.caption)
                            .foregroundColor(MFColor.textSecondary)
                    }
                }
                Spacer()
            }

            GeometryReader { geometry in
                ZStack {
                    // Flux band.
                    bandPath(in: geometry.size)
                        .fill(MFColor.expenditure.opacity(0.18))
                        .accessibilityHidden(true)

                    // Line.
                    linePath(in: geometry.size)
                        .stroke(MFColor.expenditure, lineWidth: 2.5)
                        .accessibilityHidden(true)

                    // Data dots.
                    ForEach(Array(dotPositions(in: geometry.size).enumerated()), id: \.offset) { _, point in
                        Circle()
                            .fill(MFColor.expenditure)
                            .frame(width: 9, height: 9)
                            .overlay(Circle().stroke(MFColor.surface, lineWidth: 2))
                            .position(point)
                            .accessibilityHidden(true)
                    }
                }
            }
            .frame(height: 140)

            HStack {
                Text("4 wks ago")
                Spacer()
                Text("Today")
            }
            .font(MFFont.caption2)
            .foregroundColor(MFColor.textTertiary)
            .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Expenditure: average \(MFFormat.kcal(average)) \(unit)")
    }

    private func yPosition(for value: Double, in size: CGSize) -> CGFloat {
        let all = points + band.flatMap { [$0.low, $0.high] }
        guard let min = all.min(), let max = all.max(), max > min else {
            return size.height / 2
        }
        let usable = size.height - 16
        return 8 + usable * (1 - CGFloat((value - min) / (max - min)))
    }

    private func linePath(in size: CGSize) -> Path {
        let coords = points.enumerated().map { index, value in
            CGPoint(
                x: 4 + (size.width - 8) * CGFloat(index) / CGFloat(max(points.count - 1, 1)),
                y: yPosition(for: value, in: size)
            )
        }
        var line = Path()
        guard let first = coords.first else { return line }
        line.move(to: first)
        for i in 1..<coords.count {
            let mid = CGPoint(x: (coords[i - 1].x + coords[i].x) / 2,
                              y: (coords[i - 1].y + coords[i].y) / 2)
            line.addQuadCurve(to: mid, control: CGPoint(x: mid.x, y: coords[i - 1].y))
            line.addQuadCurve(to: coords[i], control: CGPoint(x: mid.x, y: coords[i].y))
        }
        return line
    }

    private func bandPath(in size: CGSize) -> Path {
        guard band.count == points.count, points.count > 1 else { return Path() }
        let top = band.enumerated().map { index, b in
            CGPoint(
                x: 4 + (size.width - 8) * CGFloat(index) / CGFloat(max(points.count - 1, 1)),
                y: yPosition(for: b.high, in: size)
            )
        }
        let bottom = band.enumerated().map { index, b in
            CGPoint(
                x: 4 + (size.width - 8) * CGFloat(index) / CGFloat(max(points.count - 1, 1)),
                y: yPosition(for: b.low, in: size)
            )
        }
        var path = Path()
        path.move(to: top[0])
        top.dropFirst().forEach { path.addLine(to: $0) }
        bottom.reversed().forEach { path.addLine(to: $0) }
        path.closeSubpath()
        return path
    }

    private func dotPositions(in size: CGSize) -> [CGPoint] {
        points.enumerated().map { index, value in
            CGPoint(
                x: 4 + (size.width - 8) * CGFloat(index) / CGFloat(max(points.count - 1, 1)),
                y: yPosition(for: value, in: size)
            )
        }
    }
}

// MARK: - MFMeasurementRow

/// Body-measurement row with value and period delta.
public struct MFMeasurementRow: View {
    private let icon: String
    private let label: String
    private let value: String
    private let delta: String?
    private let deltaIsGood: Bool

    public init(icon: String, label: String, value: String, delta: String? = nil, deltaIsGood: Bool = true) {
        self.icon = icon
        self.label = label
        self.value = value
        self.delta = delta
        self.deltaIsGood = deltaIsGood
    }

    public var body: some View {
        HStack(spacing: MFSpacing.md) {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(MFColor.accent)
                .frame(width: 36, height: 36)
                .background(MFColor.accentSoft)
                .clipShape(Circle())
                .accessibilityHidden(true)
            Text(label)
                .font(MFFont.body)
                .foregroundColor(MFColor.textPrimary)
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(value)
                    .font(MFFont.statSmall)
                    .monospacedDigit()
                    .foregroundColor(MFColor.textPrimary)
                if let delta {
                    Text(delta)
                        .font(MFFont.caption2)
                        .monospacedDigit()
                        .foregroundColor(deltaIsGood ? MFColor.success : MFColor.warning)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)\(delta.map { ", \($0)" } ?? "")")
    }
}

// MARK: - MFStreakCell

/// Habit-streak cell: flame icon, count, and caption.
public struct MFStreakCell: View {
    private let days: Int
    private let caption: String

    public init(days: Int, caption: String = "day streak") {
        self.days = days
        self.caption = caption
    }

    public var body: some View {
        VStack(spacing: MFSpacing.sm) {
            MFFlameGlyph(size: 22, color: MFColor.carbs)
                .frame(width: 52, height: 52)
                .background(MFColor.carbs.opacity(0.14))
                .clipShape(Circle())
            Text("\(days)")
                .font(MFFont.statLarge)
                .monospacedDigit()
                .foregroundColor(MFColor.textPrimary)
            Text(caption)
                .font(MFFont.caption)
                .foregroundColor(MFColor.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, MFSpacing.lg)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(days) \(caption)")
    }
}

// MARK: - MFProgressPhotoTile

/// Progress-photo tile placeholder with pose tag and date.
public struct MFProgressPhotoTile: View {
    private let pose: String
    private let date: String

    public init(pose: String = "Front", date: String) {
        self.pose = pose
        self.date = date
    }

    public var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: MFRadii.md)
                .fill(MFColor.surfaceSunken)
            VStack {
                Spacer()
                Image(systemName: "photo")
                    .font(.title)
                    .foregroundColor(MFColor.textTertiary)
                Spacer()
                Text(date)
                    .font(MFFont.caption2)
                    .foregroundColor(MFColor.textSecondary)
                    .padding(.bottom, MFSpacing.sm)
            }
            .frame(maxWidth: .infinity)
            Text(pose)
                .font(MFFont.caption2.weight(.semibold))
                .foregroundColor(MFColor.textOnAccent)
                .padding(.horizontal, MFSpacing.sm)
                .padding(.vertical, MFSpacing.xs)
                .background(MFColor.accent)
                .clipShape(Capsule())
                .padding(MFSpacing.sm)
        }
        .aspectRatio(3 / 4, contentMode: .fit)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Progress photo, \(pose), \(date)")
    }
}

#Preview("Tracking") {
    ScrollView {
        VStack(spacing: MFSpacing.lg) {
            MFWeightTrendChartCard(
                points: PreviewData.weights,
                current: 172.4,
                delta: -2.3,
                deltaIsGood: true
            )
            .mfCard()
            MFExpenditureChartCard(
                points: [2280, 2295, 2310, 2305, 2320, 2335, 2330, 2345, 2350, 2360, 2355, 2370],
                band: [(2260, 2300), (2275, 2315), (2290, 2330), (2285, 2325), (2300, 2340), (2315, 2355), (2310, 2350), (2325, 2365), (2330, 2370), (2340, 2380), (2335, 2375), (2350, 2390)],
                average: 2330
            )
            .mfCard()
            VStack(spacing: MFSpacing.md) {
                MFMeasurementRow(icon: "figure.stand", label: "Waist", value: "32.5 in", delta: "-0.8 in", deltaIsGood: true)
                Divider().background(MFColor.separator)
                MFMeasurementRow(icon: "figure.arms.open", label: "Chest", value: "40.0 in", delta: "+0.2 in", deltaIsGood: false)
            }
            .mfCard()
            HStack(spacing: MFSpacing.md) {
                MFStreakCell(days: 12, caption: "day logging streak").mfCard()
                MFStreakCell(days: 4, caption: "wk weigh-in streak").mfCard()
            }
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: MFSpacing.md) {
                MFProgressPhotoTile(pose: "Front", date: "Sep 1")
                MFProgressPhotoTile(pose: "Side", date: "Sep 1")
                MFProgressPhotoTile(pose: "Back", date: "Sep 1")
            }
        }
        .padding()
    }
    .background(MFColor.background)
}
