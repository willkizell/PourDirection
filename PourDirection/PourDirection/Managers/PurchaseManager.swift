//
//  PurchaseManager.swift
//  PourDirection
//
//  StoreKit 2 purchase manager for the PourPro annual subscription.
//  - Fetches the product from App Store Connect on first use
//  - Handles purchase, restore, and entitlement verification
//  - Listens for background transaction updates (renewal, refund, expiry)
//  - AdsManager observes `isPremium` via Combine to hide/show ads instantly
//

import Foundation
import StoreKit
import Combine

enum StoreError: Error {
    case failedVerification
}

@MainActor
final class PurchaseManager: ObservableObject {

    // MARK: - Singleton

    static let shared = PurchaseManager()

    // MARK: - Product ID

    private let productID = "com.pourdirection.pourpro.annual"

    // MARK: - Published State

    @Published private(set) var isPremium: Bool = false
    @Published private(set) var product: Product? = nil

    // MARK: - Transaction Listener

    private var updatesTask: Task<Void, Never>?

    // MARK: - Init

    private init() {
        updatesTask = listenForTransactionUpdates()
        Task { await refreshPurchaseStatus() }
    }

    deinit {
        updatesTask?.cancel()
    }

    // MARK: - Load Product

    func loadProduct() async {
        guard product == nil else { return }
        do {
            let products = try await Product.products(for: [productID])
            product = products.first
        } catch {
            print("[PurchaseManager] Failed to load product: \(error)")
        }
    }

    // MARK: - Purchase

    func purchasePremium() async -> Bool {
        if product == nil { await loadProduct() }
        guard let product else {
            print("[PurchaseManager] Product unavailable")
            return false
        }
        return await purchase(product)
    }

    private func purchase(_ product: Product) async -> Bool {
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                await refreshPurchaseStatus()
                return true
            case .userCancelled, .pending:
                return false
            @unknown default:
                return false
            }
        } catch {
            print("[PurchaseManager] Purchase error: \(error)")
            return false
        }
    }

    // MARK: - Restore

    func restorePurchases() async -> Bool {
        do {
            try await AppStore.sync()
            await refreshPurchaseStatus()
            return isPremium
        } catch {
            print("[PurchaseManager] Restore error: \(error)")
            return false
        }
    }

    // MARK: - Entitlement Check

    /// Re-checks StoreKit for active entitlements. Called at launch and after
    /// any transaction update (purchase, renewal, refund, expiry).
    func refreshPurchaseStatus() async {
        var hasPremium = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == productID,
               transaction.revocationDate == nil {
                hasPremium = true
                break
            }
        }
        isPremium = hasPremium
    }

    // MARK: - Background Transaction Listener

    private func listenForTransactionUpdates() -> Task<Void, Never> {
        Task(priority: .background) { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await transaction.finish()
                    await self?.refreshPurchaseStatus()
                }
            }
        }
    }

    // MARK: - Verification

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let value):
            return value
        }
    }
}
