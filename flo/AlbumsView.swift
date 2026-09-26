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
              id: album.id, artistName: album.artist, albumName: album.name,
              albumCover: album.albumCover))
          {
            albumArtwork(Image(uiImage: image))
          } else {
            if let image = UIImage(named: "placeholder") {
              albumArtwork(Image(uiImage: image))
            }
          }
        } else {
          if let image = UIImage(
            contentsOfFile: viewModel.getAlbumCoverArt(id: album.id, albumCover: album.albumCover))
          {
            albumArtwork(Image(uiImage: image))
          } else {
            LazyImage(
              url: URL(
                string: viewModel.getAlbumCoverArt(id: album.id, albumCover: album.albumCover))
            ) { state in
              if let image = state.image {
                albumArtwork(image)
              } else {
                if let image = UIImage(named: "placeholder") {
                  albumArtwork(Image(uiImage: image))
                }
              }
            }
          }
        }

        HStack(alignment: .center, spacing: 4) {
          Text(album.name)
            .customFont(.caption1)
            .fontWeight(.bold)
            .foregroundColor(.primary)
            .truncationMode(.tail)
            .lineLimit(1)
            .multilineTextAlignment(.leading)

          if album.isExplicit {
            ExplicitBadge(size: .compact)
          }
        }
        .padding(.trailing, 20)
        .frame(maxWidth: .infinity, alignment: .leading)

        Text(album.albumArtist)
          .customFont(.caption2)
          .foregroundColor(.gray)
          .truncationMode(.tail)
          .padding(.trailing, 20)
          .lineLimit(1)
          .frame(maxWidth: .infinity, alignment: .leading)
      }.padding()
      .padding(.bottom, 12)
    }
  }

  private func albumArtwork(_ image: Image) -> some View {
    GeometryReader { proxy in
      image
        .resizable()
        .scaledToFill()
        .frame(width: proxy.size.width, height: proxy.size.width)
        .clipShape(
          RoundedRectangle(cornerRadius: 5, style: .continuous)
        )
    }
    .aspectRatio(1, contentMode: .fit)
  }
}

/// Searchable wrapper for the Albums tab.
///
/// ContentView.swift owns the Albums NavigationStack and builds its tab via
/// `AlbumsGridView()`. Search is provided solely by `.catalystAwareSearch` —
/// native `.searchable` on iOS/iPadOS, custom toolbar field on Catalyst — so
/// exactly one field renders per platform. No inline duplicate.
/// Filtering is live on name + artist/albumArtist, case-insensitive.
struct AlbumsGridView: View {
  @EnvironmentObject var albumViewModel: AlbumViewModel
  @EnvironmentObject var downloadViewModel: DownloadViewModel
  @EnvironmentObject var pins: PinnedStore
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  @State private var searchText = ""

  private var columns: [GridItem] {
    if horizontalSizeClass == .regular {
      #if targetEnvironment(macCatalyst)
        return Array(repeating: GridItem(.flexible(), spacing: 10), count: 5)
      #else
        return Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)
      #endif
    }
    return Array(repeating: GridItem(.flexible(), spacing: 10), count: 2)
  }

  private var filteredAlbums: [Album] {
    if searchText.isEmpty { return albumViewModel.albums }
    return albumViewModel.albums.filter { album in
      album.name.localizedCaseInsensitiveContains(searchText)
        || album.artist.localizedCaseInsensitiveContains(searchText)
        || album.albumArtist.localizedCaseInsensitiveContains(searchText)
    }
  }

  var body: some View {
    NavigationStack {
      VStack(spacing: 0) {
        ScrollView {
          LazyVGrid(columns: columns, spacing: 10) {
            ForEach(filteredAlbums) { album in
              NavigationLink {
                AlbumView(viewModel: albumViewModel)
                  .environmentObject(downloadViewModel)
                  .onAppear { albumViewModel.setActiveAlbum(album: album) }
              } label: {
                AlbumsView(viewModel: albumViewModel, album: album)
              }
              .buttonStyle(.plain)
              .contextMenu {
                Button {
                  pins.toggle(album: album)
                } label: {
                  Label(
                    PinnedKind.album.toggleTitle(pinned: pins.isPinned(album: album)),
                    systemImage: pins.isPinned(album: album) ? "pin.slash" : "pin")
                }
              }
            }
          }
          .padding(.horizontal, 10)
          .padding(.top, 8)
          .playerBottomPadding(active: 90, inactive: 12)
        }
      }
      .catalystAwareNavigationTitle("Albums")
      .catalystAwareSearch(text: $searchText, prompt: "Search")
      .onAppear { albumViewModel.fetchAlbums() }
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
