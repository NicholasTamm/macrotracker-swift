import SwiftUI
import DesignSystem

// MARK: - MFLaunchScreen

/// Branded launch screen (issue #12; the system-default splash was the
/// intentional placeholder from #2).
///
/// Shown by `AppRootView` while the service graph (`DataStore`, tracking,
/// watch/snapshot/notification wiring) builds at launch — typically a
/// fraction of a second. The OS-level splash is the `UILaunchScreen`
/// dictionary in Info.plist (background `LaunchBackground`, centered
/// `LaunchLogo`); this view continues the same branding into the app so
/// there is no visual snap between the two.
public struct MFLaunchScreen: View {
    public init() {}

    public var body: some View {
        ZStack {
            MFColor.background
                .ignoresSafeArea()

            VStack(spacing: MFSpacing.xl) {
                // Original macro-ring mark: four macro arcs on the brand
                // background, echoing the app icon.
                MFLaunchMark()
                    .frame(width: 120, height: 120)
                    .accessibilityHidden(true)

                ProgressView()
                    .tint(MFColor.textSecondary)
                    .accessibilityLabel("Loading")
            }
        }
    }
}

// MARK: - MFLaunchMark

/// Original launch mark: a macro ring built from the four macro colors
/// (blue calories, coral protein, yellow fat, green carbs) drawn as arcs.
/// Deliberately drawn in code — no image assets, no copied artwork.
struct MFLaunchMark: View {
    var body: some View {
        ZStack {
            ringSegment(color: MFColor.calories, from: 0.00, to: 0.30)
            ringSegment(color: MFColor.protein, from: 0.33, to: 0.55)
            ringSegment(color: MFColor.fat, from: 0.58, to: 0.75)
            ringSegment(color: MFColor.carbs, from: 0.78, to: 0.97)
            MFFlameGlyph(size: 44, color: MFColor.calories)
                .accessibilityHidden(true)
        }
        .accessibilityHidden(true)
    }

    private func ringSegment(color: Color, from: Double, to: Double) -> some View {
        Circle()
            .trim(from: from, to: to)
            .stroke(color, style: StrokeStyle(lineWidth: 14, lineCap: .round))
            .rotationEffect(.degrees(-90))
    }
}

#Preview("Launch screen") {
    MFLaunchScreen()
        .mfThemed()
}
