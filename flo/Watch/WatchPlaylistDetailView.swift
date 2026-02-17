//
//  WatchPlaylistDetailView.swift
//  flo
//
//  Created by Codex on 17/02/26.
//

#if os(watchOS)
import SwiftUI

struct WatchPlaylistDetailView: View {
  let playlist: Playlist
  @ObservedObject var libraryViewModel: WatchLibraryViewModel
  @ObservedObject var playerViewModel: WatchPlayerViewModel

  var body: some View {
    let songs = libraryViewModel.playlistSongs[playlist.id] ?? []

    List {
      Section {
        VStack(alignment: .leading, spacing: 2) {
          Text(playlist.name)
            .font(.headline)
          Text(playlist.ownerName)
            .font(.caption)
            .foregroundColor(.secondary)
        }

        if !songs.isEmpty {
          Button("Play All") {
            playerViewModel.playPlaylist(playlist, songs: songs)
          }
        }
      }

      if libraryViewModel.isLoading {
        ProgressView()
      }

      if let errorMessage = libraryViewModel.errorMessage {
        Text(errorMessage)
          .foregroundColor(.red)
      }

      Section("Songs") {
        ForEach(Array(songs.enumerated()), id: \.offset) { _, song in
          Button {
            playerViewModel.playSong(song, inPlaylist: playlist)
          } label: {
            VStack(alignment: .leading, spacing: 2) {
              Text(song.title)
                .font(.body)
                .lineLimit(1)
              Text(song.artist)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
            }
          }
        }
      }
    }
    .navigationTitle("Playlist")
    .onAppear {
      libraryViewModel.loadSongs(for: playlist)
    }
  }
}
#endif
