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

  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  private var columns: [GridItem] {
    if horizontalSizeClass == .regular {
      return Array(repeating: GridItem(.flexible()), count: 4)
    } else {
      return Array(repeating: GridItem(.flexible()), count: 2)
    }
  }

  var filteredAlbums: [Album] {
    if searchAlbum.isEmpty {
      return viewModel.downloadedAlbums
    } else {
      return viewModel.downloadedAlbums.filter { album in
        album.name.localizedCaseInsensitiveContains(searchAlbum)
      }
    }
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
          ForEach(filteredAlbums) { album in
            NavigationLink {
              AlbumView(viewModel: viewModel, isDownloadScreen: true)
                .onAppear {
                  viewModel.setActiveAlbum(album: album)
                }
            } label: {
              AlbumsView(viewModel: viewModel, album: album, isDownloadScreen: true)
            }
          }
        }.padding(.top, 10).padding(
          .bottom, playerViewModel.hasNowPlaying() && !playerViewModel.shouldHidePlayer ? 100 : 0
        ).navigationTitle("Downloads")
          .searchable(
            text: $searchAlbum,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Search"
          )
      }
      .onAppear {
        cachedSongs = StreamCacheManager.shared.getCachedSongs()
      }
    }
  }
}

struct DownloadsView_Previews: PreviewProvider {
  @StateObject static var viewModel: AlbumViewModel = AlbumViewModel()

  static var previews: some View {
    DownloadsView(viewModel: viewModel)
  }
}
