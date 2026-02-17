//
//  WatchRootView.swift
//  flo
//
//  Created by Codex on 17/02/26.
//

#if os(watchOS)
  import SwiftUI

  struct WatchRootView: View {
    @StateObject private var libraryViewModel = WatchLibraryViewModel()
    @StateObject private var playerViewModel = WatchPlayerViewModel()

    @ObservedObject private var connectivity = WatchConnectivityManager.shared

    var body: some View {
      if connectivity.isReachable {
        WatchHomeView(
          libraryViewModel: libraryViewModel,
          playerViewModel: playerViewModel
        )
      } else {
        VStack(spacing: 8) {
          Image(systemName: "iphone")
            .font(.title2)

          Text("Open flo on your phone")
            .font(.headline)
            .multilineTextAlignment(.center)

          Text(statusMessage)
            .font(.caption)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)

          Button("Retry") {
            connectivity.ping()
          }
          .font(.caption)
        }
        .padding()
      }
    }

    private var statusMessage: String {
      if !connectivity.isActivated {
        return "Activating Watch session"
      }

      return "Connect to sync your library"
    }
  }
#endif
