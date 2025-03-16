//
//  ArtistsView.swift
//  flo
//
//  Created by rizaldy on 30/10/24.
//

import SwiftUI

struct ArtistsView: View {
  @EnvironmentObject private var viewModel: AlbumViewModel

  @State private var searchArtist = ""

  let artists: [Artist]

  var filteredArtists: [Artist] {
    if searchArtist.isEmpty {
      return artists
    } else {
      return artists.filter { artist in
        artist.name.localizedCaseInsensitiveContains(searchArtist)
          || artist.fullText.localizedCaseInsensitiveContains(searchArtist)
      }
    }
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        LazyVStack {
          ForEach(filteredArtists) { artist in
            NavigationLink {
              ArtistDetailView(artist: artist)
                .environmentObject(viewModel)
            } label: {
              VStack {
                HStack {
                  Text(artist.name)
                    .customFont(.headline)
                    .multilineTextAlignment(.leading)

                  Spacer()

                  Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
                    .font(.caption)
                }
                .padding(.horizontal)
                .padding(.vertical, 5)

                Divider()
              }
            }
          }
        }.padding(.bottom, 100)
      }
      .navigationTitle("Artists")
      .searchable(
        text: $searchArtist, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search"
      )
    }
  }
}

struct ArtistsView_Previews: PreviewProvider {
  static var previews: some View {
    ArtistsView(artists: [])
  }
}
