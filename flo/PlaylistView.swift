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
  @EnvironmentObject private var downloadViewModel: DownloadViewModel

  @State private var searchPlaylist = ""
  @State private var showDownloadSheet: Bool = false

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
                .environmentObject(downloadViewModel)
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

                Divider()
              }
            }
          }
        }.padding(.bottom, 100)
      }
      .toolbar {
        if downloadViewModel.hasDownloadQueue() {
          Button(action: {
            showDownloadSheet.toggle()
          }) {
            Label("", systemImage: "icloud.and.arrow.down")
          }
        }
      }
      .sheet(isPresented: $showDownloadSheet) {
        DownloadQueueView().environmentObject(downloadViewModel)
      }
      .navigationTitle("Playlists")
      .searchable(
        text: $searchPlaylist, placement: .navigationBarDrawer(displayMode: .always),
        prompt: "Search")
    }
  }
}
