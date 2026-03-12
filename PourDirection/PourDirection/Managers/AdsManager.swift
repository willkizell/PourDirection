//
//  AdsManager.swift
//  PourDirection
//
//  Central place for ad eligibility and future Remove Ads entitlements.
//  Ads must not load until this manager has finished checking state.
//

import Foundation
import Combine

@MainActor
final class AdsManager: ObservableObject {

    // ── Screenshot Mode ─────────────────────────────────────────────────
    // Flip to `true` for App Store screenshots: hides ads, uses mock place names.
    // ⚠️  Set back to `false` before shipping!
    static let screenshotMode = false

    @Published private(set) var isReady: Bool = false
    @Published private(set) var adsEnabled: Bool = true

    private var cancellable: AnyCancellable?

    /// Call at app launch. Observes PurchaseManager so ads hide immediately on upgrade.
    func refreshEntitlements() {
        let pm = PurchaseManager.shared
        adsEnabled = Self.screenshotMode ? false : !pm.isPremium
        isReady = true

        cancellable = pm.$isPremium
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] isPremium in
                guard let self else { return }
                self.adsEnabled = Self.screenshotMode ? false : !isPremium
            }
    }

    static var previewReady: AdsManager {
        let manager = AdsManager()
        manager.refreshEntitlements()
        return manager
    }
}
