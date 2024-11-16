//
//  SongsView.swift
//  flo
//
//  Created by rizaldy on 17/11/24.
//

import NukeUI
import SwiftUI

struct SongsView: View {
  @EnvironmentObject private var viewModel: AlbumViewModel
  @EnvironmentObject private var playerViewModel: PlayerViewModel

  @State private var searchSong = ""

  var filteredSongs: [Song] {
    if searchSong.isEmpty {
      return viewModel.songs
    } else {
      return viewModel.songs.filter { song in
        song.title.localizedCaseInsensitiveContains(searchSong)
      }
    }
  }

  var body: some View {
    ScrollView {
      LazyVStack {
        ForEach(Array(filteredSongs.enumerated()), id: \.element) { idx, song in
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
            }
            .padding(.horizontal)

            Rectangle()
              .frame(height: 0.5)
              .foregroundColor(.gray.opacity(0.5))
          }
          .onTapGesture {
            var playlist = Playlist(name: "\"All Tracks\"")
            let songs = filteredSongs.dropFirst(idx)

            playlist.songs = Array(songs)

            playerViewModel.playBySong(
              idx: 0, item: playlist, isFromLocal: false)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
        }
      }
      .padding(.top, 10)
      .padding(.bottom, 100)
      .navigationTitle("Songs")
      .searchable(
        text: $searchSong, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search")
    }
  }
}
