//
//  PurchaseManager.swift
//  PourDirection
//
//  StoreKit 2 purchase handler for PourPro.
//  The entitlement source of truth is StoreKit (Transaction.currentEntitlements);
//  UserDefaults only caches the last known state so ads hide instantly on launch
//  while StoreKit is still loading.
//
//  Requires an auto-renewable subscription with this exact product ID in
//  App Store Connect: com.pourdirection.pro.yearly
//

import Foundation
import Combine
import StoreKit

@MainActor
final class PurchaseManager: ObservableObject {

    static let shared = PurchaseManager()

    static let proYearlyProductID = "com.pourdirection.pro.yearly"

    private let cacheKey = "com.pourdirection.premiumUnlocked"

    @Published private(set) var isPremium: Bool
    @Published private(set) var proProduct: Product?

    private var transactionListener: Task<Void, Never>?

    private init() {
        isPremium = UserDefaults.standard.bool(forKey: cacheKey)

        // Handle renewals, refunds, Ask-to-Buy approvals, and purchases
        // made on other devices.
        transactionListener = Task { [weak self] in
            for await update in StoreKit.Transaction.updates {
                if case .verified(let transaction) = update {
                    await transaction.finish()
                }
                await self?.refreshEntitlements()
            }
        }

        Task { [weak self] in
            await self?.loadProduct()
            await self?.refreshEntitlements()
        }
    }

    // MARK: - Products

    func loadProduct() async {
        guard proProduct == nil else { return }
        proProduct = try? await Product.products(for: [Self.proYearlyProductID]).first
    }

    // MARK: - Purchase

    /// Runs the real App Store purchase flow. Returns true when the purchase
    /// completed and was verified. `.pending` (e.g. Ask to Buy) returns false;
    /// the entitlement lands later via Transaction.updates.
    func purchasePremium() async -> Bool {
        await loadProduct()
        guard let product = proProduct else { return false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                guard case .verified(let transaction) = verification else { return false }
                await transaction.finish()
                setPremium(true)
                return true
            case .pending, .userCancelled:
                return false
            @unknown default:
                return false
            }
        } catch {
            print("[PurchaseManager] purchase failed: \(error)")
            return false
        }
    }

    // MARK: - Restore

    func restorePurchases() async -> Bool {
        try? await AppStore.sync()
        await refreshEntitlements()
        return isPremium
    }

    // MARK: - Entitlements

    /// Rebuilds premium state from StoreKit. Also clears any stale local flag
    /// (e.g. from the old TestFlight mock purchase) when no real entitlement exists.
    func refreshEntitlements() async {
        var hasPro = false
        for await entitlement in StoreKit.Transaction.currentEntitlements {
            guard case .verified(let transaction) = entitlement else { continue }
            if transaction.productID == Self.proYearlyProductID,
               transaction.revocationDate == nil {
                hasPro = true
            }
        }
        setPremium(hasPro)
    }

    // MARK: - Internal

    private func setPremium(_ value: Bool) {
        isPremium = value
        UserDefaults.standard.set(value, forKey: cacheKey)
    }
}
