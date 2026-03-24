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
  @State private var filterAlbumArtistOnly: Bool = true

  let artists: [Artist]

  var filteredArtists: [Artist] {
    artists.filter { artist in
      let matchesAlbumArtist = !filterAlbumArtistOnly || artist.stats.albumartist != nil
      let matchesSearch = searchArtist.isEmpty || artist.name.localizedCaseInsensitiveContains(searchArtist)
      return matchesAlbumArtist && matchesSearch
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
      .refreshable {
        await viewModel.refreshArtists()
      }
      .searchable(
        text: $searchArtist, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search"
      )
      .toolbar {
        Menu {
          Button {
            self.filterAlbumArtistOnly.toggle()
          } label: {
            Label("Album Artist Only", systemImage: self.filterAlbumArtistOnly ?  "checkmark.circle" :  "circle")
          }
        } label: {
          Label("", systemImage: "ellipsis.circle")
        }
      }
    }
  }
}

struct ArtistsView_Previews: PreviewProvider {
  static var previews: some View {
    ArtistsView(artists: [])
  }
}
