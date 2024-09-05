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
