//
//  ArtistDetailView.swift
//  flo
//
//  Created by rizaldy on 17/11/24.
//

import SwiftUI

struct ArtistDetailView: View {
  @EnvironmentObject var viewModel: AlbumViewModel
  @EnvironmentObject var playerViewModel: PlayerViewModel

  @StateObject var artistDetailViewModel = ArtistDetailViewModel()
  
  @State private var isExpanded = false
  @State private var displayAlert: Bool = false

  let artist: Artist

  let columns = [
    GridItem(.flexible()),
    GridItem(.flexible()),
  ]

  func stripBiography(biography: String) -> String {
    guard let regex = try? NSRegularExpression(pattern: "<a[^>]*>.*?</a>") else {
      return biography.isEmpty ? "No biography available" : biography
    }

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

        Text(stripBiography(biography: artist.biography ?? ""))
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
      HStack {
        if artistDetailViewModel.isLoading {
          ProgressView()
            .tint(Color.accentColor)
            .background()
            .frame(maxWidth: .infinity)
        } else {
          // MARK: Artist Radio
          Button(action: {
            artistDetailViewModel.fetchArtistRadio(artist: artist)
          }) {
            HStack {
              Image(systemName: "dot.radiowaves.up.forward")
              Text("Play Artist Radio")
            }
            .font(.subheadline)
            .fontWeight(.semibold)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.accentColor)
            .cornerRadius(20)
          }
          .disabled(artistDetailViewModel.isLoading)
          .frame(maxWidth: .infinity, alignment: .leading)
          
          Button(action: {
            // MARK: Top Songs
            artistDetailViewModel.fetchTopSongs(artist: artist)
          }) {
            HStack {
              Image(systemName: "dot.radiowaves.up.forward")
              Text("Play Top Songs")
            }
            .font(.subheadline)
            .fontWeight(.semibold)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.accentColor)
            .cornerRadius(20)
          }
          .disabled(artistDetailViewModel.isLoading)
          .frame(maxWidth: .infinity, alignment: .leading)
        }
      }
      .foregroundStyle(.background)
      .frame(maxWidth: .infinity, minHeight: 40)
      .padding(.horizontal)
      .padding(.bottom, 8)

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
    .onReceive(artistDetailViewModel.playableSongs) { songs in
      if songs.isEmpty {
        displayAlert = true
      } else {
        let playable = RadioEntity(
          id: artist.id,
          name: "\(artist.name) Radio",
          songs: songs,
          artist: artist.name
        )
        playerViewModel.playItem(item: playable, isFromLocal: false)
      }
    }
    .alert("Artist Radio", isPresented: $displayAlert) {
      Button("OK") {
        artistDetailViewModel.errorMessage = nil
      }
    } message: {
      Text(artistDetailViewModel.errorMessage ?? "")
    }
  }
}
