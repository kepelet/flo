//
//  WatchArtistDetailView.swift
//  flo
//
//  Created by Codex on 17/02/26.
//

#if os(watchOS)
  import SwiftUI

  struct WatchArtistDetailView: View {
    let artist: Artist

    @ObservedObject var libraryViewModel: WatchLibraryViewModel
    @ObservedObject var playerViewModel: WatchPlayerViewModel

    var body: some View {
      let albums = libraryViewModel.artistAlbums[artist.id] ?? []

      List {
        if libraryViewModel.isLoading {
          ProgressView()
        }

        if let errorMessage = libraryViewModel.errorMessage {
          Text(errorMessage)
            .foregroundColor(.red)
        }

        ForEach(albums) { album in
          NavigationLink {
            WatchAlbumDetailView(
              album: album,
              libraryViewModel: libraryViewModel,
              playerViewModel: playerViewModel
            )
          } label: {
            HStack(spacing: 10) {
              WatchCoverArtView(
                coverArt: album.albumCover,
                size: 36
              )

              VStack(alignment: .leading, spacing: 2) {
                Text(album.name)
                  .font(.body)
                  .lineLimit(1)

                Text(album.minYear > 0 ? String(album.minYear) : album.artist)
                  .font(.caption)
                  .foregroundColor(.secondary)
              }
            }
          }
        }
      }
      .navigationTitle(artist.name)
      .onAppear {
        libraryViewModel.loadAlbums(for: artist)
      }
    }
  }
#endif
