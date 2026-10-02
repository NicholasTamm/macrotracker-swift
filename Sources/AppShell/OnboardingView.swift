import SwiftUI
import DesignSystem

// MARK: - OnboardingView

/// First-launch onboarding. Three original intro pages, then straight into
/// the app — no account, no subscription, no trial, no paywall (issue #11
/// is cancelled: every feature ships unlocked and free).
///
/// Copy is original; the look follows the design-system tokens.
public struct OnboardingView: View {
    var onComplete: () -> Void

    public init(onComplete: @escaping () -> Void) {
        self.onComplete = onComplete
    }

    public var body: some View {
        TabView {
            OnboardingPage(
                glyph: AnyView(MFFlameGlyph(size: 64)),
                title: "Know your numbers",
                body: "Log meals in seconds and watch calories, protein, fat, and carbs update in real time."
            )
            OnboardingPage(
                glyph: AnyView(MFStrategyGlyph(size: 64, color: MFColor.accent)),
                title: "Targets that adapt",
                body: "Your nutrition targets adjust automatically as your weight trend and expenditure change — no guesswork, no plateaus you can't explain."
            )
            OnboardingPage(
                glyph: AnyView(MFAppleGlyph(size: 64, color: MFColor.textPrimary)),
                title: "Your data stays yours",
                body: "Everything lives on your device. No account to create, no subscription, no locked features — ever.",
                isLast: true,
                onComplete: onComplete
            )
        }
        .tabViewStyle(.page)
        .indexViewStyle(.page(backgroundDisplayMode: .always))
        .background(MFColor.background)
    }
}

private struct OnboardingPage: View {
    let glyph: AnyView
    let title: String
    let message: String
    var isLast: Bool = false
    var onComplete: () -> Void = {}

    init(glyph: AnyView, title: String, body: String, isLast: Bool = false, onComplete: @escaping () -> Void = {}) {
        self.glyph = glyph
        self.title = title
        self.message = body
        self.isLast = isLast
        self.onComplete = onComplete
    }

    var body: some View {
        VStack(spacing: MFSpacing.xl) {
            Spacer()
            glyph
            Text(title)
                .font(MFFont.title)
                .foregroundColor(MFColor.textPrimary)
                .multilineTextAlignment(.center)
            Text(message)
                .font(MFFont.body)
                .foregroundColor(MFColor.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, MFSpacing.xxxl)
            Spacer()
            if isLast {
                MFButton("Get started", style: .primary, action: onComplete)
                    .padding(.horizontal, MFSpacing.xxl)
            } else {
                // Reserve the button's vertical space so pages align.
                Color.clear.frame(height: 52)
            }
            Spacer().frame(height: MFSpacing.xxxl)
        }
        .padding(.horizontal, MFSpacing.lg)
    }
}

#Preview("Onboarding") {
    OnboardingView(onComplete: {})
        .mfThemed()
}
