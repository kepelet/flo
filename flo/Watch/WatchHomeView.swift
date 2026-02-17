//
//  WatchHomeView.swift
//  flo
//
//  Created by Codex on 17/02/26.
//

#if os(watchOS)
  import SwiftUI

  struct WatchHomeView: View {
    @ObservedObject var libraryViewModel: WatchLibraryViewModel
    @ObservedObject var playerViewModel: WatchPlayerViewModel
    @ObservedObject private var connectivity = WatchConnectivityManager.shared

    @State private var isNowPlayingPresented = false

    var body: some View {
      NavigationStack {
        List {
          Section {
            Button {
              isNowPlayingPresented = true
            } label: {
              HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                  if playerViewModel.nowPlayingTitle.isEmpty {
                    Text("Nothing Playing")
                      .font(.headline)
                  } else {
                    Text(playerViewModel.nowPlayingTitle)
                      .font(.headline)
                      .lineLimit(1)

                    Text(playerViewModel.nowPlayingArtist)
                      .font(.caption)
                      .foregroundColor(.secondary)
                      .lineLimit(1)
                  }
                }
                Spacer()

                if !playerViewModel.nowPlayingTitle.isEmpty {
                  if #available(watchOS 11.0, *) {
                    Image(systemName: "waveform")
                      .foregroundColor(.accentColor)
                      .symbolEffect(.bounce, options: .repeating)
                  } else {
                    Image(systemName: "waveform")
                      .foregroundColor(.accentColor)
                  }
                }
              }
            }
          }

          Section("Library") {
            NavigationLink {
              WatchAlbumsView(
                libraryViewModel: libraryViewModel,
                playerViewModel: playerViewModel
              )
            } label: {
              HStack(spacing: 6) {
                Image(systemName: "square.grid.2x2")
                  .foregroundColor(.accentColor)
                Text("Albums")
              }
            }
            NavigationLink {
              WatchArtistsView(
                libraryViewModel: libraryViewModel,
                playerViewModel: playerViewModel
              )
            } label: {
              HStack(spacing: 6) {
                Image(systemName: "music.mic")
                  .foregroundColor(.accentColor)
                Text("Artists")
              }
            }
            NavigationLink {
              WatchPlaylistsView(
                libraryViewModel: libraryViewModel,
                playerViewModel: playerViewModel
              )
            } label: {
              HStack(spacing: 6) {
                Image(systemName: "music.note.list")
                  .foregroundColor(.accentColor)
                Text("Playlists")
              }
            }
            NavigationLink {
              WatchSongsView(
                libraryViewModel: libraryViewModel,
                playerViewModel: playerViewModel
              )
            } label: {
              HStack(spacing: 6) {
                Image(systemName: "music.note")
                  .foregroundColor(.accentColor)
                Text("Songs")
              }
            }
            NavigationLink {
              WatchRadiosView(
                libraryViewModel: libraryViewModel,
                playerViewModel: playerViewModel
              )
            } label: {
              HStack(spacing: 6) {
                Image(systemName: "radio")
                  .foregroundColor(.accentColor)
                Text("Radios")
              }
            }
          }
        }
        .sheet(isPresented: $isNowPlayingPresented) {
          WatchNowPlayingView(playerViewModel: playerViewModel)
        }
        .onAppear {
          playerViewModel.refreshNowPlaying()
          connectivity.refreshServerStatus()
        }
      }
    }
  }
#endif
