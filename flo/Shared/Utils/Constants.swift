//
//  Constants.swift
//  flo
//
//  Created by rizaldy on 06/06/24.
//

import Combine
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

enum LRCLIBSource {
  static func displayName(for urlString: String) -> String? {
    guard !urlString.isEmpty else { return nil }
    switch urlString {
    case "https://lrclib.net":
      return "lrclib.net"
    case "https://lrclib.flooo.club":
      return "lrclib.flooo.club"
    default:
      return "Custom"
    }
  }
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

// MARK: - Isolated player presence (prevents progress storms)
// Observes only queue + shouldHidePlayer so parent views don't rebuild on every 1s progress tick.
final class PlayerPresenceObserver: ObservableObject {
  @Published var hasNowPlaying: Bool = PlayerViewModel.shared.hasNowPlaying() && !PlayerViewModel.shared.shouldHidePlayer
  private var cancellables = Set<AnyCancellable>()
  init() {
    Publishers.CombineLatest(PlayerViewModel.shared.$queue, PlayerViewModel.shared.$shouldHidePlayer)
      .map { queue, hide in !queue.isEmpty && !hide }
      .removeDuplicates()
      .receive(on: DispatchQueue.main)
      .sink { [weak self] has in self?.hasNowPlaying = has }
      .store(in: &cancellables)
  }
}

struct PlayerBottomPadding: ViewModifier {
  @StateObject private var presence = PlayerPresenceObserver()
  var active: CGFloat
  var inactive: CGFloat
  func body(content: Content) -> some View {
    content.padding(.bottom, playerContentBottomPadding(hasNowPlaying: presence.hasNowPlaying, iPhoneActive: active, iPhoneInactive: inactive))
  }
}

extension View {
  func playerBottomPadding(active: CGFloat, inactive: CGFloat) -> some View {
    modifier(PlayerBottomPadding(active: active, inactive: inactive))
  }

  /// Native popup-button menu on Catalyst, where SwiftUI popover menus can
  /// size to gigantic proportions. No-op on other platforms.
  @ViewBuilder
  func catalystNativeMenuStyle() -> some View {
    #if targetEnvironment(macCatalyst)
      self.menuStyle(.button)
    #else
      self
    #endif
  }
}

/// Search field: Catalyst hosts a custom field in the window toolbar (title
/// area) with fully controllable padding; other platforms use the native
/// navigation-bar drawer. Exactly one renders per platform, so call sites
/// use this alone (no separate `.searchable`).
extension View {
  @ViewBuilder
  func catalystAwareSearch(text: Binding<String>, prompt: String) -> some View {
    #if targetEnvironment(macCatalyst)
      self.toolbar {
        if #available(iOS 26.0, macOS 26.0, macCatalyst 26.0, *) {
          // macOS 26+ draws one shared capsule behind adjacent toolbar items,
          // which visually fuses the search field with the filter menu next
          // to it. Opt out so the field's own rounded background reads as a
          // separate control (and the filter keeps its own capsule).
          ToolbarItem(placement: .primaryAction) {
            CatalystToolbarSearchField(text: text, prompt: prompt)
          }
          .sharedBackgroundVisibility(.hidden)
        } else {
          ToolbarItem(placement: .primaryAction) {
            CatalystToolbarSearchField(text: text, prompt: prompt)
          }
        }
      }
    #else
      self.searchable(
        text: text, placement: .navigationBarDrawer(displayMode: .always), prompt: prompt)
    #endif
  }
}

#if targetEnvironment(macCatalyst)
  /// Custom toolbar search field shared by every Catalyst screen.
  private struct CatalystToolbarSearchField: View {
    @Binding var text: String
    let prompt: String

    var body: some View {
      HStack(spacing: 6) {
        Image(systemName: "magnifyingglass")
          .foregroundColor(.secondary)
        TextField(prompt, text: $text)
          .textFieldStyle(.plain)
        if !text.isEmpty {
          Button {
            text = ""
          } label: {
            Image(systemName: "xmark.circle.fill")
              .foregroundColor(.secondary)
          }
          .buttonStyle(.plain)
        }
      }
      .padding(.horizontal, 8)
      .padding(.vertical, 5)
      .frame(width: 200)
      .background(
        .ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
      .padding(.top, 2)
    }
  }
#endif
#if targetEnvironment(macCatalyst)
  /// Plain navigation-bar heading: system font and primary label color, no
  /// toolbar shared background (macOS 26 Liquid Glass). Deliberately not
  /// `customFont` — that forces the app's purple accent color, which reads as
  /// a tappable control instead of a window title.
  private struct CatalystNavigationHeading: View {
    let title: String

    var body: some View {
      Text(title)
        .font(.headline)
        .foregroundStyle(.primary)
        .lineLimit(1)
        .fixedSize()
    }
  }
#endif

#if targetEnvironment(macCatalyst)
  /// Invisible anchor attached to each screen. When SwiftUI inserts it into the
  /// window, the enclosing navigation stack already exists — lifting it right
  /// away means a freshly built page is never painted in the unlifted position
  /// (which reads as the header jumping after a tab switch).
  final class CatalystHeaderLiftAnchorView: UIView {
    var onWindow: (() -> Void)?

    override func willMove(toWindow newWindow: UIWindow?) {
      super.willMove(toWindow: newWindow)
      // Fires *before* the subtree is attached and laid out, so the lift is in
      // place before the navigation controller places its bar.
      if newWindow != nil { onWindow?() }
    }

    override func didMoveToWindow() {
      super.didMoveToWindow()
      if window != nil { onWindow?() }
    }
  }

  struct CatalystHeaderLiftAnchor: UIViewRepresentable {
    func makeUIView(context: Context) -> CatalystHeaderLiftAnchorView {
      let view = CatalystHeaderLiftAnchorView(frame: .zero)
      view.isUserInteractionEnabled = false
      view.backgroundColor = .clear
      view.onWindow = { [weak view] in
        guard let view = view else { return }
        // Walk up to the enclosing navigation controller's root view (its
        // `next` responder is the controller) and lift its host before this
        // page is painted. The window's safe area can still be zero at this
        // point, so the lift reads the safe area itself on every layout pass.
        var candidate: UIView? = view
        while let ancestor = candidate {
          if let nav = ancestor.next as? UINavigationController {
            SceneDelegate.wrapCatalystHeader(
              for: nav.view, topInset: nav.view.window?.safeAreaInsets.top ?? 0)
            return
          }
          candidate = ancestor.superview
        }
      }
      return view
    }

    func updateUIView(_ uiView: CatalystHeaderLiftAnchorView, context: Context) {}
  }
#endif

/// Page heading.
///
/// On Catalyst the window titlebar carries no title (see SceneDelegate:
/// `titleVisibility = .hidden`) and the heading is hosted in the navigation
/// bar, on the same row as the toolbar actions instead of on a title row of
/// its own. It sits at the leading edge of the content area (right of the
/// sidebar), the usual macOS sidebar-app placement. iOS keeps its heading.
///
/// - Note: Top-level `extension View` lives in this file; the `#if` keeps
///   both branches' opaque `some View` types consistent per platform.
extension View {
  @ViewBuilder
  func catalystAwareNavigationTitle(
    _ title: String,
    displayMode: NavigationBarItem.TitleDisplayMode = .automatic
  ) -> some View {
    #if targetEnvironment(macCatalyst)
      self.toolbar {
        if #available(iOS 26.0, macOS 26.0, macCatalyst 26.0, *) {
          ToolbarItem(placement: .navigation) {
            CatalystNavigationHeading(title: title)
          }
          .sharedBackgroundVisibility(.hidden)
        } else {
          ToolbarItem(placement: .navigation) {
            CatalystNavigationHeading(title: title)
          }
        }
      }
      .background(CatalystHeaderLiftAnchor())
    #else
      // Note: `navigationTitle(_:displayMode:)` does not exist — the older
      // `navigationBarTitle` spelling with `.automatic` renders identically.
      self.navigationBarTitle(title, displayMode: displayMode)
    #endif
  }
}
