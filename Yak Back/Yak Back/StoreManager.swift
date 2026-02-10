//
//  StoreManager.swift
//  Yak Back
//
//  Created by Jim Washkau on 2/2/26.
//

import StoreKit

@Observable
final class StoreManager {
    private(set) var isPro = false
    private(set) var proProduct: Product?
    private(set) var purchaseError: String?

    private var transactionListener: Task<Void, Never>?

    static let proProductID = "com.jimwas.yakback.pro"
    static let freeTierSoundLimit = 9

    /// Returns true if the user can add more sounds
    func canAddSound(currentCount: Int) -> Bool {
        return isPro || currentCount < Self.freeTierSoundLimit
    }

    /// Returns remaining sounds available for free tier
    func remainingSounds(currentCount: Int) -> Int {
        return max(0, Self.freeTierSoundLimit - currentCount)
    }

    init() {
        transactionListener = listenForTransactions()
        Task {
            await loadProducts()
            await checkEntitlements()
        }
    }

    deinit {
        transactionListener?.cancel()
    }

    // MARK: - Load Products

    func loadProducts() async {
        do {
            let products = try await Product.products(for: [Self.proProductID])
            proProduct = products.first
        } catch {
            print("Failed to load products: \(error)")
        }
    }

    // MARK: - Purchase

    func purchase() async {
        guard let product = proProduct else {
            purchaseError = "Product not available. Please try again later."
            return
        }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                await checkEntitlements()
            case .userCancelled:
                break
            case .pending:
                purchaseError = "Purchase is pending approval."
            @unknown default:
                break
            }
        } catch {
            purchaseError = "Purchase failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Restore

    func restorePurchases() async {
        try? await AppStore.sync()
        await checkEntitlements()
    }

    // MARK: - Entitlements

    func checkEntitlements() async {
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == Self.proProductID,
               transaction.revocationDate == nil {
                isPro = true
                return
            }
        }
        isPro = false
    }

    // MARK: - Transaction Listener

    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached {
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await transaction.finish()
                    await self.checkEntitlements()
                }
            }
        }
    }

    // MARK: - Verification

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let value):
            return value
        }
    }
}
