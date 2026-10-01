import SwiftUI
import DesignSystem
import DataLayer

// MARK: - MeasurementsView

/// Body measurements: latest value per site with deltas, per-site history,
/// and an entry sheet for a new set of tape measurements.
public struct MeasurementsView: View {
    @Environment(TrackingEnvironment.self) private var env
    @AppStorage("tracking.lengthUnit") private var lengthUnitRaw: String = TrackingLengthUnit.deviceDefault.rawValue

    @State private var entries: [BodyMeasurement] = []
    @State private var selectedSite: MeasurementSite?
    @State private var showingEditor = false
    @State private var editing: BodyMeasurement?
    @State private var error: String?

    private var metric: Bool { lengthUnitRaw != TrackingLengthUnit.imperial.rawValue }

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(spacing: MFSpacing.lg) {
                if entries.isEmpty {
                    MFEmptyState(
                        icon: "ruler",
                        title: "No measurements yet",
                        message: "Track tape measurements over time — chest, waist, arms, and more.",
                        actionTitle: "Log measurements",
                        onAction: { showingEditor = true }
                    )
                    .mfCard()
                } else {
                    latestCard
                        .mfCard()
                    historySummaryCard
                        .mfCard()
                }
            }
            .padding()
        }
        .background(MFColor.background)
        .navigationTitle("Measurements")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Picker("Unit", selection: $lengthUnitRaw) {
                    Text("cm").tag(TrackingLengthUnit.metric.rawValue)
                    Text("in").tag(TrackingLengthUnit.imperial.rawValue)
                }
                .pickerStyle(.segmented)
                .frame(width: 110)
                .accessibilityLabel("Length unit")
                Button {
                    editing = nil
                    showingEditor = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Log measurements")
            }
        }
        .sheet(isPresented: $showingEditor) {
            MeasurementEditorSheet(editing: editing)
        }
        .sheet(isPresented: Binding(
            get: { selectedSite != nil },
            set: { if !$0 { selectedSite = nil } }
        )) {
            if let site = selectedSite {
                MeasurementHistorySheet(site: site, entries: entries, metric: metric)
            }
        }
        .alert("Couldn't load measurements", isPresented: Binding(
            get: { error != nil },
            set: { if !$0 { error = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(error ?? "")
        }
        .task { load() }
        .onChange(of: env.revision) { _, _ in load() }
    }

    // MARK: Latest values

    private var latestCard: some View {
        VStack(alignment: .leading, spacing: MFSpacing.sm) {
            Text("Latest")
                .font(MFFont.headline)
                .foregroundColor(MFColor.textPrimary)
            let latest = entries.last!
            let previous = entries.dropLast().last
            ForEach(siteRows(latest: latest, previous: previous), id: \.site) { row in
                Button {
                    selectedSite = row.site
                } label: {
                    MFMeasurementRow(
                        icon: icon(for: row.site),
                        label: row.site.displayName,
                        value: TrackingFormatting.measurement(row.value, metric: metric),
                        delta: row.delta.map { TrackingFormatting.measurementDelta($0, metric: metric) },
                        deltaIsGood: row.deltaIsGood
                    )
                }
                .buttonStyle(.plain)
                if row.site != siteRows(latest: latest, previous: previous).last?.site {
                    Divider().background(MFColor.separator)
                }
            }
        }
    }

    private struct SiteRow: Equatable {
        let site: MeasurementSite
        let value: Double
        let delta: Double?
        let deltaIsGood: Bool
    }

    /// One row per site that has a value in the latest entry. Deltas are
    /// vs. the previous entry that recorded that site. "Good" is neutral
    /// for measurements (no goal direction here) — shown as success when
    /// the change is small or zero, warning otherwise, purely informational.
    private func siteRows(latest: BodyMeasurement, previous: BodyMeasurement?) -> [SiteRow] {
        MeasurementSite.allCases.compactMap { site in
            guard let value = latest.value(for: site) else { return nil }
            var delta: Double?
            if let previous, let prevValue = previous.value(for: site) {
                delta = value - prevValue
            } else if let earlier = entries.dropLast().last(where: { $0.value(for: site) != nil }),
                      let prevValue = earlier.value(for: site) {
                delta = value - prevValue
            }
            return SiteRow(
                site: site,
                value: value,
                delta: delta,
                deltaIsGood: (delta ?? 0) <= 0.0005
            )
        }
    }

    private func icon(for site: MeasurementSite) -> String {
        switch site {
        case .chest: return "figure.stand"
        case .waist: return "figure.arms.open"
        case .hips: return "figure.walk"
        case .thigh: return "figure.run"
        case .arm: return "dumbbell"
        case .neck: return "person"
        case .calf: return "figure.stand.line.dotted.figure.stand"
        case .shoulder: return "figure.strengthtraining.traditional"
        case .bodyFat: return "percent"
        }
    }

    // MARK: History summary

    private var historySummaryCard: some View {
        VStack(alignment: .leading, spacing: MFSpacing.md) {
            Text("History")
                .font(MFFont.headline)
                .foregroundColor(MFColor.textPrimary)
            ForEach(entries.suffix(8).reversed(), id: \.id) { entry in
                HStack {
                    Text(TrackingFormatting.shortDate.string(from: entry.date))
                        .font(MFFont.subheadline)
                        .foregroundColor(MFColor.textPrimary)
                    Spacer()
                    Text(summaryLine(for: entry))
                        .font(MFFont.caption)
                        .foregroundColor(MFColor.textSecondary)
                        .lineLimit(1)
                }
                .contentShape(Rectangle())
                .contextMenu {
                    Button {
                        editing = entry
                        showingEditor = true
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        delete(entry)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                .accessibilityLabel("Measurements from \(TrackingFormatting.shortDate.string(from: entry.date))")
            }
        }
    }

    private func summaryLine(for entry: BodyMeasurement) -> String {
        MeasurementSite.allCases.compactMap { site in
            entry.value(for: site).map { "\(site.displayName) \(TrackingFormatting.measurement($0, metric: metric))" }
        }.joined(separator: " · ")
    }

    // MARK: Data

    private func load() {
        do {
            let from = Calendar.current.date(byAdding: .year, value: -2, to: Date()) ?? .distantPast
            entries = try env.measurements.measurements(from: from, to: Date())
                .filter(\.hasAnyMeasurement)
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func delete(_ entry: BodyMeasurement) {
        do {
            try env.measurements.deleteMeasurement(entry)
            env.noteMutation()
            load()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

// MARK: - MeasurementEditorSheet

/// Entry form for one set of body measurements. Values are stored in
/// centimeters; the fields follow the selected display unit.
struct MeasurementEditorSheet: View {
    @Environment(TrackingEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss
    @AppStorage("tracking.lengthUnit") private var lengthUnitRaw: String = TrackingLengthUnit.deviceDefault.rawValue

    let editing: BodyMeasurement?

    @State private var date: Date = Date()
    @State private var values: [MeasurementSite: String] = [:]
    @State private var note: String = ""
    @State private var error: String?

    private var metric: Bool { lengthUnitRaw != TrackingLengthUnit.imperial.rawValue }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Date", selection: $date, in: ...Date(), displayedComponents: .date)
                }
                Section("Measurements (\(metric ? "cm" : "in"))") {
                    ForEach(MeasurementSite.allCases, id: \.self) { site in
                        HStack {
                            Text(site.displayName)
                            Spacer()
                            TextField("—", text: binding(for: site))
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .monospacedDigit()
                                .frame(width: 90)
                                .accessibilityLabel("\(site.displayName) in \(metric ? "centimeters" : "inches")")
                        }
                    }
                }
                Section("Note") {
                    TextField("Optional note", text: $note, axis: .vertical)
                }
                if let error {
                    Section {
                        MFBanner(kind: .danger, title: "Couldn't save", message: error)
                    }
                }
            }
            .navigationTitle(editing == nil ? "Log measurements" : "Edit measurements")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(!hasAnyValue)
                }
            }
            .onAppear { seed() }
        }
    }

    private func binding(for site: MeasurementSite) -> Binding<String> {
        Binding(
            get: { values[site] ?? "" },
            set: { values[site] = $0 }
        )
    }

    private var hasAnyValue: Bool {
        values.values.contains { Double($0.trimmingCharacters(in: .whitespaces)) != nil }
    }

    private func seed() {
        guard let editing else { return }
        date = editing.date
        note = editing.note ?? ""
        for site in MeasurementSite.allCases {
            if let stored = editing.value(for: site) {
                if site == .bodyFat {
                    values[site] = String(format: "%.1f", stored)
                } else {
                    values[site] = String(format: "%.1f", TrackingFormatting.length(stored, metric: metric))
                }
            }
        }
    }

    private func save() {
        error = nil
        let measurement = editing ?? BodyMeasurement(date: date)
        measurement.date = date
        measurement.note = note.isEmpty ? nil : note
        for site in MeasurementSite.allCases {
            guard let text = values[site]?.trimmingCharacters(in: .whitespaces),
                  !text.isEmpty else {
                if editing != nil { measurement.setValue(nil, for: site) }
                continue
            }
            guard let number = Double(text), number >= 0 else {
                error = "\(site.displayName) doesn't look like a number."
                return
            }
            if site == .bodyFat {
                guard number <= 100 else {
                    error = "Body fat must be a percentage between 0 and 100."
                    return
                }
                measurement.setValue(number, for: site)
            } else {
                measurement.setValue(metric ? number : number * 2.54, for: site)
            }
        }
        do {
            _ = try env.measurements.saveMeasurement(measurement)
            env.noteMutation()
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

// MARK: - MeasurementHistorySheet

/// Per-site history: every recorded value, newest first, with deltas.
struct MeasurementHistorySheet: View {
    let site: MeasurementSite
    let entries: [BodyMeasurement]
    let metric: Bool

    @Environment(\.dismiss) private var dismiss

    private var series: [(date: Date, value: Double)] {
        entries.compactMap { entry in
            entry.value(for: site).map { (entry.date, $0) }
        }.sorted { $0.date > $1.date }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(Array(series.enumerated()), id: \.offset) { index, point in
                    HStack {
                        Text(TrackingFormatting.shortDate.string(from: point.date))
                            .font(MFFont.subheadline)
                            .foregroundColor(MFColor.textPrimary)
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(TrackingFormatting.measurement(point.value, metric: metric))
                                .font(MFFont.bodyBold)
                                .monospacedDigit()
                                .foregroundColor(MFColor.textPrimary)
                            if index + 1 < series.count {
                                let delta = point.value - series[index + 1].value
                                Text(TrackingFormatting.measurementDelta(delta, metric: metric))
                                    .font(MFFont.caption2)
                                    .monospacedDigit()
                                    .foregroundColor(delta <= 0.0005 ? MFColor.success : MFColor.warning)
                            }
                        }
                    }
                }
            }
            .navigationTitle(site.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview("Measurements") {
    withPreviewEnvironment(seed: { env in
        let m = BodyMeasurement()
        m.waistCm = 82.5; m.chestCm = 101.0; m.armCm = 35.0
        try? env.measurements.saveMeasurement(m)
    }) { env in
        NavigationStack {
            MeasurementsView()
        }
        .environment(env)
    }
}
