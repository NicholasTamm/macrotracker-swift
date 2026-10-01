import SwiftUI

// MARK: - MFFlame

/// Original calories-flame artwork for the design system.
///
/// Drawn in-house (unit 100×100, y-down): a single lick leaning right with a
/// hooked tip, a left notch, and a rounded base. Rendered via
/// ``MFFlameGlyph`` — never via emoji or `flame.fill`.
public struct MFFlame: Shape {
    public init() {}

    public func path(in rect: CGRect) -> Path {
        let sx = rect.width / 100
        let sy = rect.height / 100
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * sx, y: rect.minY + y * sy)
        }
        var path = Path()
        path.move(to: p(36, 90))
        path.addCurve(to: p(22, 58), control1: p(26, 84), control2: p(20, 72))
        path.addCurve(to: p(38, 38), control1: p(24, 46), control2: p(30, 40))
        path.addCurve(to: p(34, 24), control1: p(34, 34), control2: p(32, 30))
        path.addCurve(to: p(48, 12), control1: p(36, 18), control2: p(42, 14))
        path.addCurve(to: p(64, 2), control1: p(54, 10), control2: p(58, 6))
        path.addCurve(to: p(68, 18), control1: p(70, 4), control2: p(72, 10))
        path.addCurve(to: p(72, 38), control1: p(64, 26), control2: p(66, 30))
        path.addCurve(to: p(76, 72), control1: p(78, 48), control2: p(80, 60))
        path.addCurve(to: p(52, 90), control1: p(72, 84), control2: p(62, 90))
        path.addCurve(to: p(36, 90), control1: p(46, 90), control2: p(40, 90))
        path.closeSubpath()
        return path
    }
}

// MARK: - MFFlameGlyph

/// Sized, tinted flame glyph. Calories contexts use the default
/// calories-blue; the streak cell tints it yellow.
public struct MFFlameGlyph: View {
    private let size: CGFloat
    private let color: Color

    public init(size: CGFloat = 14, color: Color = MFColor.calories) {
        self.size = size
        self.color = color
    }

    public var body: some View {
        MFFlame()
            .fill(color)
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

// MARK: - MFApple

/// Original apple silhouette for the Food Log tab icon (unit 100×100):
/// body with a top dip, stem, and leaf.
public struct MFApple: Shape {
    public init() {}

    public func path(in rect: CGRect) -> Path {
        let sx = rect.width / 100
        let sy = rect.height / 100
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * sx, y: rect.minY + y * sy)
        }
        var path = Path()
        // Body.
        path.move(to: p(50, 38))
        path.addCurve(to: p(26, 60), control1: p(34, 30), control2: p(24, 42))
        path.addCurve(to: p(50, 90), control1: p(28, 78), control2: p(40, 90))
        path.addCurve(to: p(74, 60), control1: p(60, 90), control2: p(72, 78))
        path.addCurve(to: p(50, 38), control1: p(76, 42), control2: p(66, 30))
        path.closeSubpath()
        // Stem.
        path.move(to: p(49, 34))
        path.addCurve(to: p(53, 13), control1: p(49, 26), control2: p(50, 20))
        path.addLine(to: p(57, 15))
        path.addCurve(to: p(53, 34), control1: p(54, 21), control2: p(53, 27))
        path.closeSubpath()
        // Leaf.
        path.move(to: p(55, 22))
        path.addCurve(to: p(86, 15), control1: p(63, 10), control2: p(77, 8))
        path.addCurve(to: p(55, 22), control1: p(78, 25), control2: p(63, 28))
        path.closeSubpath()
        return path
    }
}

// MARK: - MFAppleGlyph

public struct MFAppleGlyph: View {
    private let size: CGFloat
    private let color: Color

    public init(size: CGFloat = 24, color: Color = MFColor.textPrimary) {
        self.size = size
        self.color = color
    }

    public var body: some View {
        MFApple()
            .fill(color)
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

// MARK: - MFStrategyGlyph

/// Original Strategy-tab artwork (unit 100×100): three nodes joined by
/// links, matching the real app's Strategy icon.
public struct MFStrategyGlyph: View {
    private let size: CGFloat
    private let color: Color

    public init(size: CGFloat = 24, color: Color = MFColor.textPrimary) {
        self.size = size
        self.color = color
    }

    public var body: some View {
        Canvas { context, size in
            let s = min(size.width, size.height) / 100
            let nodes = [CGPoint(x: 28 * s, y: 32 * s),
                         CGPoint(x: 72 * s, y: 28 * s),
                         CGPoint(x: 50 * s, y: 72 * s)]
            for (a, b) in [(nodes[0], nodes[1]), (nodes[0], nodes[2]), (nodes[1], nodes[2])] {
                var line = Path()
                line.move(to: a)
                line.addLine(to: b)
                context.stroke(line, with: .color(color), lineWidth: 5 * s)
            }
            for n in nodes {
                var dot = Path()
                dot.addEllipse(in: CGRect(x: n.x - 9 * s, y: n.y - 9 * s,
                                          width: 18 * s, height: 18 * s))
                context.fill(dot, with: .color(color))
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

// MARK: - MFMacroBadge

/// Badge rendered beside a mini-bar value: the calories flame or a
/// P / F / C letter. Position (leading/trailing) is set per surface via
/// ``MFMacroBadgePosition`` — the timeline strip leads, the plate header
/// trails (see `ref-timeline-log.png`, `ref-your-plate-help.png`).
public enum MFMacroBadge: Equatable {
    case flame
    case letter(String)
}

// MARK: - MFIconSpec / MFIconCatalog

/// One entry of the project's icon set: display name, category, source
/// (SF Symbol name or custom vector view), and where it is used.
public struct MFIconSpec: Identifiable {
    public let id = UUID()
    public let name: String
    public let category: String
    public let source: String
    public let usedIn: String

    public init(name: String, category: String, source: String, usedIn: String) {
        self.name = name
        self.category = category
        self.source = source
        self.usedIn = usedIn
    }
}

/// The complete, approved icon set. Tab-bar icons marked "(planned)" are
/// defined here for the issue #2 scaffold to consume.
public enum MFIconCatalog {
    public static let all: [MFIconSpec] = [
        // Tab bar
        MFIconSpec(name: "Dashboard", category: "Tab bar",
                   source: "SF Symbol: square.grid.2x2",
                   usedIn: "Dashboard tab (planned)"),
        MFIconSpec(name: "Food Log", category: "Tab bar",
                   source: "Custom vector: MFAppleGlyph",
                   usedIn: "Food Log tab (planned)"),
        MFIconSpec(name: "Quick Log", category: "Tab bar",
                   source: "SF Symbol: plus",
                   usedIn: "Center log button (planned)"),
        MFIconSpec(name: "Strategy", category: "Tab bar",
                   source: "Custom vector: MFStrategyGlyph",
                   usedIn: "Strategy tab (planned)"),
        MFIconSpec(name: "More", category: "Tab bar",
                   source: "SF Symbol: ellipsis.circle",
                   usedIn: "More tab (planned)"),

        // Macros & nutrients
        MFIconSpec(name: "Calories", category: "Macros & nutrients",
                   source: "Custom vector: MFFlameGlyph (calories-blue)",
                   usedIn: "Timeline header, plate sheet, food rows"),
        MFIconSpec(name: "Protein / Fat / Carbs", category: "Macros & nutrients",
                   source: "Custom vector: MFMacroLetterBadge",
                   usedIn: "Timeline totals, plate sheet"),
        MFIconSpec(name: "Micronutrients", category: "Macros & nutrients",
                   source: "SF Symbol: pill.fill",
                   usedIn: "Micro rows (issue #8)"),
        MFIconSpec(name: "Expenditure", category: "Macros & nutrients",
                   source: "SF Symbol: bolt.fill",
                   usedIn: "Expenditure card (issue #8)"),
        MFIconSpec(name: "Brand mark", category: "Macros & nutrients",
                   source: "Custom vector: MFMacroRing",
                   usedIn: "Macro ring header / brand"),

        // Food log
        MFIconSpec(name: "Search", category: "Food log",
                   source: "SF Symbol: magnifyingglass",
                   usedIn: "Food search field"),
        MFIconSpec(name: "Barcode scan", category: "Food log",
                   source: "SF Symbol: barcode.viewfinder",
                   usedIn: "Scan action (issue #5)"),
        MFIconSpec(name: "Label OCR", category: "Food log",
                   source: "SF Symbol: text.viewfinder",
                   usedIn: "Nutrition-label capture (issue #5)"),
        MFIconSpec(name: "Photo log", category: "Food log",
                   source: "SF Symbol: camera.viewfinder",
                   usedIn: "AI photo logging (issue #5)"),
        MFIconSpec(name: "Voice log", category: "Food log",
                   source: "SF Symbol: mic.fill",
                   usedIn: "Voice logging (issue #5)"),
        MFIconSpec(name: "Quick add", category: "Food log",
                   source: "SF Symbol: wand.and.stars",
                   usedIn: "Quick-add action"),
        MFIconSpec(name: "Recipe import", category: "Food log",
                   source: "SF Symbol: book.pages",
                   usedIn: "Recipe import (issue #5)"),
        MFIconSpec(name: "Library", category: "Food log",
                   source: "SF Symbol: books.vertical",
                   usedIn: "Food library action"),
        MFIconSpec(name: "Food (generic)", category: "Food log",
                   source: "SF Symbol: fork.knife",
                   usedIn: "MFFoodIcon fallback"),
        MFIconSpec(name: "Verified", category: "Food log",
                   source: "SF Symbol: checkmark.seal.fill",
                   usedIn: "Verified food badge"),

        // Tracking
        MFIconSpec(name: "Weight", category: "Tracking",
                   source: "SF Symbol: scalemass",
                   usedIn: "Weight tracking (issue #7)"),
        MFIconSpec(name: "Measurements", category: "Tracking",
                   source: "SF Symbol: ruler",
                   usedIn: "Body measurements (issue #7)"),
        MFIconSpec(name: "Progress photos", category: "Tracking",
                   source: "SF Symbol: photo",
                   usedIn: "Progress-photo tile"),
        MFIconSpec(name: "Streak", category: "Tracking",
                   source: "Custom vector: MFFlameGlyph (yellow)",
                   usedIn: "Habit streak cell"),
        MFIconSpec(name: "Weight trend", category: "Tracking",
                   source: "SF Symbol: chart.line.uptrend.xyaxis",
                   usedIn: "Progress tab (planned)"),

        // System
        MFIconSpec(name: "Add", category: "System",
                   source: "SF Symbol: plus",
                   usedIn: "MFIconButton add buttons"),
        MFIconSpec(name: "Close", category: "System",
                   source: "SF Symbol: xmark",
                   usedIn: "Dismiss buttons, plate sheet"),
        MFIconSpec(name: "Delete", category: "System",
                   source: "SF Symbol: trash",
                   usedIn: "MFIconButton destructive"),
        MFIconSpec(name: "Banner: info", category: "System",
                   source: "SF Symbol: info.circle.fill",
                   usedIn: "MFBanner / MFToast"),
        MFIconSpec(name: "Banner: success", category: "System",
                   source: "SF Symbol: checkmark.circle.fill",
                   usedIn: "MFBanner / MFToast"),
        MFIconSpec(name: "Banner: warning", category: "System",
                   source: "SF Symbol: exclamationmark.triangle.fill",
                   usedIn: "MFBanner / MFToast"),
        MFIconSpec(name: "Banner: danger", category: "System",
                   source: "SF Symbol: xmark.octagon.fill",
                   usedIn: "MFBanner / MFToast"),
        MFIconSpec(name: "Trend up / down", category: "System",
                   source: "SF Symbol: arrow.up.right / arrow.down.right",
                   usedIn: "Delta readouts"),
    ]
}

#Preview("Icons") {
    ScrollView {
        VStack(alignment: .leading, spacing: MFSpacing.md) {
            Text("MFFlameGlyph")
                .font(MFFont.headline).foregroundColor(MFColor.textPrimary)
            HStack(spacing: MFSpacing.lg) {
                MFFlameGlyph(size: 16)
                MFFlameGlyph(size: 24)
                MFFlameGlyph(size: 40)
                MFFlameGlyph(size: 24, color: MFColor.carbs)
            }
            Text("MFAppleGlyph · MFStrategyGlyph")
                .font(MFFont.headline).foregroundColor(MFColor.textPrimary)
            HStack(spacing: MFSpacing.lg) {
                MFAppleGlyph(size: 32)
                MFStrategyGlyph(size: 32)
            }
            Text("MFMacroBadge")
                .font(MFFont.headline).foregroundColor(MFColor.textPrimary)
            HStack(spacing: MFSpacing.md) {
                MFMacroMiniBar(eaten: 770, target: 2446, color: MFColor.calories, badge: .flame, isKcal: true)
                MFMacroMiniBar(eaten: 29, target: 107, color: MFColor.protein, badge: .letter("P"))
            }
        }
        .padding()
    }
    .background(MFColor.background)
}
