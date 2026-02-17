//
//  WatchRootView.swift
//  flo
//
//  Created by Codex on 17/02/26.
//

#if os(watchOS)
import SwiftUI

struct WatchRootView: View {
  @StateObject private var authViewModel = AuthViewModel()
  @StateObject private var libraryViewModel = WatchLibraryViewModel()
  @StateObject private var playerViewModel = WatchPlayerViewModel()

  var body: some View {
    if authViewModel.isLoggedIn {
      WatchHomeView(
        authViewModel: authViewModel,
        libraryViewModel: libraryViewModel,
        playerViewModel: playerViewModel
      )
    } else {
      WatchLoginView(authViewModel: authViewModel)
    }
  }
}
#endif
