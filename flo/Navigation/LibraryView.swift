//
//  LibraryView.swift
//  flo
//
//  Created by rizaldy on 08/06/24.
//

import SwiftUI

struct LibraryView: View {
  @ObservedObject var viewModel: AlbumViewModel

  let columns = [
    GridItem(.flexible()),
    GridItem(.flexible()),
  ]

  var body: some View {
    NavigationView {
      ScrollView {
        LazyVGrid(columns: columns, spacing: 20) {
          ForEach(viewModel.albums) { album in
            NavigationLink(
              destination:
                AlbumView(viewModel: viewModel).onAppear {
                  viewModel.setActiveAlbum(album: album)
                }
            ) {
              AlbumsView(viewModel: viewModel, album: album)
            }
          }
        }.padding(.top, 10).padding(.bottom, 100)
      }
      .navigationTitle("Library")
    }
  }
}

struct LibraryView_Previews: PreviewProvider {
  static private var songs: [Song] = [
    Song(
      id: "0", title: "Song name", artist: "Artist Name", trackNumber: 1, discNumber: 0, bitRate: 0,
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
