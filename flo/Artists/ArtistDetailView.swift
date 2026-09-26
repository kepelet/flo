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
  @EnvironmentObject var downloadViewModel: DownloadViewModel
  @EnvironmentObject var pins: PinnedStore

  @StateObject var artistDetailViewModel = ArtistDetailViewModel()

  @State private var isExpanded = false
  @State private var displayAlert: Bool = false

  let artist: Artist

  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  private var columns: [GridItem] {
    if horizontalSizeClass == .regular {
      return Array(repeating: GridItem(.flexible()), count: 4)
    } else {
      return Array(repeating: GridItem(.flexible()), count: 2)
    }
  }

  func stripBiography(biography: String) -> String {
    guard let regex = try? NSRegularExpression(pattern: "<a[^>]*>.*?</a>") else {
      return biography.isEmpty ? "No biography available" : biography
    }

    let range = NSRange(location: 0, length: biography.utf16.count)

    let stripped = regex.stringByReplacingMatches(
      in: biography, range: range, withTemplate: ""
    )

    return stripped == "" ? "No biography available" : stripped
  }

  private func playArtistTracks(shuffle: Bool) {
    artistDetailViewModel.fetchArtistSongs(albums: viewModel.artistAlbums) { songs in
      if songs.isEmpty {
        artistDetailViewModel.errorMessage = "No songs found for this artist."
        displayAlert = true
      } else {
        let collection = SongCollection(id: artist.id, name: artist.name, songs: songs)
        if shuffle {
          playerViewModel.shuffleItem(item: collection, isFromLocal: false)
        } else {
          playerViewModel.playItem(item: collection, isFromLocal: false)
        }
      }
    }
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading) {
        HStack(alignment: .top, spacing: 16) {
          ArtistImageView(artist: artist, size: 88)

          VStack(alignment: .leading, spacing: 6) {
            Text(artist.name)
              .customFont(.title)
              .fontWeight(.bold)
              .multilineTextAlignment(.leading)
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
        }
      }
      .padding()
      .onAppear {
        viewModel.fetchAlbumsByArtist(id: artist.id)
      }
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 12) {
          Button(action: {
            playArtistTracks(shuffle: false)
          }) {
            if artistDetailViewModel.isLoadingTracks {
              ProgressView()
                .tint(Color(UIColor.systemBackground))
            } else {
              Image(systemName: "play.fill")
            }
          }
          .font(.headline)
          .frame(width: 44, height: 44)
          .background(Color.accentColor)
          .foregroundStyle(.background)
          .clipShape(Circle())
          .accessibilityLabel("Play artist tracks")
          .disabled(
            viewModel.artistAlbums.isEmpty || artistDetailViewModel.isLoadingTracks
              || artistDetailViewModel.isLoadingRadio || artistDetailViewModel.isLoadingTopSongs
          )

          Button(action: {
            playArtistTracks(shuffle: true)
          }) {
            if artistDetailViewModel.isLoadingTracks {
              ProgressView()
            } else {
              Image(systemName: "shuffle")
            }
          }
          .font(.headline)
          .frame(width: 44, height: 44)
          .background(Color.accentColor.opacity(0.15))
          .foregroundStyle(Color.accentColor)
          .clipShape(Circle())
          .accessibilityLabel("Shuffle artist tracks")
          .disabled(
            viewModel.artistAlbums.isEmpty || artistDetailViewModel.isLoadingTracks
              || artistDetailViewModel.isLoadingRadio || artistDetailViewModel.isLoadingTopSongs
          )

          Button(action: {
            artistDetailViewModel.fetchArtistRadio(artist: artist)
          }) {
            HStack(spacing: 6) {
              Group {
                if artistDetailViewModel.isLoadingRadio {
                  ProgressView()
                    .tint(Color(UIColor.systemBackground))
                } else {
                  Image(systemName: "dot.radiowaves.left.and.right")
                }
              }
              // Fixed slot so the spinner swaps the icon 1:1 — text stays
              // put and the button never changes width while loading.
              .frame(width: 20, height: 20)
              Text("Play Artist Radio")
            }
            .font(.subheadline)
            .fontWeight(.semibold)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color.accentColor)
            .cornerRadius(16)
            .fixedSize(horizontal: true, vertical: false)
          }
          .foregroundStyle(.background)
          .disabled(
            artistDetailViewModel.isLoadingRadio || artistDetailViewModel.isLoadingTopSongs
              || artistDetailViewModel.isLoadingTracks
          )

          Button(action: {
            artistDetailViewModel.fetchTopSongs(artist: artist)
          }) {
            HStack(spacing: 6) {
              Group {
                if artistDetailViewModel.isLoadingTopSongs {
                  ProgressView()
                    .tint(Color(UIColor.systemBackground))
                } else {
                  Image(systemName: "star")
                }
              }
              // Fixed slot so the spinner swaps the icon 1:1 — text stays
              // put and the button never changes width while loading.
              .frame(width: 20, height: 20)
              Text("Play Top Songs")
            }
            .font(.subheadline)
            .fontWeight(.semibold)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color.accentColor)
            .cornerRadius(16)
            .fixedSize(horizontal: true, vertical: false)
          }
          .foregroundStyle(.background)
          .disabled(
            artistDetailViewModel.isLoadingRadio || artistDetailViewModel.isLoadingTopSongs
              || artistDetailViewModel.isLoadingTracks
          )
        }
        .padding(.horizontal)
      }
      .padding(.bottom, 8)

      LazyVGrid(columns: columns) {
        ForEach(viewModel.artistAlbums) { album in
          NavigationLink {
            AlbumView(viewModel: viewModel)
              .environmentObject(playerViewModel)
              .environmentObject(downloadViewModel)
              .onAppear {
                viewModel.setActiveAlbum(album: album)
              }
          } label: {
            AlbumsView(viewModel: viewModel, album: album)
          }
        }
      }.padding(.bottom, playerContentBottomPadding(viewModel: playerViewModel, iPhoneActive: 100, iPhoneInactive: 12))
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
    .alert("Artist", isPresented: $displayAlert) {
      Button("OK") {
        artistDetailViewModel.errorMessage = nil
      }
    } message: {
      Text(artistDetailViewModel.errorMessage ?? "")
    }
    .toolbar {
      Button(action: {
        pins.toggle(artist: artist)
      }) {
        Label(
          pins.isPinned(artist: artist) ? "Unpin artist" : "Pin artist",
          systemImage: pins.isPinned(artist: artist) ? "pin.fill" : "pin"
        )
      }
    }
  }
}
