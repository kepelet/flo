//
//  App.swift
//  flo
//
//  Created by rizaldy on 01/06/24.
//

import AVFoundation
import SwiftUI
import UIKit

@main
struct FloApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        StreamCacheManager.shared.reconcile()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
