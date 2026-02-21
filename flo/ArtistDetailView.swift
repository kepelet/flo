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

  @State private var isExpanded = false
  @State private var isLoadingRadio = false

  var artist: Artist

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

      Button(action: {
        isLoadingRadio = true
        RadioService.shared.getSimilarSongs(id: artist.id) { result in
          DispatchQueue.main.async {
            isLoadingRadio = false
            switch result {
            case .success(let songs):
              print("Artist Radio: got \(songs.count) songs")
              if !songs.isEmpty {
                let playable = ArtistRadioPlayable(
                  id: artist.id,
                  name: "\(artist.name) Radio",
                  songs: songs,
                  artist: artist.name
                )
                playerViewModel.playItem(item: playable, isFromLocal: false)
              }
            case .failure(let error):
              print("Artist Radio error: \(error)")
            }
          }
        }
      }) {
        HStack {
          if isLoadingRadio {
            ProgressView()
              .tint(.white)
          } else {
            Image(systemName: "dot.radiowaves.up.forward")
          }
          Text("Artist Radio")
        }
        .font(.subheadline)
        .fontWeight(.semibold)
        .foregroundColor(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.accentColor)
        .cornerRadius(20)
      }
      .disabled(isLoadingRadio)
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
  }
}
