//
//  LibraryView.swift
//  flo
//
//  Created by rizaldy on 08/06/24.
//

import SwiftUI

struct LibraryView: View {
  let showQuickNavigation: Bool
  @State private var searchAlbum = ""
  @State private var showDownloadSheet: Bool = false
  @State private var forceShowQuickNavigation: Bool = false

  @ObservedObject var viewModel: AlbumViewModel

  @EnvironmentObject var playerViewModel: PlayerViewModel
  @EnvironmentObject var downloadViewModel: DownloadViewModel

  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  @AppStorage(UserDefaultsKeys.audioplayLibraryId) private var audioplayLibraryId: Int = 0
  @AppStorage(UserDefaultsKeys.selectedLibraryId) private var selectedLibraryId: Int = 0

  private var columns: [GridItem] {
    if horizontalSizeClass == .regular {
      return Array(repeating: GridItem(.flexible()), count: 4)
    } else {
      return Array(repeating: GridItem(.flexible()), count: 2)
    }
  }

  init(viewModel: AlbumViewModel, showQuickNavigation: Bool = true) {
    self.viewModel = viewModel
    self.showQuickNavigation = showQuickNavigation
    _forceShowQuickNavigation = State(initialValue: !showQuickNavigation)
  }

  // Albums that live in the audioplay library are surfaced in their own
  // category, so keep them out of the main music grid.
  private var musicAlbums: [Album] {
    viewModel.albums.filter { audioplayLibraryId == 0 || $0.libraryId != audioplayLibraryId }
  }

  private var hasAudioplays: Bool {
    audioplayLibraryId != 0 && viewModel.albums.contains { $0.libraryId == audioplayLibraryId }
  }

  // Libraries the user can filter the music grid by (the audioplay library has
  // its own category, so it's excluded here).
  private var selectableLibraries: [Library] {
    viewModel.libraries.filter { $0.id != audioplayLibraryId }
  }

  var filteredAlbums: [Album] {
    let byLibrary = musicAlbums.filter {
      selectedLibraryId == 0 || $0.libraryId == selectedLibraryId
    }

    let base =
      searchAlbum.isEmpty
      ? byLibrary
      : byLibrary.filter { $0.name.localizedCaseInsensitiveContains(searchAlbum) }

    return base.sorted {
      $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
    }
  }

  private var shouldShowQuickNavigation: Bool {
    showQuickNavigation || forceShowQuickNavigation
  }

  var body: some View {
    NavigationStack {
      libraryContent
    }
  }

  var libraryContent: some View {
    ScrollView {
      if viewModel.albums.isEmpty && viewModel.error != nil {
        VStack(alignment: .center) {
          Image("Home").resizable().aspectRatio(contentMode: .fit).frame(
            maxWidth: .infinity, maxHeight: 300
          ).padding()
          Group {
            Text("Your Navidrome session may have expired")
              .customFont(.title1)
              .fontWeight(.bold)
              .multilineTextAlignment(.center)
              .padding(.bottom, 10)
            Text(
              "The quickest action you can take is to log back in — for now."
            )
            .customFont(.subheadline)
            .multilineTextAlignment(.center)

          }.padding(.horizontal, 20).foregroundColor(.accent)
        }
        .frame(maxWidth: .infinity)
      } else {
        if !showQuickNavigation && searchAlbum.isEmpty {
          Button(action: {
            forceShowQuickNavigation.toggle()
          }) {
            HStack {
              Image(systemName: forceShowQuickNavigation ? "eye.slash" : "list.bullet")
              Text(forceShowQuickNavigation ? "Hide quick links" : "Show quick links")
                .customFont(.headline)
              Spacer()
              Image(systemName: "chevron.right")
                .foregroundColor(.gray)
                .font(.caption)
            }
            .padding(.horizontal)
            .padding(.vertical, 5)
          }
          Divider()
        }

        if shouldShowQuickNavigation && searchAlbum.isEmpty {
          NavigationLink {
            ArtistsView(artists: viewModel.artists)
              .environmentObject(viewModel)
              .environmentObject(playerViewModel)
              .environmentObject(downloadViewModel)
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
            LikedSongsView()
              .environmentObject(viewModel)
              .environmentObject(playerViewModel)
          } label: {
            HStack {
              Image(systemName: "heart.fill")
                .frame(width: 20, height: 10)
                .foregroundColor(.accent)
              Text("Liked Songs")
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
              .environmentObject(downloadViewModel)
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

          NavigationLink {
            RadiosView()
              .environmentObject(playerViewModel)
          } label: {
            HStack {
              Image(systemName: "radio")
                .frame(width: 20, height: 10)
                .foregroundColor(.accent)
              Text("Radios")
                .customFont(.headline)
                .padding(.leading, 8)
              Spacer()
              Image(systemName: "chevron.right")
                .foregroundColor(.gray)
                .font(.caption)
            }.padding(.horizontal).padding(.vertical, 5)
          }

          Divider()

          if hasAudioplays {
            NavigationLink {
              AudioplaysView(viewModel: viewModel)
                .environmentObject(playerViewModel)
                .environmentObject(downloadViewModel)
            } label: {
              HStack {
                Image(systemName: "books.vertical")
                  .frame(width: 20, height: 10)
                  .foregroundColor(.accent)
                Text("Audioplays")
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

      if selectableLibraries.count > 1 {
        Menu {
          Picker("Library", selection: $selectedLibraryId) {
            Text("All Libraries").tag(0)

            ForEach(selectableLibraries) { library in
              Text(library.name).tag(library.id)
            }
          }
        } label: {
          Label("Library", systemImage: "line.3.horizontal.decrease.circle")
        }
      }
    }
    .navigationTitle("Library")
    .refreshable {
      await viewModel.refreshAlbums()
      await viewModel.refreshArtists()
      await viewModel.refreshPlaylists()
      await viewModel.refreshLibraries()
    }
  }
}

// Shows albums that live in the Navidrome library the user has marked as
// "audioplay", giving that content its own category separate from music.
struct AudioplaysView: View {
  @ObservedObject var viewModel: AlbumViewModel

  @EnvironmentObject var playerViewModel: PlayerViewModel
  @EnvironmentObject var downloadViewModel: DownloadViewModel

  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  @AppStorage(UserDefaultsKeys.audioplayLibraryId) private var audioplayLibraryId: Int = 0

  @State private var searchAudioplay = ""

  private var columns: [GridItem] {
    if horizontalSizeClass == .regular {
      return Array(repeating: GridItem(.flexible()), count: 4)
    } else {
      return Array(repeating: GridItem(.flexible()), count: 2)
    }
  }

  private var audioplays: [Album] {
    let base = viewModel.albums.filter {
      audioplayLibraryId != 0 && $0.libraryId == audioplayLibraryId
    }

    let searched =
      searchAudioplay.isEmpty
      ? base
      : base.filter { $0.name.localizedCaseInsensitiveContains(searchAudioplay) }

    return searched.sorted {
      $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
    }
  }

  var body: some View {
    ScrollView {
      if audioplays.isEmpty {
        VStack(alignment: .center, spacing: 8) {
          Image(systemName: "books.vertical")
            .font(.largeTitle)
            .foregroundColor(.accent)
          Text("No audioplays yet")
            .customFont(.headline)
          Text("Albums from your audioplay library will appear here.")
            .customFont(.subheadline)
            .foregroundColor(.gray)
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
        .padding(.horizontal, 20)
      } else {
        LazyVGrid(columns: columns) {
          ForEach(audioplays) { album in
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
          text: $searchAudioplay,
          placement: .navigationBarDrawer(displayMode: .always),
          prompt: "Search"
        )
      }
    }
    .navigationTitle("Audioplays")
    .refreshable {
      await viewModel.refreshAlbums()
    }
  }
}

struct LibraryView_Previews: PreviewProvider {
  private static var songs: [Song] = [
    Song(
      id: "0", title: "Song name", albumId: "", albumName: "Album 1", artist: "",
      trackNumber: 1, discNumber: 0, bitRate: 0,
      sampleRate: 44100,
      suffix: "m4a", duration: 100, mediaFileId: "0"
    )
  ]

  private static var albums: [Album] = [
    Album(
      name: "Album 1",
      artist: "Artist 1",
      songs: songs
    )
  ]
  @StateObject private static var playerViewModel: PlayerViewModel = .init()
  @StateObject private static var viewModel: AlbumViewModel = .init(albums: albums)

  static var previews: some View {
    LibraryView(viewModel: viewModel).environmentObject(playerViewModel)
  }
}
