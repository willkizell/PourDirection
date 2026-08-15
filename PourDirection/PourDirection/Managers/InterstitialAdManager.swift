//
//  InterstitialAdManager.swift
//  PourDirection
//
//  Full-screen interstitial shown after a compass session ends ("Let's Go" →
//  compass → close). Interstitials earn ~10–20× banner eCPM, so this single
//  placement is the app's main ad revenue lever.
//
//  Frequency capped: at most one ad every `sessionsPerAd` compass sessions
//  AND at least `minSecondsBetweenAds` apart, and never for Pro users.
//
//  ⚠️ Before shipping: create an *Interstitial* ad unit in AdMob and paste
//     its ID into `productionAdUnitID` below. Until then, Release builds
//     fail to load (silently — no crash, just no interstitials).
//

import Foundation
import UIKit
#if canImport(GoogleMobileAds)
import GoogleMobileAds
#endif

final class InterstitialAdManager: NSObject {

    static let shared = InterstitialAdManager()

    // ── Configuration ────────────────────────────────────────────────────
    /// AdMob interstitial ad unit — REPLACE with your real unit ID.
    private static let productionAdUnitID = "REPLACE_WITH_ADMOB_INTERSTITIAL_UNIT_ID"

    private var effectiveAdUnitID: String {
        #if DEBUG
        // Google's guaranteed-fill test interstitial.
        return "ca-app-pub-3940256099942544/4411468910"
        #else
        return Self.productionAdUnitID
        #endif
    }

    /// Show an ad after every Nth compass session…
    private let sessionsPerAd = 2
    /// …but never more often than this.
    private let minSecondsBetweenAds: TimeInterval = 180

    // ── State (main thread only) ─────────────────────────────────────────
    private var compassSessionCount = 0
    private var lastShownAt: Date?

    #if canImport(GoogleMobileAds)
    private var interstitial: InterstitialAd?
    private var isLoading = false
    #endif

    private override init() {
        super.init()
    }

    // MARK: - Public API

    /// Call once the Mobile Ads SDK has started (after ATT prompt).
    @MainActor
    func preload() {
        #if canImport(GoogleMobileAds)
        guard adsAllowed, interstitial == nil, !isLoading else { return }
        isLoading = true
        InterstitialAd.load(with: effectiveAdUnitID, request: Request()) { [weak self] ad, error in
            Task { @MainActor in
                guard let self else { return }
                self.isLoading = false
                if let error {
                    print("[AdMob] interstitial failed to load: \(error.localizedDescription)")
                    return
                }
                ad?.fullScreenContentDelegate = self
                self.interstitial = ad
                print("[AdMob] interstitial loaded")
            }
        }
        #endif
    }

    /// Call when a compass session ends. Shows an interstitial when the
    /// frequency caps allow it; otherwise just counts the session.
    @MainActor
    func maybeShowAfterCompassSession() {
        #if canImport(GoogleMobileAds)
        guard adsAllowed else { return }

        compassSessionCount += 1
        guard compassSessionCount >= sessionsPerAd else {
            preload() // make sure one is ready for next time
            return
        }
        if let last = lastShownAt, Date().timeIntervalSince(last) < minSecondsBetweenAds {
            return
        }
        guard let ad = interstitial, let rootVC = Self.rootViewController() else {
            preload()
            return
        }

        compassSessionCount = 0
        lastShownAt = Date()
        interstitial = nil
        ad.present(from: rootVC)
        #endif
    }

    // MARK: - Helpers

    @MainActor
    private var adsAllowed: Bool {
        !AdsManager.screenshotMode && !PurchaseManager.shared.isPremium
    }

    private static func rootViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let keyWindow = scenes.flatMap { $0.windows }.first { $0.isKeyWindow }
        return keyWindow?.rootViewController
            ?? scenes.flatMap { $0.windows }.first?.rootViewController
    }
}

// MARK: - FullScreenContentDelegate

#if canImport(GoogleMobileAds)
extension InterstitialAdManager: FullScreenContentDelegate {

    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        Task { @MainActor in
            self.interstitial = nil
            self.preload()
        }
    }

    func ad(_ ad: FullScreenPresentingAd,
            didFailToPresentFullScreenContentWithError error: Error) {
        print("[AdMob] interstitial failed to present: \(error.localizedDescription)")
        Task { @MainActor in
            self.interstitial = nil
            self.preload()
        }
    }
}
#endif
