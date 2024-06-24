//
//  UserDefaultsManager.swift
//  flo
//
//  Created by rizaldy on 09/06/24.
//

import Foundation

class UserDefaultsManager {
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

  static var nowPlaying: Data? {
    get {
      return UserDefaults.standard.data(forKey: UserDefaultsKeys.nowPlaying)
    }
    set {
      UserDefaults.standard.set(newValue, forKey: UserDefaultsKeys.nowPlaying)
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
}