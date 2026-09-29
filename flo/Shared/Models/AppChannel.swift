//
//  AppChannel.swift
//  flo
//
//  Created by rizaldy on 24/09/26.
//

import Foundation

/// Build-time release channel, stamped into the binary via the `FLO_CHANNEL`
/// user-defined build setting (expanded into the `FLOChannel` Info.plist key;
/// project default "" + fastlane xcargs stamp). Set by fastlane on the mac
/// lane: public TestFlight → `beta`, internal TestFlight → `preview`,
/// store / unset → `store`.
///
/// There is no runtime API for "which TestFlight group installed this",
/// so the channel must be baked in at build time — one upload per channel.
enum AppChannel: String {
  case store
  case beta
  case preview

  static var current: Self {
    #if DEBUG
      // Local dev builds carry no channel stamp; surface them as preview
      // so they never masquerade as production.
      if channelFromInfoPlist == .store { return .preview }
    #endif
    return channelFromInfoPlist
  }

  private static var channelFromInfoPlist: Self {
    guard
      let raw = Bundle.main.infoDictionary?["FLOChannel"] as? String,
      let channel = Self(rawValue: raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
    else { return .store }
    return channel
  }

  /// Channel word shown beside the app name: "" (store), "Beta", or "Preview".
  var channelLabel: String {
    switch self {
    case .store: return ""
    case .beta: return "Beta"
    case .preview: return "Preview"
    }
  }
}
