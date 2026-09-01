//
//  UserDefaultsManager.swift
//  flo
//
//  Created by rizaldy on 09/06/24.
//

import Foundation

class UserDefaultsManager {
  static func getAll() -> [String: Any] {
    var result = [String: Any]()

    // filter only the "important" part because the rest is displayed via the UI
    let keys = [
      UserDefaultsKeys.serverURL,
      UserDefaultsKeys.nowPlayingProgress,
      UserDefaultsKeys.queueActiveIdx,
      UserDefaultsKeys.playbackMode,
    ]

    for key in keys {
      if let value = UserDefaults.standard.object(forKey: key) {
        result[key] = value
      }
    }

    return result
  }

  static func removeObject(key: String) {
    UserDefaults.standard.removeObject(forKey: key)
  }

  static var serverBaseURL: String {
    get {
      return UserDefaults.standard.string(forKey: UserDefaultsKeys.serverURL) ?? ""
    }
    set {
      UserDefaults.standard.set(newValue, forKey: UserDefaultsKeys.serverURL)
    }
  }

  static var queueActiveIdx: Int {
    get {
      return UserDefaults.standard.integer(forKey: UserDefaultsKeys.queueActiveIdx)
    }
    set {
      UserDefaults.standard.set(newValue, forKey: UserDefaultsKeys.queueActiveIdx)
    }
  }

  static var nowPlayingProgress: Double {
    get {
      return UserDefaults.standard.double(forKey: UserDefaultsKeys.nowPlayingProgress)
    }
    set {
      UserDefaults.standard.set(newValue, forKey: UserDefaultsKeys.nowPlayingProgress)
    }
  }

  static var playbackMode: String {
    get {
      return UserDefaults.standard.string(forKey: UserDefaultsKeys.playbackMode)
        ?? PlaybackMode.defaultPlayback
    }
    set {
      UserDefaults.standard.set(newValue, forKey: UserDefaultsKeys.playbackMode)
    }
  }

  static var enableDebug: Bool {
    get {
      return UserDefaults.standard.bool(forKey: UserDefaultsKeys.enableDebug)
    }
    set {
      UserDefaults.standard.set(newValue, forKey: UserDefaultsKeys.enableDebug)
    }
  }

  static var maxBitRate: String {
    get {
      return UserDefaults.standard.string(forKey: UserDefaultsKeys.enableMaxBitRate)
        ?? TranscodingSettings.sourceBitRate
    }
    set {
      UserDefaults.standard.set(newValue, forKey: UserDefaultsKeys.enableMaxBitRate)
    }
  }

  static var playerBackground: String {
    get {
      return PlayerBackground.translucent
    }
    set {
      UserDefaults.standard.set(
        PlayerBackground.translucent, forKey: UserDefaultsKeys.playerBackground)
    }
  }

  static var saveLoginInfo: Bool {
    get {
      return UserDefaults.standard.bool(forKey: UserDefaultsKeys.saveLoginInfo)
    }

    set {
      UserDefaults.standard.set(newValue, forKey: UserDefaultsKeys.saveLoginInfo)
    }
  }

  static var LRCLIBServerURL: String {
    get {
      return UserDefaults.standard.string(forKey: UserDefaultsKeys.LRCLIBServerURL) ?? ""
    }

    set {
      UserDefaults.standard.set(newValue, forKey: UserDefaultsKeys.LRCLIBServerURL)
    }
  }

  static var streamCacheMaxSize: Int64 {
    get {
      let stored = UserDefaults.standard.object(forKey: UserDefaultsKeys.streamCacheMaxSize)
      return (stored as? Int64) ?? 0  // default off
    }
    set {
      UserDefaults.standard.set(newValue, forKey: UserDefaultsKeys.streamCacheMaxSize)
    }
  }

  static var libraryViewV2: Bool {
    get {
      return UserDefaults.standard.bool(forKey: UserDefaultsKeys.libraryViewV2)
    }
    set {
      UserDefaults.standard.set(newValue, forKey: UserDefaultsKeys.libraryViewV2)
    }
  }

  static var playbackVolume: Float {
    get {
      if UserDefaults.standard.object(forKey: UserDefaultsKeys.playbackVolume) == nil {
        return 1.0
      }
      return UserDefaults.standard.float(forKey: UserDefaultsKeys.playbackVolume)
    }
    set {
      UserDefaults.standard.set(newValue, forKey: UserDefaultsKeys.playbackVolume)
    }
  }

  static var uiFontScale: Float {
    get {
      if UserDefaults.standard.object(forKey: UserDefaultsKeys.uiFontScale) == nil {
        return 1.0
      }
      let raw = UserDefaults.standard.float(forKey: UserDefaultsKeys.uiFontScale)
      // Clamp on read so out-of-bounds values persisted externally are normalized
      return min(max(raw, 0.8), 1.4)
    }
    set {
      let clamped = min(max(newValue, 0.8), 1.4)
      UserDefaults.standard.set(clamped, forKey: UserDefaultsKeys.uiFontScale)
    }
  }

  /// Number of times the user has tipped a given product. Stored per product so
  /// it survives relaunch, and recoverable from StoreKit history on reinstall.
  static func tipCount(for productID: String) -> Int {
    return UserDefaults.standard.integer(forKey: "tipCount.\(productID)")
  }

  static func setTipCount(_ count: Int, for productID: String) {
    UserDefaults.standard.set(count, forKey: "tipCount.\(productID)")
  }

}
