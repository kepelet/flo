//
//  DownloadsView.swift
//  flo
//
//  Created by rizaldy on 08/06/24.
//

import SwiftUI

struct DownloadsView: View {
  @State private var searchAlbum = ""
  @State private var cachedSongs: [Song] = []

  @ObservedObject var viewModel: AlbumViewModel

  @EnvironmentObject var playerViewModel: PlayerViewModel
  @EnvironmentObject var pins: PinnedStore

  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  private var columns: [GridItem] {
    if horizontalSizeClass == .regular {
      return Array(repeating: GridItem(.flexible()), count: 4)
    } else {
      return Array(repeating: GridItem(.flexible()), count: 2)
    }
  }

  var filteredAlbums: [Album] {
    let sorted = PinnedStore.sortedAlbumPinsFirst(
      albums: viewModel.downloadedAlbums, order: pins.albumPinOrder)
    if searchAlbum.isEmpty {
      return sorted
    } else {
      return sorted.filter { album in
        album.name.localizedCaseInsensitiveContains(searchAlbum)
      }
    }
  }

  private var pinnedFilteredAlbums: [Album] {
    filteredAlbums.filter { pins.isPinned(album: $0) }
  }

  private var unpinnedFilteredAlbums: [Album] {
    filteredAlbums.filter { !pins.isPinned(album: $0) }
  }

  private var isSearching: Bool {
    !searchAlbum.isEmpty
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        if viewModel.downloadedAlbums.isEmpty && cachedSongs.isEmpty {
          VStack(alignment: .center) {
            Image("Downloads").resizable().aspectRatio(contentMode: .fit).frame(width: 300)
              .padding()
              .padding(.bottom, 10)
            Group {
              Text("Going off the grid?")
                .customFont(.title1)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
                .padding(.bottom, 10)
              Text(
                "Bring your music anywhere, even when you're offline. Your downloaded music will be here."
              )
              .customFont(.subheadline)
              .multilineTextAlignment(.center)

            }.padding(.horizontal, 20).foregroundColor(.accent)
          }
          .frame(maxWidth: .infinity)
        }

        // Cached songs section
        if !cachedSongs.isEmpty {
          NavigationLink {
            CachedSongsView(viewModel: viewModel, songs: cachedSongs)
          } label: {
            HStack {
              Image(systemName: "music.note.list")
                .font(.title3)
                .foregroundColor(.accentColor)
                .frame(width: 40)
              VStack(alignment: .leading) {
                Text("Cached")
                  .customFont(.headline)
                Text("\(cachedSongs.count) songs")
                  .customFont(.caption1)
                  .foregroundColor(.gray)
              }
              Spacer()
              Image(systemName: "chevron.right")
                .foregroundColor(.gray)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
          }
          .buttonStyle(.plain)

          Divider().padding(.horizontal)
        }

        LazyVGrid(columns: columns, spacing: 20) {
          if !isSearching && !pinnedFilteredAlbums.isEmpty {
            Section {
              ForEach(pinnedFilteredAlbums) { album in
                downloadedAlbumLink(album)
              }
            } header: {
              pinnedSectionHeader
            }
          }

          if !isSearching && !pinnedFilteredAlbums.isEmpty && !unpinnedFilteredAlbums.isEmpty {
            Section {
              ForEach(unpinnedFilteredAlbums) { album in
                downloadedAlbumLink(album)
              }
            } header: {
              allDownloadsSectionHeader
            }
          } else {
            ForEach(filteredAlbums) { album in
              downloadedAlbumLink(album)
            }
          }
        }.padding(.top, 10).padding(
          .bottom, playerContentBottomPadding(viewModel: playerViewModel, iPhoneActive: 100, iPhoneInactive: 0)
        ).catalystAwareNavigationTitle("Downloads")
          .catalystAwareSearch(text: $searchAlbum, prompt: "Search")
      }
      .onAppear {
        cachedSongs = StreamCacheManager.shared.getCachedSongs()
      }
    }
  }

  private func downloadedAlbumLink(_ album: Album) -> some View {
    NavigationLink {
      AlbumView(viewModel: viewModel, isDownloadScreen: true)
        .onAppear {
          viewModel.setActiveAlbum(album: album)
        }
    } label: {
      AlbumsView(viewModel: viewModel, album: album, isDownloadScreen: true)
    }
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

  private var pinnedSectionHeader: some View {
    HStack {
      Text("Pinned")
        .customFont(.headline)
      Spacer()
    }
    .padding(.horizontal, 16)
  }

  private var allDownloadsSectionHeader: some View {
    HStack {
      Text("All downloads")
        .customFont(.headline)
      Spacer()
    }
    .padding(.horizontal, 16)
  }
}

struct DownloadsView_Previews: PreviewProvider {
  @StateObject static var viewModel: AlbumViewModel = AlbumViewModel()

  static var previews: some View {
    DownloadsView(viewModel: viewModel)
      .environmentObject(PinnedStore())
  }
}
