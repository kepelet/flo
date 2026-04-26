//
//  KeychainManager.swift
//  flo
//
//  Created by rizaldy on 09/06/24.
//

import Foundation
import KeychainAccess

/// Storage for sensitive credentials.
///
/// On iOS we use `KeychainAccess` (Apple Keychain). On Mac Catalyst the
/// system Keychain rejects every read/write with `errSecMissingEntitlement`
/// (-34018) unless the app is either sandboxed or signed with a real
/// development certificate plus `keychain-access-groups` entitlement.
/// Neither is acceptable for this project today (sandboxing would relocate
/// the app's data container and drop existing downloads, and ad-hoc local
/// builds don't have a dev cert), so on Catalyst we fall back to a tiny
/// file-backed store inside the app's Application Support directory with
/// `0600` permissions. macOS file system permissions already restrict it
/// to the current user account, which matches the threat model the prior
/// Keychain usage actually relied on.
class KeychainManager {
  #if targetEnvironment(macCatalyst)
    private static let store = FileBackedCredentialStore()
  #else
    private static let keychain = Keychain(service: KeychainKeys.service)
      .accessibility(.afterFirstUnlockThisDeviceOnly)
  #endif

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
    #if targetEnvironment(macCatalyst)
      return try store.get(KeychainKeys.dataKey)
    #else
      return try keychain.get(KeychainKeys.dataKey)
    #endif
  }

  static func getAuthPassword() throws -> String? {
    #if targetEnvironment(macCatalyst)
      return try store.get(KeychainKeys.serverPassword)
    #else
      return try keychain.get(KeychainKeys.serverPassword)
    #endif
  }

  static func removeAuthCreds() throws {
    #if targetEnvironment(macCatalyst)
      try store.remove(KeychainKeys.dataKey)
    #else
      try keychain.remove(KeychainKeys.dataKey)
    #endif
  }

  static func removeAuthPassword() throws {
    #if targetEnvironment(macCatalyst)
      try store.remove(KeychainKeys.serverPassword)
    #else
      try keychain.remove(KeychainKeys.serverPassword)
    #endif
  }

  static func setAuthCreds(newValue: String) throws {
    #if targetEnvironment(macCatalyst)
      try store.set(newValue, for: KeychainKeys.dataKey)
    #else
      try keychain.set(newValue, key: KeychainKeys.dataKey)
    #endif
  }

  static func setAuthPassword(newValue: String) throws {
    #if targetEnvironment(macCatalyst)
      try store.set(newValue, for: KeychainKeys.serverPassword)
    #else
      try keychain.set(newValue, key: KeychainKeys.serverPassword)
    #endif
  }

  static func getIAPAuthInfo() throws -> IAPAuthInfo? {
    #if targetEnvironment(macCatalyst)
      guard let jsonString = try store.get(iapAuthInfoKey),
        let jsonData = jsonString.data(using: .utf8)
      else {
        return nil
      }
    #else
      guard let jsonString = try keychain.get(iapAuthInfoKey),
        let jsonData = jsonString.data(using: .utf8)
      else {
        return nil
      }
    #endif
    return try JSONDecoder().decode(IAPAuthInfo.self, from: jsonData)
  }

  static func setIAPAuthInfo(_ info: IAPAuthInfo) throws {
    let jsonData = try JSONEncoder().encode(info)
    guard let jsonString = String(data: jsonData, encoding: .utf8) else {
      throw NSError(
        domain: "KeychainManager", code: -1,
        userInfo: [NSLocalizedDescriptionKey: "Failed to encode IAP auth info"])
    }
    #if targetEnvironment(macCatalyst)
      try store.set(jsonString, for: iapAuthInfoKey)
    #else
      try keychain.set(jsonString, key: iapAuthInfoKey)
    #endif
  }

  static func removeIAPAuthInfo() throws {
    #if targetEnvironment(macCatalyst)
      try store.remove(iapAuthInfoKey)
    #else
      try keychain.remove(iapAuthInfoKey)
    #endif
  }

  static func getAuthMode() throws -> AuthMode? {
    #if targetEnvironment(macCatalyst)
      guard let rawValue = try store.get(authModeKey) else { return nil }
    #else
      guard let rawValue = try keychain.get(authModeKey) else { return nil }
    #endif
    return AuthMode(rawValue: rawValue)
  }

  static func setAuthMode(_ mode: AuthMode) throws {
    #if targetEnvironment(macCatalyst)
      try store.set(mode.rawValue, for: authModeKey)
    #else
      try keychain.set(mode.rawValue, key: authModeKey)
    #endif
  }

  static func removeAuthMode() throws {
    #if targetEnvironment(macCatalyst)
      try store.remove(authModeKey)
    #else
      try keychain.remove(authModeKey)
    #endif
  }
}

#if targetEnvironment(macCatalyst)
  /// Mac Catalyst credential store backed by per-key files under
  /// `~/Library/Application Support/<bundle-id>/Credentials/`.
  ///
  /// File permissions are set to `0600` so only the current user account can
  /// read them, matching what the system Keychain provided in practice for
  /// this app. This is intentionally simple — secure-by-isolation, not by
  /// encryption — and exists because the system Keychain refuses to work on
  /// non-sandboxed, ad-hoc-signed Catalyst builds.
  final class FileBackedCredentialStore {
    enum StoreError: Error, LocalizedError {
      case directoryUnavailable

      var errorDescription: String? {
        switch self {
        case .directoryUnavailable:
          return "Could not resolve Application Support directory for credential storage."
        }
      }
    }

    private let directoryURL: URL
    private let fileManager = FileManager.default

    init() {
      let baseURL: URL
      if let supportURL = try? FileManager.default.url(
        for: .applicationSupportDirectory, in: .userDomainMask,
        appropriateFor: nil, create: true
      ) {
        let bundleID = Bundle.main.bundleIdentifier ?? AppMeta.identifier
        baseURL = supportURL.appendingPathComponent(bundleID, isDirectory: true)
      } else {
        baseURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
      }
      directoryURL = baseURL.appendingPathComponent("Credentials", isDirectory: true)
    }

    private func ensureDirectory() throws {
      if !fileManager.fileExists(atPath: directoryURL.path) {
        try fileManager.createDirectory(
          at: directoryURL, withIntermediateDirectories: true,
          attributes: [.posixPermissions: 0o700]
        )
      }
    }

    private func fileURL(for key: String) -> URL {
      // Sanitize key to keep it filesystem-safe.
      let safe = key.replacingOccurrences(of: "/", with: "_")
      return directoryURL.appendingPathComponent(safe, isDirectory: false)
    }

    func get(_ key: String) throws -> String? {
      let url = fileURL(for: key)
      guard fileManager.fileExists(atPath: url.path) else { return nil }
      let data = try Data(contentsOf: url)
      return String(data: data, encoding: .utf8)
    }

    func set(_ value: String, for key: String) throws {
      try ensureDirectory()
      let url = fileURL(for: key)
      guard let data = value.data(using: .utf8) else {
        throw NSError(
          domain: "FileBackedCredentialStore", code: -1,
          userInfo: [NSLocalizedDescriptionKey: "Failed to encode value as UTF-8"]
        )
      }
      try data.write(to: url, options: [.atomic, .completeFileProtection])
      try? fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }

    func remove(_ key: String) throws {
      let url = fileURL(for: key)
      if fileManager.fileExists(atPath: url.path) {
        try fileManager.removeItem(at: url)
      }
    }
  }
#endif
