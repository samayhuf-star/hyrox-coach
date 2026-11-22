// Linux stand-in for the one UIKit call the engine makes (haptic tick).
@MainActor public final class UINotificationFeedbackGenerator {
  public enum FeedbackType { case success, warning, error }
  public nonisolated(unsafe) static var fired = 0
  public init() {}
  public func notificationOccurred(_ type: FeedbackType) { Self.fired += 1 }
}
