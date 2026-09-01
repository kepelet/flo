//
//  LibraryView.swift
//  flo
//
//  Created by rizaldy on 08/06/24.
//

import NukeUI
import SwiftUI

enum LibraryV2Segment: String, CaseIterable, Identifiable {
  case library = "Library"
  case downloads = "Downloads"
  var id: String { rawValue }
}

struct LibraryView: View {
  let showQuickNavigation: Bool
  @State private var searchAlbum = ""
  @State private var showDownloadSheet: Bool = false
  @State private var forceShowQuickNavigation: Bool = false
  @State private var selectedSegment: LibraryV2Segment = .library
  @State private var downloadsSearch = ""
  @State private var cachedSongs: [Song] = []

  @ObservedObject var viewModel: AlbumViewModel
  @StateObject private var radiosViewModel = RadiosViewModel()

  @AppStorage(UserDefaultsKeys.libraryViewV2) private var libraryViewV2Enabled = false

  @EnvironmentObject var playerViewModel: PlayerViewModel
  @EnvironmentObject var downloadViewModel: DownloadViewModel
  @EnvironmentObject var libraryRouter: LibraryRouter

  private var isUserLoggedIn: Bool {
    !AuthService.shared.getCreds(key: "NDToken").isEmpty
  }

  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

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

  var filteredAlbums: [Album] {
    if searchAlbum.isEmpty {
      return viewModel.albums
    } else {
      return viewModel.albums.filter { album in
        album.name.localizedCaseInsensitiveContains(searchAlbum)
      }
    }
  }

  private var filteredDownloadedAlbums: [Album] {
    if downloadsSearch.isEmpty {
      return viewModel.downloadedAlbums
    } else {
      return viewModel.downloadedAlbums.filter { $0.name.localizedCaseInsensitiveContains(downloadsSearch) }
    }
  }

  private var shouldShowQuickNavigation: Bool {
    showQuickNavigation || forceShowQuickNavigation
  }

  var body: some View {
    NavigationStack(path: $libraryRouter.libraryPath) {
      libraryContent
        .navigationDestination(for: LibraryDestination.self) { destination in
          LibraryDestinationView(
            destination: destination,
            albumViewModel: viewModel,
            playerViewModel: playerViewModel,
            downloadViewModel: downloadViewModel
          )
        }
    }
  }

  @ViewBuilder
  var libraryContent: some View {
    if libraryViewV2Enabled {
      libraryV2ContentWrapper
    } else {
      libraryLegacyContent
    }
  }

  // MARK: - Legacy (V1)

  var libraryLegacyContent: some View {
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
          .bottom, playerContentBottomPadding(viewModel: playerViewModel, iPhoneActive: 100, iPhoneInactive: 0)
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
    .refreshable {
      await viewModel.refreshAlbums()
      await viewModel.refreshArtists()
      await viewModel.refreshPlaylists()
    }
  }

  // MARK: - V2

  private var activeSearchBinding: Binding<String> {
    Binding(
      get: { selectedSegment == .downloads ? downloadsSearch : searchAlbum },
      set: { if selectedSegment == .downloads { downloadsSearch = $0 } else { searchAlbum = $0 } }
    )
  }

  @ViewBuilder
  private var libraryV2ContentWrapper: some View {
    if #available(iOS 26.0, macOS 26.0, macCatalyst 26.0, *) {
      libraryV2ScrollContent
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
        .refreshable {
          await viewModel.refreshAlbums()
          await viewModel.refreshArtists()
          await viewModel.refreshPlaylists()
          await viewModel.refreshAllSongs()
          await viewModel.refreshRecentlyPlayedAlbums()
          await viewModel.refreshRecentlyAddedAlbums()
          viewModel.fetchStarredSongs()
          radiosViewModel.fetchAllRadios()
          viewModel.fetchDownloadedAlbums()
          cachedSongs = StreamCacheManager.shared.getCachedSongs()
        }
        .onAppear {
          viewModel.getArtists()
          viewModel.getPlaylists()
          viewModel.fetchAllSongs()
          viewModel.fetchStarredSongs()
          viewModel.fetchRecentlyPlayedAlbums()
          viewModel.fetchRecentlyAddedAlbums()
          viewModel.fetchDownloadedAlbums()
          cachedSongs = StreamCacheManager.shared.getCachedSongs()
          radiosViewModel.fetchAllRadios()
        }
    } else {
      libraryV2ScrollContent
        .searchable(text: activeSearchBinding, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search")
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
        .refreshable {
          await viewModel.refreshAlbums()
          await viewModel.refreshArtists()
          await viewModel.refreshPlaylists()
          await viewModel.refreshAllSongs()
          await viewModel.refreshRecentlyPlayedAlbums()
          await viewModel.refreshRecentlyAddedAlbums()
          viewModel.fetchStarredSongs()
          radiosViewModel.fetchAllRadios()
          viewModel.fetchDownloadedAlbums()
          cachedSongs = StreamCacheManager.shared.getCachedSongs()
        }
        .onAppear {
          viewModel.getArtists()
          viewModel.getPlaylists()
          viewModel.fetchAllSongs()
          viewModel.fetchStarredSongs()
          viewModel.fetchRecentlyPlayedAlbums()
          viewModel.fetchRecentlyAddedAlbums()
          viewModel.fetchDownloadedAlbums()
          cachedSongs = StreamCacheManager.shared.getCachedSongs()
          radiosViewModel.fetchAllRadios()
        }
    }
  }

  private var libraryV2SegmentedControl: some View {
    Picker("Library section", selection: $selectedSegment) {
      Label("Library", systemImage: "square.grid.2x2")
        .tag(LibraryV2Segment.library)
      Label("Downloads", systemImage: "arrow.down.circle")
        .tag(LibraryV2Segment.downloads)
    }
    .pickerStyle(.segmented)
    .accessibilityLabel("Library section")
    .padding(.horizontal)
    .padding(.top, 8)
    .padding(.bottom, 4)
  }

  private var libraryV2NotLoggedInView: some View {
    VStack(alignment: .center) {
      Image("Downloads").resizable().aspectRatio(contentMode: .fit).frame(width: 300)
        .padding().padding(.bottom, 10)
      Group {
        Text("Going off the grid?")
          .customFont(.title1)
          .fontWeight(.bold)
          .multilineTextAlignment(.center)
          .padding(.bottom, 10)
        Text("Bring your music anywhere, even when you're offline. Your downloaded music will be here.")
          .customFont(.subheadline)
          .multilineTextAlignment(.center)
      }.padding(.horizontal, 20).foregroundColor(.accent)
    }.frame(maxWidth: .infinity).padding(.top, 20)
  }

  private var libraryV2ScrollContent: some View {
    Group {
      if !isUserLoggedIn {
        ScrollView {
          VStack(alignment: .leading, spacing: 24) {
            libraryV2SegmentedControl
            if selectedSegment == .downloads {
              v2DownloadsBody
            } else {
              libraryV2NotLoggedInView
            }
          }
          .padding(.top, 10)
          .padding(.bottom, playerContentBottomPadding(viewModel: playerViewModel, iPhoneActive: 90, iPhoneInactive: 12))
        }
      } else if selectedSegment == .downloads {
        ScrollView {
          VStack(alignment: .leading, spacing: 24) {
            libraryV2SegmentedControl
            v2DownloadsBody
          }
          .padding(.top, 10)
          .padding(.bottom, playerContentBottomPadding(viewModel: playerViewModel, iPhoneActive: 90, iPhoneInactive: 12))
        }
      } else {
        ScrollView {
          VStack(alignment: .leading, spacing: 24) {
            libraryV2SegmentedControl
            if !viewModel.recentlyPlayedAlbums.isEmpty {
              v2RecentlyPlayedSection
            }
            v2AlbumsHorizontalSection
            if !viewModel.recentlyAddedAlbums.isEmpty {
              v2RecentlyAddedSection
            }

            if searchAlbum.isEmpty {
              if !viewModel.artists.isEmpty {
                v2ArtistsSection
              }
              if !viewModel.starredSongs.isEmpty {
                v2LikedSongsSection
              }
              if !viewModel.playlists.isEmpty {
                v2PlaylistsSection
              }
              if !viewModel.songs.isEmpty {
                v2SongsSection
              }
              if !radiosViewModel.radios.isEmpty {
                v2RadiosSection
              }
            }
          }
          .padding(.top, 10)
          .padding(.bottom, playerContentBottomPadding(viewModel: playerViewModel, iPhoneActive: 90, iPhoneInactive: 12))
        }
      }
    }
  }

  private var v2DownloadsBody: some View {
    Group {
      if viewModel.downloadedAlbums.isEmpty && cachedSongs.isEmpty {
        VStack(alignment: .center) {
          Image("Downloads").resizable().aspectRatio(contentMode: .fit).frame(width: 300)
            .padding().padding(.bottom, 10)
          Group {
            Text("Going off the grid?")
              .customFont(.title1)
              .fontWeight(.bold)
              .multilineTextAlignment(.center)
              .padding(.bottom, 10)
            Text("Bring your music anywhere, even when you're offline. Your downloaded music will be here.")
              .customFont(.subheadline)
              .multilineTextAlignment(.center)
          }.padding(.horizontal, 20).foregroundColor(.accent)
        }.frame(maxWidth: .infinity).padding(.top, 20)
      } else {
        VStack(alignment: .leading, spacing: 16) {
          if !cachedSongs.isEmpty {
            NavigationLink {
              CachedSongsView(viewModel: viewModel, songs: cachedSongs)
            } label: {
              HStack {
                Image(systemName: "music.note.list").font(.title3).foregroundColor(.accentColor).frame(width: 40)
                VStack(alignment: .leading) {
                  Text("Cached").customFont(.headline)
                  Text("\(cachedSongs.count) songs").customFont(.caption1).foregroundColor(.gray)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundColor(.gray)
              }.padding(.horizontal).padding(.vertical, 8)
            }.buttonStyle(.plain)
            Divider().padding(.horizontal)
          }
          LazyVGrid(columns: columns, spacing: 20) {
            ForEach(filteredDownloadedAlbums) { album in
              NavigationLink {
                AlbumView(viewModel: viewModel, isDownloadScreen: true).onAppear { viewModel.setActiveAlbum(album: album) }
              } label: {
                AlbumsView(viewModel: viewModel, album: album, isDownloadScreen: true)
              }
            }
          }.padding(.horizontal, 4).padding(.top, 10)
        }
      }
    }
  }

  private var v2DownloadsScrollContent: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 24) {
        libraryV2SegmentedControl
        v2DownloadsBody
      }
      .padding(.top, 10)
      .padding(.bottom, playerContentBottomPadding(viewModel: playerViewModel, iPhoneActive: 90, iPhoneInactive: 12))
    }
    .onAppear {
      cachedSongs = StreamCacheManager.shared.getCachedSongs()
      viewModel.fetchDownloadedAlbums()
    }
  }

  // MARK: V2 helpers

  private func v2SectionHeader<Destination: View>(title: String, subtitle: String? = nil, hasMore: Bool = true, destination: Destination) -> some View {
    HStack(alignment: .center) {
      VStack(alignment: .leading, spacing: 2) {
        Text(title)
          .customFont(.title3)
          .fontWeight(.bold)
        if let subtitle, !subtitle.isEmpty {
          Text(subtitle)
            .customFont(.caption1)
            .foregroundColor(.gray)
        }
      }
      Spacer()
      if hasMore {
        NavigationLink {
          destination
        } label: {
          HStack(alignment: .center, spacing: 8) {
            Text("More")
              .customFont(.subheadline)
            Image(systemName: "chevron.right")
              .font(.caption2.weight(.semibold))
              .foregroundColor(.accent)
          }
        }
        .buttonStyle(.plain)
      }
    }
    .padding(.horizontal)
  }

  private func v2SectionHeaderStatic(title: String, subtitle: String? = nil) -> some View {
    HStack(alignment: .center) {
      VStack(alignment: .leading, spacing: 2) {
        Text(title)
          .customFont(.title3)
          .fontWeight(.bold)
        if let subtitle, !subtitle.isEmpty {
          Text(subtitle)
            .customFont(.caption1)
            .foregroundColor(.gray)
        }
      }
      Spacer()
    }
    .padding(.horizontal)
  }

  private func v2SectionHeaderNoMore(title: String) -> some View {
    HStack(alignment: .center) {
      Text(title)
        .customFont(.title3)
        .fontWeight(.bold)
      Spacer()
    }
    .padding(.horizontal)
  }

  private func tintColor(for key: String) -> Color {
    let hash = abs(key.hashValue)
    let hue = Double(hash % 360) / 360.0
    return Color(hue: hue, saturation: 0.22, brightness: 0.94)
  }

  private func v2PlaceholderArtwork(key: String, systemImage: String = "music.note") -> some View {
    ZStack {
      RoundedRectangle(cornerRadius: 8, style: .continuous)
        .fill(tintColor(for: key).opacity(0.85))
      RoundedRectangle(cornerRadius: 8, style: .continuous)
        .fill(Color.gray.opacity(0.08))
      Image(systemName: systemImage)
        .foregroundColor(.accent.opacity(0.7))
        .font(.system(size: 22))
    }
  }

  // MARK: Sections

  private var v2ArtistsSection: some View {
    VStack(alignment: .leading, spacing: 14) {
      v2SectionHeader(title: "Artists", subtitle: "Sorted by name", hasMore: viewModel.artists.count > 5, destination:
        ArtistsView(artists: viewModel.artists)
          .environmentObject(viewModel)
          .environmentObject(playerViewModel)
          .environmentObject(downloadViewModel)
          .onAppear { viewModel.getArtists() }
      )
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 12) {
          ForEach(Array(viewModel.artists.prefix(5))) { artist in
            NavigationLink {
              ArtistDetailView(artist: artist)
                .environmentObject(viewModel)
                .environmentObject(playerViewModel)
                .environmentObject(downloadViewModel)
            } label: {
              VStack(spacing: 6) {
                v2ArtistCircle(artist: artist)
                Text(artist.name)
                  .customFont(.caption1)
                  .fontWeight(.bold)
                  .lineLimit(1)
                  .frame(width: 72)
              }
            }
            .buttonStyle(.plain)
          }
        }
        .padding(.horizontal)
      }
    }
  }

  private func v2ArtistCircle(artist: Artist) -> some View {
    let size: CGFloat = 72
    let imageURL = artist.mediumImageURL ?? artist.smallImageURL ?? artist.largeImageURL ?? ""
    let hasImageSource = !artist.id.isEmpty || !imageURL.isEmpty
    return Group {
      if hasImageSource {
        LazyImage(url: URL(string: viewModel.getArtistCoverArt(id: artist.id, imageURL: imageURL))) { state in
          if let image = state.image {
            image
              .resizable()
              .aspectRatio(contentMode: .fill)
              .frame(width: size, height: size)
              .clipShape(Circle())
          } else if state.error != nil {
            ZStack {
              Circle().fill(tintColor(for: artist.id.isEmpty ? artist.name : artist.id))
              Image(systemName: "music.mic")
                .foregroundColor(.white.opacity(0.9))
            }
            .frame(width: size, height: size)
          } else {
            ZStack {
              Circle().fill(Color.gray.opacity(0.12))
              ProgressView().scaleEffect(0.7)
            }
            .frame(width: size, height: size)
          }
        }
      } else {
        ZStack {
          Circle().fill(tintColor(for: artist.name))
          Image(systemName: "music.mic")
            .foregroundColor(.white.opacity(0.9))
        }
        .frame(width: size, height: size)
      }
    }
  }

  private var v2LikedSongsSection: some View {
    VStack(alignment: .leading, spacing: 14) {
      v2SectionHeader(title: "Liked Songs", subtitle: "Yeah, not this again", hasMore: viewModel.starredSongs.count > 16, destination:
        LikedSongsView()
          .environmentObject(viewModel)
          .environmentObject(playerViewModel)
      )
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(alignment: .top, spacing: 16) {
          ForEach(Array(chunkedSongs(Array(viewModel.starredSongs.prefix(16))).enumerated()), id: \.offset) { _, chunk in
            VStack(spacing: 12) {
              ForEach(chunk, id: \.id) { song in
                v2SongHorizontalCard(song: song, onTap: {
                  if let idx = viewModel.starredSongs.firstIndex(where: { $0.id == song.id }) {
                    let liked = SongCollection(id: "starred-songs", name: "Liked Songs", songs: viewModel.starredSongs)
                    playerViewModel.playBySong(idx: idx, item: liked, isFromLocal: false)
                  }
                })
              }
            }
          }
        }
        .padding(.horizontal)
      }
    }
  }

  private var v2PlaylistsSection: some View {
    VStack(alignment: .leading, spacing: 14) {
      v2SectionHeader(title: "Playlists", subtitle: "As usual?", hasMore: viewModel.playlists.count > 5, destination:
        PlaylistView()
          .environmentObject(viewModel)
          .environmentObject(playerViewModel)
          .environmentObject(downloadViewModel)
          .onAppear { viewModel.getPlaylists() }
      )
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 12) {
          ForEach(Array(viewModel.playlists.prefix(5))) { playlist in
            NavigationLink {
              PlaylistDetailView()
                .environmentObject(viewModel)
                .environmentObject(playerViewModel)
                .environmentObject(downloadViewModel)
                .onAppear { viewModel.setActivePlaylist(playlist: playlist) }
            } label: {
              VStack(alignment: .leading) {
                v2PlaylistCover(playlist: playlist)
                Text(playlist.name)
                  .customFont(.caption1)
                  .fontWeight(.bold)
                  .foregroundColor(.primary)
                  .lineLimit(1)
                  .frame(width: 120, alignment: .leading)
                Text(playlist.ownerName)
                  .customFont(.caption2)
                  .foregroundColor(.gray)
                  .lineLimit(1)
                  .frame(width: 120, alignment: .leading)
              }
            }
            .buttonStyle(.plain)
          }
        }
        .padding(.horizontal)
      }
    }
  }

  private func v2PlaylistCover(playlist: Playlist) -> some View {
    let key = playlist.id.isEmpty ? playlist.name : playlist.id
    return Group {
      if let local = UIImage(contentsOfFile: viewModel.getPlaylistCoverArt(id: playlist.id, coverArtId: playlist.coverArtId)) {
        Image(uiImage: local)
          .resizable()
          .aspectRatio(contentMode: .fill)
          .frame(width: 120, height: 120)
          .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
      } else {
        LazyImage(url: URL(string: viewModel.getPlaylistCoverArt(id: playlist.id, coverArtId: playlist.coverArtId))) { state in
          if let image = state.image {
            image
              .resizable()
              .aspectRatio(contentMode: .fill)
              .frame(width: 120, height: 120)
              .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
          } else if state.error != nil {
            v2PlaceholderArtwork(key: key, systemImage: "music.note.list")
              .frame(width: 120, height: 120)
              .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
          } else {
            ZStack {
              RoundedRectangle(cornerRadius: 8).fill(Color.gray.opacity(0.12))
              if state.isLoading {
                ProgressView().scaleEffect(0.7)
              } else {
                Image(uiImage: UIImage(named: "placeholder") ?? UIImage())
                  .resizable()
                  .scaledToFit()
                  .padding(16)
                  .opacity(0.6)
                  .overlay(
                    RoundedRectangle(cornerRadius: 8).fill(tintColor(for: key).opacity(0.35))
                  )
              }
            }
            .frame(width: 120, height: 120)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
          }
        }
      }
    }
  }

  private func v2SongHorizontalCard(song: Song, onTap: @escaping () -> Void) -> some View {
    Button(action: onTap) {
      HStack(spacing: 10) {
        v2SongCoverTiny(song: song)
        VStack(alignment: .leading, spacing: 3) {
          Text(song.title)
            .customFont(.caption1)
            .fontWeight(.bold)
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
          HStack(spacing: 3) {
            Text(song.artist)
              .customFont(.caption2)
              .foregroundColor(.gray)
              .lineLimit(1)
            Text("•")
              .font(.system(size: 8, weight: .regular))
              .foregroundColor(.gray.opacity(0.5))
            Text(timeString(for: song.duration))
              .font(.system(size: 10, weight: .regular))
              .foregroundColor(.gray.opacity(0.65))
              .lineLimit(1)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
        }
      }
      .frame(width: 240, alignment: .leading)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }

  private func chunkedSongs(_ songs: [Song], chunkSize: Int = 4) -> [[Song]] {
    stride(from: 0, to: songs.count, by: chunkSize).map { Array(songs[$0..<min($0 + chunkSize, songs.count)]) }
  }

  private var v2SongsSection: some View {
    VStack(alignment: .leading, spacing: 14) {
      v2SectionHeader(title: "Songs", subtitle: "Sorted by name", hasMore: viewModel.songs.count > 16, destination:
        SongsView()
          .environmentObject(viewModel)
          .environmentObject(playerViewModel)
          .onAppear { viewModel.fetchAllSongs() }
      )
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(alignment: .top, spacing: 16) {
          ForEach(Array(chunkedSongs(Array(viewModel.songs.prefix(16))).enumerated()), id: \.offset) { _, chunk in
            VStack(spacing: 12) {
              ForEach(chunk, id: \.id) { song in
                v2SongHorizontalCard(song: song) {
                  if let idx = viewModel.songs.firstIndex(where: { $0.id == song.id }) {
                    var playlist = Playlist(name: "\"All Tracks\"")
                    playlist.songs = viewModel.songs
                    playerViewModel.playBySong(idx: idx, item: playlist, isFromLocal: false)
                  }
                }
              }
            }
          }
        }
        .padding(.horizontal)
      }
    }
  }

  private func v2SongCoverTiny(song: Song) -> some View {
    let key = song.albumId.isEmpty ? song.id : song.albumId
    let remoteURL = songCoverURL(for: song)
    let localPath = songLocalCoverPath(for: song)
    return Group {
      if let local = UIImage(contentsOfFile: localPath) {
        Image(uiImage: local)
          .resizable()
          .aspectRatio(contentMode: .fill)
          .frame(width: 44, height: 44)
          .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
      } else {
        LazyImage(url: URL(string: remoteURL)) { state in
          if let image = state.image {
            image
              .resizable()
              .aspectRatio(contentMode: .fill)
              .frame(width: 44, height: 44)
              .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
          } else if state.error != nil {
            ZStack {
              RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.gray.opacity(0.12))
              Image(uiImage: UIImage(named: "placeholder") ?? UIImage())
                .resizable()
                .scaledToFit()
                .padding(8)
                .opacity(0.6)
                .overlay(
                  RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(tintColor(for: key).opacity(0.35))
                )
            }
            .frame(width: 44, height: 44)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
          } else {
            ZStack {
              RoundedRectangle(cornerRadius: 6).fill(Color.gray.opacity(0.12))
              if state.isLoading { ProgressView().scaleEffect(0.6) }
            }
            .frame(width: 44, height: 44)
          }
        }
      }
    }
  }

  private func songCoverURL(for song: Song) -> String {
    // Navidrome docs: mediafile artwork via mf- falls back embedded -> disc -> album
    let mediaId = song.mediaFileId.isEmpty ? song.id : song.mediaFileId
    if !mediaId.isEmpty {
      return "\(UserDefaultsManager.serverBaseURL)\(API.SubsonicEndpoint.coverArt)\(AuthService.shared.getCreds(key: "subsonicToken"))&id=mf-\(mediaId)&size=300"
    }
    return viewModel.getAlbumCoverArt(id: song.albumId)
  }

  private func songLocalCoverPath(for song: Song) -> String {
    let mediaId = song.mediaFileId.isEmpty ? song.id : song.mediaFileId
    return AlbumService.shared.getAlbumCover(
      artistName: song.artist,
      albumName: song.albumName,
      albumId: song.albumId,
      trackId: mediaId
    )
  }

  private func v2SongCoverSmall(song: Song) -> some View {
    let key = song.albumId.isEmpty ? song.id : song.albumId
    let remoteURL = songCoverURL(for: song)
    let localPath = songLocalCoverPath(for: song)
    return Group {
      if let local = UIImage(contentsOfFile: localPath) {
        Image(uiImage: local)
          .resizable()
          .aspectRatio(contentMode: .fill)
          .frame(width: 100, height: 100)
          .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
      } else if let cached = UIImage(contentsOfFile: viewModel.getAlbumCoverArt(id: song.albumId)), remoteURL == viewModel.getAlbumCoverArt(id: song.albumId) {
        Image(uiImage: cached)
          .resizable()
          .aspectRatio(contentMode: .fill)
          .frame(width: 100, height: 100)
          .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
      } else {
        LazyImage(url: URL(string: remoteURL)) { state in
          if let image = state.image {
            image
              .resizable()
              .aspectRatio(contentMode: .fill)
              .frame(width: 100, height: 100)
              .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
          } else if state.error != nil {
            ZStack {
              RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.gray.opacity(0.12))
              Image(uiImage: UIImage(named: "placeholder") ?? UIImage())
                .resizable()
                .scaledToFit()
                .padding(16)
                .opacity(0.6)
                .overlay(
                  RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(tintColor(for: key).opacity(0.35))
                )
            }
            .frame(width: 100, height: 100)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
          } else {
            ZStack {
              RoundedRectangle(cornerRadius: 8).fill(Color.gray.opacity(0.12))
              if state.isLoading {
                ProgressView().scaleEffect(0.7)
              } else {
                Image(uiImage: UIImage(named: "placeholder") ?? UIImage())
                  .resizable()
                  .scaledToFit()
                  .padding(16)
                  .opacity(0.6)
                  .overlay(
                    RoundedRectangle(cornerRadius: 8).fill(tintColor(for: key).opacity(0.35))
                  )
              }
            }
            .frame(width: 100, height: 100)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
          }
        }
      }
    }
  }

  private var v2RadiosSection: some View {
    VStack(alignment: .leading, spacing: 14) {
      v2SectionHeader(title: "Radios", subtitle: "The good ol radio", hasMore: radiosViewModel.radios.count > 5, destination:
        RadiosView()
          .environmentObject(playerViewModel)
      )
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 12) {
          ForEach(Array(radiosViewModel.radios.prefix(5)), id: \.id) { radio in
            ZStack(alignment: .bottomLeading) {
              RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(tintColor(for: radio.name.isEmpty ? radio.id : radio.name))
              LinearGradient(colors: [Color.black.opacity(0.58), Color.clear], startPoint: .bottom, endPoint: .top)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
              Text(radio.name)
                .font(.custom("Plus Jakarta Sans", size: 17).weight(.bold))
                .foregroundColor(.white)
                .shadow(color: Color.black.opacity(0.50), radius: 2, x: 0, y: 1)
                .lineLimit(1)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .bottomLeading)
            }
            .frame(width: 220, height: 110)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.white.opacity(0.12), lineWidth: 1))
            .onTapGesture {
              playerViewModel.playRadioItem(radio: radio)
            }
          }
        }
        .padding(.horizontal)
      }
    }
  }

  private var v2RecentlyPlayedSection: some View {
    VStack(alignment: .leading, spacing: 14) {
      v2SectionHeaderStatic(title: "Recently Played", subtitle: "I think you will like this?")
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 12) {
          ForEach(Array(viewModel.recentlyPlayedAlbums.prefix(16))) { album in
            NavigationLink {
              AlbumView(viewModel: viewModel)
                .environmentObject(downloadViewModel)
                .onAppear { viewModel.setActiveAlbum(album: album) }
            } label: {
              VStack(alignment: .leading) {
                v2AlbumCoverSmall(album: album)
                HStack(alignment: .center, spacing: 4) {
                  Text(album.name)
                    .customFont(.caption1)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                  if album.isExplicit {
                    ExplicitBadge(size: .compact)
                  }
                }
                .frame(width: 120, alignment: .leading)
                Text(album.albumArtist.isEmpty ? album.artist : album.albumArtist)
                  .customFont(.caption2)
                  .foregroundColor(.gray)
                  .lineLimit(1)
                  .frame(width: 120, alignment: .leading)
              }
            }.buttonStyle(.plain)
          }
        }
        .padding(.horizontal)
      }
    }
  }

  private var v2RecentlyAddedSection: some View {
    VStack(alignment: .leading, spacing: 14) {
      v2SectionHeaderStatic(title: "Recently Added", subtitle: "Let's try this one or two, maybe?")
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 12) {
          ForEach(Array(viewModel.recentlyAddedAlbums.prefix(16))) { album in
            NavigationLink {
              AlbumView(viewModel: viewModel)
                .environmentObject(downloadViewModel)
                .onAppear { viewModel.setActiveAlbum(album: album) }
            } label: {
              VStack(alignment: .leading) {
                v2AlbumCoverSmall(album: album)
                HStack(alignment: .center, spacing: 4) {
                  Text(album.name)
                    .customFont(.caption1)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                  if album.isExplicit {
                    ExplicitBadge(size: .compact)
                  }
                }
                .frame(width: 120, alignment: .leading)
                Text(album.albumArtist.isEmpty ? album.artist : album.albumArtist)
                  .customFont(.caption2)
                  .foregroundColor(.gray)
                  .lineLimit(1)
                  .frame(width: 120, alignment: .leading)
              }
            }.buttonStyle(.plain)
          }
        }
        .padding(.horizontal)
      }
    }
  }

  private var v2AlbumsHorizontalSection: some View {
    VStack(alignment: .leading, spacing: 14) {
      v2SectionHeader(title: "Albums", subtitle: "Sorted by name", hasMore: filteredAlbums.count > 10, destination:
        // Expand to grid view for all albums when More tapped
        ScrollView {
          LazyVGrid(columns: columns, spacing: 12) {
            ForEach(filteredAlbums) { album in
              NavigationLink {
                AlbumView(viewModel: viewModel)
                  .environmentObject(downloadViewModel)
                  .onAppear { viewModel.setActiveAlbum(album: album) }
              } label: {
                v2AlbumGridItem(album: album)
              }.buttonStyle(.plain)
            }
          }.padding()
        }.navigationTitle("Albums")
      )
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 12) {
          ForEach(Array(filteredAlbums.prefix(10))) { album in
            NavigationLink {
              AlbumView(viewModel: viewModel)
                .environmentObject(downloadViewModel)
                .onAppear {
                  viewModel.setActiveAlbum(album: album)
                }
            } label: {
              VStack(alignment: .leading) {
                v2AlbumCoverSmall(album: album)
                HStack(alignment: .center, spacing: 4) {
                  Text(album.name)
                    .customFont(.caption1)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                  if album.isExplicit {
                    ExplicitBadge(size: .compact)
                  }
                }
                .frame(width: 120, alignment: .leading)
                Text(album.albumArtist)
                  .customFont(.caption2)
                  .foregroundColor(.gray)
                  .lineLimit(1)
                  .frame(width: 120, alignment: .leading)
              }
            }
            .buttonStyle(.plain)
          }
        }
        .padding(.horizontal)
      }
    }
  }

  // Keep for search mode - grid limited to 10 (not used in normal V2 flow since albums is horizontal)
  private var v2AlbumsGridSection: some View {
    VStack(alignment: .leading, spacing: 14) {
      v2SectionHeaderNoMore(title: "Albums")
      LazyVGrid(columns: columns) {
        ForEach(Array(filteredAlbums.prefix(10))) { album in
          NavigationLink {
            AlbumView(viewModel: viewModel)
              .environmentObject(downloadViewModel)
              .onAppear {
                viewModel.setActiveAlbum(album: album)
              }
          } label: {
            v2AlbumGridItem(album: album)
          }
          .buttonStyle(.plain)
        }
      }
      .padding(.horizontal, 4)
    }
  }

  private func v2AlbumCoverSmall(album: Album) -> some View {
    let key = album.id.isEmpty ? album.name : album.id
    return Group {
      if let local = UIImage(contentsOfFile: viewModel.getAlbumCoverArt(id: album.id, albumCover: album.albumCover)) {
        Image(uiImage: local)
          .resizable()
          .aspectRatio(contentMode: .fill)
          .frame(width: 120, height: 120)
          .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
      } else {
        LazyImage(url: URL(string: viewModel.getAlbumCoverArt(id: album.id, albumCover: album.albumCover))) { state in
          if let image = state.image {
            image
              .resizable()
              .aspectRatio(contentMode: .fill)
              .frame(width: 120, height: 120)
              .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
          } else if state.error != nil {
            v2PlaceholderArtwork(key: key)
              .frame(width: 120, height: 120)
              .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
          } else {
            ZStack {
              RoundedRectangle(cornerRadius: 8).fill(Color.gray.opacity(0.12))
              if state.isLoading { ProgressView().scaleEffect(0.7) }
            }
            .frame(width: 120, height: 120)
          }
        }
      }
    }
  }

  private func v2AlbumGridItem(album: Album) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      v2AlbumCover(album: album)
      HStack(alignment: .center, spacing: 4) {
        Text(album.name)
          .customFont(.caption1)
          .fontWeight(.bold)
          .foregroundColor(.primary)
          .truncationMode(.tail)
          .lineLimit(1)
        if album.isExplicit {
          ExplicitBadge(size: .compact)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      Text(album.albumArtist)
        .customFont(.caption2)
        .foregroundColor(.gray)
        .truncationMode(.tail)
        .lineLimit(1)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(6)
  }

  private func v2AlbumCover(album: Album) -> some View {
    let key = album.id.isEmpty ? album.name : album.id
    return Group {
      if let local = UIImage(contentsOfFile: viewModel.getAlbumCoverArt(id: album.id, albumCover: album.albumCover)) {
        Image(uiImage: local)
          .resizable()
          .aspectRatio(contentMode: .fill)
          .frame(maxWidth: .infinity)
          .aspectRatio(1, contentMode: .fit)
          .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
      } else {
        LazyImage(url: URL(string: viewModel.getAlbumCoverArt(id: album.id, albumCover: album.albumCover))) { state in
          if let image = state.image {
            image
              .resizable()
              .aspectRatio(contentMode: .fill)
              .frame(maxWidth: .infinity)
              .aspectRatio(1, contentMode: .fit)
              .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
          } else if state.error != nil {
            v2PlaceholderArtwork(key: key)
              .aspectRatio(1, contentMode: .fit)
              .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
          } else {
            ZStack {
              RoundedRectangle(cornerRadius: 8).fill(Color.gray.opacity(0.12))
              if state.isLoading {
                ProgressView()
              } else {
                Image(uiImage: UIImage(named: "placeholder") ?? UIImage())
                  .resizable()
                  .scaledToFit()
                  .padding(24)
                  .opacity(0.6)
                  .overlay(
                    RoundedRectangle(cornerRadius: 8).fill(tintColor(for: key).opacity(0.35))
                  )
              }
            }
            .aspectRatio(1, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
          }
        }
      }
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
    LibraryView(viewModel: viewModel)
      .environmentObject(playerViewModel)
      .environmentObject(LibraryRouter())
  }
}
