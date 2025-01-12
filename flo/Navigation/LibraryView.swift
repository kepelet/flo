//
//  LibraryView.swift
//  flo
//
//  Created by rizaldy on 08/06/24.
//

import SwiftUI

struct LibraryView: View {
  @State private var searchAlbum = ""
  @State private var showDownloadSheet: Bool = false

  @ObservedObject var viewModel: AlbumViewModel

  @EnvironmentObject var playerViewModel: PlayerViewModel
  @EnvironmentObject var downloadViewModel: DownloadViewModel

  let columns = [
    GridItem(.flexible()),
    GridItem(.flexible()),
  ]

  var filteredAlbums: [Album] {
    if searchAlbum.isEmpty {
      return viewModel.albums
    } else {
      return viewModel.albums.filter { album in
        album.name.localizedCaseInsensitiveContains(searchAlbum)
      }
    }
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        if viewModel.albums.isEmpty && viewModel.error != nil {
          VStack(alignment: .leading) {
            Image("Home").resizable().aspectRatio(contentMode: .fit).frame(
              maxWidth: .infinity, maxHeight: 300
            ).padding()
            Group {
              Text("Your Navidrome session may have expired")
                .customFont(.title1)
                .fontWeight(.bold)
                .multilineTextAlignment(.leading)
                .padding(.bottom, 10)
              Text(
                "The quickest action you can take is to log back in — for now."
              )
              .customFont(.subheadline)

            }.padding(.horizontal, 20).foregroundColor(.accent)
          }
        } else {
          if searchAlbum.isEmpty {
            NavigationLink {
              ArtistsView(artists: viewModel.artists)
                .environmentObject(viewModel)
                .onAppear {
                  viewModel.getArtists()
                }
            } label: {
              HStack {
                Image(systemName: "music.mic")
                  .frame(width: 20, height: 10)
                  .foregroundColor(.accent)
                Text("Artists")
                  .customFont(.headline)
                  .padding(.leading, 8)
                Spacer()
                Image(systemName: "chevron.right")
                  .foregroundColor(.gray)
                  .font(.caption)
              }.padding(.horizontal).padding(.vertical, 5)
            }

            Divider()

            NavigationLink {
              PlaylistView()
                .environmentObject(viewModel)
                .environmentObject(playerViewModel)
                .onAppear {
                  viewModel.getPlaylists()
                }
            } label: {
              HStack {
                Image(systemName: "music.note.list")
                  .frame(width: 20, height: 10)
                  .foregroundColor(.accent)
                Text("Playlists")
                  .customFont(.headline)
                  .padding(.leading, 8)
                Spacer()
                Image(systemName: "chevron.right")
                  .foregroundColor(.gray)
                  .font(.caption)
              }.padding(.horizontal).padding(.vertical, 5)
            }

            Divider()

            NavigationLink {
              SongsView()
                .environmentObject(viewModel)
                .environmentObject(playerViewModel)
                .onAppear {
                  viewModel.fetchAllSongs()
                }
            } label: {
              HStack {
                Image(systemName: "music.note")
                  .frame(width: 20, height: 10)
                  .foregroundColor(.accent)
                Text("Songs")
                  .customFont(.headline)
                  .padding(.leading, 8)
                Spacer()
                Image(systemName: "chevron.right")
                  .foregroundColor(.gray)
                  .font(.caption)
              }.padding(.horizontal).padding(.vertical, 5)
            }

            Divider()
          }

          LazyVGrid(columns: columns) {
            ForEach(filteredAlbums) { album in
              NavigationLink {
                AlbumView(viewModel: viewModel)
                  .environmentObject(downloadViewModel)
                  .onAppear {
                    viewModel.setActiveAlbum(album: album)
                  }
              } label: {
                AlbumsView(viewModel: viewModel, album: album)
              }
            }
          }
          .padding(.top, 10)
          .padding(
            .bottom, playerViewModel.hasNowPlaying() && !playerViewModel.shouldHidePlayer ? 100 : 0
          )
          .searchable(
            text: $searchAlbum,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Search"
          )
        }
      }
      .sheet(isPresented: $showDownloadSheet) {
        DownloadQueueView().environmentObject(downloadViewModel)
      }
      .toolbar {
        if downloadViewModel.hasDownloadQueue() {
          Button(action: {
            showDownloadSheet.toggle()
          }) {
            Label("", systemImage: "icloud.and.arrow.down")
          }
        }
      }
      .navigationTitle("Library")
    }
  }
}

struct LibraryView_Previews: PreviewProvider {
  static private var songs: [Song] = [
    Song(
      id: "0", title: "Song name", albumId: "", artist: "", trackNumber: 1, discNumber: 0,
      bitRate: 0,
      sampleRate: 44100,
      suffix: "m4a", duration: 100, mediaFileId: "0")
  ]

  static private var albums: [Album] = [
    Album(
      name: "Album 1",
      artist: "Artist 1",
      songs: songs
    )
  ]
  @StateObject static private var playerViewModel: PlayerViewModel = PlayerViewModel()
  @StateObject static private var viewModel: AlbumViewModel = AlbumViewModel(albums: albums)

  static var previews: some View {
    LibraryView(viewModel: viewModel).environmentObject(playerViewModel)
  }
}
