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
  @Published var isPurchasing = false
  @Published var isRestoring = false
  @Published var isLoadingProduct = false
  @Published var floPlusProduct: Product?
  @Published var purchaseErrorMessage = ""
  @Published var showPurchaseError = false

  private let floPlusProductID = "flo.plus"
  private var transactionUpdatesTask: Task<Void, Never>?

  init(startObservingTransactions: Bool = true) {
    guard startObservingTransactions else {
      return
    }

    transactionUpdatesTask = observeTransactionUpdates()

    Task {
      await loadFloPlusProduct()
      await refreshFloPlusEntitlement()
    }
  }

  deinit {
    transactionUpdatesTask?.cancel()
  }

  func purchaseFloPlus() async {
    guard !isPurchasing else {
      return
    }

    isPurchasing = true
    defer {
      isPurchasing = false
    }

    do {
      let product = try await fetchFloPlusProduct()

      let result = try await product.purchase()

      switch result {
      case .success(let verificationResult):
        let transaction = try verify(verificationResult)
        await transaction.finish()
        await refreshFloPlusEntitlement()
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

  func loadFloPlusProduct() async {
    guard !isLoadingProduct else {
      return
    }

    isLoadingProduct = true
    defer { isLoadingProduct = false }

    floPlusProduct = try? await fetchFloPlusProduct()
  }

  func restorePurchases() async {
    guard !isRestoring else {
      return
    }

    isRestoring = true
    defer { isRestoring = false }

    do {
      try await AppStore.sync()
      await refreshFloPlusEntitlement()
    } catch {
      purchaseErrorMessage = error.localizedDescription
      showPurchaseError = true
    }
  }

  func refreshFloPlusEntitlement() async {
    var hasFloPlus = false
    let now = Date()

    for await result in Transaction.currentEntitlements {
      guard let transaction = try? verify(result) else {
        continue
      }

      if transaction.productID != floPlusProductID {
        continue
      }

      if transaction.revocationDate != nil {
        continue
      }

      if let expirationDate = transaction.expirationDate, expirationDate < now {
        continue
      }

      hasFloPlus = true
      break
    }

    UserDefaultsManager.floPlus = hasFloPlus
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
        await self.refreshFloPlusEntitlement()
      }
    }
  }

  private func fetchFloPlusProduct() async throws -> Product {
    let products = try await Product.products(for: [floPlusProductID])

    guard let product = products.first else {
      throw PurchaseError.productNotFound
    }

    return product
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
    case productNotFound
    case verificationFailed

    var errorDescription: String? {
      switch self {
      case .productNotFound:
        return "flo+ product was not found. Check the product ID in App Store Connect."
      case .verificationFailed:
        return "Unable to verify purchase transaction."
      }
    }
  }
}
