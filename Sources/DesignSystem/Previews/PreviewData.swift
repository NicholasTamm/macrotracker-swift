import SwiftUI

/// Sample data for SwiftUI previews only. Never ship in production.
enum PreviewData {
    static let macros: [MFMacroRing.Macro] = [
        MFMacroRing.Macro(name: "Protein", eaten: 96, target: 150, kcalPerGram: 4, color: MFColor.protein),
        MFMacroRing.Macro(name: "Carbs", eaten: 210, target: 250, kcalPerGram: 4, color: MFColor.carbs),
        MFMacroRing.Macro(name: "Fat", eaten: 58, target: 70, kcalPerGram: 9, color: MFColor.fat),
    ]

    static let barSegments: [MFMacroBar.Segment] = [
        MFMacroBar.Segment(label: "Protein", eatenGrams: 96, targetGrams: 150, kcalPerGram: 4, color: MFColor.protein),
        MFMacroBar.Segment(label: "Carbs", eatenGrams: 210, targetGrams: 250, kcalPerGram: 4, color: MFColor.carbs),
        MFMacroBar.Segment(label: "Fat", eatenGrams: 58, targetGrams: 70, kcalPerGram: 9, color: MFColor.fat),
    ]

    /// 28 days of sample weights trending downward.
    static let weights: [Double] = [
        176.8, 176.2, 177.1, 176.0, 175.6, 176.3, 175.4, 175.9,
        175.1, 174.8, 175.5, 174.6, 174.2, 174.9, 174.0, 173.8,
        174.4, 173.5, 173.2, 173.9, 173.1, 172.8, 173.4, 172.6,
        172.2, 172.9, 172.1, 171.8,
    ]
}
