import SwiftUI

struct TrainingReveal: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    var delay: Double = 0
    func body(content: Content) -> some View {
        content
            .opacity(appeared || reduceMotion ? 1 : 0)
            .offset(y: appeared || reduceMotion ? 0 : 16)
            .task {
                guard !appeared else { return }
                withAnimation(reduceMotion ? nil : .spring(response: 0.55, dampingFraction: 0.85).delay(delay)) {
                    appeared = true
                }
            }
    }
}

extension View {
    func trainingReveal(delay: Double = 0) -> some View {
        modifier(TrainingReveal(delay: delay))
    }
}

struct JourneyEmblem: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let symbol: String
    var progress: Double = 0.75
    var compact = false
    @State private var appeared = false
    private var size: CGFloat { compact ? 140 : 220 }
    var body: some View {
        ZStack {
            Circle().fill(TrainingTheme.mint.opacity(0.06)).frame(width: size, height: size)
            Circle().stroke(TrainingTheme.mint.opacity(0.12), lineWidth: 1)
                .frame(width: size * 0.95, height: size * 0.95)
            Circle().stroke(TrainingTheme.border, lineWidth: 9)
                .frame(width: size * 0.76, height: size * 0.76)
            arc
            center
            Image(systemName: "sparkle")
                .font(.title2).foregroundStyle(TrainingTheme.mint)
                .offset(x: size * 0.39, y: -size * 0.32)
                .scaleEffect(appeared || reduceMotion ? 1 : 0.2)
                .animation(reduceMotion ? nil : .spring(response: 0.65).delay(0.2), value: appeared)
        }
        .frame(maxWidth: .infinity).frame(height: size + 10)
        .accessibilityHidden(true)
        .onAppear { appeared = true }
    }
    private var arc: some View {
        Circle().trim(from: 0, to: appeared || reduceMotion ? progress : 0)
            .stroke(TrainingTheme.mint.gradient, style: StrokeStyle(lineWidth: 9, lineCap: .round))
            .rotationEffect(.degrees(-90))
            .frame(width: size * 0.76, height: size * 0.76)
            .animation(reduceMotion ? nil : .spring(response: 1.1, dampingFraction: 0.85), value: appeared)
            .animation(reduceMotion ? nil : .spring(response: 0.6, dampingFraction: 0.8), value: progress)
    }
    private var center: some View {
        Image(systemName: symbol)
            .font(.system(size: compact ? 38 : 60, weight: .medium))
            .foregroundStyle(TrainingTheme.mint)
            .contentTransition(.symbolEffect(.replace))
            .scaleEffect(appeared || reduceMotion ? 1 : 0.7)
            .animation(reduceMotion ? nil : .spring(response: 0.6, dampingFraction: 0.65), value: appeared)
            .transaction { if reduceMotion { $0.disablesAnimations = true } }
    }
}

struct RewardConfetti: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var launched = false
    private let particles = Array(0..<20)
    var body: some View {
        GeometryReader { geometry in
            if !reduceMotion {
                ForEach(particles, id: \.self) { particle in
                    piece(particle, size: geometry.size)
                }
            }
        }
        .allowsHitTesting(false).accessibilityHidden(true)
        .task {
            guard !reduceMotion else { return }
            withAnimation(.easeOut(duration: 1.8)) { launched = true }
        }
    }
    private func piece(_ index: Int, size: CGSize) -> some View {
        let angle = Double(index) / 20 * Double.pi * 2
        let radius = Double(min(size.width, size.height)) * (index.isMultiple(of: 2) ? 0.5 : 0.38)
        let x = launched ? cos(angle) * radius : 0
        let y = launched ? sin(angle) * radius + 35 : 0
        return Capsule()
            .fill(index.isMultiple(of: 3) ? TrainingTheme.primary : TrainingTheme.mint)
            .frame(width: 5, height: index.isMultiple(of: 2) ? 12 : 6)
            .rotationEffect(.degrees(launched ? Double(index * 41) : 0))
            .offset(x: x, y: y)
            .position(x: size.width / 2, y: size.height / 2)
            .opacity(launched ? 0 : 1)
    }
}
