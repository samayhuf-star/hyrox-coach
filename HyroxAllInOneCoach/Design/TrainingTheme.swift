import SwiftUI
import UIKit

enum TrainingTheme {
    static let background = adaptive(0xF6F8FC, dark: 0x10182C)
    static let surface = adaptive(0xFFFFFF, dark: 0x19243B)
    static let border = adaptive(0xDFE5F0, dark: 0x34425E)
    static let primary = adaptive(0x0A2540, dark: 0xF3F5FF)
    static let secondary = adaptive(0x52647A, dark: 0xAFBED4)
    static let accent = adaptive(0x554BE3, dark: 0xA69FFF)
    static let mint = accent
    static let blue = adaptive(0x196FAD, dark: 0x75CFFF)
    static let lavender = adaptive(0x8B80F9, dark: 0xBDB4FF)
    static let inset = adaptive(0xF1F4FA, dark: 0x111D33)
    static let accentSoft = adaptive(0xEEEDFF, dark: 0x2A2851)
    static let heroBase = adaptive(0xF0F2FF, dark: 0x202D4C)
    static let glowViolet = adaptive(0xDAD5FF, dark: 0x473A7B)
    static let glowBlue = adaptive(0xB9E8FF, dark: 0x1B5479)
    static let shadow = adaptive(0x243F70, dark: 0x000815)
    static let actionGradient = LinearGradient(colors: [Color(hex: 0x635BFF), Color(hex: 0x5145CD)],
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

private extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 255) / 255,
                  green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255)
    }
}

extension View {
    func trainingPanel(padding: CGFloat = 20) -> some View {
        self.padding(padding)
            .background(TrainingTheme.surface, in: RoundedRectangle(cornerRadius: 24))
            .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(TrainingTheme.border, lineWidth: 1))
            .shadow(color: TrainingTheme.shadow.opacity(0.045), radius: 16, x: 0, y: 6)
    }
    func trainingScreen() -> some View {
        self.background(TrainingTheme.background)
            .foregroundStyle(TrainingTheme.primary)
            .tint(TrainingTheme.accent)
    }
}

struct TrainingButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var prominent = true
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, minHeight: 56)
            .padding(.horizontal, 14)
            .padding(.vertical, 3)
            .foregroundStyle(prominent ? Color.white : TrainingTheme.primary)
            .background {
                if prominent {
                    RoundedRectangle(cornerRadius: 18).fill(TrainingTheme.actionGradient)
                } else {
                    RoundedRectangle(cornerRadius: 18).fill(TrainingTheme.surface)
                }
            }
            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(prominent ? .white.opacity(0.2) : TrainingTheme.border, lineWidth: 1))
            .shadow(color: prominent ? TrainingTheme.accent.opacity(0.2) : .clear, radius: 12, y: 5)
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
