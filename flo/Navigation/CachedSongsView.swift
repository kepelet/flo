//
//  CachedSongsView.swift
//  flo
//

import NukeUI
import SwiftUI

struct CachedSongsView: View {
  @ObservedObject var viewModel: AlbumViewModel
  @EnvironmentObject private var playerViewModel: PlayerViewModel

  let songs: [Song]

  var body: some View {
    ScrollView {
      LazyVStack {
        ForEach(Array(songs.enumerated()), id: \.element.id) { idx, song in
          VStack {
            HStack {
              LazyImage(url: URL(string: viewModel.getAlbumCoverArt(id: song.albumId))) { state in
                if let image = state.image {
                  image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 60, height: 60)
                    .clipShape(
                      RoundedRectangle(cornerRadius: 10, style: .continuous)
                    )
                } else {
                  Color("PlayerColor").frame(width: 60, height: 60)
                    .cornerRadius(5)
                }
              }

              VStack(alignment: .leading) {
                Text(song.title)
                  .customFont(.headline)
                  .multilineTextAlignment(.leading)
                  .lineLimit(2)
                  .padding(.bottom, 3)

                Text(song.artist)
                  .customFont(.subheadline)
                  .foregroundColor(.gray)
                  .lineLimit(2)
                  .multilineTextAlignment(.leading)
              }
              .padding(.horizontal, 10)

              Spacer()

              Text(timeString(for: song.duration)).customFont(.caption1)
            }
            .padding(.horizontal)
            .background(Color(UIColor.systemBackground))

            Divider()
          }
          .onTapGesture {
            let cached = SongCollection(id: "cached-songs", name: "Cached", songs: songs)
            playerViewModel.playBySong(idx: idx, item: cached, isFromLocal: true)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
        }
      }
      .padding(.top, 10)
      .padding(
        .bottom, playerViewModel.hasNowPlaying() && !playerViewModel.shouldHidePlayer ? 100 : 0)
    }
    .navigationTitle("Cached")
  }
}
