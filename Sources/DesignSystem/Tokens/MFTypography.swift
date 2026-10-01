import SwiftUI

/// Semantic type roles for the design system.
///
/// Always prefer these over hardcoded fonts so Dynamic Type scales correctly.
/// Numeric/stat roles use the rounded design for tabular figures.
public enum MFFont {

    // MARK: - Text roles

    public static let largeTitle = Font.largeTitle.weight(.bold)
    public static let title = Font.title.weight(.bold)
    public static let title2 = Font.title2.weight(.semibold)
    public static let title3 = Font.title3.weight(.semibold)
    public static let headline = Font.headline
    public static let body = Font.body
    public static let bodyBold = Font.body.weight(.semibold)
    public static let callout = Font.callout
    public static let subheadline = Font.subheadline
    public static let footnote = Font.footnote
    public static let caption = Font.caption
    public static let caption2 = Font.caption2

    // MARK: - Numeric / stat roles

    /// Hero numbers (ring centers, dashboard totals).
    public static let statHero = Font.system(.largeTitle, design: .rounded).weight(.bold)
    /// Large stat numbers (chart cards, streak counts).
    public static let statLarge = Font.system(.title, design: .rounded).weight(.bold)
    /// Medium stat numbers (row values, meal totals).
    public static let statMedium = Font.system(.title3, design: .rounded).weight(.semibold)
    /// Small stat numbers (badges, chips, slider values).
    public static let statSmall = Font.system(.footnote, design: .rounded).weight(.semibold)
}
