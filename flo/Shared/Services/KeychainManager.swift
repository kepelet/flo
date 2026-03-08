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
    .accessibility(.afterFirstUnlockThisDeviceOnly)

  private static let iapAuthInfoKey = "iapAuthInfo"
  private static let authModeKey = "authMode"

  static func getAuthCredsAndPasswords() -> [String: Any] {
    var keychainData: [String: Any] = [:]

    do {
      if let creds = try getAuthCreds() {
        keychainData["authCreds"] = creds
      } else {
        keychainData["authCreds"] = "nil"
      }
    } catch {
      keychainData["authCreds"] = "Error: \(error.localizedDescription)"
    }

    do {
      if let password = try getAuthPassword() {
        keychainData["authPassword"] = password
      } else {
        keychainData["authPassword"] = "nil"
      }
    } catch {
      keychainData["authPassword"] = "Error: \(error.localizedDescription)"
    }
    
    do {
      if let authMode = try getAuthMode() {
        keychainData["authMode"] = authMode.rawValue
      } else {
        keychainData["authMode"] = "nil"
      }
    } catch {
      keychainData["authMode"] = "Error: \(error.localizedDescription)"
    }

    return keychainData
  }

  static func getAuthCreds() throws -> String? {
    return try keychain.get(KeychainKeys.dataKey)
  }

  static func getAuthPassword() throws -> String? {
    return try keychain.get(KeychainKeys.serverPassword)
  }

  static func removeAuthCreds() throws {
    try keychain.remove(KeychainKeys.dataKey)
  }

  static func removeAuthPassword() throws {
    try keychain.remove(KeychainKeys.serverPassword)
  }

  static func setAuthCreds(newValue: String) throws {
    try keychain.set(newValue, key: KeychainKeys.dataKey)
  }

  static func setAuthPassword(newValue: String) throws {
    try keychain.set(newValue, key: KeychainKeys.serverPassword)
  }
    
  static func getIAPAuthInfo() throws -> IAPAuthInfo? {
    guard let jsonString = try keychain.get(iapAuthInfoKey),
          let jsonData = jsonString.data(using: .utf8) else {
      return nil
    }
    return try JSONDecoder().decode(IAPAuthInfo.self, from: jsonData)
  }
  
  static func setIAPAuthInfo(_ info: IAPAuthInfo) throws {
    let jsonData = try JSONEncoder().encode(info)
    guard let jsonString = String(data: jsonData, encoding: .utf8) else {
      throw NSError(domain: "KeychainManager", code: -1, 
                    userInfo: [NSLocalizedDescriptionKey: "Failed to encode IAP auth info"])
    }
    try keychain.set(jsonString, key: iapAuthInfoKey)
  }
  
  static func removeIAPAuthInfo() throws {
    try keychain.remove(iapAuthInfoKey)
  }
    
  static func getAuthMode() throws -> AuthMode? {
    guard let rawValue = try keychain.get(authModeKey) else {
      return nil
    }
    return AuthMode(rawValue: rawValue)
  }
  
  static func setAuthMode(_ mode: AuthMode) throws {
    try keychain.set(mode.rawValue, key: authModeKey)
  }
  
  static func removeAuthMode() throws {
    try keychain.remove(authModeKey)
  }
}
