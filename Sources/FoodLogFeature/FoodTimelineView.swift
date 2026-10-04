import SwiftUI
import DesignSystem
import DataLayer

// MARK: - FoodTimelineBlock

/// One hour of the day timeline: entries grouped by hour.
public struct FoodTimelineBlock: Identifiable {
    public var hour: Int
    public var entries: [LogEntry]

    public var id: Int { hour }

    public init(hour: Int, entries: [LogEntry]) {
        self.hour = hour
        self.entries = entries
    }

    public var totals: MFDayTotals { MFDayTotals.summing(entries) }
}

// MARK: - FoodTimelineBlockView

/// An hour block: time pill, add button, block totals (kcal with trailing
/// flame, macro values with trailing letter badges — per
/// `ref-timeline-log.png`), and food thumbnails below.
public struct FoodTimelineBlockView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let block: FoodTimelineBlock
    let onAdd: () -> Void
    let onSelectEntry: (LogEntry) -> Void
    let onCopyBlock: () -> Void
    let onDeleteEntry: (LogEntry) -> Void

    public init(
        block: FoodTimelineBlock,
        onAdd: @escaping () -> Void,
        onSelectEntry: @escaping (LogEntry) -> Void,
        onCopyBlock: @escaping () -> Void,
        onDeleteEntry: @escaping (LogEntry) -> Void
    ) {
        self.block = block
        self.onAdd = onAdd
        self.onSelectEntry = onSelectEntry
        self.onCopyBlock = onCopyBlock
        self.onDeleteEntry = onDeleteEntry
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: MFSpacing.sm) {
            if block.entries.isEmpty {
                // Slim empty-hour row: time pill + add only.
                HStack(spacing: MFSpacing.sm) {
                    timePill
                    MFIconButton(icon: "plus", label: "Log food at \(timeLabel)") {
                        onAdd()
                    }
                    Spacer()
                }
            } else {
                MFTimeBlockHeader(
                    time: timeLabel,
                    isNow: isCurrentHour,
                    kcal: block.totals.calories,
                    protein: block.totals.protein,
                    fat: block.totals.fat,
                    carbs: block.totals.carbs,
                    onAdd: onAdd
                )
                .contextMenu {
                    Button("Copy \(block.entries.count) foods") { onCopyBlock() }
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: MFSpacing.md) {
                        ForEach(block.entries, id: \.id) { entry in
                            Button { onSelectEntry(entry) } label: {
                                VStack(spacing: MFSpacing.xs) {
                                    MFFoodThumbnail(
                                        openmojiHex: MFFoodIconMapper.hex(forName: entry.foodName),
                                        symbol: symbol(for: entry)
                                    )
                                    Text(entry.foodName)
                                        .font(MFFont.footnote.weight(.semibold))
                                        .foregroundColor(MFColor.textPrimary)
                                        .multilineTextAlignment(.center)
                                        .fixedSize(horizontal: false, vertical: true)
                                    Text(MFFormat.kcal(entry.calories))
                                        .font(MFFont.caption2)
                                        .monospacedDigit()
                                        .foregroundColor(MFColor.textSecondary)
                                }
                                .frame(width: dynamicTypeSize.isAccessibilitySize ? 220 : 144)
                                .padding(.vertical, MFSpacing.xs)
                                .contentShape(Rectangle())
                            }
                            .contextMenu {
                                Button("Copy food") {
                                    FoodLogClipboard.shared.copyFood(entry)
                                }
                                Button("Delete", role: .destructive) {
                                    onDeleteEntry(entry)
                                }
                            }
                            .accessibilityLabel("\(entry.foodName), \(MFFormat.kcal(entry.calories)) calories")
                        }
                    }
                }
            }
        }
        .padding(.vertical, MFSpacing.xs)
    }

    private var timeLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h a"
        var components = DateComponents()
        components.hour = block.hour
        let date = Calendar.current.date(from: components) ?? Date()
        return formatter.string(from: date)
    }

    private var isCurrentHour: Bool {
        Calendar.current.component(.hour, from: Date()) == block.hour
    }

    private var timePill: some View {
        Text(timeLabel)
            .font(MFFont.subheadline.weight(.semibold))
            .foregroundColor(MFColor.textPrimary)
            .padding(.horizontal, MFSpacing.md)
            .padding(.vertical, MFSpacing.sm)
            .background(MFColor.surfaceSunken)
            .clipShape(Capsule())
    }

    private func symbol(for entry: LogEntry) -> String {
        entry.entrySource == .quickAdd ? "wand.and.stars" : "fork.knife"
    }
}

// MARK: - MFFoodIconMapper

/// Heuristic keyword → OpenMoji food-art mapping for timeline thumbnails.
/// (No per-food artwork is stored yet — issue #12 may add it.)
public enum MFFoodIconMapper {
    public static func hex(forName name: String) -> String? {
        let lower = name.lowercased()
        let mapping: [(keywords: [String], hex: String)] = [
            (["chicken", "turkey", "poultry"], MFFoodIconAsset.chickenLeg),
            (["egg"], MFFoodIconAsset.friedEgg),
            (["bread", "toast", "roll", "bagel"], MFFoodIconAsset.bread),
            (["potato"], MFFoodIconAsset.potato),
            (["carrot"], MFFoodIconAsset.carrot),
            (["avocado", "guacamole"], MFFoodIconAsset.avocado),
            (["tomato", "salsa"], MFFoodIconAsset.tomato),
            (["blueberry", "blueberries"], MFFoodIconAsset.blueberries),
            (["strawberry", "strawberries"], MFFoodIconAsset.strawberry),
            (["coffee", "latte", "espresso"], MFFoodIconAsset.coffee),
            (["butter", "margarine"], MFFoodIconAsset.butter),
            (["olive oil", "oil"], MFFoodIconAsset.olive),
        ]
        for item in mapping where item.keywords.contains(where: lower.contains) {
            return item.hex
        }
        return nil
    }
}

#Preview("Timeline block") {
    struct Demo: View {
        var body: some View {
            VStack(spacing: MFSpacing.lg) {
                // Static preview: real blocks need SwiftData models, so we
                // show the header + thumbnail composition directly.
                MFTimeBlockHeader(time: "8 AM", kcal: 381, protein: 10, fat: 23, carbs: 41, onAdd: {})
                HStack(spacing: MFSpacing.md) {
                    MFFoodThumbnail(openmojiHex: MFFoodIconAsset.friedEgg)
                    MFFoodThumbnail(openmojiHex: MFFoodIconAsset.coffee)
                    MFFoodThumbnail(openmojiHex: MFFoodIconAsset.avocado)
                }
            }
            .padding()
            .background(MFColor.background)
            .tint(MFColor.accent)
        }
    }
    return Demo()
}
