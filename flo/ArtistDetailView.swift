//
//  ArtistDetailView.swift
//  flo
//
//  Created by rizaldy on 17/11/24.
//

import SwiftUI

struct ArtistDetailView: View {
  @EnvironmentObject var viewModel: AlbumViewModel

  @State private var isExpanded = false

  var artist: Artist

  let columns = [
    GridItem(.flexible()),
    GridItem(.flexible()),
  ]

  func stripBiography(biography: String) -> String {
    let regex = try! NSRegularExpression(pattern: "<a[^>]*>.*?</a>")
    let range = NSRange(location: 0, length: biography.utf16.count)

    let stripped = regex.stringByReplacingMatches(
      in: biography, range: range, withTemplate: "")

    return stripped == "" ? "No biography available" : stripped
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading) {
        Text(artist.name)
          .customFont(.title)
          .fontWeight(.bold)
          .multilineTextAlignment(.leading)
          .padding(.bottom, 3)
          .frame(maxWidth: .infinity, alignment: .leading)

        Text(stripBiography(biography: artist.biography))
          .customFont(.subheadline)
          .lineSpacing(3)
          .multilineTextAlignment(.leading)
          .lineLimit(isExpanded ? nil : 3)
          .onTapGesture {
            isExpanded.toggle()
          }
      }
      .padding()
      .onAppear {
        viewModel.fetchAlbumsByArtist(id: artist.id)
      }

      LazyVGrid(columns: columns) {
        ForEach(viewModel.artistAlbums) { album in
          NavigationLink {
            AlbumView(viewModel: viewModel)
              .onAppear {
                viewModel.setActiveAlbum(album: album)
              }
          } label: {
            AlbumsView(viewModel: viewModel, album: album)
          }
        }
      }.padding(.bottom, 100)
    }
  }
}
