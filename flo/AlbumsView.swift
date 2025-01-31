//
//  AlbumsView.swift
//  flo
//
//  Created by rizaldy on 26/06/24.
//

import NukeUI
import SwiftUI

struct AlbumsView: View {
  var viewModel: AlbumViewModel
  var album: Album

  var isDownloadScreen: Bool = false

  var body: some View {
    Group {
      VStack(alignment: .leading) {
        if self.isDownloadScreen {
          if let image = UIImage(
            contentsOfFile: viewModel.getAlbumCoverArt(
              id: album.id, artistName: album.artist, albumName: album.name))
          {
            Image(uiImage: image)
              .resizable()
              .aspectRatio(contentMode: .fill)
              .frame(maxWidth: .infinity, maxHeight: 300)
              .clipShape(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
              )
          } else {
            if let image = UIImage(named: "placeholder") {
              Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(maxWidth: .infinity, maxHeight: 300)
                .clipShape(
                  RoundedRectangle(cornerRadius: 5, style: .continuous)
                )
            }
          }
        } else {
          if let image = UIImage(
            contentsOfFile: viewModel.getAlbumCoverArt(id: album.id))
          {
            Image(uiImage: image)
              .resizable()
              .aspectRatio(contentMode: .fill)
              .frame(maxWidth: .infinity, maxHeight: 300)
              .clipShape(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
              )
          } else {
            LazyImage(url: URL(string: viewModel.getAlbumCoverArt(id: album.id))) { state in
              if let image = state.image {
                image
                  .resizable()
                  .aspectRatio(contentMode: .fill)
                  .frame(maxWidth: .infinity, maxHeight: 300)
                  .clipShape(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                  )
              } else {
                if let image = UIImage(named: "placeholder") {
                  Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity, maxHeight: 300)
                    .clipShape(
                      RoundedRectangle(cornerRadius: 5, style: .continuous)
                    )
                }
              }
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

        Text(album.albumArtist)
          .customFont(.caption2)
          .foregroundColor(.gray)
          .truncationMode(.tail)
          .padding(.trailing, 20)
          .lineLimit(1)
          .frame(maxWidth: .infinity, alignment: .leading)
      }.padding()
    }
  }
}

struct AlbumsView_Preview: PreviewProvider {
  @StateObject static private var viewModel: AlbumViewModel = AlbumViewModel()

  static private var albumData = Album(name: "Album 1", artist: "Artist 1")

  static var previews: some View {
    AlbumsView(viewModel: viewModel, album: albumData)
  }
}
