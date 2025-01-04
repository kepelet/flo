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
      return UserDefaults.standard.string(forKey: UserDefaultsKeys.playerBackground)
        ?? PlayerBackground.translucent
    }
    set {
      UserDefaults.standard.set(newValue, forKey: UserDefaultsKeys.playerBackground)
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
}
