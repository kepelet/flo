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
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  @State private var isPlayerExpanded: Bool = false
  @State private var playerLibraryDestination: LibraryDestination?
  @State private var shouldRestorePlayerAfterLibrary = false
  @State private var tabViewID = UUID()

  @StateObject private var authViewModel = AuthViewModel()
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
    TabView {
      HomeView(viewModel: authViewModel).tabItem {
        Label("Home", systemImage: "house")
      }
      .environmentObject(floooViewModel)
      .environmentObject(albumViewModel)
      .environmentObject(playerViewModel)
      .environmentObject(downloadViewModel)

      if authViewModel.isLoggedIn {
        LibraryView(viewModel: albumViewModel).tabItem {
          Label("Library", systemImage: "square.grid.2x2")
        }.environmentObject(playerViewModel).environmentObject(downloadViewModel)
          .onAppear {
            albumViewModel.fetchAlbums()
          }
      }

      DownloadsView(viewModel: albumViewModel).tabItem {
        Label("Downloads", systemImage: "arrow.down.circle")
      }.environmentObject(playerViewModel).environmentObject(downloadViewModel).onAppear {
        albumViewModel.fetchDownloadedAlbums()
      }.badge(downloadViewModel.getRemainingDownloadItems())

      PreferencesView(authViewModel: authViewModel).tabItem {
        Label("Preferences", systemImage: "gear")
      }.environmentObject(playerViewModel).environmentObject(floooViewModel).environmentObject(
        inAppPurchaseManager)

      if UserDefaultsManager.enableDebug {
        ConsoleView().tabItem {
          Label("Debug", systemImage: "terminal")
        }
      }
    }
    .id(tabViewID)
    .onChange(of: enableDebug) { _ in
      tabViewID = UUID()
    }
  }

  @available(iOS 18.0, *)
  private func sidebarTabContent<Content: View>(_ content: Content) -> some View {
    content
      .overlay(alignment: .bottom) {
        if playerViewModel.hasNowPlaying() && !playerViewModel.shouldHidePlayer {
          FloatingPlayerView(viewModel: playerViewModel)
            .frame(maxWidth: 720)
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
    TabView {
      Tab("Home", systemImage: "house") {
        sidebarTabContent(
          HomeView(viewModel: authViewModel)
            .environmentObject(floooViewModel)
            .environmentObject(albumViewModel)
            .environmentObject(playerViewModel)
            .environmentObject(downloadViewModel)
        )
      }

      if authViewModel.isLoggedIn {
        TabSection("Library") {
          Tab("Albums", systemImage: "square.grid.2x2") {
            sidebarTabContent(
              LibraryView(viewModel: albumViewModel, showQuickNavigation: false)
                .environmentObject(playerViewModel)
                .environmentObject(downloadViewModel)
                .onAppear {
                  albumViewModel.fetchAlbums()
                }
            )
          }

          Tab("Artists", systemImage: "music.mic") {
            sidebarTabContent(
              NavigationStack {
                ArtistsView(artists: albumViewModel.artists)
                  .onAppear {
                    albumViewModel.getArtists()
                  }
              }
              .environmentObject(albumViewModel)
              .environmentObject(playerViewModel)
              .environmentObject(downloadViewModel)
            )
          }

          Tab("Liked Songs", systemImage: "heart.fill") {
            sidebarTabContent(
              NavigationStack {
                LikedSongsView()
                  .environmentObject(albumViewModel)
                  .environmentObject(playerViewModel)
              }
            )
          }

          Tab("Playlists", systemImage: "music.note.list") {
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

          Tab("Songs", systemImage: "music.note") {
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

          Tab("Radios", systemImage: "radio") {
            sidebarTabContent(
              NavigationStack {
                RadiosView()
                  .environmentObject(playerViewModel)
              }
            )
          }
        }
      }

      Tab("Downloads", systemImage: "arrow.down.circle") {
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

      Tab("Preferences", systemImage: "gear") {
        sidebarTabContent(
          PreferencesView(authViewModel: authViewModel)
            .environmentObject(playerViewModel)
            .environmentObject(floooViewModel)
            .environmentObject(inAppPurchaseManager)
        )
      }

      if UserDefaultsManager.enableDebug {
        Tab("Debug", systemImage: "terminal") {
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

        if let destination = playerLibraryDestination {
          NavigationStack {
            playerLibraryContent(destination)
              .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                  Button("Close") {
                    closePlayerLibraryDestination()
                  }
                }
              }
          }
          .background(Color(.systemBackground).ignoresSafeArea())
        }

        if playerViewModel.hasNowPlaying() && !playerViewModel.shouldHidePlayer
          && playerLibraryDestination == nil
        {
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
                  10
                #else
                  if playerLibraryDestination != nil {
                    return 0
                  }

                  return isPad ? 0 : (40 + bottomPadding)
                #endif
              }()

              FloatingPlayerView(viewModel: playerViewModel)
                .frame(maxWidth: playerWidth ?? .infinity)
                .padding(.bottom, playerBottomPadding)
                .opacity(playerViewModel.hasNowPlaying() ? 1 : 0)
                .offset(
                  x: playerCenterOffsetX + self.floatingPlayerOffsetX,
                  y: (isPlayerExpanded && playerLibraryDestination == nil) ? offScreenY : 0
                )
                .animation(.spring(duration: 0.2), value: isPlayerExpanded)
                .onTapGesture {
                  if playerLibraryDestination != nil {
                    closePlayerLibraryDestination()
                  } else {
                    self.isPlayerExpanded = true
                  }
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

  private func openLibraryDestinationFromPlayer(_ destination: LibraryDestination) {
    shouldRestorePlayerAfterLibrary = true
    isPlayerExpanded = false
    playerLibraryDestination = destination
  }

  private func closePlayerLibraryDestination() {
    playerLibraryDestination = nil
    if shouldRestorePlayerAfterLibrary {
      shouldRestorePlayerAfterLibrary = false
      isPlayerExpanded = true
    }
  }

  @ViewBuilder
  private func playerLibraryContent(_ destination: LibraryDestination) -> some View {
    switch destination {
    case .artist(let id, let name):
      if let artist = albumViewModel.artistForNavigation(id: id, name: name) {
        ArtistDetailView(artist: artist)
          .environmentObject(albumViewModel)
          .environmentObject(playerViewModel)
          .environmentObject(downloadViewModel)
      } else {
        Text("Artist unavailable")
          .foregroundColor(.secondary)
      }
    case .album(let id, let name, let artist):
      if let album = albumViewModel.albumForNavigation(id: id, name: name, artist: artist) {
        AlbumView(viewModel: albumViewModel)
          .environmentObject(playerViewModel)
          .environmentObject(downloadViewModel)
          .onAppear {
            albumViewModel.setActiveAlbum(album: album)
          }
      } else {
        Text("Album unavailable")
          .foregroundColor(.secondary)
      }
    }
  }
}

struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    ContentView()
  }
}
