//
//  WatchSongsView.swift
//  flo
//
//  Created by Codex on 17/02/26.
//

#if os(watchOS)
import SwiftUI

struct WatchSongsView: View {
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

      ForEach(libraryViewModel.songs) { song in
        Button {
          playerViewModel.playSongAll(song)
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
    .navigationTitle("Songs")
    .onAppear {
      if libraryViewModel.songs.isEmpty {
        libraryViewModel.loadAllSongs()
      }
    }
  }
}
#endif
