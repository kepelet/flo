//
//  InAppPurchaseManager.swift
//  flo
//
//  Created by rizaldy on 22/02/26.
//

import Foundation
import StoreKit

@MainActor
final class InAppPurchaseManager: ObservableObject {
  /// A single consumable tip tier shown to the user.
  struct TipTier: Identifiable {
    let product: Product
    let displayName: String

    var id: String { product.id }

    var priceLabel: String { product.displayPrice }
  }

  @Published var isPurchasing = false
  @Published var purchasingProductID: String?
  @Published var isLoadingProducts = false
  @Published var tipTiers: [TipTier] = []
  @Published var purchaseErrorMessage = ""
  @Published var showPurchaseError = false
  @Published var thankYouTierName = ""
  @Published var showThankYou = false

  private let tipProductIDs = ["tipjar.small", "tipjar.medium", "tipjar.large"]
  private var transactionUpdatesTask: Task<Void, Never>?

  init(startObservingTransactions: Bool = true) {
    guard startObservingTransactions else {
      return
    }

    transactionUpdatesTask = observeTransactionUpdates()

    Task {
      await loadTipProducts()
    }
  }

  deinit {
    transactionUpdatesTask?.cancel()
  }

  func purchase(_ tier: TipTier) async {
    guard !isPurchasing else {
      return
    }

    isPurchasing = true
    purchasingProductID = tier.id
    defer {
      isPurchasing = false
      purchasingProductID = nil
    }

    do {
      let result = try await tier.product.purchase()

      switch result {
      case .success(let verificationResult):
        let transaction = try verify(verificationResult)
        await transaction.finish()
        thankYouTierName = tier.displayName
        showThankYou = true
      case .pending, .userCancelled:
        break
      @unknown default:
        break
      }
    } catch {
      purchaseErrorMessage = error.localizedDescription
      showPurchaseError = true
    }
  }

  func loadTipProducts() async {
    guard !isLoadingProducts else {
      return
    }

    isLoadingProducts = true
    defer { isLoadingProducts = false }

    let products = try? await Product.products(for: tipProductIDs)
    let tiers =
      products?.compactMap { product -> TipTier? in
        guard let displayName = Self.displayName(for: product.id) else {
          return nil
        }

        return TipTier(product: product, displayName: displayName)
      } ?? []

    tipTiers = tiers
  }

  /// Re-fetches tip products from scratch, discarding any previously loaded set.
  /// Used so reopening the sheet always pulls the latest products from StoreKit
  /// (newly added products can take a moment to propagate to the sandbox).
  func refreshTipProducts() async {
    tipTiers = []
    await loadTipProducts()
  }

  /// Maps a product identifier to its user-facing display name.
  private static func displayName(for productID: String) -> String? {
    switch productID {
    case "tipjar.small":
      return "Coffee"
    case "tipjar.medium":
      return "Lunch"
    case "tipjar.large":
      return "Dinner"
    default:
      return nil
    }
  }

  private func observeTransactionUpdates() -> Task<Void, Never> {
    return Task { [weak self] in
      guard let self else {
        return
      }

      for await result in Transaction.updates {
        guard let transaction = try? self.verify(result) else {
          continue
        }

        await transaction.finish()
      }
    }
  }

  private func verify<T>(_ verificationResult: VerificationResult<T>) throws -> T {
    switch verificationResult {
    case .verified(let safeResult):
      return safeResult
    case .unverified:
      throw PurchaseError.verificationFailed
    }
  }
}

extension InAppPurchaseManager {
  enum PurchaseError: LocalizedError {
    case verificationFailed

    var errorDescription: String? {
      switch self {
      case .verificationFailed:
        return "Unable to verify the tip transaction."
      }
    }
  }
}
