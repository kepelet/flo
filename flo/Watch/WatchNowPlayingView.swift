//
//  WatchNowPlayingView.swift
//  flo
//
//  Created by Codex on 17/02/26.
//

#if os(watchOS)
import SwiftUI

struct WatchNowPlayingView: View {
  @ObservedObject var playerViewModel: WatchPlayerViewModel

  var body: some View {
    ScrollView {
      VStack(spacing: 10) {
        if !playerViewModel.nowPlayingTitle.isEmpty {
          Text(playerViewModel.contextTitle)
            .font(.caption)
            .foregroundColor(.secondary)
            .lineLimit(1)

          VStack(spacing: 2) {
            Text(playerViewModel.nowPlayingTitle)
              .font(.headline)
              .lineLimit(2)
            Text(playerViewModel.nowPlayingArtist)
              .font(.caption)
              .foregroundColor(.secondary)
              .lineLimit(1)
          }

          HStack(spacing: 16) {
            Button {
              playerViewModel.previous()
            } label: {
              Image(systemName: "backward.fill")
            }

            Button {
              playerViewModel.togglePlayPause()
            } label: {
              Image(systemName: playerViewModel.isPlaying ? "pause.fill" : "play.fill")
            }

            Button {
              playerViewModel.next()
            } label: {
              Image(systemName: "forward.fill")
            }
          }
        } else {
          Text("Nothing Playing")
            .font(.headline)
            .foregroundColor(.secondary)
        }
      }
      .padding(.horizontal, 8)
    }
    .navigationTitle("Now Playing")
  }
}
#endif
