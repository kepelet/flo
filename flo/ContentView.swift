//
//  ContentView.swift
//  flo
//
//  Created by rizaldy on 01/06/24.
//

import NukeUI
import PulseUI
import SwiftUI

struct ContentView: View {
  @AppStorage(UserDefaultsKeys.enableDebug) private var enableDebug = false
  @AppStorage(UserDefaultsKeys.libraryViewV2) private var libraryViewV2Enabled = false
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  @State private var isPlayerExpanded: Bool = false
  // Legacy: tabViewID previously drove `.id(tabViewID)` forced recreation.
  // Retained (unused) to keep git history / ABI stable; TabViews no longer use
  // .id — see defensive comment in baseTabView/sidebarTabView.
  @State private var tabViewID = UUID()

  @StateObject private var authViewModel = AuthViewModel()
  @StateObject private var libraryRouter = LibraryRouter()
  private let playerViewModel = PlayerViewModel.shared
  @StateObject private var playerPresence = PlayerPresenceObserver()
  @StateObject private var albumViewModel = AlbumViewModel()
  @StateObject private var floooViewModel = FloooViewModel()
  @StateObject private var downloadViewModel = DownloadViewModel()
  @StateObject private var inAppPurchaseManager = InAppPurchaseManager()

  @AppStorage("floatingSidePanelWidth") private var persistedPanelWidth: Double = 380
  @State private var floatingPlayerOffsetX: CGFloat = .zero
  @State private var isSwipping = false
  @State private var floatingSidePanel: FloatingPlayerPanel?
  @State private var lastSidePanel: FloatingPlayerPanel = .lyrics
  @State private var sidePanelDragStartWidth: CGFloat?
  @State private var isResizingSidePanel = false

  var swipeThreshold: CGFloat = 150.0

  // MARK: iPad sidebar adaptation — intentional stability
  // isPadSidebar is intentionally STABLE (device idiom + OS version only).
  // It does NOT observe horizontalSizeClass / geometry width. Swapping the
  // entire TabView between `sidebarTabView` (.sidebarAdaptable) and
  // `baseTabView` mid-resize recreates the UITabBarController while its
  // internal _UITabSidebar transitionCoordinator is in-flight, which is the
  // suspected EXC_BAD_ACCESS during Stage Manager / Slide Over resize.
  // iOS 18's .sidebarAdaptable already collapses internally (sidebar ↔ top
  // bar) without swapping view identity; the floating-player offset helper
  // `estimatedSidebarWidth` already returns 0 below 600pt to follow that
  // collapse. Keeping this bool stable avoids the cross-identity crash.
  private var isPadSidebar: Bool {
    #if targetEnvironment(macCatalyst)
      if #available(iOS 18.0, *) {
        return true
      }
      return false
    #else
      guard UIDevice.current.userInterfaceIdiom == .pad else { return false }
      if #available(iOS 18.0, *) {
        return true
      }
      return false
    #endif
  }

  private func estimatedSidebarWidth(for totalWidth: CGFloat) -> CGFloat {
    guard totalWidth.isFinite, totalWidth > 0 else { return 0 }
    // Sidebar collapses to overlay / hidden below ~600pt (Stage Manager narrow
    // or iPad Slide Over). No shift when collapsed to avoid offset artifacts.
    guard totalWidth >= 600 else { return 0 }
    // Fixed 104 yields the polished -52pt shift; cap to 15% of window so
    // very narrow/tall windows never over-shift and the value stays finite.
    let raw: CGFloat = 104
    let capped = min(raw, max(0, totalWidth * 0.15))
    return capped.isFinite ? capped : 0
  }

  private func floatingPlayerContentCenterOffsetX(totalWidth: CGFloat) -> CGFloat {
    guard isPadSidebar else { return 0 }
    guard totalWidth.isFinite, totalWidth > 0 else { return 0 }
    let w = estimatedSidebarWidth(for: totalWidth)
    guard w.isFinite, w > 0 else { return 0 }
    let off = -w / 2
    return off.isFinite ? off : 0
  }

  private func toggleSidePanel() {
    withAnimation(.spring(duration: 0.26, bounce: 0.08)) {
      if floatingSidePanel != nil {
        lastSidePanel = floatingSidePanel ?? .lyrics
        floatingSidePanel = nil
      } else {
        floatingSidePanel = lastSidePanel
      }
    }
  }

  @ViewBuilder
  var baseBackgroundView: some View {
    #if targetEnvironment(macCatalyst)
      Color(.systemBackground)
        .ignoresSafeArea()
    #else
      EmptyView()
    #endif
  }

  @ViewBuilder
  private var rootTabView: some View {
    if isPadSidebar {
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

  var baseTabView: some View {
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
            Tab("Library", systemImage: "circle.grid.2x2", value: AppTab.library) {
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
                .environmentObject(authViewModel)
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
            Tab("Library", systemImage: "circle.grid.2x2", value: AppTab.library) {
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
                .environmentObject(authViewModel)
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
            LibraryView(viewModel: albumViewModel).tabItem { Label("Library", systemImage: "circle.grid.2x2") }
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
            LibraryView(viewModel: albumViewModel).tabItem { Label("Library", systemImage: "circle.grid.2x2") }
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
    // Defensive: removed .id(tabViewID) forced recreation.
    // The previous `.id(tabViewID)` + `tabViewID = UUID()` on every
    // enableDebug/library toggle nuked the TabView's UIKit controller
    // (UITabBarController/_UITabSidebar) mid-transition. SwiftUI can diff
    // the conditional Debug tab without destroying the container.
    .onChange(of: libraryViewV2Enabled) { isEnabled in
      if isEnabled, libraryRouter.selectedTab == .downloads {
        libraryRouter.selectedTab = authViewModel.isLoggedIn ? .library : .home
      }
    }
  }

  @available(iOS 18.0, *)
  func sidebarTabContent<Content: View>(_ content: Content) -> some View {
    content
      .overlay(alignment: .bottom) {
        if playerPresence.hasNowPlaying {
          PadFloatingPlayerView(viewModel: playerViewModel, activePanel: $floatingSidePanel)
            .frame(maxWidth: 860)
            .padding(.bottom, 20)
            .opacity(playerPresence.hasNowPlaying ? 1 : 0)
            .offset(x: floatingPlayerOffsetX.isFinite ? floatingPlayerOffsetX : 0)
            .zIndex(10)
            .gesture(
              DragGesture()
                .onChanged { value in
                  let tx = value.translation.width
                  guard tx.isFinite else { return }
                  if tx < .zero {
                    floatingPlayerOffsetX = tx
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
  var sidebarTabView: some View {
    TabView(selection: $libraryRouter.selectedTab) {
#if targetEnvironment(macCatalyst)
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
#else
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
#endif

      if libraryViewV2Enabled {
        Tab("Library", systemImage: "circle.grid.2x2", value: AppTab.library) {
          sidebarTabContent(
            LibraryView(viewModel: albumViewModel)
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
      }

      if authViewModel.isLoggedIn || libraryViewV2Enabled {
        TabSection {

          Tab("Albums", systemImage: "square.grid.2x2", value: AppTab.libraryAlbums) {
            sidebarTabContent(
              AlbumsGridView()
                .environmentObject(albumViewModel)
                .environmentObject(playerViewModel)
                .environmentObject(downloadViewModel)
                .environmentObject(libraryRouter)
                .environmentObject(authViewModel)
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
        } header: {
          Text("Collections")
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
        Tab("Search", systemImage: "magnifyingglass", value: AppTab.search) {
          sidebarTabContent(
            LibrarySearchTabView()
              .environmentObject(albumViewModel)
              .environmentObject(playerViewModel)
              .environmentObject(downloadViewModel)
              .environmentObject(authViewModel)
          )
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
#if targetEnvironment(macCatalyst)
    .tabViewSidebarHeader {
      HStack(spacing: 20) {
        Image("logo")
          .resizable()
          .scaledToFit()
          .frame(width: 28, height: 28)
          .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        Text("flo")
          .customFont(.headline)
      }
      .padding(.top, 2)
      .padding(.bottom, 24)
    }
#endif
    // Defensive: same removal as baseTabView — no .id(tabViewID) recreation.
#if targetEnvironment(macCatalyst)
    .toolbar(.hidden, for: .tabBar)
    .toolbarBackground(.hidden, for: .tabBar)
#endif
    .onChange(of: libraryViewV2Enabled) { isEnabled in
      if isEnabled, libraryRouter.selectedTab == .downloads {
        libraryRouter.selectedTab = authViewModel.isLoggedIn ? .library : .home
      }
    }
  }

  var body: some View {
    GeometryReader { geometry in
      // Centralized safe geometry — all downstream math must use these,
      // never raw geometry.size or UIScreen directly (Stage Manager can
      // produce non-finite / zero / very short heights mid-resize).
      let safeWidth: CGFloat = (geometry.size.width.isFinite && geometry.size.width > 0) ? geometry.size.width : 0
      let safeHeight: CGFloat = (geometry.size.height.isFinite && geometry.size.height > 0) ? geometry.size.height : 0
      let safeBottom: CGFloat = geometry.safeAreaInsets.bottom.isFinite ? geometry.safeAreaInsets.bottom : 0
      let offScreenY: CGFloat = {
        #if targetEnvironment(macCatalyst)
          return safeHeight.isFinite && safeHeight > 0 ? safeHeight : 0
        #else
          // Use geometry height when available; falls back to screen height for initial layout.
          // Prevents mismatch during iPad multitasking/window resize where screen height != window height.
          if safeHeight > 0 { return safeHeight }
          let fb = UIScreen.main.bounds.height
          return (fb.isFinite && fb > 0) ? fb : 800
        #endif
      }()

      ZStack {
        baseBackgroundView

        if isPadSidebar {
          let panelGutter: CGFloat = 10
          let minPanelWidth: CGFloat = 280
          let maxPanelWidthCap: CGFloat = 520
          // Window-capped upper bound: min(520, 45% of width - gutter), plus safeWidth guards.
          let upperBound: CGFloat = {
            guard safeWidth > 0, safeWidth.isFinite else { return maxPanelWidthCap }
            return min(maxPanelWidthCap, max(0, safeWidth * 0.45 - panelGutter))
          }()
          // Persisted width (AppStorage Double) drives display; clamp between 280 and upperBound.
          // When window is narrower than 280, upperBound < 280 — allow shrinking below 280 to avoid overflow.
          let rawPersistedWidth: CGFloat = {
            let v = CGFloat(persistedPanelWidth)
            return v.isFinite ? v : 380
          }()
          let sidePanelWidth: CGFloat = {
            if upperBound < minPanelWidth {
              // Narrow window forces below-min width — clamp to window max.
              return min(max(rawPersistedWidth, 0), upperBound)
            }
            return min(max(rawPersistedWidth, minPanelWidth), upperBound)
          }()
          let trailingInset: CGFloat = {
            let v = sidePanelWidth + panelGutter
            return (v.isFinite && v >= 0) ? v : 0
          }()
          let isPanelVisible =
            floatingSidePanel != nil && playerPresence.hasNowPlaying
          // Defensive: use isPanelVisible (Bool) as animation value — the
          // previous `value: floatingSidePanel` (enum) + duplicated outer &
          // inner spring both firing during geometry/WINDOW_RESIZE collided
          // with TabView's internal sidebarAdaptable animation. Single source
          // + transaction that suppresses animation when geometry is
          // non-finite/zero or during drag keeps the UITabSideBar coordinator stable.
          ZStack(alignment: .trailing) {
            rootTabView
              .padding(.trailing, isPanelVisible ? trailingInset : 0)
              .animation(
                isResizingSidePanel ? nil : .spring(duration: 0.26, bounce: 0.08), value: isPanelVisible
              )
              .transaction { t in
                if !safeWidth.isFinite || safeWidth == 0 || isResizingSidePanel {
                  t.animation = nil
                  t.disablesAnimations = true
                }
              }
              .frame(maxWidth: .infinity, maxHeight: .infinity)

            if isPanelVisible {
              PlayerSidePanelView(
                activePanel: $floatingSidePanel, viewModel: playerViewModel
              )
              .frame(width: sidePanelWidth)
              .frame(maxHeight: .infinity, alignment: .top)
              .transition(.move(edge: .trailing).combined(with: .opacity))
              .zIndex(2)
              // Leading-edge grab zone — thin overlay INSIDE ContentView's ZStack
              // (not inside PlayerSidePanelView per spec). Dragging left expands,
              // right shrinks. Clamped to [280, min(520, 45% width)] respecting
              // safeWidth guards; updates persistedPanelWidth (@AppStorage) so
              // width survives relaunch. Existing spring animations stay working
              // (disabled only during live drag).
              .overlay(alignment: .leading) {
                Color.clear
                  .frame(width: 12)
                  .contentShape(Rectangle())
                  .gesture(
                    DragGesture(minimumDistance: 2, coordinateSpace: .global)
                      .onChanged { value in
                        if sidePanelDragStartWidth == nil {
                          sidePanelDragStartWidth = sidePanelWidth
                        }
                        guard let start = sidePanelDragStartWidth else { return }
                        let tx = value.translation.width
                        guard tx.isFinite else { return }
                        var proposed = start - tx
                        let upper = upperBound
                        if upper < minPanelWidth {
                          proposed = min(max(proposed, 0), upper)
                        } else {
                          proposed = min(max(proposed, minPanelWidth), upper)
                        }
                        proposed = min(proposed, maxPanelWidthCap)
                        guard proposed.isFinite else { return }
                        isResizingSidePanel = true
                        persistedPanelWidth = Double(proposed)
                      }
                      .onEnded { _ in
                        sidePanelDragStartWidth = nil
                        isResizingSidePanel = false
                      }
                  )
              }
            }
          }
          .animation(isResizingSidePanel ? nil : .spring(duration: 0.26, bounce: 0.08), value: isPanelVisible)
        } else {
          rootTabView
        }

        tabKeyboardShortcuts

        // Full-screen PlayerView — iPhone/non-pad only. Pad path never renders it (fixes bottom-visibility + resize crash).
        if !isPadSidebar, playerPresence.hasNowPlaying {
          PlayerView(
            isExpanded: $isPlayerExpanded,
            viewModel: playerViewModel,
            albumViewModel: albumViewModel,
            onOpenLibraryDestination: openLibraryDestinationFromPlayer
          )
          .environmentObject(downloadViewModel)
          .ignoresSafeArea()
          .opacity(isPlayerExpanded ? 1 : 0)
          .allowsHitTesting(isPlayerExpanded)
          .accessibilityHidden(!isPlayerExpanded)
          .offset(y: isPlayerExpanded ? 0 : offScreenY + safeBottom + 40)
          .animation(.spring(duration: 0.2), value: isPlayerExpanded)
        }

        if !isPadSidebar {
          VStack {
            Spacer()

            if playerPresence.hasNowPlaying {
              let isSmallScreen = safeWidth > 0 ? safeWidth <= 390 : UIScreen.main.bounds.width <= 390
              let isPad = UIDevice.current.userInterfaceIdiom == .pad
              let bottomPadding: CGFloat = isSmallScreen ? 32 : 0
              let playerWidth: CGFloat? =
                isPad
                ? (safeWidth > 0 ? min(720, max(0, safeWidth - 32)) : 720)
                : (horizontalSizeClass == .regular ? 500 : nil)
              let rawCenterX = floatingPlayerContentCenterOffsetX(totalWidth: safeWidth)
              let playerCenterOffsetX: CGFloat = rawCenterX.isFinite ? rawCenterX : 0
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
                .opacity(playerPresence.hasNowPlaying ? 1 : 0)
                .offset(
                  x: {
                    let x = playerCenterOffsetX + self.floatingPlayerOffsetX
                    return x.isFinite ? x : 0
                  }(),
                  y: isPlayerExpanded ? offScreenY : 0
                )
                .animation(.spring(duration: 0.2), value: isPlayerExpanded)
                .onTapGesture {
                  self.isPlayerExpanded = true
                }
                .gesture(
                  DragGesture()
                    .onChanged { value in
                      let tx = value.translation.width
                      guard tx.isFinite else { return }
                      if tx < .zero {
                        floatingPlayerOffsetX = tx
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
#if targetEnvironment(macCatalyst)
      // macOS: aggressively trim the big empty strip above content.
      // SceneDelegate hides the titlebar; also collapse the top safe area
      // so detail content starts near the window top. Navigation titles
      // and search remain functional (they are inside NavigationStack).
      .ignoresSafeArea(edges: .top)
#endif
    }
#if targetEnvironment(macCatalyst)
    .frame(minWidth: 640)
#endif
    .onChange(of: floatingSidePanel) { _ in
      if let panel = floatingSidePanel {
        lastSidePanel = panel
      }
    }
    .onAppear {
      PlaybackCoordinator.shared.attach(playerViewModel: playerViewModel)
      if CommandLine.arguments.contains("-UITestSearchTab") {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
          libraryRouter.selectedTab = .search
        }
      }
    }
  }

  @ViewBuilder
  var tabKeyboardShortcuts: some View {
    Group {
      if isPadSidebar {
        tabShortcut(.home, key: "1")
        conditionalShortcut(v2Tab: .library, legacyTab: .libraryAlbums, key: "2")
        conditionalShortcut(v2Tab: .libraryAlbums, legacyTab: .libraryArtists, key: "3")
        conditionalShortcut(v2Tab: .libraryArtists, legacyTab: .likedSongs, key: "4")
        conditionalShortcut(v2Tab: .likedSongs, legacyTab: .playlists, key: "5")
        conditionalShortcut(v2Tab: .playlists, legacyTab: .songs, key: "6")
        conditionalShortcut(v2Tab: .songs, legacyTab: .radios, key: "7")
        conditionalShortcut(v2Tab: .radios, legacyTab: nil, key: "8")
        tabShortcut(.debug, key: "0")
        tabShortcut(.preferences, key: ",")
        searchShortcut(key: "f")
        Button {
          toggleSidePanel()
        } label: {
          EmptyView()
        }
        .keyboardShortcut("b", modifiers: .command)
        fontScaleShortcut(key: "-", increase: false)
        fontScaleShortcut(key: "+", increase: true)
        fontScaleShortcut(key: "=", increase: true)
      } else {
        tabShortcut(.home, key: "1")
        tabShortcut(.library, key: "2")
        tabShortcut(.downloads, key: "3")
        tabShortcut(.preferences, key: "4")
        tabShortcut(.preferences, key: ",")
        searchShortcut(key: "f")
        fontScaleShortcut(key: "-", increase: false)
        fontScaleShortcut(key: "+", increase: true)
        fontScaleShortcut(key: "=", increase: true)
      }
    }
    .frame(width: 0, height: 0)
    .opacity(0)
  }

  func tabShortcut(_ tab: AppTab, key: KeyEquivalent) -> some View {
    Button {
      libraryRouter.selectedTab = tab
    } label: {
      EmptyView()
    }
    .keyboardShortcut(key, modifiers: .command)
  }

  func conditionalShortcut(v2Tab: AppTab, legacyTab: AppTab?, key: KeyEquivalent) -> some View {
    Button {
      if libraryViewV2Enabled {
        libraryRouter.selectedTab = v2Tab
      } else if let legacyTab {
        libraryRouter.selectedTab = legacyTab
      }
    } label: {
      EmptyView()
    }
    .keyboardShortcut(key, modifiers: .command)
  }

  func libraryOrAlbumsShortcut(key: KeyEquivalent) -> some View {
    Button {
      libraryRouter.selectedTab = libraryViewV2Enabled ? .library : .libraryAlbums
    } label: {
      EmptyView()
    }
    .keyboardShortcut(key, modifiers: .command)
  }

  func albumsOrArtistsShortcut(key: KeyEquivalent) -> some View {
    Button {
      libraryRouter.selectedTab = libraryViewV2Enabled ? .libraryAlbums : .libraryArtists
    } label: {
      EmptyView()
    }
    .keyboardShortcut(key, modifiers: .command)
  }

  func searchShortcut(key: KeyEquivalent) -> some View {
    Button {
      libraryRouter.selectedTab = .search
    } label: {
      EmptyView()
    }
    .keyboardShortcut(key, modifiers: .command)
  }

  func fontScaleShortcut(key: KeyEquivalent, increase: Bool) -> some View {
    Button {
      let delta: Float = increase ? 0.05 : -0.05
      UserDefaultsManager.uiFontScale = UserDefaultsManager.uiFontScale + delta
    } label: {
      EmptyView()
    }
    .keyboardShortcut(key, modifiers: .command)
  }

  func openLibraryDestinationFromPlayer(_ destination: LibraryDestination) {
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
  @EnvironmentObject var downloadViewModel: DownloadViewModel
  @EnvironmentObject var authViewModel: AuthViewModel
  private let playerViewModel = PlayerViewModel.shared
  @StateObject private var radiosViewModel = RadiosViewModel()
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  @State private var searchText = ""
  @State private var cachedSongs: [Song] = []
  @State private var genres: [Genre] = []
  @State private var isLoadingGenres = false
  @State private var selectedGenre: Genre?
  @State private var genreAlbums: [Album] = []
  @State private var isLoadingGenreAlbums = false
  @State private var path = NavigationPath()

  private var columns: [GridItem] {
    if horizontalSizeClass == .regular { return Array(repeating: GridItem(.flexible()), count: 4) }
    else { return Array(repeating: GridItem(.flexible()), count: 2) }
  }

  private var isLoggedIn: Bool {
    if ProcessInfo.processInfo.arguments.contains("-UITestForceLoggedIn") { return true }
    return authViewModel.isLoggedIn
  }

  private func tintColor(for key: String) -> Color {
    let hue = Double(UInt(bitPattern: key.hashValue) % 360) / 360.0
    return Color(hue: hue, saturation: 0.22, brightness: 0.94)
  }

  private func placeholderArtwork(key: String, systemImage: String = "music.note") -> some View {
    ZStack {
      RoundedRectangle(cornerRadius: 8, style: .continuous).fill(tintColor(for: key).opacity(0.85))
      RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.gray.opacity(0.08))
      Image(systemName: systemImage).foregroundColor(.accent.opacity(0.7)).font(.system(size: 22))
    }
  }

  private func artistCircle(_ artist: Artist) -> some View {
    let size: CGFloat = 72
    let url = artist.mediumImageURL ?? artist.smallImageURL ?? artist.largeImageURL ?? ""
    let has = !artist.id.isEmpty || !url.isEmpty
    return Group {
      if has {
        LazyImage(url: URL(string: albumViewModel.getArtistCoverArt(id: artist.id, imageURL: url))) { state in
          if let img = state.image { img.resizable().scaledToFill().frame(width: size, height: size).clipShape(Circle()) }
          else if state.error != nil { ZStack { Circle().fill(tintColor(for: artist.id.isEmpty ? artist.name : artist.id)); Image(systemName: "music.mic").foregroundColor(.white.opacity(0.9)) }.frame(width: size, height: size) }
          else { ZStack { Circle().fill(Color.gray.opacity(0.12)); ProgressView().scaleEffect(0.7) }.frame(width: size, height: size) }
        }
      } else {
        ZStack { Circle().fill(tintColor(for: artist.name)); Image(systemName: "music.mic").foregroundColor(.white.opacity(0.9)) }.frame(width: size, height: size)
      }
    }
  }

  private func songCoverTiny(_ song: Song) -> some View {
    let key = song.albumId.isEmpty ? song.id : song.albumId
    let mediaId = song.mediaFileId.isEmpty ? song.id : song.mediaFileId
    let cover = AlbumService.shared.getAlbumCover(artistName: song.artist, albumName: song.albumName, albumId: song.albumId, trackId: mediaId)
    let remote = mediaId.isEmpty ? albumViewModel.getAlbumCoverArt(id: song.albumId) : "\(UserDefaultsManager.serverBaseURL)\(API.SubsonicEndpoint.coverArt)\(AuthService.shared.getCreds(key: "subsonicToken"))&id=mf-\(mediaId)&size=300"
    return Group {
      if let img = UIImage(contentsOfFile: cover) { Image(uiImage: img).resizable().scaledToFill().frame(width: 44, height: 44).clipShape(RoundedRectangle(cornerRadius: 6)) }
      else {
        LazyImage(url: URL(string: remote)) { state in
          if let i = state.image { i.resizable().scaledToFill().frame(width: 44, height: 44).clipShape(RoundedRectangle(cornerRadius: 6)) }
          else if state.error != nil { placeholderArtwork(key: key).frame(width: 44, height: 44).clipShape(RoundedRectangle(cornerRadius: 6)) }
          else { RoundedRectangle(cornerRadius: 6).fill(Color.gray.opacity(0.12)).frame(width: 44, height: 44).overlay { if state.isLoading { ProgressView().scaleEffect(0.6) } } }
        }
      }
    }
  }

  private func songCard(_ song: Song, onTap: @escaping () -> Void) -> some View {
    Button(action: onTap) {
      HStack(spacing: 10) {
        songCoverTiny(song)
        VStack(alignment: .leading, spacing: 3) {
          Text(song.title).customFont(.caption1).fontWeight(.bold).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
          HStack(spacing: 3) {
            Text(song.artist).customFont(.caption2).foregroundColor(.gray).lineLimit(1)
            Text("•").font(.system(size: 8)).foregroundColor(.gray.opacity(0.5))
            Text(timeString(for: song.duration)).font(.system(size: 10)).foregroundColor(.gray.opacity(0.65))
          }.frame(maxWidth: .infinity, alignment: .leading)
        }
      }.frame(width: 240, alignment: .leading).contentShape(Rectangle())
    }.buttonStyle(.plain)
  }

  private func albumCard(_ album: Album) -> some View {
    let key = album.id.isEmpty ? album.name : album.id
    return VStack(alignment: .leading, spacing: 6) {
      Group {
        if let img = UIImage(contentsOfFile: albumViewModel.getAlbumCoverArt(id: album.id, albumCover: album.albumCover)) {
          Image(uiImage: img).resizable().scaledToFill().frame(width: 120, height: 120).clipShape(RoundedRectangle(cornerRadius: 8))
        } else {
          LazyImage(url: URL(string: albumViewModel.getAlbumCoverArt(id: album.id, albumCover: album.albumCover))) { state in
            if let i = state.image { i.resizable().scaledToFill().frame(width: 120, height: 120).clipShape(RoundedRectangle(cornerRadius: 8)) }
            else if state.error != nil { placeholderArtwork(key: key).frame(width: 120, height: 120).clipShape(RoundedRectangle(cornerRadius: 8)) }
            else { RoundedRectangle(cornerRadius: 8).fill(Color.gray.opacity(0.12)).frame(width: 120, height: 120).overlay { if state.isLoading { ProgressView().scaleEffect(0.7) } } }
          }
        }
      }
      Text(album.name).customFont(.caption1).fontWeight(.bold).foregroundColor(.primary).lineLimit(1).frame(width: 120, alignment: .leading)
      Text(album.albumArtist.isEmpty ? album.artist : album.albumArtist).customFont(.caption2).foregroundColor(.gray).lineLimit(1).frame(width: 120, alignment: .leading)
    }
  }

  private func sectionHeader(title: String, subtitle: String? = nil) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(title).customFont(.title3).fontWeight(.bold)
      if let s = subtitle { Text(s).customFont(.caption1).foregroundColor(.gray) }
    }.frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal)
  }

  private func genreCell(_ genre: Genre) -> some View {
    ZStack(alignment: .bottomLeading) {
      RoundedRectangle(cornerRadius: 12, style: .continuous)
        .fill(tintColor(for: genre.name))
      LinearGradient(colors: [Color.black.opacity(0.58), Color.black.opacity(0.0)], startPoint: .bottom, endPoint: .top)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
      Text(genre.name)
        .font(.custom("Plus Jakarta Sans", size: 17).weight(.bold))
        .foregroundColor(.white)
        .shadow(color: Color.black.opacity(0.50), radius: 2, x: 0, y: 1)
        .lineLimit(1)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .bottomLeading)
    }
    .frame(maxWidth: .infinity, minHeight: 110)
    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.white.opacity(0.12), lineWidth: 1))
  }

  private func chunked(_ songs: [Song], size: Int = 4) -> [[Song]] {
    stride(from: 0, to: songs.count, by: size).map { Array(songs[$0..<min($0+size, songs.count)]) }
  }

  private var filteredAlbums: [Album] {
    guard !searchText.isEmpty else { return [] }
    let source = isLoggedIn ? albumViewModel.albums : albumViewModel.downloadedAlbums
    return source.filter { $0.name.localizedCaseInsensitiveContains(searchText) || $0.artist.localizedCaseInsensitiveContains(searchText) }
  }

  private var filteredArtists: [Artist] {
    guard isLoggedIn, !searchText.isEmpty else { return [] }
    return albumViewModel.artists.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
  }

  private var filteredSongs: [Song] {
    guard !searchText.isEmpty else { return [] }
    if isLoggedIn {
      return albumViewModel.songs.filter { $0.title.localizedCaseInsensitiveContains(searchText) || $0.artist.localizedCaseInsensitiveContains(searchText) }
    } else {
      let downloaded = albumViewModel.downloadedAlbums.flatMap { AlbumService.shared.getSongsByAlbumId(albumId: $0.id) }
      let combined = Array(Set(cachedSongs + downloaded))
      return combined.filter { $0.title.localizedCaseInsensitiveContains(searchText) || $0.artist.localizedCaseInsensitiveContains(searchText) }
    }
  }

  private var filteredPlaylists: [Playlist] {
    guard isLoggedIn, !searchText.isEmpty else { return [] }
    return albumViewModel.playlists.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
  }

  private var filteredRadios: [Radio] {
    guard isLoggedIn, !searchText.isEmpty else { return [] }
    return radiosViewModel.radios.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
  }

  private var filteredLiked: [Song] {
    guard isLoggedIn, !searchText.isEmpty else { return [] }
    return albumViewModel.starredSongs.filter { $0.title.localizedCaseInsensitiveContains(searchText) || $0.artist.localizedCaseInsensitiveContains(searchText) }
  }

  private var filteredRecentPlayed: [Album] {
    guard isLoggedIn, !searchText.isEmpty else { return [] }
    return albumViewModel.recentlyPlayedAlbums.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
  }

  private var filteredRecentAdded: [Album] {
    guard isLoggedIn, !searchText.isEmpty else { return [] }
    return albumViewModel.recentlyAddedAlbums.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
  }

  private var hasResults: Bool {
    !filteredAlbums.isEmpty || !filteredArtists.isEmpty || !filteredSongs.isEmpty || !filteredPlaylists.isEmpty || !filteredRadios.isEmpty || !filteredLiked.isEmpty || !filteredRecentPlayed.isEmpty || !filteredRecentAdded.isEmpty
  }

  private func fetchGenres() {
    if ProcessInfo.processInfo.arguments.contains("-UITestMockGenres") {
      genres = [Genre(name: "Rock"), Genre(name: "Pop"), Genre(name: "Jazz"), Genre(name: "Electronic"), Genre(name: "Hip-Hop")]
      isLoadingGenres = false
      return
    }
    let cacheKey = "search_genres"
    if let cached: [Genre] = LibraryCacheManager.shared.load([Genre].self, forKey: cacheKey), !cached.isEmpty {
      genres = cached
    }
    isLoadingGenres = genres.isEmpty
    AlbumService.shared.getGenres { result in
      DispatchQueue.main.async {
        isLoadingGenres = false
        switch result {
        case .success(let g):
          genres = g
          if !g.isEmpty {
            DispatchQueue.global(qos: .utility).async {
              LibraryCacheManager.shared.save(g, forKey: cacheKey)
            }
          }
        case .failure:
          if genres.isEmpty { genres = [] }
        }
      }
    }
  }

  private func fetchGenreAlbums(_ genre: Genre) {
    selectedGenre = genre
    isLoadingGenreAlbums = true
    genreAlbums = []
    AlbumService.shared.getAlbumsByGenre(genre: genre.name) { result in
      DispatchQueue.main.async {
        isLoadingGenreAlbums = false
        switch result {
        case .success(let albums): genreAlbums = albums
        case .failure: genreAlbums = []
        }
      }
    }
  }

  var body: some View {
    NavigationStack(path: $path) {
      ScrollView {
        if searchText.isEmpty {
            if isLoadingGenres {
              ProgressView().frame(maxWidth: .infinity).padding(.top, 40)
            } else if genres.isEmpty {
              Color.clear.frame(height: 1).padding(.top, 40)
            } else {
              LazyVGrid(columns: columns, spacing: 10) {
                ForEach(genres) { genre in
                  NavigationLink(value: genre) {
                    genreCell(genre)
                  }.buttonStyle(.plain)
                }
              }.padding(.horizontal).padding(.top, 10).playerBottomPadding(active: 90, inactive: 12)
            }
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
          VStack(alignment: .leading, spacing: 24) {
            if !filteredAlbums.isEmpty {
              VStack(alignment: .leading, spacing: 14) {
                sectionHeader(title: "Albums")
                ScrollView(.horizontal, showsIndicators: false) {
                  HStack(spacing: 12) {
                    ForEach(filteredAlbums.prefix(10)) { album in
                      NavigationLink {
                        AlbumView(viewModel: albumViewModel).environmentObject(downloadViewModel).onAppear { albumViewModel.setActiveAlbum(album: album) }
                      } label: { albumCard(album) }.buttonStyle(.plain)
                    }
                  }.padding(.horizontal)
                }
              }
            }
            if !filteredRecentPlayed.isEmpty {
              VStack(alignment: .leading, spacing: 14) {
                sectionHeader(title: "Recently Played")
                ScrollView(.horizontal, showsIndicators: false) {
                  HStack(spacing: 12) {
                    ForEach(filteredRecentPlayed.prefix(10)) { album in
                      NavigationLink {
                        AlbumView(viewModel: albumViewModel).environmentObject(downloadViewModel).onAppear { albumViewModel.setActiveAlbum(album: album) }
                      } label: { albumCard(album) }.buttonStyle(.plain)
                    }
                  }.padding(.horizontal)
                }
              }
            }
            if !filteredRecentAdded.isEmpty {
              VStack(alignment: .leading, spacing: 14) {
                sectionHeader(title: "Recently Added")
                ScrollView(.horizontal, showsIndicators: false) {
                  HStack(spacing: 12) {
                    ForEach(filteredRecentAdded.prefix(10)) { album in
                      NavigationLink {
                        AlbumView(viewModel: albumViewModel).environmentObject(downloadViewModel).onAppear { albumViewModel.setActiveAlbum(album: album) }
                      } label: { albumCard(album) }.buttonStyle(.plain)
                    }
                  }.padding(.horizontal)
                }
              }
            }
            if !filteredArtists.isEmpty {
              VStack(alignment: .leading, spacing: 14) {
                sectionHeader(title: "Artists")
                ScrollView(.horizontal, showsIndicators: false) {
                  HStack(spacing: 12) {
                    ForEach(filteredArtists.prefix(5)) { artist in
                      NavigationLink {
                        ArtistDetailView(artist: artist).environmentObject(albumViewModel).environmentObject(playerViewModel).environmentObject(downloadViewModel)
                      } label: {
                        VStack(spacing: 6) {
                          artistCircle(artist)
                          Text(artist.name).customFont(.caption1).fontWeight(.bold).lineLimit(1).frame(width: 72)
                        }
                      }.buttonStyle(.plain)
                    }
                  }.padding(.horizontal)
                }
              }
            }
            if !filteredLiked.isEmpty {
              VStack(alignment: .leading, spacing: 14) {
                sectionHeader(title: "Liked Songs")
                ScrollView(.horizontal, showsIndicators: false) {
                  HStack(alignment: .top, spacing: 16) {
                    ForEach(Array(chunked(Array(filteredLiked.prefix(16))).enumerated()), id: \.offset) { _, chunk in
                      VStack(spacing: 12) {
                        ForEach(chunk, id: \.id) { song in
                          songCard(song) {
                            if let idx = filteredLiked.firstIndex(where: { $0.id == song.id }) {
                              let c = SongCollection(id: "starred-songs", name: "Liked Songs", songs: filteredLiked)
                              playerViewModel.playBySong(idx: idx, item: c, isFromLocal: false)
                            }
                          }
                        }
                      }
                    }
                  }.padding(.horizontal)
                }
              }
            }
            if !filteredPlaylists.isEmpty {
              VStack(alignment: .leading, spacing: 14) {
                sectionHeader(title: "Playlists")
                ScrollView(.horizontal, showsIndicators: false) {
                  HStack(spacing: 12) {
                    ForEach(filteredPlaylists.prefix(5)) { playlist in
                      NavigationLink {
                        PlaylistDetailView().environmentObject(albumViewModel).environmentObject(playerViewModel).environmentObject(downloadViewModel).onAppear { albumViewModel.setActivePlaylist(playlist: playlist) }
                      } label: {
                        VStack(alignment: .leading, spacing: 6) {
                          if let img = UIImage(contentsOfFile: albumViewModel.getPlaylistCoverArt(id: playlist.id, coverArtId: playlist.coverArtId)) {
                            Image(uiImage: img).resizable().scaledToFill().frame(width: 120, height: 120).clipShape(RoundedRectangle(cornerRadius: 8))
                          } else {
                            LazyImage(url: URL(string: albumViewModel.getPlaylistCoverArt(id: playlist.id, coverArtId: playlist.coverArtId))) { state in
                              if let i = state.image { i.resizable().scaledToFill().frame(width: 120, height: 120).clipShape(RoundedRectangle(cornerRadius: 8)) }
                              else if state.error != nil { placeholderArtwork(key: playlist.id, systemImage: "music.note.list").frame(width: 120, height: 120).clipShape(RoundedRectangle(cornerRadius: 8)) }
                              else { RoundedRectangle(cornerRadius: 8).fill(Color.gray.opacity(0.12)).frame(width: 120, height: 120) }
                            }
                          }
                          Text(playlist.name).customFont(.caption1).fontWeight(.bold).lineLimit(1).frame(width: 120, alignment: .leading)
                          Text(playlist.ownerName).customFont(.caption2).foregroundColor(.gray).lineLimit(1).frame(width: 120, alignment: .leading)
                        }
                      }.buttonStyle(.plain)
                    }
                  }.padding(.horizontal)
                }
              }
            }
            if !filteredSongs.isEmpty {
              VStack(alignment: .leading, spacing: 14) {
                sectionHeader(title: "Songs")
                ScrollView(.horizontal, showsIndicators: false) {
                  HStack(alignment: .top, spacing: 16) {
                    ForEach(Array(chunked(Array(filteredSongs.prefix(16))).enumerated()), id: \.offset) { _, chunk in
                      VStack(spacing: 12) {
                        ForEach(chunk, id: \.id) { song in
                          songCard(song) {
                            if let idx = filteredSongs.firstIndex(where: { $0.id == song.id }) {
                              var pl = Playlist(name: "Search Results")
                              pl.songs = filteredSongs
                              playerViewModel.playBySong(idx: idx, item: pl, isFromLocal: !isLoggedIn)
                            }
                          }
                        }
                      }
                    }
                  }.padding(.horizontal)
                }
              }
            }
            if !filteredRadios.isEmpty {
              VStack(alignment: .leading, spacing: 14) {
                sectionHeader(title: "Radios")
                ScrollView(.horizontal, showsIndicators: false) {
                  HStack(spacing: 12) {
                    ForEach(filteredRadios.prefix(5), id: \.id) { radio in
                      VStack(spacing: 6) {
                        placeholderArtwork(key: radio.id, systemImage: "radio").frame(width: 100, height: 100).clipShape(RoundedRectangle(cornerRadius: 8))
                        Text(radio.name).customFont(.caption1).lineLimit(1).frame(width: 100)
                      }.onTapGesture { playerViewModel.playRadioItem(radio: radio) }
                    }
                  }.padding(.horizontal)
                }
              }
            }
          }.padding(.top, 10).playerBottomPadding(active: 90, inactive: 12)
        }
      }
      .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search Library")
      .navigationTitle("Search")
      .navigationDestination(for: Genre.self) { genre in
        GenreAlbumsView(genre: genre)
          .environmentObject(albumViewModel)
          .environmentObject(playerViewModel)
          .environmentObject(downloadViewModel)
      }
      .onAppear {
        albumViewModel.getArtists()
        albumViewModel.fetchAllSongs()
        albumViewModel.getPlaylists()
        albumViewModel.fetchRecentlyPlayedAlbums()
        albumViewModel.fetchRecentlyAddedAlbums()
        radiosViewModel.fetchAllRadios()
        albumViewModel.fetchDownloadedAlbums()
        cachedSongs = StreamCacheManager.shared.getCachedSongs()
        fetchGenres()
        if ProcessInfo.processInfo.arguments.contains("-UITestPushGenre") {
          DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            path.append(Genre(name: "Rock"))
          }
        }
      }
      .onChange(of: searchText) { _ in
        if searchText.isEmpty { selectedGenre = nil; genreAlbums = [] }
      }
    }
  }
}

struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    ContentView()
  }
}
