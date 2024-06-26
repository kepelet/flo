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

  // FIXME: https://github.com/kepelet/flo/issues/4 on "something-is-wrong-with-songs-props"
  static var _albumPlayQueue: Data? {
    get {
      return UserDefaults.standard.data(forKey: UserDefaultsKeys._albumPlayQueue)
    }
    set {
      UserDefaults.standard.set(newValue, forKey: UserDefaultsKeys._albumPlayQueue)
    }
  }

  static var playQueue: Data? {
    get {
      return UserDefaults.standard.data(forKey: UserDefaultsKeys.playQueue)
    }
    set {
      UserDefaults.standard.set(newValue, forKey: UserDefaultsKeys.playQueue)
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
}
