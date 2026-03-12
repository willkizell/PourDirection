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

    /// Call at app launch. Replace with StoreKit entitlement checks later.
    func refreshEntitlements() {
        // TODO: wire to StoreKit / server entitlements.
        adsEnabled = Self.screenshotMode ? false : true
        isReady = true
    }

    static var previewReady: AdsManager {
        let manager = AdsManager()
        manager.refreshEntitlements()
        return manager
    }
}
