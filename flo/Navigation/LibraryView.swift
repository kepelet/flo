//
//  LibraryView.swift
//  flo
//
//  Created by rizaldy on 08/06/24.
//

import SwiftUI

struct LibraryView: View {
  @State private var searchAlbum = ""

  @ObservedObject var viewModel: AlbumViewModel

  @EnvironmentObject var playerViewModel: PlayerViewModel

  let columns = [
    GridItem(.flexible()),
    GridItem(.flexible()),
  ]

  var filteredAlbums: [Album] {
    if searchAlbum.isEmpty {
      return viewModel.albums
    } else {
      return viewModel.albums.filter { album in
        album.name.localizedCaseInsensitiveContains(searchAlbum)
      }
    }
  }

  var body: some View {
    NavigationView {
      ScrollView {
        if viewModel.albums.isEmpty && viewModel.error != nil {
          VStack(alignment: .leading) {
            Image("Home").resizable().aspectRatio(contentMode: .fit).frame(
              maxWidth: .infinity, maxHeight: 300
            ).padding()
            Group {
              Text("Your Navidrome session may have expired")
                .customFont(.title1)
                .fontWeight(.bold)
                .multilineTextAlignment(.leading)
                .padding(.bottom, 10)
              Text(
                "The quickest action you can take is to log back in — for now."
              )
              .customFont(.subheadline)

            }.padding(.horizontal, 20).foregroundColor(.accent)
          }
        }

        LazyVGrid(columns: columns) {
          ForEach(filteredAlbums) { album in
            NavigationLink(
              destination:
                AlbumView(viewModel: viewModel).onAppear {
                  viewModel.setActiveAlbum(album: album)
                }
            ) {
              AlbumsView(viewModel: viewModel, album: album)
            }
          }
        }.padding(.top, 10).padding(
          .bottom, playerViewModel.hasNowPlaying() && !playerViewModel.shouldHidePlayer ? 100 : 0)
      }
      .searchable(
        text: $searchAlbum,
        placement: .navigationBarDrawer,
        prompt: "Search"
      )
      .navigationTitle("Library")
    }
  }
}

struct LibraryView_Previews: PreviewProvider {
  static private var songs: [Song] = [
    Song(
      id: "0", title: "Song name", artist: "Artist Name", trackNumber: 1, discNumber: 0, bitRate: 0,
      sampleRate: 44100,
      suffix: "m4a", duration: 100)
  ]

  static private var albums: [Album] = [
    Album(
      name: "Album 1",
      artist: "Artist 1",
      songs: songs
    )
  ]
  @StateObject static private var playerViewModel: PlayerViewModel = PlayerViewModel()
  @StateObject static private var viewModel: AlbumViewModel = AlbumViewModel(albums: albums)

  static var previews: some View {
    LibraryView(viewModel: viewModel).environmentObject(playerViewModel)
  }
}
