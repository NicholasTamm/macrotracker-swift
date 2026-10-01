import SwiftUI

// MARK: - MFBanner

/// Inline notice banner: info / success / warning / danger.
public struct MFBanner: View {
    public enum Kind {
        case info, success, warning, danger

        var icon: String {
            switch self {
            case .info: "info.circle.fill"
            case .success: "checkmark.circle.fill"
            case .warning: "exclamationmark.triangle.fill"
            case .danger: "xmark.octagon.fill"
            }
        }

        var tint: Color {
            switch self {
            case .info: MFColor.accent
            case .success: MFColor.success
            case .warning: MFColor.warning
            case .danger: MFColor.danger
            }
        }
    }

    private let kind: Kind
    private let title: String
    private let message: String?
    private let actionTitle: String?
    private let onAction: (() -> Void)?
    private let onDismiss: (() -> Void)?

    public init(
        kind: Kind = .info,
        title: String,
        message: String? = nil,
        actionTitle: String? = nil,
        onAction: (() -> Void)? = nil,
        onDismiss: (() -> Void)? = nil
    ) {
        self.kind = kind
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.onAction = onAction
        self.onDismiss = onDismiss
    }

    public var body: some View {
        HStack(alignment: .top, spacing: MFSpacing.md) {
            Image(systemName: kind.icon)
                .foregroundColor(kind.tint)
                .font(.title3)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: MFSpacing.xs) {
                Text(title)
                    .font(MFFont.subheadline.weight(.semibold))
                    .foregroundColor(MFColor.textPrimary)
                if let message {
                    Text(message)
                        .font(MFFont.footnote)
                        .foregroundColor(MFColor.textSecondary)
                }
                if let actionTitle, let onAction {
                    Button(actionTitle, action: onAction)
                        .font(MFFont.footnote.weight(.semibold))
                        .foregroundColor(kind.tint)
                }
            }
            Spacer()
            if let onDismiss {
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.footnote.weight(.semibold))
                        .foregroundColor(MFColor.textTertiary)
                }
                .accessibilityLabel("Dismiss")
            }
        }
        .padding(MFSpacing.md)
        .background(kind.tint.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: MFRadii.md))
        .overlay {
            RoundedRectangle(cornerRadius: MFRadii.md)
                .stroke(kind.tint.opacity(0.25), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(message ?? "")")
    }
}

// MARK: - MFToast

/// Floating bottom toast. Present with the `mfToast` modifier.
public struct MFToast: View {
    private let message: String
    private let kind: MFBanner.Kind

    public init(message: String, kind: MFBanner.Kind = .info) {
        self.message = message
        self.kind = kind
    }

    public var body: some View {
        HStack(spacing: MFSpacing.sm) {
            Image(systemName: kind.icon)
                .foregroundColor(kind.tint)
                .accessibilityHidden(true)
            Text(message)
                .font(MFFont.subheadline.weight(.medium))
                .foregroundColor(MFColor.textPrimary)
        }
        .padding(.horizontal, MFSpacing.lg)
        .padding(.vertical, MFSpacing.md)
        .background(MFColor.surfaceElevated)
        .clipShape(Capsule())
        .mfRaisedShadow()
        .accessibilityLabel(message)
    }
}

public extension View {
    /// Presents a toast that auto-dismisses after `duration` seconds.
    func mfToast(
        isPresented: Binding<Bool>,
        message: String,
        kind: MFBanner.Kind = .info,
        duration: Duration = .seconds(3)
    ) -> some View {
        overlay(alignment: .bottom) {
            if isPresented.wrappedValue {
                MFToast(message: message, kind: kind)
                    .padding(.bottom, MFSpacing.xxl)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .task {
                        try? await Task.sleep(for: duration)
                        withAnimation { isPresented.wrappedValue = false }
                    }
            }
        }
        .animation(.spring(response: 0.35), value: isPresented.wrappedValue)
    }
}

// MARK: - MFSheetContainer

/// Bottom-sheet chrome (grabber + surface). Use inside `.sheet { }` with `mfSheetStyle()`.
public struct MFSheetContainer<Content: View>: View {
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(MFColor.separator)
                .frame(width: 36, height: 5)
                .padding(.top, MFSpacing.sm)
                .padding(.bottom, MFSpacing.md)
                .accessibilityHidden(true)
            content
        }
        .padding(.horizontal, MFSpacing.lg)
        .padding(.bottom, MFSpacing.xl)
        .frame(maxWidth: .infinity)
        .background(MFColor.surfaceElevated)
    }
}

public extension View {
    /// Standard sheet presentation for the design system.
    func mfSheetStyle() -> some View {
        self
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.hidden) // custom grabber in MFSheetContainer
            .presentationCornerRadius(MFRadii.xl)
            .presentationBackground(MFColor.surfaceElevated)
    }
}

// MARK: - MFEmptyState

/// Friendly placeholder for empty lists and zero states.
public struct MFEmptyState: View {
    private let icon: String
    private let title: String
    private let message: String
    private let actionTitle: String?
    private let onAction: (() -> Void)?

    public init(
        icon: String,
        title: String,
        message: String,
        actionTitle: String? = nil,
        onAction: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.onAction = onAction
    }

    public var body: some View {
        VStack(spacing: MFSpacing.md) {
            Image(systemName: icon)
                .font(.largeTitle)
                .foregroundColor(MFColor.accent)
                .frame(width: 72, height: 72)
                .background(MFColor.accentSoft)
                .clipShape(Circle())
                .accessibilityHidden(true)
            Text(title)
                .font(MFFont.title3)
                .foregroundColor(MFColor.textPrimary)
            Text(message)
                .font(MFFont.subheadline)
                .foregroundColor(MFColor.textSecondary)
                .multilineTextAlignment(.center)
            if let actionTitle, let onAction {
                MFButton(actionTitle, style: .secondary, size: .medium, action: onAction)
                    .frame(maxWidth: 240)
            }
        }
        .padding(MFSpacing.xxl)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(message)")
    }
}

// MARK: - Skeleton

/// Shimmering placeholder. Apply to any view while its content loads.
public struct MFSkeletonModifier: ViewModifier {
    @State private var isAnimating = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public func body(content: Content) -> some View {
        let placeholder = content.redacted(reason: .placeholder)
        placeholder
            .overlay {
                LinearGradient(
                    gradient: Gradient(colors: [.clear, Color.white.opacity(0.45), .clear]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .rotationEffect(.degrees(12))
                .scaleEffect(1.6)
                .offset(x: isAnimating ? 180 : -180)
                .mask(placeholder)
                .opacity(reduceMotion ? 0 : 1)
            }
            .accessibilityHidden(true)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                    isAnimating = true
                }
            }
    }
}

public extension View {
    func mfSkeleton() -> some View {
        modifier(MFSkeletonModifier())
    }
}

/// Example skeleton for a food-log row while loading.
public struct MFFoodRowSkeleton: View {
    public init() {}
    public var body: some View {
        HStack(spacing: MFSpacing.md) {
            RoundedRectangle(cornerRadius: MFRadii.sm)
                .frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: MFSpacing.xs) {
                RoundedRectangle(cornerRadius: 4).frame(width: 140, height: 14)
                RoundedRectangle(cornerRadius: 4).frame(width: 90, height: 12)
            }
            Spacer()
            RoundedRectangle(cornerRadius: 4).frame(width: 48, height: 16)
        }
        .mfSkeleton()
    }
}

#Preview("Overlays") {
    struct Demo: View {
        @State private var showToast = true
        var body: some View {
            ScrollView {
                VStack(spacing: MFSpacing.lg) {
                    MFBanner(kind: .info, title: "Check-in due", message: "Weigh in to keep your expenditure estimate accurate.", actionTitle: "Log weight", onAction: {}, onDismiss: {})
                    MFBanner(kind: .success, title: "Synced with Apple Health", message: "30 days of history imported.")
                    MFBanner(kind: .warning, title: "Weigh-in reminder", message: "Log your weight today to keep your trend accurate.")
                    MFEmptyState(icon: "fork.knife", title: "Nothing logged yet", message: "Search the food database or scan a barcode to log your first meal.", actionTitle: "Log food", onAction: {})
                    MFFoodRowSkeleton()
                    MFFoodRowSkeleton()
                }
                .padding()
            }
            .background(MFColor.background)
            .mfToast(isPresented: $showToast, message: "Meal copied to today", kind: .success)
        }
    }
    return Demo()
}
