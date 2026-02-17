//
//  WatchArtistsView.swift
//  flo
//
//  Created by Codex on 17/02/26.
//

#if os(watchOS)
  import SwiftUI

  struct WatchArtistsView: View {
    @ObservedObject var libraryViewModel: WatchLibraryViewModel
    @ObservedObject var playerViewModel: WatchPlayerViewModel

    private var filteredArtists: [Artist] {
      libraryViewModel.artists.filter { artist in
        artist.stats.albumartist != nil
      }
    }

    var body: some View {
      List {
        if libraryViewModel.isLoading {
          ProgressView()
        }

        if let errorMessage = libraryViewModel.errorMessage {
          Text(errorMessage)
            .foregroundColor(.red)
        }

        ForEach(filteredArtists) { artist in
          NavigationLink {
            WatchArtistDetailView(
              artist: artist,
              libraryViewModel: libraryViewModel,
              playerViewModel: playerViewModel
            )
          } label: {
            VStack(alignment: .leading, spacing: 2) {
              Text(artist.name)
                .font(.headline)
                .lineLimit(1)
              Text("\(artist.albumCount) albums")
                .font(.caption)
                .foregroundColor(.secondary)
            }
          }
        }
      }
      .navigationTitle("Artists")
      .onAppear {
        if libraryViewModel.artists.isEmpty {
          libraryViewModel.loadArtists()
        }
      }
    }
  }
#endif
