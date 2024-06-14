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
                AlbumView(
                  viewModel: viewModel, album: album, albumArt: viewModel.getAlbumArt(id: album.id))
            ) {
              VStack(alignment: .leading) {
                AsyncImage(url: URL(string: viewModel.getAlbumArt(id: album.id))) { phase in
                  switch phase {
                  case .empty:
                    ProgressView().frame(width: 150, height: 150)
                  case .success(let image):
                    image
                      .resizable()
                      .aspectRatio(contentMode: .fit)
                      .frame(width: 150, height: 150)
                      .clipShape(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                      )

                  case .failure:
                    Color("PlayerColor").frame(width: 150, height: 150)
                      .cornerRadius(5)
                  @unknown default:
                    EmptyView().frame(width: 150, height: 150)
                  }
                }

                Text(album.name)
                  .customFont(.caption1)
                  .fontWeight(.bold)
                  .foregroundColor(.primary)
                  .truncationMode(.tail)
                  .padding(.trailing, 20)
                  .lineLimit(1)
                  .multilineTextAlignment(.leading)
                  .frame(maxWidth: .infinity, alignment: .leading)

                Text(album.artist)
                  .customFont(.caption2)
                  .foregroundColor(.gray)
                  .truncationMode(.tail)
                  .padding(.trailing, 20)
                  .lineLimit(1)
                  .frame(maxWidth: .infinity, alignment: .leading)

              }.padding(.horizontal)
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
