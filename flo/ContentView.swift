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

  var body: some View {
    ZStack {
      TabView {
        HomeView(viewModel: authViewModel).tabItem {
          Label("Home", systemImage: "house")
        }.environmentObject(floooViewModel)

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
        }.environmentObject(playerViewModel).environmentObject(floooViewModel).environmentObject(inAppPurchaseManager)

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

      if playerViewModel.hasNowPlaying() && !playerViewModel.shouldHidePlayer {
        PlayerView(isExpanded: $isPlayerExpanded, viewModel: playerViewModel)
          .ignoresSafeArea()
          .offset(y: isPlayerExpanded ? 0 : UIScreen.main.bounds.height)
          .animation(.spring(duration: 0.2), value: isPlayerExpanded)
      }

      VStack {
        Spacer()

        if playerViewModel.hasNowPlaying() && !playerViewModel.shouldHidePlayer {
          let isSmallScreen = UIScreen.main.bounds.width <= 390
          let bottomPadding: CGFloat = isSmallScreen ? 32 : 0

          FloatingPlayerView(viewModel: playerViewModel)
            .frame(maxWidth: horizontalSizeClass == .regular ? 500 : .infinity)
            .padding(.bottom, 40 + bottomPadding)
            .opacity(playerViewModel.hasNowPlaying() ? 1 : 0)
            .offset(
              x: self.floatingPlayerOffsetX, y: isPlayerExpanded ? UIScreen.main.bounds.height : 0
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

                  if abs(floatingPlayerOffsetX) > swipeThreshold && !isSwipping {
                    isSwipping = true
                  }
                }
                .onEnded { value in
                  if abs(floatingPlayerOffsetX) > swipeThreshold && isSwipping {
                    playerViewModel.destroyPlayerAndQueue()
                  }

                  self.floatingPlayerOffsetX = .zero
                  self.isSwipping = false
                }
            )
        }
      }
    }
    .onAppear {
      PlaybackCoordinator.shared.attach(playerViewModel: playerViewModel)
    }
  }
}

struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    ContentView()
  }
}
