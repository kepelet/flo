//
//  App.swift
//  flo
//
//  Created by rizaldy on 01/06/24.
//

import AVFoundation
import SwiftUI

@main
struct FloApp: App {
  @StateObject private var inAppPurchaseManager = InAppPurchaseManager()

  init() {
    do {
      try AVAudioSession.sharedInstance().setCategory(AVAudioSession.Category.playback)
      try AVAudioSession.sharedInstance().setActive(true)
    } catch {
      print(error)
    }

    #if os(iOS)
      WatchConnectivityManager.shared.start()
    #endif
  }

  var body: some Scene {
    WindowGroup {
      ContentView()
        .environmentObject(inAppPurchaseManager)
    }
  }
}
