//
//  Constants.swift
//  flo
//
//  Created by rizaldy on 06/06/24.
//

import Foundation
import SwiftUI
import UIKit

enum API {
  static let NDAuthHeader = "X-ND-Authorization"

  enum NDEndpoint {
    static let login = "/auth/login"
    static let getAlbum = "/api/album"
    static let getArtists = "/api/artist"
    static let getPlaylists = "/api/playlist"
    static let getSong = "/api/song"
    static let getGenre = "/api/genre"
    static let shareAlbum = "/api/share"
    static let listenBrainzLink = "/api/listenbrainz/link"
    static let lastFMLink = "/api/lastfm/link"
  }

  enum SubsonicEndpoint {
    static let stream = "/rest/stream"
    static let coverArt = "/rest/getCoverArt"
    static let albuminfo = "/rest/getAlbumInfo"
    static let scanStatus = "/rest/getScanStatus"
    static let download = "/rest/download"
    static let scrobble = "/rest/scrobble"
    static let radios = "/rest/getInternetRadioStations"
    static let similarSongs = "/rest/getSimilarSongs2"
    static let topSongs = "/rest/getTopSongs"
    static let star = "/rest/star"
    static let unstar = "/rest/unstar"
    static let getStarred2 = "/rest/getStarred2"
    static let getAlbumList2 = "/rest/getAlbumList2"
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
  static let enableDebug = "enableDebug"
  static let enableMaxBitRate = "enableMaxBitRate"
  static let playerBackground = "playerBackground"
  static let saveLoginInfo = "saveLoginInfo"
  static let LRCLIBServerURL = "LRCLIBServerURL"
  static let streamCacheMaxSize = "streamCacheMaxSize"
  static let libraryViewV2 = "libraryViewV2"
  static let playbackVolume = "playbackVolume"
  static let uiFontScale = "uiFontScale"
}

enum KeychainKeys {
  // On iOS the app has historically shipped with this fixed service name; keep it
  // to avoid logging existing users out on upgrade. On Mac Catalyst the keychain
  // is namespaced by app bundle id, so use that to ensure writes succeed.
  #if targetEnvironment(macCatalyst)
    static let service = Bundle.main.bundleIdentifier ?? AppMeta.identifier
  #else
    static let service = AppMeta.identifier
  #endif
  static let dataKey = "authCreds"
  static let serverPassword = "serverPassword"
}

enum TranscodingSettings {
  static let availableBitRate = [
    "0", "32", "48", "64", "80", "96", "112", "128", "160", "192", "224", "256", "320",
  ]
  static let sourceBitRate = "0"
  static let sourceFormat = "raw"
  static let targetFormat = "mp3"
}

enum PlayerBackground {
  static let availablePlayerBackground = ["solid", "translucent"]
  static let solid = "solid"
  static let translucent = "translucent"
}

// MARK: - Pad-aware bottom padding helper (pad/mac floating player is ~68pt tall)
// Returns 140 when now-playing on pad/mac (iPadOS 18+ / macCatalyst 18+), otherwise iPhone values unchanged.
var isPadOrMacLayout: Bool {
  #if targetEnvironment(macCatalyst)
    if #available(iOS 18.0, *) { return true }
    return false
  #else
    guard UIDevice.current.userInterfaceIdiom == .pad else { return false }
    if #available(iOS 18.0, *) { return true }
    return false
  #endif
}

func playerContentBottomPadding(hasNowPlaying: Bool, iPhoneActive: CGFloat, iPhoneInactive: CGFloat) -> CGFloat {
  if hasNowPlaying {
    return isPadOrMacLayout ? 140 : iPhoneActive
  } else {
    return iPhoneInactive
  }
}

func playerContentBottomPadding(viewModel: PlayerViewModel, iPhoneActive: CGFloat, iPhoneInactive: CGFloat) -> CGFloat {
  let hasNow = viewModel.hasNowPlaying() && !viewModel.shouldHidePlayer
  return playerContentBottomPadding(hasNowPlaying: hasNow, iPhoneActive: iPhoneActive, iPhoneInactive: iPhoneInactive)
}
