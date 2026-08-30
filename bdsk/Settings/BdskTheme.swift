import SwiftUI

enum BdskTheme {
    static let bgBase = Color(hex: 0x2A2540)
    static let surface = Color(hex: 0x352F4D)
    static let surfaceRaised = Color(hex: 0x3E3858)
    static let stroke = Color(hex: 0x4A4466)
    static let lavender = Color(hex: 0xB9B5DF)
    static let lavenderDeep = Color(hex: 0x8F8ABD)
    static let pink = Color(hex: 0xF2C3CB)
    static let pinkDeep = Color(hex: 0xD98B9A)
    static let pearl = Color(hex: 0xF1ECEC)
    static let pearlMuted = Color(hex: 0xC9C3CF)
    static let cursorGlow = Color(hex: 0xFFE6C2)
    static let shadow = Color(red: 16 / 255, green: 12 / 255, blue: 30 / 255).opacity(0.45)

    static let radiusCard: CGFloat = 28
    static let radiusField: CGFloat = 20
    static let radiusChip: CGFloat = 14
    static let radiusPebble: CGFloat = 40

    static func titleFont() -> Font {
        .system(size: 20, weight: .semibold, design: .rounded)
    }

    static func bodyFont() -> Font {
        .system(size: 16, weight: .regular, design: .rounded)
    }

    static func labelFont() -> Font {
        .system(size: 14, weight: .medium, design: .rounded)
    }

    static func captionFont() -> Font {
        .system(size: 12, weight: .medium, design: .rounded)
    }
}

extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}

struct CeramicCard<Content: View>: View {
    var padding: CGFloat = 24
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(BdskTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: BdskTheme.radiusCard, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: BdskTheme.radiusCard, style: .continuous)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
            .shadow(color: BdskTheme.shadow, radius: 12, x: 0, y: 6)
    }
}

struct BdskField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var focus: FocusState<Bool>.Binding? = nil

    private var isFocused: Bool {
        focus?.wrappedValue ?? false
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(BdskTheme.captionFont())
                .foregroundStyle(BdskTheme.pearlMuted)
            TextField("", text: $text, prompt: Text(placeholder).foregroundStyle(BdskTheme.pearlMuted.opacity(0.7)))
                .textFieldStyle(.plain)
                .font(BdskTheme.bodyFont())
                .foregroundStyle(BdskTheme.pearl)
                .padding(.horizontal, 16)
                .frame(height: 52)
                .background(BdskTheme.surfaceRaised)
                .clipShape(RoundedRectangle(cornerRadius: BdskTheme.radiusField, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: BdskTheme.radiusField, style: .continuous)
                        .stroke(isFocused ? BdskTheme.lavender : BdskTheme.stroke, lineWidth: isFocused ? 1.5 : 1)
                )
                .modifier(OptionalBoolFocus(focus: focus))
        }
    }
}

private struct OptionalBoolFocus: ViewModifier {
    var focus: FocusState<Bool>.Binding?

    @ViewBuilder
    func body(content: Content) -> some View {
        if let focus {
            content.focused(focus)
        } else {
            content
        }
    }
}

struct BdskPrimaryButton: View {
    let title: String
    var enabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(BdskTheme.labelFont())
                .foregroundStyle(enabled ? BdskTheme.bgBase : BdskTheme.pearlMuted)
                .frame(minWidth: 88, minHeight: 44)
                .padding(.horizontal, 16)
                .background(enabled ? BdskTheme.pearl : BdskTheme.surfaceRaised)
                .clipShape(RoundedRectangle(cornerRadius: BdskTheme.radiusField, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}

struct BdskGhostButton: View {
    let title: String
    var role: ButtonRole?
    let action: () -> Void

    var body: some View {
        Button(role: role, action: action) {
            Text(title)
                .font(BdskTheme.labelFont())
                .foregroundStyle(role == .destructive ? BdskTheme.pinkDeep : BdskTheme.lavender)
                .frame(minHeight: 36)
                .padding(.horizontal, 10)
        }
        .buttonStyle(.plain)
    }
}
