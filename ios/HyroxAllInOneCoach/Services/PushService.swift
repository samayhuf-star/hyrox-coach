import Foundation
import OneSignalFramework

/// OneSignal push. Nothing is initialized until the person opts in during onboarding
/// (or later in settings), and nothing runs when no App ID is configured.
@MainActor
enum PushService {
    private static let consentKey = "push.consentGiven"
    private static var started = false

    /// Read from Info.plist (`OneSignalAppID`). Empty means push is not set up for this build.
    static var appID: String {
        (Bundle.main.object(forInfoDictionaryKey: "OneSignalAppID") as? String ?? "")
            .trimmingCharacters(in: .whitespaces)
    }
    static var isConfigured: Bool { !appID.isEmpty }
    static var hasConsent: Bool { UserDefaults.standard.bool(forKey: consentKey) }

    /// Call at launch. Starts OneSignal only if the person already agreed.
    static func startIfConsented() {
        guard hasConsent else { return }
        start()
    }

    /// Records consent, starts OneSignal and shows the system permission prompt.
    static func optIn() async -> Bool {
        UserDefaults.standard.set(true, forKey: consentKey)
        start()
        guard isConfigured else { return false }
        return await withCheckedContinuation { continuation in
            OneSignal.Notifications.requestPermission({ accepted in
                continuation.resume(returning: accepted)
            }, fallbackToSettings: false)
        }
    }

    static func optOut() {
        UserDefaults.standard.set(false, forKey: consentKey)
        guard started else { return }
        OneSignal.setConsentGiven(false)
    }

    private static func start() {
        guard isConfigured, !started else { return }
        OneSignal.setConsentRequired(true)
        OneSignal.setConsentGiven(true)
        OneSignal.initialize(appID, withLaunchOptions: nil)
        started = true
    }
}
