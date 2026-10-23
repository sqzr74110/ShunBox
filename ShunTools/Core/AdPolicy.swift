import SwiftUI

/// Adapter contract for a production ad network. A nil adapter means no SDK or ad requests.
@MainActor protocol InterstitialAdProvider: AnyObject {
    var canRequestAds: Bool { get }
    func presentIfReady() async -> Bool
}
struct AdEligibility {
    static let trialDuration: TimeInterval = 7 * 24 * 60 * 60
    static func mayPresent(start: Date, now: Date, purchased: Bool, configured: Bool, lastAd: Date?) -> Bool {
        guard configured, !purchased, now.timeIntervalSince(start) >= trialDuration else { return false }
        return lastAd.map { now.timeIntervalSince($0) >= 180 } ?? true
    }
}
@MainActor @Observable final class AdPolicy {
    static let shared = AdPolicy()
    private let defaults: UserDefaults
    var provider: (any InterstitialAdProvider)?
    private var presenting = false
    private var lastAd: Date?
    var configured: Bool { provider != nil }
    var start: Date { defaults.object(forKey: "firstUseDate") as? Date ?? Date() }
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if defaults.object(forKey: "firstUseDate") == nil { defaults.set(Date(), forKey: "firstUseDate") }
    }
    func conversionCompleted() async {
        guard !BuildDistribution.isSideload, !presenting, SupportStore.shared.entitlementsLoaded, UIApplication.shared.applicationState == .active,
              let provider, provider.canRequestAds,
              AdEligibility.mayPresent(start: start, now: Date(), purchased: SupportStore.shared.supported, configured: configured, lastAd: lastAd) else { return }
        presenting = true; defer { presenting = false }
        // The result exists before this call. Never gate saving or exporting on an ad.
        if await provider.presentIfReady() { lastAd = Date() }
    }
}
