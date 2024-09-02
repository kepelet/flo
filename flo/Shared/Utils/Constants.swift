//
//  Constants.swift
//  flo
//
//  Created by rizaldy on 06/06/24.
//

import Foundation

struct API {
  static let NDAuthHeader = "X-ND-Authorization"

  struct NDEndpoint {
    static let login = "/auth/login"
    static let getAlbum = "/api/album"
    static let getSong = "/api/song"
    static let shareAlbum = "/api/share"
  }

  struct SubsonicEndpoint {
    static let stream = "/rest/stream"
    static let coverArt = "/rest/getCoverArt"
    static let albuminfo = "/rest/getAlbumInfo"
    static let scanStatus = "/rest/getScanStatus"
    static let download = "/rest/download"
  }
}

enum PlaybackMode {
  static let defaultPlayback = "default"
  static let repeatAlbum = "repeatAlbum"
  static let repeatOnce = "repeatOnce"
}

enum AppMeta {
  static let name = "flo"
  static let identifier = "net.faultables.flo"
  static let subsonicApiVersion = "1.16.1"  // FIXME: should we respect the subsonic-response?
}

enum UserDefaultsKeys {
  static let serverURL = "serverURL"
  static let queueActiveIdx = "queueActiveIdx"
  static let nowPlayingProgress = "nowPlayingProgress"
  static let playbackMode = "playbackMode"
}

enum KeychainKeys {
  static let service = AppMeta.identifier
  static let dataKey = "authCreds"
}
