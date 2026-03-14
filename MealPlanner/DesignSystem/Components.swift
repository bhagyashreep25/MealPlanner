import SwiftUI

// MARK: - Custom Button

struct MPButton: View {
    let title: String
    var icon: String? = nil
    var style: MPButtonStyle = .primary
    var isFullWidth: Bool = false
    let action: () -> Void

    enum MPButtonStyle {
        case primary, secondary, outline, destructive, ghost
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: MPSpacing.sm) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .semibold))
                }
                Text(title)
                    .font(MPTypography.callout(.semibold))
            }
            .padding(.horizontal, MPSpacing.xl)
            .padding(.vertical, MPSpacing.md)
            .frame(maxWidth: isFullWidth ? .infinity : nil)
            .foregroundColor(foregroundColor)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: MPRadius.xl))
            .overlay(
                RoundedRectangle(cornerRadius: MPRadius.xl)
                    .stroke(borderColor, lineWidth: style == .outline ? 1.5 : 0)
            )
        }
        .buttonStyle(.plain)
    }

    private var foregroundColor: Color {
        switch style {
        case .primary: return .white
        case .secondary: return MPColors.primary
        case .outline: return MPColors.primary
        case .destructive: return .white
        case .ghost: return MPColors.primary
        }
    }

    private var backgroundColor: Color {
        switch style {
        case .primary: return MPColors.primary
        case .secondary: return MPColors.primarySoft
        case .outline: return .clear
        case .destructive: return MPColors.error
        case .ghost: return .clear
        }
    }

    private var borderColor: Color {
        switch style {
        case .outline: return MPColors.primary.opacity(0.4)
        default: return .clear
        }
    }
}

// MARK: - Custom Text Field

struct MPTextField: View {
    let placeholder: String
    @Binding var text: String
    var icon: String? = nil
    var keyboardType: UIKeyboardType = .default

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: MPSpacing.md) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 15))
                    .foregroundColor(isFocused ? MPColors.primary : MPColors.textTertiary)
            }
            TextField(placeholder, text: $text)
                .font(MPTypography.body())
                .keyboardType(keyboardType)
                .focused($isFocused)
        }
        .padding(.horizontal, MPSpacing.lg)
        .padding(.vertical, MPSpacing.md)
        .background(MPColors.surfaceSecondary)
        .clipShape(RoundedRectangle(cornerRadius: MPRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: MPRadius.md)
                .stroke(isFocused ? MPColors.primary : Color.clear, lineWidth: 1.5)
        )
        .animation(.easeInOut(duration: 0.2), value: isFocused)
    }
}

// MARK: - Number Field

struct MPNumberField: View {
    let placeholder: String
    @Binding var value: Int
    var icon: String? = nil
    var suffix: String? = nil

    @FocusState private var isFocused: Bool
    @State private var textValue: String = ""

    var body: some View {
        HStack(spacing: MPSpacing.md) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 15))
                    .foregroundColor(isFocused ? MPColors.primary : MPColors.textTertiary)
            }
            TextField(placeholder, text: $textValue)
                .font(MPTypography.body())
                .keyboardType(.numberPad)
                .focused($isFocused)
                .onChange(of: textValue) { _, newValue in
                    value = Int(newValue) ?? 0
                }
            if let suffix = suffix {
                Text(suffix)
                    .font(MPTypography.caption())
                    .foregroundColor(MPColors.textTertiary)
            }
        }
        .padding(.horizontal, MPSpacing.lg)
        .padding(.vertical, MPSpacing.md)
        .background(MPColors.surfaceSecondary)
        .clipShape(RoundedRectangle(cornerRadius: MPRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: MPRadius.md)
                .stroke(isFocused ? MPColors.primary : Color.clear, lineWidth: 1.5)
        )
        .animation(.easeInOut(duration: 0.2), value: isFocused)
        .onAppear {
            textValue = value > 0 ? "\(value)" : ""
        }
    }
}

// MARK: - Card

struct MPCard<Content: View>: View {
    @Environment(\.colorScheme) var colorScheme
    let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        content()
            .background(MPAdaptiveColors.surface(for: colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: MPRadius.lg))
            .shadow(color: MPColors.shadow, radius: 8, x: 0, y: 2)
    }
}

// MARK: - Chip / Tag

struct MPChip: View {
    let label: String
    var isSelected: Bool = false
    var onTap: (() -> Void)? = nil

    var body: some View {
        Text(label)
            .font(MPTypography.caption(.medium))
            .padding(.horizontal, MPSpacing.md)
            .padding(.vertical, MPSpacing.xs + 2)
            .foregroundColor(isSelected ? .white : MPColors.primary)
            .background(isSelected ? MPColors.primary : MPColors.primarySoft)
            .clipShape(Capsule())
            .onTapGesture {
                onTap?()
            }
    }
}

// MARK: - Removable Chip

struct MPRemovableChip: View {
    let label: String
    var onRemove: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: MPSpacing.xs) {
            Text(label)
                .font(MPTypography.caption(.medium))
            if onRemove != nil {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .onTapGesture {
                        onRemove?()
                    }
            }
        }
        .padding(.horizontal, MPSpacing.md)
        .padding(.vertical, MPSpacing.xs + 2)
        .foregroundColor(MPColors.primary)
        .background(MPColors.primarySoft)
        .clipShape(Capsule())
    }
}

// MARK: - Section Header

struct MPSectionHeader: View {
    let title: String
    var action: String? = nil
    var onAction: (() -> Void)? = nil

    var body: some View {
        HStack {
            Text(title)
                .font(MPTypography.headline())
                .foregroundColor(MPColors.textPrimary)
            Spacer()
            if let action = action {
                Button(action: { onAction?() }) {
                    Text(action)
                        .font(MPTypography.callout(.medium))
                        .foregroundColor(MPColors.primary)
                }
            }
        }
    }
}

// MARK: - Empty State

struct MPEmptyState: View {
    let icon: String
    let title: String
    let subtitle: String
    var buttonTitle: String? = nil
    var onAction: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: MPSpacing.lg) {
            Image(systemName: icon)
                .font(.system(size: 56, weight: .light))
                .foregroundColor(MPColors.primaryMuted)

            VStack(spacing: MPSpacing.sm) {
                Text(title)
                    .font(MPTypography.title2())
                    .foregroundColor(MPColors.textPrimary)
                Text(subtitle)
                    .font(MPTypography.body())
                    .foregroundColor(MPColors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            if let buttonTitle = buttonTitle, let onAction = onAction {
                MPButton(title: buttonTitle, icon: "plus", action: onAction)
                    .padding(.top, MPSpacing.sm)
            }
        }
        .padding(MPSpacing.xxl)
    }
}

// MARK: - Floating Action Button

struct MPFloatingButton: View {
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(MPColors.primary)
                .clipShape(Circle())
                .shadow(color: MPColors.primary.opacity(0.35), radius: 12, x: 0, y: 4)
        }
    }
}

// MARK: - Search Bar

struct MPSearchBar: View {
    @Binding var text: String
    var placeholder: String = "Search recipes..."

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: MPSpacing.md) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(isFocused ? MPColors.primary : MPColors.textTertiary)

            TextField(placeholder, text: $text)
                .font(MPTypography.body())
                .focused($isFocused)

            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(MPColors.textTertiary)
                }
            }
        }
        .padding(.horizontal, MPSpacing.lg)
        .padding(.vertical, MPSpacing.md)
        .background(MPColors.surfaceSecondary)
        .clipShape(RoundedRectangle(cornerRadius: MPRadius.xl))
        .animation(.easeInOut(duration: 0.2), value: isFocused)
    }
}
