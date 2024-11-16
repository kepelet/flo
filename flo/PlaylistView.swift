//
//  PlaylistView.swift
//  flo
//
//  Created by rizaldy on 15/11/24.
//

import SwiftUI

struct PlaylistView: View {
  @EnvironmentObject private var viewModel: AlbumViewModel
  @EnvironmentObject private var playerViewModel: PlayerViewModel

  @State private var searchPlaylist = ""

  var filteredPlaylists: [Playlist] {
    if searchPlaylist.isEmpty {
      return viewModel.playlists
    } else {
      return viewModel.playlists.filter { playlist in
        playlist.name.localizedCaseInsensitiveContains(searchPlaylist)
      }
    }
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        LazyVStack {
          ForEach(filteredPlaylists) { playlist in
            NavigationLink {
              PlaylistDetailView()
                .environmentObject(viewModel)
                .environmentObject(playerViewModel)
                .onAppear {
                  viewModel.setActivePlaylist(playlist: playlist)
                }
            } label: {
              VStack {
                HStack {
                  VStack(alignment: .leading) {
                    Text("\(playlist.name)\(playlist.isPublic ? "" : " 🔒")")
                      .customFont(.headline)
                      .multilineTextAlignment(.leading)

                    Text(playlist.comment)
                      .customFont(.caption1)
                      .multilineTextAlignment(.leading)
                  }

                  Spacer()

                  Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
                    .font(.caption)
                }
                .padding(.horizontal)
                .padding(.vertical, 5)

                Rectangle()
                  .frame(height: 0.5)
                  .foregroundColor(.gray.opacity(0.5))
              }
            }
          }
        }.padding(.bottom, 100)
      }
      .navigationTitle("Playlists")
      .searchable(
        text: $searchPlaylist, placement: .navigationBarDrawer(displayMode: .always),
        prompt: "Search")
    }
  }
}
