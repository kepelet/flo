//
//  DownloadsView.swift
//  flo
//
//  Created by rizaldy on 08/06/24.
//

import SwiftUI

struct DownloadsView: View {
  @State private var searchAlbum = ""

  @ObservedObject var viewModel: AlbumViewModel

  @EnvironmentObject var playerViewModel: PlayerViewModel

  let columns = [
    GridItem(.flexible()),
    GridItem(.flexible()),
  ]

  var filteredAlbums: [Album] {
    if searchAlbum.isEmpty {
      return viewModel.downloadedAlbums
    } else {
      return viewModel.downloadedAlbums.filter { album in
        album.name.localizedCaseInsensitiveContains(searchAlbum)
      }
    }
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        if viewModel.downloadedAlbums.isEmpty {
          VStack(alignment: .leading) {
            Image("Downloads").resizable().aspectRatio(contentMode: .fit).frame(width: 300)
              .padding()
              .padding(.bottom, 10)
            Group {
              Text("Going off the grid?")
                .customFont(.title1)
                .fontWeight(.bold)
                .multilineTextAlignment(.leading)
                .padding(.bottom, 10)
              Text(
                "Bring your music anywhere, even when you're offline. Your downloaded music will be here."
              )
              .customFont(.subheadline)

            }.padding(.horizontal, 20).foregroundColor(.accent)
          }
        }

        LazyVGrid(columns: columns, spacing: 20) {
          ForEach(filteredAlbums) { album in
            NavigationLink {
              AlbumView(viewModel: viewModel, isDownloadScreen: true)
                .onAppear {
                  viewModel.setActiveAlbum(album: album)
                }
            } label: {
              AlbumsView(viewModel: viewModel, album: album, isDownloadScreen: true)
            }
          }
        }.padding(.top, 10).padding(
          .bottom, playerViewModel.hasNowPlaying() && !playerViewModel.shouldHidePlayer ? 100 : 0
        ).navigationTitle("Downloads")
          .searchable(
            text: $searchAlbum,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Search"
          )
      }
    }
  }
}

struct DownloadsView_Previews: PreviewProvider {
  @StateObject static var viewModel: AlbumViewModel = AlbumViewModel()

  static var previews: some View {
    DownloadsView(viewModel: viewModel)
  }
}
