//
//  WatchHomeView.swift
//  flo
//
//  Created by Codex on 17/02/26.
//

#if os(watchOS)
import SwiftUI

struct WatchHomeView: View {
  @ObservedObject var libraryViewModel: WatchLibraryViewModel
  @ObservedObject var playerViewModel: WatchPlayerViewModel

  var body: some View {
    NavigationStack {
      List {
        Section("Library") {
          NavigationLink("Albums") {
            WatchAlbumsView(
              libraryViewModel: libraryViewModel,
              playerViewModel: playerViewModel
            )
          }
          NavigationLink("Artists") {
            WatchArtistsView(
              libraryViewModel: libraryViewModel,
              playerViewModel: playerViewModel
            )
          }
          NavigationLink("Playlists") {
            WatchPlaylistsView(
              libraryViewModel: libraryViewModel,
              playerViewModel: playerViewModel
            )
          }
        }

        Section("Player") {
          NavigationLink("Now Playing") {
            WatchNowPlayingView(playerViewModel: playerViewModel)
          }
        }

        Section("Status") {
          if WatchConnectivityManager.shared.isReachable {
            Text("Connected")
              .foregroundColor(.green)
          } else {
            Text("Disconnected")
              .foregroundColor(.red)
          }
        }
      }
      .navigationTitle("flo")
    }
  }
}
#endif
