//
//  WatchPlaylistsView.swift
//  flo
//
//  Created by Codex on 17/02/26.
//

#if os(watchOS)
import SwiftUI

struct WatchPlaylistsView: View {
  @ObservedObject var libraryViewModel: WatchLibraryViewModel
  @ObservedObject var playerViewModel: WatchPlayerViewModel

  var body: some View {
    List {
      if libraryViewModel.isLoading {
        ProgressView()
      }

      if let errorMessage = libraryViewModel.errorMessage {
        Text(errorMessage)
          .foregroundColor(.red)
      }

      ForEach(libraryViewModel.playlists) { playlist in
        NavigationLink {
          WatchPlaylistDetailView(
            playlist: playlist,
            libraryViewModel: libraryViewModel,
            playerViewModel: playerViewModel
          )
        } label: {
          VStack(alignment: .leading, spacing: 2) {
            Text(playlist.name)
              .font(.headline)
              .lineLimit(1)
            Text(playlist.ownerName)
              .font(.caption)
              .foregroundColor(.secondary)
              .lineLimit(1)
          }
        }
      }
    }
    .navigationTitle("Playlists")
    .onAppear {
      if libraryViewModel.playlists.isEmpty {
        libraryViewModel.loadPlaylists()
      }
    }
  }
}
#endif
