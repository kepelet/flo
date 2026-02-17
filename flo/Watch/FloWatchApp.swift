//
//  FloWatchApp.swift
//  flo
//
//  Created by Codex on 17/02/26.
//

#if os(watchOS)
import SwiftUI

@main
struct FloWatchApp: App {
  var body: some Scene {
    WindowGroup {
      WatchRootView()
    }
  }
}
#endif
