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

  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  @State private var searchPlaylist = ""
  @State private var showDownloadSheet: Bool = false

  private var columns: [GridItem] {
    if horizontalSizeClass == .regular {
      return Array(repeating: GridItem(.flexible()), count: 4)
    } else {
      return Array(repeating: GridItem(.flexible()), count: 2)
    }
  }

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
    ScrollView {
      LazyVGrid(columns: columns) {
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
            PlaylistsView(viewModel: viewModel, playlist: playlist)
          }
        }
      }
      .padding(.top, 10)
      .padding(
        .bottom, playerContentBottomPadding(viewModel: playerViewModel, iPhoneActive: 100, iPhoneInactive: 0)
      )
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
    .refreshable {
      await viewModel.refreshPlaylists()
    }
    .searchable(
      text: $searchPlaylist, placement: .navigationBarDrawer(displayMode: .always),
      prompt: "Search")
  }
}
