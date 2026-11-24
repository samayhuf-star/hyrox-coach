import SwiftUI
import AVFoundation

/// Silent looping demo clip. One clip holds four poses with generated in-between frames, 3 seconds per pose.
struct ExerciseClipView: UIViewRepresentable {
    let url: URL
    let active: Bool
    let rate: Float

    func makeUIView(context: Context) -> ClipPlayerUIView {
        let view = ClipPlayerUIView()
        view.load(url)
        return view
    }

    func updateUIView(_ view: ClipPlayerUIView, context: Context) {
        view.update(active: active, rate: rate)
    }

    static func dismantleUIView(_ view: ClipPlayerUIView, coordinator: ()) { view.stop() }
}

final class ClipPlayerUIView: UIView {
    private var player: AVQueuePlayer?
    private var looper: AVPlayerLooper?
    private var wasActive = false

    override class var layerClass: AnyClass { AVPlayerLayer.self }
    private var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }

    func load(_ url: URL) {
        let queue = AVQueuePlayer()
        queue.isMuted = true
        queue.preventsDisplaySleepDuringVideoPlayback = false
        looper = AVPlayerLooper(player: queue, templateItem: AVPlayerItem(url: url))
        player = queue
        playerLayer.player = queue
        playerLayer.videoGravity = .resizeAspectFill
        backgroundColor = UIColor(white: 0.17, alpha: 1)
        isAccessibilityElement = false
    }

    func update(active: Bool, rate: Float) {
        guard let player else { return }
        if active { player.rate = rate } else if wasActive { player.pause() }
        wasActive = active
    }

    func stop() {
        player?.pause()
        looper?.disableLooping()
    }
}
