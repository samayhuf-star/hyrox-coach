import SwiftUI

/// Each bundled sheet contains four equally sized poses in reading order.
/// Rendering a cropped quadrant reuses the same asset without decoding new frames on every tick.
struct ExercisePoseView: View {
    let asset: String
    var frame = 0

    var body: some View {
        GeometryReader { geometry in
            let side = geometry.size.width
            let column = CGFloat(frame % 2)
            let row = CGFloat(frame / 2)
            Image(asset)
                .resizable()
                .frame(width: side * 2, height: side * 2)
                .offset(x: -column * side, y: -row * side)
                .frame(width: side, height: side, alignment: .topLeading)
                .clipped()
        }
        .aspectRatio(1, contentMode: .fit)
        .background(Color(white: 0.17))
        .accessibilityHidden(true)
    }
}

/// Blends adjacent illustrations continuously, including the end-to-start join.
/// This softens still-frame changes; it does not synthesize new movement positions.
struct ExerciseLoopView: View {
    let asset: String
    let frames: [Int]
    let position: Double

    private var current: Int { Int(position) % frames.count }
    private var next: Int { (current + 1) % frames.count }
    private var blend: Double {
        let fraction = position - floor(position)
        return fraction * fraction * (3 - 2 * fraction)
    }

    var body: some View {
        ZStack {
            ExercisePoseView(asset: asset, frame: frames[current])
            ExercisePoseView(asset: asset, frame: frames[next])
                .opacity(blend)
        }
        .transaction { $0.animation = nil }
        .accessibilityHidden(true)
    }
}

struct ExerciseDemoThumbnail: View {
    let exercise: Exercise
    var size: CGFloat = 64

    var body: some View {
        ExercisePoseView(asset: exercise.demo.asset, frame: exercise.id == "rest" ? 0 : 2)
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(alignment: .bottomTrailing) {
                Image(systemName: exercise.id == "rest" ? "pause.fill" : "play.fill")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(5).background(.black.opacity(0.6), in: Circle()).padding(4)
            }
            .accessibilityHidden(true)
    }
}
