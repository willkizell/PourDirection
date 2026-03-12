//
//  PurchaseManager.swift
//  PourDirection
//
//  Temporary purchase handler for TestFlight validation.
//  Simulates a 1-second purchase delay, then persists "premiumUnlocked"
//  via UserDefaults. Replace internals with StoreKit 2 when ready.
//

import Foundation
import Combine

@MainActor
final class PurchaseManager: ObservableObject {

    static let shared = PurchaseManager()

    private let key = "com.pourdirection.premiumUnlocked"

    @Published private(set) var isPremium: Bool

    private init() {
        isPremium = UserDefaults.standard.bool(forKey: key)
    }

    // MARK: - Purchase (simulated)

    /// Simulates a 1-second purchase flow. Replace with StoreKit 2 later.
    func purchasePremium() async -> Bool {
        try? await Task.sleep(for: .seconds(1))
        setPremium(true)
        return true
    }

    // MARK: - Restore

    /// Simulates restoring purchases. Replace with StoreKit 2 later.
    func restorePurchases() async -> Bool {
        try? await Task.sleep(for: .seconds(1))
        // In the real implementation, query StoreKit for past transactions.
        // For now, just return whatever is persisted.
        return isPremium
    }

    // MARK: - Internal

    private func setPremium(_ value: Bool) {
        isPremium = value
        UserDefaults.standard.set(value, forKey: key)
    }
}
