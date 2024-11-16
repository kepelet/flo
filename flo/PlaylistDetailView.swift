//
//  PlaylistDetailView.swift
//  flo
//
//  Created by rizaldy on 16/11/24.
//

import SwiftUI

struct PlaylistDetailView: View {
  @EnvironmentObject private var viewModel: AlbumViewModel
  @EnvironmentObject private var playerViewModel: PlayerViewModel

  var body: some View {
    ScrollView {
      VStack {
        Text(viewModel.playlist.name)
          .customFont(.title)
          .fontWeight(.bold)
          .multilineTextAlignment(.center)
          .padding(.bottom, 5)

        Text(viewModel.playlist.comment)
          .customFont(.body)
          .multilineTextAlignment(.center)
          .padding(.bottom, 10)

        Text(
          "by \(viewModel.playlist.ownerName) (\(viewModel.playlist.isPublic ? "public" : "private"))"
        )
        .customFont(.caption1)
        .multilineTextAlignment(.center)
        .padding(.bottom, 10)

        HStack(spacing: 20) {
          Button(action: {
            print(viewModel.playlist.songs)
            playerViewModel.playItem(
              item: viewModel.playlist,
              isFromLocal: false)

          }) {
            Text("Play")
              .foregroundColor(.white)
              .customFont(.headline)
              .padding(.vertical, 10)
              .padding(.horizontal, 30)
              .background(Color("PlayerColor"))
              .cornerRadius(5)
          }.disabled(viewModel.playlist.songs.isEmpty)

          Button(action: {
            playerViewModel.shuffleItem(
              item: viewModel.playlist,
              isFromLocal: false)
          }) {
            Text("Shuffle")
              .foregroundColor(.white)
              .customFont(.headline)
              .padding(.vertical, 10)
              .padding(.horizontal, 30)
              .background(Color("PlayerColor"))
              .cornerRadius(5)
          }.disabled(viewModel.playlist.songs.isEmpty)
        }
        .padding(.bottom, 20)

        ForEach(Array(viewModel.playlist.songs.enumerated()), id: \.element) { idx, song in
          VStack {
            HStack(alignment: .top) {
              Text(song.id)
                .customFont(.caption1)
                .foregroundColor(.gray)
                .padding(.trailing, 5)

              Text(song.title)
                .fontWeight(.medium)

              Spacer()

              if !song.fileUrl.isEmpty {
                Image(systemName: "arrow.down.circle.fill")
                  .font(.system(size: 14))
              }

              Text(timeString(for: song.duration)).customFont(.caption1)
            }
          }
          .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
          .listRowSeparator(.hidden)
          .contentShape(Rectangle())
          .onTapGesture {
            playerViewModel.playBySong(
              idx: idx, item: viewModel.playlist, isFromLocal: false)
          }
        }
        .environment(\.defaultMinListRowHeight, 60)
        .listStyle(PlainListStyle()).padding().customFont(.body)
      }
      .padding(.bottom, 100)
    }
  }
}
