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
      Section {
        Text(artist.name)
          .font(.headline)
      }

      if libraryViewModel.isLoading {
        ProgressView()
      }

      if let errorMessage = libraryViewModel.errorMessage {
        Text(errorMessage)
          .foregroundColor(.red)
      }

      Section("Albums") {
        ForEach(albums) { album in
          NavigationLink {
            WatchAlbumDetailView(
              album: album,
              libraryViewModel: libraryViewModel,
              playerViewModel: playerViewModel
            )
          } label: {
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
    .navigationTitle("Artist")
    .onAppear {
      libraryViewModel.loadAlbums(for: artist)
    }
  }
}
#endif
