import SwiftUI

// MARK: - MFButton

/// Primary action button. Styles match the real app: primary is a solid
/// stadium button (black in light mode, white in dark mode), secondary is a
/// quiet gray pill, destructive is red.
public struct MFButton: View {
    public enum Style { case primary, secondary, destructive }
    public enum Size { case large, medium }

    private let title: String
    private let style: Style
    private let size: Size
    private let icon: String?
    private let isLoading: Bool
    private let action: () -> Void

    public init(
        _ title: String,
        style: Style = .primary,
        size: Size = .large,
        icon: String? = nil,
        isLoading: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.style = style
        self.size = size
        self.icon = icon
        self.isLoading = isLoading
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: MFSpacing.sm) {
                if isLoading {
                    ProgressView()
                        .tint(foregroundColor)
                } else if let icon {
                    Image(systemName: icon)
                        .font(.body.weight(.semibold))
                }
                Text(title)
                    .font(size == .large ? MFFont.bodyBold : MFFont.subheadline.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, size == .large ? MFSpacing.lg : MFSpacing.md)
            .background(backgroundColor)
            .foregroundColor(foregroundColor)
            .clipShape(Capsule())
        }
        .disabled(isLoading)
        .accessibilityLabel(title)
        .accessibilityHint(isLoading ? "Loading" : "")
    }

    private var backgroundColor: Color {
        switch style {
        case .primary: MFColor.buttonPrimary
        case .secondary: MFColor.surfaceSunken
        case .destructive: MFColor.danger
        }
    }

    private var foregroundColor: Color {
        switch style {
        case .primary: MFColor.textOnButtonPrimary
        case .secondary: MFColor.textPrimary
        case .destructive: MFColor.textOnAccent
        }
    }
}

// MARK: - MFIconButton

/// Circular icon button for toolbars, row actions, and timeline "+" buttons.
public struct MFIconButton: View {
    private let icon: String
    private let label: String
    private let tint: Color
    private let fill: Color
    private let action: () -> Void

    public init(
        icon: String,
        label: String,
        tint: Color = MFColor.textPrimary,
        fill: Color = MFColor.surfaceSunken,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.label = label
        self.tint = tint
        self.fill = fill
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.body.weight(.semibold))
                .foregroundColor(tint)
                .frame(width: 36, height: 36)
                .background(fill)
                .clipShape(Circle())
        }
        .accessibilityLabel(label)
    }
}

#Preview("Buttons") {
    VStack(spacing: MFSpacing.md) {
        MFButton("Log foods", style: .primary, icon: "plus") {}
        MFButton("Save changes", style: .secondary, size: .medium) {}
        MFButton("Delete entry", style: .destructive, size: .medium) {}
        MFButton("Syncing", style: .primary, isLoading: true) {}
        HStack {
            MFIconButton(icon: "plus", label: "Add food") {}
            MFIconButton(icon: "barcode.viewfinder", label: "Scan barcode") {}
            MFIconButton(icon: "trash", label: "Delete", tint: MFColor.danger) {}
        }
    }
    .padding()
    .background(MFColor.background)
}

#Preview("Buttons — Dark") {
    VStack(spacing: MFSpacing.md) {
        MFButton("Log foods", style: .primary, icon: "plus") {}
        MFButton("Save changes", style: .secondary, size: .medium) {}
        MFButton("Delete entry", style: .destructive, size: .medium) {}
    }
    .padding()
    .background(MFColor.background)
    .preferredColorScheme(.dark)
}
