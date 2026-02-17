//
//  WatchAlbumsView.swift
//  flo
//
//  Created by Codex on 17/02/26.
//

#if os(watchOS)
  import SwiftUI

  struct WatchAlbumsView: View {
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

        ForEach(libraryViewModel.albums) { album in
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
                  .font(.headline)
                  .lineLimit(1)

                Text(album.artist)
                  .font(.caption)
                  .foregroundColor(.secondary)
                  .lineLimit(1)
              }
            }
          }
        }
      }
      .navigationTitle("Albums")
      .onAppear {
        if libraryViewModel.albums.isEmpty {
          libraryViewModel.loadAlbums()
        }
      }
    }
  }
#endif
