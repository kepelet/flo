//
//  WatchAlbumDetailView.swift
//  flo
//
//  Created by Codex on 17/02/26.
//

#if os(watchOS)
  import SwiftUI

  struct WatchAlbumDetailView: View {
    let album: Album

    @ObservedObject var libraryViewModel: WatchLibraryViewModel
    @ObservedObject var playerViewModel: WatchPlayerViewModel

    var body: some View {
      let songs = libraryViewModel.albumSongs[album.id] ?? []

      List {
        Section {
          HStack(spacing: 10) {
            WatchCoverArtView(
              coverArt: album.albumCover,
              size: 44
            )

            VStack(alignment: .leading, spacing: 2) {
              Text(album.name)
                .font(.headline)
              Text(album.artist)
                .font(.caption)
                .foregroundColor(.secondary)
            }
          }

          if !songs.isEmpty {
            Button("Play All") {
              playerViewModel.playAlbum(album, songs: songs)
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
              playerViewModel.playSong(song, inAlbum: album)
            } label: {
              VStack(alignment: .leading, spacing: 2) {
                Text(song.title)
                  .font(.body)
                  .lineLimit(1)
              }
            }
          }
        }
      }
      .navigationTitle(album.name)
      .onAppear {
        libraryViewModel.loadSongs(for: album)
      }
    }
  }
#endif
