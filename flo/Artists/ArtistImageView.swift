//
//  ArtistImageView.swift
//  flo
//

import NukeUI
import SwiftUI

struct ArtistImageView: View {
  @EnvironmentObject private var viewModel: AlbumViewModel

  let artist: Artist
  var size: CGFloat = 44

  var body: some View {
    let imageURL = artist.mediumImageURL ?? artist.smallImageURL ?? artist.largeImageURL ?? ""
    let hasImageSource = !artist.id.isEmpty || !imageURL.isEmpty

    if hasImageSource {
      LazyImage(url: URL(string: viewModel.getArtistCoverArt(id: artist.id, imageURL: imageURL))) {
        state in
        if let image = state.image {
          image
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: size, height: size)
            .clipShape(Circle())
        } else {
          placeholderImage
        }
      }
    } else {
      placeholderImage
    }
  }

  private var placeholderImage: some View {
    Image("placeholder")
      .resizable()
      .aspectRatio(contentMode: .fill)
      .frame(width: size, height: size)
      .clipShape(Circle())
  }
}
