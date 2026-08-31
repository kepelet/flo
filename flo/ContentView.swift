//
//  ContentView.swift
//  flo
//
//  Created by rizaldy on 01/06/24.
//

import PulseUI
import SwiftUI

struct ContentView: View {
  @AppStorage(UserDefaultsKeys.enableDebug) private var enableDebug = false
  @AppStorage(UserDefaultsKeys.libraryViewV2) private var libraryViewV2Enabled = false
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  @State private var isPlayerExpanded: Bool = false
  @State private var tabViewID = UUID()

  @StateObject private var authViewModel = AuthViewModel()
  @StateObject private var libraryRouter = LibraryRouter()
  @ObservedObject private var playerViewModel = PlayerViewModel.shared
  @StateObject private var albumViewModel = AlbumViewModel()
  @StateObject private var floooViewModel = FloooViewModel()
  @StateObject private var downloadViewModel = DownloadViewModel()
  @StateObject private var inAppPurchaseManager = InAppPurchaseManager()

  @State private var floatingPlayerOffsetX: CGFloat = .zero
  @State private var isSwipping = false

  private var swipeThreshold: CGFloat = 150.0

  private var isPadSidebar: Bool {
    guard UIDevice.current.userInterfaceIdiom == .pad else { return false }
    if #available(iOS 18.0, *) {
      return true
    }
    return false
  }

  private func estimatedSidebarWidth(for totalWidth: CGFloat) -> CGFloat {
    #if targetEnvironment(macCatalyst)
      return min(max(totalWidth * 0.22, 220), 320)
    #else
      return 0
    #endif
  }

  private func floatingPlayerContentCenterOffsetX(totalWidth: CGFloat) -> CGFloat {
    #if targetEnvironment(macCatalyst)
      return estimatedSidebarWidth(for: totalWidth) / 2
    #else
      return 0
    #endif
  }

  @ViewBuilder
  private var baseBackgroundView: some View {
    #if targetEnvironment(macCatalyst)
      Color(.systemBackground)
        .ignoresSafeArea()
    #else
      EmptyView()
    #endif
  }

  @ViewBuilder
  private var rootTabView: some View {
    if UIDevice.current.userInterfaceIdiom == .pad {
      if #available(iOS 18.0, *) {
        sidebarTabView
          .tabViewStyle(.sidebarAdaptable)
      } else {
        baseTabView
      }
    } else {
      baseTabView
    }
  }

  private var baseTabView: some View {
    Group {
      if libraryViewV2Enabled {
        if #available(iOS 26.0, *) {
          TabView(selection: $libraryRouter.selectedTab) {
            Tab("Home", systemImage: "house", value: AppTab.home) {
              HomeView(viewModel: authViewModel)
                .environmentObject(floooViewModel)
                .environmentObject(albumViewModel)
                .environmentObject(playerViewModel)
                .environmentObject(downloadViewModel)
                .environmentObject(libraryRouter)
            }
            Tab("Library", systemImage: "square.grid.2x2", value: AppTab.library) {
              LibraryView(viewModel: albumViewModel)
                .environmentObject(albumViewModel)
                .environmentObject(playerViewModel)
                .environmentObject(downloadViewModel)
                .environmentObject(libraryRouter)
                .environmentObject(authViewModel)
                .onAppear { albumViewModel.fetchAlbums() }
            }
            Tab("Search", systemImage: "magnifyingglass", value: AppTab.search, role: .search) {
              LibrarySearchTabView()
                .environmentObject(albumViewModel)
                .environmentObject(playerViewModel)
                .environmentObject(downloadViewModel)
            }
            Tab("Preferences", systemImage: "gear", value: AppTab.preferences) {
              PreferencesView(authViewModel: authViewModel)
                .environmentObject(playerViewModel)
                .environmentObject(floooViewModel)
                .environmentObject(inAppPurchaseManager)
            }
            if UserDefaultsManager.enableDebug {
              Tab("Debug", systemImage: "terminal", value: AppTab.debug) { ConsoleView() }
            }
          }
        } else if #available(iOS 18.0, *) {
          TabView(selection: $libraryRouter.selectedTab) {
            Tab("Home", systemImage: "house", value: AppTab.home) {
              HomeView(viewModel: authViewModel)
                .environmentObject(floooViewModel)
                .environmentObject(albumViewModel)
                .environmentObject(playerViewModel)
                .environmentObject(downloadViewModel)
                .environmentObject(libraryRouter)
            }
            Tab("Library", systemImage: "square.grid.2x2", value: AppTab.library) {
              LibraryView(viewModel: albumViewModel)
                .environmentObject(albumViewModel)
                .environmentObject(playerViewModel)
                .environmentObject(downloadViewModel)
                .environmentObject(libraryRouter)
                .environmentObject(authViewModel)
                .onAppear { albumViewModel.fetchAlbums() }
            }
            Tab("Search", systemImage: "magnifyingglass", value: AppTab.search) {
              LibrarySearchTabView()
                .environmentObject(albumViewModel)
                .environmentObject(playerViewModel)
                .environmentObject(downloadViewModel)
            }
            Tab("Preferences", systemImage: "gear", value: AppTab.preferences) {
              PreferencesView(authViewModel: authViewModel)
                .environmentObject(playerViewModel)
                .environmentObject(floooViewModel)
                .environmentObject(inAppPurchaseManager)
            }
            if UserDefaultsManager.enableDebug {
              Tab("Debug", systemImage: "terminal", value: AppTab.debug) { ConsoleView() }
            }
          }
        } else {
          TabView(selection: $libraryRouter.selectedTab) {
            HomeView(viewModel: authViewModel).tabItem { Label("Home", systemImage: "house") }
              .tag(AppTab.home)
              .environmentObject(floooViewModel).environmentObject(albumViewModel).environmentObject(playerViewModel).environmentObject(downloadViewModel).environmentObject(libraryRouter)
            LibraryView(viewModel: albumViewModel).tabItem { Label("Library", systemImage: "square.grid.2x2") }
              .tag(AppTab.library)
              .environmentObject(albumViewModel).environmentObject(playerViewModel).environmentObject(downloadViewModel).environmentObject(libraryRouter).environmentObject(authViewModel)
            LibrarySearchTabView().tabItem { Label("Search", systemImage: "magnifyingglass") }
              .tag(AppTab.search)
              .environmentObject(albumViewModel).environmentObject(playerViewModel).environmentObject(downloadViewModel)
            PreferencesView(authViewModel: authViewModel).tabItem { Label("Preferences", systemImage: "gear") }
              .tag(AppTab.preferences)
              .environmentObject(playerViewModel).environmentObject(floooViewModel).environmentObject(inAppPurchaseManager)
          }
        }
      } else {
        TabView(selection: $libraryRouter.selectedTab) {
          HomeView(viewModel: authViewModel).tabItem { Label("Home", systemImage: "house") }
            .tag(AppTab.home)
            .environmentObject(floooViewModel).environmentObject(albumViewModel).environmentObject(playerViewModel).environmentObject(downloadViewModel).environmentObject(libraryRouter)
          if authViewModel.isLoggedIn {
            LibraryView(viewModel: albumViewModel).tabItem { Label("Library", systemImage: "square.grid.2x2") }
              .tag(AppTab.library)
              .environmentObject(albumViewModel).environmentObject(playerViewModel).environmentObject(downloadViewModel).environmentObject(libraryRouter)
              .onAppear { albumViewModel.fetchAlbums() }
          }
          DownloadsView(viewModel: albumViewModel).tabItem { Label("Downloads", systemImage: "arrow.down.circle") }
            .tag(AppTab.downloads)
            .environmentObject(playerViewModel).environmentObject(downloadViewModel)
            .onAppear { albumViewModel.fetchDownloadedAlbums() }
            .badge(downloadViewModel.getRemainingDownloadItems())
          PreferencesView(authViewModel: authViewModel).tabItem { Label("Preferences", systemImage: "gear") }
            .tag(AppTab.preferences)
            .environmentObject(playerViewModel).environmentObject(floooViewModel).environmentObject(inAppPurchaseManager)
          if UserDefaultsManager.enableDebug {
            ConsoleView().tabItem { Label("Debug", systemImage: "terminal") }.tag(AppTab.debug)
          }
        }
      }
    }
    .id(tabViewID)
    .onChange(of: enableDebug) { _ in tabViewID = UUID() }
    .onChange(of: libraryViewV2Enabled) { isEnabled in
      if isEnabled, libraryRouter.selectedTab == .downloads {
        libraryRouter.selectedTab = authViewModel.isLoggedIn ? .library : .home
      }
    }
  }

  @available(iOS 18.0, *)
  private func sidebarTabContent<Content: View>(_ content: Content) -> some View {
    content
      .overlay(alignment: .bottom) {
        if playerViewModel.hasNowPlaying() && !playerViewModel.shouldHidePlayer {
          FloatingPlayerView(viewModel: playerViewModel)
            .frame(maxWidth: 720)
            .padding(.bottom, 16)
            .opacity(playerViewModel.hasNowPlaying() ? 1 : 0)
            .offset(x: floatingPlayerOffsetX)
            .onTapGesture {
              self.isPlayerExpanded = true
            }
            .gesture(
              DragGesture()
                .onChanged { value in
                  if value.translation.width < .zero {
                    floatingPlayerOffsetX = value.translation.width
                  }

                  if abs(floatingPlayerOffsetX) > swipeThreshold, !isSwipping {
                    isSwipping = true
                  }
                }
                .onEnded { _ in
                  if abs(floatingPlayerOffsetX) > swipeThreshold, isSwipping {
                    playerViewModel.destroyPlayerAndQueue()
                  }

                  self.floatingPlayerOffsetX = .zero
                  self.isSwipping = false
                }
            )
        }
      }
  }

  @available(iOS 18.0, *)
  private var sidebarTabView: some View {
    TabView(selection: $libraryRouter.selectedTab) {
      Tab("Home", systemImage: "house", value: AppTab.home) {
        sidebarTabContent(
          HomeView(viewModel: authViewModel)
            .environmentObject(floooViewModel)
            .environmentObject(albumViewModel)
            .environmentObject(playerViewModel)
            .environmentObject(downloadViewModel)
            .environmentObject(libraryRouter)
        )
      }

      if authViewModel.isLoggedIn || libraryViewV2Enabled {
        TabSection("Library") {
          Tab("Albums", systemImage: "square.grid.2x2", value: AppTab.library) {
            sidebarTabContent(
              LibraryView(viewModel: albumViewModel, showQuickNavigation: false)
                .environmentObject(albumViewModel)
                .environmentObject(playerViewModel)
                .environmentObject(downloadViewModel)
                .environmentObject(libraryRouter)
                .environmentObject(authViewModel)
                .onAppear {
                  albumViewModel.fetchAlbums()
                }
            )
          }

          Tab("Artists", systemImage: "music.mic", value: AppTab.libraryArtists) {
            sidebarTabContent(
              NavigationStack(path: $libraryRouter.artistsPath) {
                ArtistsView(artists: albumViewModel.artists)
                  .navigationDestination(for: LibraryDestination.self) { destination in
                    LibraryDestinationView(
                      destination: destination,
                      albumViewModel: albumViewModel,
                      playerViewModel: playerViewModel,
                      downloadViewModel: downloadViewModel
                    )
                  }
                  .onAppear {
                    albumViewModel.getArtists()
                  }
              }
              .environmentObject(albumViewModel)
              .environmentObject(playerViewModel)
              .environmentObject(downloadViewModel)
              .environmentObject(libraryRouter)
            )
          }

          Tab("Liked Songs", systemImage: "heart.fill", value: AppTab.likedSongs) {
            sidebarTabContent(
              NavigationStack {
                LikedSongsView()
                  .environmentObject(albumViewModel)
                  .environmentObject(playerViewModel)
              }
            )
          }

          Tab("Playlists", systemImage: "music.note.list", value: AppTab.playlists) {
            sidebarTabContent(
              NavigationStack {
                PlaylistView()
                  .environmentObject(albumViewModel)
                  .environmentObject(playerViewModel)
                  .environmentObject(downloadViewModel)
                  .onAppear {
                    albumViewModel.getPlaylists()
                  }
              }
            )
          }

          Tab("Songs", systemImage: "music.note", value: AppTab.songs) {
            sidebarTabContent(
              NavigationStack {
                SongsView()
                  .environmentObject(albumViewModel)
                  .environmentObject(playerViewModel)
                  .onAppear {
                    albumViewModel.fetchAllSongs()
                  }
              }
            )
          }

          Tab("Radios", systemImage: "radio", value: AppTab.radios) {
            sidebarTabContent(
              NavigationStack {
                RadiosView()
                  .environmentObject(playerViewModel)
              }
            )
          }
        }
      }

      if !libraryViewV2Enabled {
        Tab("Downloads", systemImage: "arrow.down.circle", value: AppTab.downloads) {
          sidebarTabContent(
            DownloadsView(viewModel: albumViewModel)
              .environmentObject(playerViewModel)
              .environmentObject(downloadViewModel)
              .onAppear {
                albumViewModel.fetchDownloadedAlbums()
              }
          )
        }
        .badge(downloadViewModel.getRemainingDownloadItems())
      }

      if libraryViewV2Enabled {
        if #available(iOS 26.0, *) {
          Tab("Search", systemImage: "magnifyingglass", value: AppTab.search, role: .search) {
            LibrarySearchTabView()
              .environmentObject(albumViewModel)
              .environmentObject(playerViewModel)
              .environmentObject(downloadViewModel)
          }
        } else {
          Tab("Search", systemImage: "magnifyingglass", value: AppTab.search) {
            LibrarySearchTabView()
              .environmentObject(albumViewModel)
              .environmentObject(playerViewModel)
              .environmentObject(downloadViewModel)
          }
        }
      }

      Tab("Preferences", systemImage: "gear", value: AppTab.preferences) {
        sidebarTabContent(
          PreferencesView(authViewModel: authViewModel)
            .environmentObject(playerViewModel)
            .environmentObject(floooViewModel)
            .environmentObject(inAppPurchaseManager)
        )
      }

      if UserDefaultsManager.enableDebug {
        Tab("Debug", systemImage: "terminal", value: AppTab.debug) {
          sidebarTabContent(
            ConsoleView()
          )
        }
      }
    }
    .id(tabViewID)
    .onChange(of: enableDebug) { _ in
      tabViewID = UUID()
    }
    .onChange(of: libraryViewV2Enabled) { isEnabled in
      if isEnabled, libraryRouter.selectedTab == .downloads {
        libraryRouter.selectedTab = authViewModel.isLoggedIn ? .library : .home
      }
    }
  }

  var body: some View {
    GeometryReader { geometry in
      let offScreenY: CGFloat = {
        #if targetEnvironment(macCatalyst)
          geometry.size.height
        #else
          UIScreen.main.bounds.height
        #endif
      }()

      ZStack {
        baseBackgroundView

        rootTabView

        tabKeyboardShortcuts

        if playerViewModel.hasNowPlaying() && !playerViewModel.shouldHidePlayer {
          PlayerView(
            isExpanded: $isPlayerExpanded,
            viewModel: playerViewModel,
            albumViewModel: albumViewModel,
            onOpenLibraryDestination: openLibraryDestinationFromPlayer
          )
          .environmentObject(downloadViewModel)
          .ignoresSafeArea()
          .offset(y: isPlayerExpanded ? 0 : offScreenY)
          .animation(.spring(duration: 0.2), value: isPlayerExpanded)
        }

        if !isPadSidebar {
          VStack {
            Spacer()

            if playerViewModel.hasNowPlaying() && !playerViewModel.shouldHidePlayer {
              let isSmallScreen = UIScreen.main.bounds.width <= 390
              let isPad = UIDevice.current.userInterfaceIdiom == .pad
              let bottomPadding: CGFloat = isSmallScreen ? 32 : 0
              let playerWidth: CGFloat? =
                isPad
                ? 720
                : (horizontalSizeClass == .regular ? 500 : nil)
              let playerCenterOffsetX = floatingPlayerContentCenterOffsetX(
                totalWidth: geometry.size.width
              )
              let playerBottomPadding: CGFloat = {
                #if targetEnvironment(macCatalyst)
                  24
                #else
                  return isPad ? 0 : (40 + bottomPadding)
                #endif
              }()

              FloatingPlayerView(viewModel: playerViewModel)
                .frame(maxWidth: playerWidth ?? .infinity)
                .padding(.bottom, playerBottomPadding)
                .opacity(playerViewModel.hasNowPlaying() ? 1 : 0)
                .offset(
                  x: playerCenterOffsetX + self.floatingPlayerOffsetX,
                  y: isPlayerExpanded ? offScreenY : 0
                )
                .animation(.spring(duration: 0.2), value: isPlayerExpanded)
                .onTapGesture {
                  self.isPlayerExpanded = true
                }
                .gesture(
                  DragGesture()
                    .onChanged { value in
                      if value.translation.width < .zero {
                        floatingPlayerOffsetX = value.translation.width
                      }

                      if abs(floatingPlayerOffsetX) > swipeThreshold, !isSwipping {
                        isSwipping = true
                      }
                    }
                    .onEnded { _ in
                      if abs(floatingPlayerOffsetX) > swipeThreshold, isSwipping {
                        playerViewModel.destroyPlayerAndQueue()
                      }

                      self.floatingPlayerOffsetX = .zero
                      self.isSwipping = false
                    }
                )
            }
          }
        }
      }
    }
    .onAppear {
      PlaybackCoordinator.shared.attach(playerViewModel: playerViewModel)
    }
  }

  @ViewBuilder
  private var tabKeyboardShortcuts: some View {
    Group {
      if isPadSidebar {
        tabShortcut(.home, key: "1")
        tabShortcut(.library, key: "2")
        tabShortcut(.libraryArtists, key: "3")
        tabShortcut(.likedSongs, key: "4")
        tabShortcut(.playlists, key: "5")
        tabShortcut(.songs, key: "6")
        tabShortcut(.radios, key: "7")
        tabShortcut(.downloads, key: "8")
        tabShortcut(.preferences, key: "9")
        tabShortcut(.debug, key: "0")
      } else {
        tabShortcut(.home, key: "1")
        tabShortcut(.library, key: "2")
        tabShortcut(.downloads, key: "3")
        tabShortcut(.preferences, key: "4")
      }
    }
    .frame(width: 0, height: 0)
    .opacity(0)
  }

  private func tabShortcut(_ tab: AppTab, key: KeyEquivalent) -> some View {
    Button {
      libraryRouter.selectedTab = tab
    } label: {
      EmptyView()
    }
    .keyboardShortcut(key, modifiers: .command)
  }

  private func openLibraryDestinationFromPlayer(_ destination: LibraryDestination) {
    isPlayerExpanded = false

    let targetTab: AppTab
    switch destination {
    case .artist:
      if isPadSidebar {
        targetTab = .libraryArtists
      } else if authViewModel.isLoggedIn {
        targetTab = .library
      } else {
        targetTab = .home
      }
    case .album:
      targetTab = authViewModel.isLoggedIn ? .library : .home
    }

    libraryRouter.selectedTab = targetTab

    DispatchQueue.main.async {
      switch targetTab {
      case .libraryArtists:
        libraryRouter.artistsPath.append(destination)
      case .library:
        libraryRouter.libraryPath.append(destination)
      default:
        libraryRouter.homePath.append(destination)
      }
    }
  }
}

private struct LibrarySearchTabView: View {
  @EnvironmentObject var albumViewModel: AlbumViewModel
  @EnvironmentObject var playerViewModel: PlayerViewModel
  @EnvironmentObject var downloadViewModel: DownloadViewModel
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  @State private var searchText = ""
  private var columns: [GridItem] {
    if horizontalSizeClass == .regular { return Array(repeating: GridItem(.flexible()), count: 4) }
    else { return Array(repeating: GridItem(.flexible()), count: 2) }
  }
  private var filteredAlbums: [Album] {
    if searchText.isEmpty { return [] }
    return albumViewModel.albums.filter { $0.name.localizedCaseInsensitiveContains(searchText) || $0.artist.localizedCaseInsensitiveContains(searchText) }
  }
  private var filteredArtists: [Artist] {
    if searchText.isEmpty { return [] }
    return albumViewModel.artists.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
  }
  private var filteredSongs: [Song] {
    if searchText.isEmpty { return [] }
    return albumViewModel.songs.filter { $0.title.localizedCaseInsensitiveContains(searchText) || $0.artist.localizedCaseInsensitiveContains(searchText) }
  }
  private var hasResults: Bool { !filteredAlbums.isEmpty || !filteredArtists.isEmpty || !filteredSongs.isEmpty }
  var body: some View {
    NavigationStack {
      ScrollView {
        if searchText.isEmpty {
          Group {
            if #available(iOS 17.0, *) {
              ContentUnavailableView("Search your library", systemImage: "magnifyingglass", description: Text("Albums, artists and songs — all in one place."))
            } else {
              VStack(spacing: 12) {
                Image(systemName: "magnifyingglass").font(.largeTitle).foregroundColor(.secondary)
                Text("Search your library").customFont(.headline)
                Text("Albums, artists and songs — all in one place.").customFont(.subheadline).foregroundColor(.secondary)
              }
            }
          }.padding(.top, 40)
        } else if !hasResults {
          Group {
            if #available(iOS 17.0, *) {
              ContentUnavailableView.search(text: searchText)
            } else {
              VStack(spacing: 12) {
                Image(systemName: "magnifyingglass").font(.largeTitle).foregroundColor(.secondary)
                Text("No results for \"\(searchText)\"").customFont(.headline)
              }
            }
          }.padding(.top, 40)
        } else {
          LazyVStack(alignment: .leading, spacing: 20) {
            if !filteredAlbums.isEmpty {
              Section {
                LazyVGrid(columns: columns, spacing: 12) {
                  ForEach(filteredAlbums) { album in
                    NavigationLink {
                      AlbumView(viewModel: albumViewModel).environmentObject(downloadViewModel).onAppear { albumViewModel.setActiveAlbum(album: album) }
                    } label: { AlbumsView(viewModel: albumViewModel, album: album) }
                  }
                }
              } header: { Text("Albums").customFont(.headline).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal) }
            }
            if !filteredArtists.isEmpty {
              Section {
                VStack(alignment: .leading, spacing: 8) {
                  ForEach(filteredArtists.prefix(8)) { artist in
                    NavigationLink {
                      ArtistDetailView(artist: artist).environmentObject(albumViewModel).environmentObject(playerViewModel).environmentObject(downloadViewModel)
                    } label: {
                      HStack {
                        ArtistImageView(artist: artist)
                        Text(artist.name).customFont(.headline).padding(.leading, 8)
                        Spacer()
                        Image(systemName: "chevron.right").foregroundColor(.secondary).font(.caption)
                      }.padding(.horizontal).padding(.vertical, 4)
                    }
                    Divider().padding(.leading, 56)
                  }
                }
              } header: { Text("Artists").customFont(.headline).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal) }
            }
            if !filteredSongs.isEmpty {
              Section {
                VStack(spacing: 0) {
                  ForEach(filteredSongs.prefix(12), id: \.id) { song in
                    HStack {
                      if let img = UIImage(contentsOfFile: albumViewModel.getAlbumCoverArt(id: song.albumId)) {
                        Image(uiImage: img).resizable().scaledToFill().frame(width: 44, height: 44).clipShape(RoundedRectangle(cornerRadius: 6))
                      } else {
                        RoundedRectangle(cornerRadius: 6).fill(Color.gray.opacity(0.15)).frame(width: 44, height: 44)
                      }
                      VStack(alignment: .leading, spacing: 2) {
                        Text(song.title).customFont(.caption1).fontWeight(.bold).lineLimit(1)
                        Text("\(song.artist) • \(timeString(for: song.duration))").customFont(.caption2).foregroundColor(.gray).lineLimit(1)
                      }.padding(.leading, 8)
                      Spacer()
                    }.padding(.horizontal).padding(.vertical, 6).contentShape(Rectangle())
                    .onTapGesture {
                      if let idx = albumViewModel.songs.firstIndex(where: { $0.id == song.id }) {
                        var pl = Playlist(name: "\"All Tracks\"")
                        pl.songs = albumViewModel.songs
                        playerViewModel.playBySong(idx: idx, item: pl, isFromLocal: false)
                      }
                    }
                    Divider().padding(.leading, 60)
                  }
                }
              } header: { Text("Songs").customFont(.headline).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal) }
            }
          }.padding(.top, 8).padding(.bottom, 90)
        }
      }
      .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search Library")
      .navigationTitle("Search")
      .onAppear { albumViewModel.getArtists(); albumViewModel.fetchAllSongs() }
    }
  }
}

struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    ContentView()
  }
}
