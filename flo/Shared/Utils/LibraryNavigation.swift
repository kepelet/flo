//
//  LibraryNavigation.swift
//  flo
//

import SwiftUI

enum AppTab: Hashable {
  case home
  case library
  case libraryAlbums
  case libraryArtists
  case likedSongs
  case playlists
  case songs
  case radios
  case downloads
  case preferences
  case debug
  case search
}

// MARK: - FLO-36: tab selection clamping (single source of truth, pure logic)

/// Pure helper: returns `selected` if it is in `available`, otherwise `fallback` if that is available, otherwise any available tab.
/// Always prefers to keep the current selection; only falls back when it has vanished.
func normalizedTab(_ selected: AppTab, available: Set<AppTab>, fallback: AppTab = .home) -> AppTab {
  if available.contains(selected) { return selected }
  if available.contains(fallback) { return fallback }
  // Home is always available in practice; this branch is defensive.
  return available.first ?? fallback
}

/// Pure helper: computes the exact set of tabs that the active TabView variant renders,
/// mirroring the conditional gates in `ContentView.baseTabView` and `ContentView.sidebarTabView`.
///
/// - isPadSidebar: `true` when `ContentView.isPadSidebar` (device is iPad + iOS 18+ or Catalyst 18+), i.e. sidebarTabView is active via rootTabView; otherwise baseTabView is active.
/// - isLoggedIn: `AuthViewModel.isLoggedIn`
/// - libraryViewV2Enabled: `UserDefaultsKeys.libraryViewV2`
/// - isDebugEnabled: `UserDefaultsManager.enableDebug` / `UserDefaultsKeys.enableDebug`
func availableTabs(
  isPadSidebar: Bool,
  isLoggedIn: Bool,
  libraryViewV2Enabled: Bool,
  isDebugEnabled: Bool
) -> Set<AppTab> {
  if isPadSidebar {
    // Mirrors sidebarTabView (iOS 18+)
    var tabs: Set<AppTab> = [.home, .preferences]
    if libraryViewV2Enabled {
      tabs.insert(.library)
      tabs.insert(.search)
    }
    if isLoggedIn || libraryViewV2Enabled {
      tabs.formUnion([.libraryAlbums, .libraryArtists, .likedSongs, .playlists, .songs, .radios])
    }
    if !libraryViewV2Enabled {
      tabs.insert(.downloads)
    }
    if isDebugEnabled {
      tabs.insert(.debug)
    }
    return tabs
  } else {
    // Mirrors baseTabView
    if libraryViewV2Enabled {
      var tabs: Set<AppTab> = [.home, .library, .search, .preferences]
      if isDebugEnabled { tabs.insert(.debug) }
      return tabs
    } else {
      var tabs: Set<AppTab> = [.home, .downloads, .preferences]
      if isLoggedIn { tabs.insert(.library) }
      if isDebugEnabled { tabs.insert(.debug) }
      return tabs
    }
  }
}

/// Pure helper backing ContentView's render-time clamped `TabView(selection:)` binding.
/// The binding getter normalizes through this so the TabView never observes a
/// selection outside `available` — not even for a single diff pass between a
/// tab-removing state change and its `onChange` repair (FLO-36).
func clampedSelectionValue(_ selected: AppTab, available: Set<AppTab>, fallback: AppTab = .home) -> AppTab {
  normalizedTab(selected, available: available, fallback: fallback)
}

extension LibraryRouter {
  /// Clamps `selectedTab` to `available`, using `fallback` when the current selection has vanished.
  /// No-op when already valid. Pure logic aside from the final assignment.
  func clampSelection(to available: Set<AppTab>, fallback: AppTab = .home) {
    let clamped = normalizedTab(selectedTab, available: available, fallback: fallback)
    if clamped != selectedTab {
      selectedTab = clamped
    }
  }
}

final class LibraryRouter: ObservableObject {
  @Published var selectedTab: AppTab = .home
  @Published var homePath = NavigationPath()
  @Published var libraryPath = NavigationPath()
  @Published var artistsPath = NavigationPath()
}

struct LibraryDestinationView: View {
  let destination: LibraryDestination

  @ObservedObject var albumViewModel: AlbumViewModel
  @ObservedObject var playerViewModel: PlayerViewModel
  @ObservedObject var downloadViewModel: DownloadViewModel

  var body: some View {
    switch destination {
    case .artist(let id, let name):
      if let artist = albumViewModel.artistForNavigation(id: id, name: name) {
        ArtistDetailView(artist: artist)
          .environmentObject(albumViewModel)
          .environmentObject(playerViewModel)
          .environmentObject(downloadViewModel)
      } else {
        Text("Artist unavailable")
          .foregroundColor(.secondary)
      }
    case .album(let id, let name, let artist):
      if let album = albumViewModel.albumForNavigation(id: id, name: name, artist: artist) {
        AlbumView(viewModel: albumViewModel)
          .environmentObject(playerViewModel)
          .environmentObject(downloadViewModel)
          .onAppear {
            albumViewModel.setActiveAlbum(album: album)
          }
      } else {
        Text("Album unavailable")
          .foregroundColor(.secondary)
      }
    }
  }
}
