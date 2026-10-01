//  MFWidgets.swift
//  WidgetKit extension — home-screen + lock-screen widgets (issue #10).
//
//  DROP-IN: this file is NOT part of the Swift package. Add it to the
//  WidgetKit Extension target in the Xcode project (see Widgets/README.md).
//
//  Data comes exclusively from `MFSharedSnapshot` in the App Group
//  container (written by `MFSnapshotPublisher` in the iOS app). The
//  extension never touches SwiftData. Taps deep-link through `mfclone://`
//  URLs handled by MFRouter in AppShell.

import WidgetKit
import SwiftUI
import DesignSystem
import EngagementFeature

// MARK: - Timeline

struct MFTodayEntry: TimelineEntry {
    let date: Date
    let snapshot: MFSharedSnapshot
}

struct MFTodayProvider: TimelineProvider {
    func placeholder(in context: Context) -> MFTodayEntry {
        MFTodayEntry(date: Date(), snapshot: .preview)
    }

    func getSnapshot(in context: Context, completion: @escaping (MFTodayEntry) -> Void) {
        let snapshot = MFSharedSnapshotStore.read() ?? .preview
        completion(MFTodayEntry(date: Date(), snapshot: snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MFTodayEntry>) -> Void) {
        let snapshot = MFSharedSnapshotStore.read() ?? .preview
        let entry = MFTodayEntry(date: Date(), snapshot: snapshot)
        // The iOS app calls WidgetCenter.reloadAllTimelines() on every data
        // change; midnight is the backstop for day rollover.
        let nextMidnight = Calendar.current.startOfDay(
            for: Date().addingTimeInterval(24 * 3600)
        )
        completion(Timeline(entries: [entry], policy: .after(nextMidnight)))
    }
}

// MARK: - Home-screen widget

struct MFTodayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: "com.macrofactor.clone.widget.today",
            provider: MFTodayProvider()
        ) { entry in
            MFTodayWidgetView(entry: entry)
        }
        .configurationDisplayName("Today's nutrition")
        .description("Calories remaining and macro progress for today.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct MFTodayWidgetView: View {
    let entry: MFTodayEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .systemMedium:
            MFTodayMediumView(snapshot: entry.snapshot)
        default:
            MFTodaySmallView(snapshot: entry.snapshot)
        }
    }
}

// MARK: Small — calorie ring

struct MFTodaySmallView: View {
    let snapshot: MFSharedSnapshot

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .stroke(MFColor.ringTrack, lineWidth: 9)
                Circle()
                    .trim(from: 0, to: CGFloat(snapshot.calorieProgress))
                    .stroke(MFColor.calories, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    Text(MFFormat.kcal(max(snapshot.remainingCalories, 0)))
                        .font(MFFont.statSmall)
                        .foregroundColor(MFColor.textPrimary)
                    Text("left")
                        .font(MFFont.caption2)
                        .foregroundColor(MFColor.textSecondary)
                }
            }
            .frame(width: 84, height: 84)
            Text("\(MFFormat.kcal(snapshot.calories)) of \(MFFormat.kcal(snapshot.targetCalories))")
                .font(MFFont.caption2)
                .foregroundColor(MFColor.textSecondary)
        }
        .containerBackground(for: .widget) { MFColor.surface }
        .widgetURL(URL(string: "mfclone://foodlog"))
    }
}

// MARK: Medium — ring + macro bars

struct MFTodayMediumView: View {
    let snapshot: MFSharedSnapshot

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(MFColor.ringTrack, lineWidth: 10)
                Circle()
                    .trim(from: 0, to: CGFloat(snapshot.calorieProgress))
                    .stroke(MFColor.calories, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    Text(MFFormat.kcal(max(snapshot.remainingCalories, 0)))
                        .font(MFFont.headline)
                        .foregroundColor(MFColor.textPrimary)
                    Text("kcal left")
                        .font(MFFont.caption2)
                        .foregroundColor(MFColor.textSecondary)
                }
            }
            .frame(width: 96, height: 96)

            VStack(alignment: .leading, spacing: 8) {
                MFMacroBar(
                    label: "Protein",
                    eaten: snapshot.proteinGrams,
                    target: snapshot.targetProteinGrams,
                    color: MFColor.protein
                )
                MFMacroBar(
                    label: "Fat",
                    eaten: snapshot.fatGrams,
                    target: snapshot.targetFatGrams,
                    color: MFColor.fat
                )
                MFMacroBar(
                    label: "Carbs",
                    eaten: snapshot.carbsGrams,
                    target: snapshot.targetCarbsGrams,
                    color: MFColor.carbs
                )
            }
        }
        .containerBackground(for: .widget) { MFColor.surface }
        .widgetURL(URL(string: "mfclone://foodlog"))
    }
}

struct MFMacroBar: View {
    let label: String
    let eaten: Double
    let target: Double
    let color: Color

    private var progress: Double {
        guard target > 0 else { return 0 }
        return min(max(eaten / target, 0), 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(label)
                    .font(MFFont.caption)
                    .foregroundColor(MFColor.textSecondary)
                Spacer()
                Text("\(MFFormat.grams(eaten)) / \(MFFormat.grams(target))g")
                    .font(MFFont.caption)
                    .foregroundColor(MFColor.textPrimary)
            }
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(MFColor.ringTrack)
                    Capsule()
                        .fill(color)
                        .frame(width: geometry.size.width * CGFloat(progress))
                }
            }
            .frame(height: 6)
        }
    }
}

// MARK: - Lock-screen widget

struct MFCompactWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: "com.macrofactor.clone.widget.compact",
            provider: MFTodayProvider()
        ) { entry in
            MFCompactWidgetView(entry: entry)
        }
        .configurationDisplayName("Calories remaining")
        .description("Today's remaining calories on the Lock Screen.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

struct MFCompactWidgetView: View {
    let entry: MFTodayEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 0) {
                    Text(MFFormat.kcal(max(entry.snapshot.remainingCalories, 0)))
                        .font(.headline)
                    Text("left")
                        .font(.caption2)
                }
            }
            .widgetURL(URL(string: "mfclone://quicklog"))
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Text("\(MFFormat.kcal(max(entry.snapshot.remainingCalories, 0))) kcal left")
                    .font(.headline)
                Text("P \(MFFormat.grams(entry.snapshot.proteinGrams)) · F \(MFFormat.grams(entry.snapshot.fatGrams)) · C \(MFFormat.grams(entry.snapshot.carbsGrams))")
                    .font(.caption2)
            }
            .widgetURL(URL(string: "mfclone://foodlog"))
        default: // .accessoryInline
            Text("\(MFFormat.kcal(max(entry.snapshot.remainingCalories, 0))) kcal left today")
                .widgetURL(URL(string: "mfclone://foodlog"))
        }
    }
}

// MARK: - Bundle

@main
struct MFWidgetBundle: WidgetBundle {
    var body: some Widget {
        MFTodayWidget()
        MFCompactWidget()
    }
}

// MARK: - Previews

#Preview("Today Small", as: .systemSmall) {
    MFTodayWidget()
} timeline: {
    MFTodayEntry(date: Date(), snapshot: .preview)
}

#Preview("Today Medium", as: .systemMedium) {
    MFTodayWidget()
} timeline: {
    MFTodayEntry(date: Date(), snapshot: .preview)
}

#Preview("Compact", as: .accessoryRectangular) {
    MFCompactWidget()
} timeline: {
    MFTodayEntry(date: Date(), snapshot: .preview)
}
