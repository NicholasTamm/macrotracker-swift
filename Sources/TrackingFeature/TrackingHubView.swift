import SwiftUI
import DesignSystem
import DataLayer
import CoachingEngine

// MARK: - TrackingHubView

/// Tracking home screen: weight trend, measurements, progress photos,
/// habits, cycle, and steps. Each section links to its detail screen;
/// every screen loads its own data from `TrackingEnvironment`.
public struct TrackingHubView: View {
    @Environment(TrackingEnvironment.self) private var env

    @State private var trendSummary: WeightTrendSummary?
    @State private var trendPoints: [Double] = []
    @State private var goalType: GoalType = .maintain
    @State private var latestMeasurement: BodyMeasurement?
    @State private var recentPhotos: [ProgressPhoto] = []
    @State private var habits: [(habit: Habit, streak: Int)] = []
    @State private var showingWeighIn = false

    @AppStorage("tracking.lengthUnit") private var lengthUnitRaw: String = TrackingLengthUnit.deviceDefault.rawValue

    private var metric: Bool { lengthUnitRaw != TrackingLengthUnit.imperial.rawValue }

    public init() {}

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: MFSpacing.lg) {
                    weightSection
                    measurementsSection
                    photosSection
                    habitsSection
                    cycleSection
                    StepsSummaryCard()
                        .mfCard()
                }
                .padding()
            }
            .background(MFColor.background)
            .navigationTitle("Tracking")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingWeighIn = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Log weight")
                }
            }
            .sheet(isPresented: $showingWeighIn) {
                WeighInSheet()
            }
            .task {
                env.ensureSystemHabits()
                load()
            }
            .onChange(of: env.revision) { _, _ in load() }
        }
    }

    // MARK: Weight

    private var weightSection: some View {
        NavigationLink {
            WeightTrendView()
        } label: {
            Group {
                if let summary = trendSummary, !trendPoints.isEmpty {
                    let unit = env.weightUnit
                    MFWeightTrendChartCard(
                        points: trendPoints.map { unit.fromKilograms($0) },
                        unit: unit == .pounds ? "lb" : "kg",
                        current: unit.fromKilograms(summary.endTrendKg),
                        delta: unit.fromKilograms(summary.totalChangeKg),
                        deltaIsGood: TrackingFormatting.deltaIsGood(summary.totalChangeKg, goalType: goalType)
                    )
                    .accessibilityHint("Opens the weight trend detail")
                } else {
                    hubPlaceholder(
                        icon: "scalemass",
                        title: "Weight trend",
                        message: "Log a weigh-in to start your trend."
                    )
                }
            }
        }
        .buttonStyle(.plain)
        .mfCard()
    }

    // MARK: Measurements

    private var measurementsSection: some View {
        NavigationLink {
            MeasurementsView()
        } label: {
            VStack(alignment: .leading, spacing: MFSpacing.sm) {
                hubRowHeader(icon: "ruler", title: "Measurements")
                if let latest = latestMeasurement {
                    let rows = MeasurementSite.allCases.compactMap { site in
                        latest.value(for: site).map { (site, $0) }
                    }.prefix(3)
                    ForEach(rows, id: \.0) { site, value in
                        HStack {
                            Text(site.displayName)
                                .font(MFFont.subheadline)
                                .foregroundColor(MFColor.textSecondary)
                            Spacer()
                            Text(TrackingFormatting.measurement(value, metric: metric))
                                .font(MFFont.bodyBold)
                                .monospacedDigit()
                                .foregroundColor(MFColor.textPrimary)
                        }
                    }
                } else {
                    Text("No measurements logged yet.")
                        .font(MFFont.caption)
                        .foregroundColor(MFColor.textSecondary)
                }
            }
        }
        .buttonStyle(.plain)
        .mfCard()
    }

    // MARK: Photos

    private var photosSection: some View {
        NavigationLink {
            ProgressPhotosView()
        } label: {
            VStack(alignment: .leading, spacing: MFSpacing.md) {
                hubRowHeader(icon: "photo.on.rectangle", title: "Progress photos")
                if recentPhotos.isEmpty {
                    Text("Add front, side, and back photos to track visual progress.")
                        .font(MFFont.caption)
                        .foregroundColor(MFColor.textSecondary)
                } else {
                    HStack(spacing: MFSpacing.sm) {
                        ForEach(recentPhotos.prefix(3), id: \.id) { photo in
                            HubPhotoThumb(photo: photo)
                        }
                        Spacer()
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .mfCard()
    }

    // MARK: Habits

    private var habitsSection: some View {
        NavigationLink {
            HabitsView()
        } label: {
            VStack(alignment: .leading, spacing: MFSpacing.md) {
                hubRowHeader(icon: "flame", title: "Streaks")
                if habits.isEmpty {
                    Text("Create habits to start building streaks.")
                        .font(MFFont.caption)
                        .foregroundColor(MFColor.textSecondary)
                } else {
                    HStack(spacing: MFSpacing.md) {
                        ForEach(habits.prefix(3), id: \.habit.id) { item in
                            VStack(spacing: 4) {
                                MFFlameGlyph(size: 20, color: item.streak > 0 ? MFColor.fat : MFColor.textTertiary)
                                    .accessibilityHidden(true)
                                Text("\(item.streak)")
                                    .font(MFFont.statSmall)
                                    .monospacedDigit()
                                    .foregroundColor(MFColor.textPrimary)
                                Text(item.habit.name)
                                    .font(MFFont.caption2)
                                    .foregroundColor(MFColor.textSecondary)
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity)
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("\(item.habit.name): \(item.streak) day streak")
                        }
                        Spacer()
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .mfCard()
    }

    // MARK: Cycle

    private var cycleSection: some View {
        NavigationLink {
            CycleTrackingView()
        } label: {
            VStack(alignment: .leading, spacing: MFSpacing.sm) {
                hubRowHeader(icon: "drop", title: "Cycle")
                Text("Log your period and see cycle predictions.")
                    .font(MFFont.caption)
                    .foregroundColor(MFColor.textSecondary)
            }
        }
        .buttonStyle(.plain)
        .mfCard()
    }

    // MARK: Shared bits

    private func hubRowHeader(icon: String, title: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(MFColor.accent)
                .accessibilityHidden(true)
            Text(title)
                .font(MFFont.headline)
                .foregroundColor(MFColor.textPrimary)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundColor(MFColor.textTertiary)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityHint("Opens details")
    }

    private func hubPlaceholder(icon: String, title: String, message: String) -> some View {
        VStack(spacing: MFSpacing.sm) {
            hubRowHeader(icon: icon, title: title)
            Text(message)
                .font(MFFont.caption)
                .foregroundColor(MFColor.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: Data

    private func load() {
        env.refreshWeightUnit()
        goalType = (try? env.program.settings().goalType) ?? .maintain
        let end = Date()

        // Weight trend (same smoothing as the coaching engine).
        if let seedFrom = Calendar.current.date(byAdding: .day, value: -120, to: end),
           let samples = try? env.weights.samples(from: seedFrom, to: end) {
            let series = WeightTrend.trendSeries(samples: samples, endDate: end, windowDays: 28)
            trendPoints = series.map(\.trendKg)
            trendSummary = WeightTrend.summarize(samples: samples, endDate: end, windowDays: 28)
        }

        // Latest measurements.
        if let from = Calendar.current.date(byAdding: .year, value: -2, to: end),
           let all = try? env.measurements.measurements(from: from, to: end) {
            latestMeasurement = all.filter(\.hasAnyMeasurement).last
        }

        // Recent photos.
        recentPhotos = Array((try? env.measurements.photos(from: .distantPast, to: end))?.suffix(3).reversed() ?? [])

        // Habits + streaks.
        if let all = try? env.habits.habits(activeOnly: true) {
            habits = all.map { ($0, env.streak(for: $0)) }
        }
    }
}

// MARK: - HubPhotoThumb

/// Small async thumbnail for the hub's photo strip.
struct HubPhotoThumb: View {
    @Environment(TrackingEnvironment.self) private var env
    let photo: ProgressPhoto
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                RoundedRectangle(cornerRadius: MFRadii.sm)
                    .fill(MFColor.surfaceSunken)
            }
        }
        .frame(width: 64, height: 84)
        .clipShape(RoundedRectangle(cornerRadius: MFRadii.sm))
        .task(id: photo.id) {
            let url = env.thumbnailURL(for: photo)
            let loaded = await Task.detached {
                guard let data = try? Data(contentsOf: url) else { return nil as UIImage? }
                return UIImage(data: data)
            }.value
            image = loaded
        }
        .accessibilityHidden(true)
    }
}

#Preview("Tracking hub") {
    withPreviewEnvironment(seed: { env in
        env.ensureSystemHabits()
        let calendar = Calendar.current
        for day in 0..<28 {
            let date = calendar.date(byAdding: .day, value: -day, to: Date())!
            try? env.weights.logWeight(82.0 - Double(28 - day) * 0.05, timestamp: date, note: nil, source: .manual)
        }
    }) { env in
        TrackingHubView()
            .environment(env)
    }
}
