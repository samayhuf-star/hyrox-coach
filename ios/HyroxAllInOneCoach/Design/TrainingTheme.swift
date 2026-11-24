import SwiftUI
import UIKit

enum TrainingTheme {
    static let background = adaptive(0x0B0B0E, dark: 0x0B0B0E)
    static let surface = adaptive(0x17171C, dark: 0x17171C)
    static let border = adaptive(0x2B2B33, dark: 0x2B2B33)
    static let primary = adaptive(0xF4F4F6, dark: 0xF4F4F6)
    static let secondary = adaptive(0xA7A7B3, dark: 0xA7A7B3)
    static let accent = adaptive(0x8B7BFF, dark: 0x8B7BFF)
    /// Second accent: strength work, ticks and highlights.
    static let mint = adaptive(0x5EEAD4, dark: 0x5EEAD4)
    /// Text and icons that sit on an accent fill.
    static let onAccent = adaptive(0x0B0B0E, dark: 0x0B0B0E)
    static let blue = adaptive(0x75CFFF, dark: 0x75CFFF)
    static let lavender = adaptive(0x8B7BFF, dark: 0x8B7BFF)
    static let inset = adaptive(0x111116, dark: 0x111116)
    static let accentSoft = adaptive(0x23213F, dark: 0x23213F)
    static let heroBase = adaptive(0x17171C, dark: 0x17171C)
    static let glowViolet = adaptive(0x2A2550, dark: 0x2A2550)
    static let glowBlue = adaptive(0x1E1E26, dark: 0x1E1E26)
    static let shadow = adaptive(0x000000, dark: 0x000000)
    static let actionGradient = LinearGradient(colors: [Color(hex: 0x8B7BFF), Color(hex: 0x8B7BFF)],
                                              startPoint: .topLeading, endPoint: .bottomTrailing)

    private static func adaptive(_ light: UInt32, dark: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: CGFloat((hex >> 16) & 255) / 255,
                           green: CGFloat((hex >> 8) & 255) / 255,
                           blue: CGFloat(hex & 255) / 255, alpha: 1)
        })
    }
}

extension Font {
    /// Condensed display face for headings and buttons. Scales with Dynamic Type.
    static func trainingDisplay(_ style: Font.TextStyle = .largeTitle) -> Font {
        let size: CGFloat
        switch style {
        case .largeTitle: size = 44
        case .title: size = 36
        case .title2: size = 28
        case .title3: size = 22
        default: size = 20
        }
        return .custom("BarlowCondensed-Bold", size: size, relativeTo: style)
    }
}

private extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 255) / 255,
                  green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255)
    }
}

extension View {
    func trainingPanel(padding: CGFloat = 20) -> some View {
        self.padding(padding)
            .background(TrainingTheme.surface, in: RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(TrainingTheme.border, lineWidth: 1))
    }
    func trainingScreen() -> some View {
        self.background(TrainingTheme.background)
            .foregroundStyle(TrainingTheme.primary)
            .tint(TrainingTheme.accent)
            .preferredColorScheme(.dark)
    }
}

struct TrainingButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var prominent = true
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.trainingDisplay(.title3))
            .textCase(.uppercase)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, minHeight: 56)
            .padding(.horizontal, 18)
            .padding(.vertical, 3)
            .foregroundStyle(prominent ? TrainingTheme.onAccent : TrainingTheme.primary)
            .background {
                if prominent {
                    Capsule().fill(TrainingTheme.accent)
                } else {
                    Capsule().fill(Color.clear)
                }
            }
            .overlay(Capsule().strokeBorder(prominent ? Color.clear : TrainingTheme.border, lineWidth: 1.5))
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct Eyebrow: View {
    let text: String
    var color: Color = TrainingTheme.secondary
    var body: some View {
        Text(text.uppercased())
            .font(.caption.weight(.semibold))
            .tracking(1.5)
            .foregroundStyle(color)
    }
}

struct StatusPill: View {
    let text: String
    var symbol: String?
    var body: some View {
        HStack(spacing: 5) {
            if let symbol { Image(systemName: symbol).accessibilityHidden(true) }
            Text(text)
        }
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .foregroundStyle(TrainingTheme.mint)
        .background(TrainingTheme.mint.opacity(0.10), in: Capsule())
        .accessibilityElement(children: .combine)
    }
}

struct SectionHeading: View {
    let title: String
    var subtitle: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.title3.weight(.semibold)).accessibilityAddTraits(.isHeader)
            if let subtitle { Text(subtitle).font(.subheadline).foregroundStyle(TrainingTheme.secondary) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SymbolTile: View {
    let symbol: String
    var body: some View {
        Image(systemName: symbol)
            .font(.title3)
            .foregroundStyle(TrainingTheme.mint)
            .frame(width: 48, height: 48)
            .background(TrainingTheme.mint.opacity(0.08), in: RoundedRectangle(cornerRadius: 13))
            .accessibilityHidden(true)
    }
}

struct ChoiceRow: View {
    let title: String
    var detail: String? = nil
    let selected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.body.weight(.medium)).foregroundStyle(TrainingTheme.primary)
                    if let detail { Text(detail).font(.subheadline).foregroundStyle(TrainingTheme.secondary) }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.title2).foregroundStyle(selected ? TrainingTheme.mint : TrainingTheme.secondary)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .frame(minHeight: 56)
            .background(selected ? TrainingTheme.mint.opacity(0.06) : TrainingTheme.surface, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(selected ? TrainingTheme.mint.opacity(0.4) : TrainingTheme.border))
        }
        .buttonStyle(TrainingCardButtonStyle())
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

struct SafetyNote: View {
    var body: some View {
        Label("Train at your pace. Take extra rest whenever you need it. Stop if you feel pain or dizziness.", systemImage: "heart")
            .font(.subheadline)
            .foregroundStyle(TrainingTheme.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}
