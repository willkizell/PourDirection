//
//  PremiumGates.swift
//  PourDirection
//
//  Central source of truth for free-vs-premium limits.
//  UI reads the computed properties; nothing else should hardcode these caps.
//

import Foundation

enum PremiumGates {

    // MARK: - Free-Tier Caps

    static let freeSavedPlacesLimit: Int       = 5
    static let freeSearchAreaMeters: Double    = 5_000   // 5 km

    // MARK: - Effective Caps

    /// Max saved places allowed given current entitlement. Returns .max for premium.
    @MainActor static var savedPlacesLimit: Int {
        PurchaseManager.shared.isPremium ? .max : freeSavedPlacesLimit
    }

    /// Max search area radius (meters) given current entitlement.
    @MainActor static var maxSearchAreaMeters: Double {
        PurchaseManager.shared.isPremium
            ? DistancePreferences.searchAreaMaxMeters
            : freeSearchAreaMeters
    }

    // MARK: - Queries

    @MainActor static func canSaveMore(currentCount: Int) -> Bool {
        currentCount < savedPlacesLimit
    }
}
