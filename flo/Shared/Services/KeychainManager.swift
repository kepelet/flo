//
//  KeychainManager.swift
//  flo
//
//  Created by rizaldy on 09/06/24.
//

import Foundation
import KeychainAccess

class KeychainManager {
  private static let keychain = Keychain(service: KeychainKeys.service)

  static func getAuthCreds() throws -> String? {
    return try keychain.get(KeychainKeys.dataKey)
  }

  static func removeAuthCreds() throws {
    try keychain.remove(KeychainKeys.dataKey)
  }

  static func setAuthCreds(newValue: String) throws {
    try keychain.set(newValue, key: KeychainKeys.dataKey)
  }
}
