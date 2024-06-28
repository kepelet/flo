//
//  AlbumsView.swift
//  flo
//
//  Created by rizaldy on 26/06/24.
//

import SwiftUI

struct AlbumsView: View {
  var viewModel: AlbumViewModel
  var album: Album

  var body: some View {
    VStack(alignment: .leading) {
      AsyncImage(url: URL(string: viewModel.getAlbumArt(id: album.id))) { phase in
        switch phase {
        case .empty:
          ProgressView().frame(width: 150, height: 150)

        case .success(let image):
          image
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(maxWidth: .infinity, maxHeight: 300)
            .clipShape(
              RoundedRectangle(cornerRadius: 5, style: .continuous)
            )

        case .failure:
          ZStack {
            Color("PlayerColor")
              .frame(maxWidth: .infinity, maxHeight: 300)
              .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            Image(systemName: "photo")
              .resizable()
              .aspectRatio(contentMode: .fit)
              .padding()
              .padding(.top, 10)
              .padding(.bottom, 10)
              .foregroundColor(Color("PlayerColor"))
          }

        @unknown default:
          ZStack {
            Color("PlayerColor")
              .frame(maxWidth: .infinity, maxHeight: 250)
              .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            Image(systemName: "photo")
              .resizable()
              .aspectRatio(contentMode: .fit)
              .padding()
              .padding(.bottom, 20)
              .foregroundColor(Color("PlayerColor"))
          }
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

struct AlbumsView_Preview: PreviewProvider {
  @StateObject static private var viewModel: AlbumViewModel = AlbumViewModel()

  static private var albumData = Album(name: "Album 1", artist: "Artist 1")

  static var previews: some View {
    AlbumsView(viewModel: viewModel, album: albumData)
  }
}
