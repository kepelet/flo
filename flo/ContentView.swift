//
//  ContentView.swift
//  flo
//
//  Created by rizaldy on 01/06/24.
//

import SwiftUI

struct ContentView: View {
  @State private var isPlayerExpanded: Bool = false

  @StateObject private var authViewModel = AuthViewModel()
  @StateObject private var playerViewModel = PlayerViewModel()
  @StateObject private var albumViewModel = AlbumViewModel()
  @StateObject private var scanStatusViewModel = ScanStatusViewModel()

  var body: some View {
    ZStack {
      TabView {
        HomeView(viewModel: authViewModel).tabItem {
          Label("Home", systemImage: "house")
        }.environmentObject(scanStatusViewModel)

        if authViewModel.isLoggedIn {
          LibraryView(viewModel: albumViewModel).tabItem {
            Label("Library", systemImage: "square.grid.2x2")
          }.environmentObject(playerViewModel).onAppear {
            albumViewModel.fetchAlbums()
          }
        }

        DownloadsView(viewModel: albumViewModel).tabItem {
          Label("Downloads", systemImage: "arrow.down.circle")
        }.environmentObject(playerViewModel).onAppear {
          albumViewModel.fetchDownloadedAlbums()
        }

        PreferencesView(authViewModel: authViewModel).tabItem {
          Label("Preferences", systemImage: "gear")
        }.environmentObject(scanStatusViewModel).environmentObject(playerViewModel)
      }

      ZStack {
        if playerViewModel.hasNowPlaying() && !playerViewModel.shouldHidePlayer {
          PlayerView(isExpanded: $isPlayerExpanded, viewModel: playerViewModel)
        }
      }
      .offset(y: isPlayerExpanded ? 0 : UIScreen.main.bounds.height)
      .animation(.spring(), value: isPlayerExpanded)

      VStack {
        Spacer()

        if playerViewModel.hasNowPlaying() && !playerViewModel.shouldHidePlayer {
          FloatingPlayerView(viewModel: playerViewModel)
            .padding(.bottom, 50)
            .shadow(radius: 10)
            .opacity(playerViewModel.hasNowPlaying() ? 1 : 0)
            .offset(y: isPlayerExpanded ? UIScreen.main.bounds.height : 0)
            .animation(.spring(), value: isPlayerExpanded)
            .onTapGesture {
              self.isPlayerExpanded = true
            }
        }
      }
    }
  }
}

struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    ContentView()
  }
}
