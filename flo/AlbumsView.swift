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

struct AlbumsView_Preview: PreviewProvider {
  @StateObject static private var viewModel: AlbumViewModel = AlbumViewModel()

  static private var albumData = Album(name: "Album 1", artist: "Artist 1")

  static var previews: some View {
    AlbumsView(viewModel: viewModel, album: albumData)
  }
}
