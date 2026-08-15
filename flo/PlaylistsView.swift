//
//  PlaylistsView.swift
//  flo
//
//  Created by rizaldy on 16/08/26.
//

import NukeUI
import SwiftUI

struct PlaylistsView: View {
  var viewModel: AlbumViewModel
  var playlist: Playlist

  var body: some View {
    Group {
      VStack(alignment: .leading) {
        if let image = UIImage(
          contentsOfFile: viewModel.getPlaylistCoverArt(
            id: playlist.id, coverArtId: playlist.coverArtId))
        {
          Image(uiImage: image)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(maxWidth: .infinity, maxHeight: 300)
            .clipShape(
              RoundedRectangle(cornerRadius: 5, style: .continuous)
            )
        } else {
          LazyImage(
            url: URL(
              string: viewModel.getPlaylistCoverArt(
                id: playlist.id, coverArtId: playlist.coverArtId))
          ) { state in
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

        HStack(alignment: .center, spacing: 4) {
          Text(playlist.name)
            .customFont(.caption1)
            .fontWeight(.bold)
            .foregroundColor(.primary)
            .truncationMode(.tail)
            .lineLimit(1)
            .multilineTextAlignment(.leading)

          if !playlist.isPublic {
            Text("🔒")
              .customFont(.caption2)
          }
        }
        .padding(.trailing, 20)
        .frame(maxWidth: .infinity, alignment: .leading)

        Text(playlist.ownerName)
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

struct PlaylistsView_Preview: PreviewProvider {
  @StateObject static private var viewModel: AlbumViewModel = AlbumViewModel()

  static private var playlistData = Playlist(name: "Playlist 1", ownerName: "Owner 1")

  static var previews: some View {
    PlaylistsView(viewModel: viewModel, playlist: playlistData)
  }
}
