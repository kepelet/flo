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
  init() {
    do {
      try AVAudioSession.sharedInstance().setCategory(AVAudioSession.Category.playback)
      try AVAudioSession.sharedInstance().setActive(true)
    } catch {
      print(error)
    }
  }

  var body: some Scene {
    WindowGroup {
      ContentView()
    }
  }
}
