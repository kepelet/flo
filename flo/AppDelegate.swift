//
//  AppDelegate.swift
//  flo
//

import AVFoundation
import UIKit

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        do {
            try AVAudioSession.sharedInstance().setCategory(AVAudioSession.Category.playback)
        } catch {
            print(error)
        }

        #if targetEnvironment(macCatalyst)
        // Disable "Show Tab Bar" (Window tabbing) on Mac Catalyst.
        // NSWindow is unavailable directly in Catalyst SDK, so use dynamic dispatch.
        if let windowClass = NSClassFromString("NSWindow") as? NSObjectProtocol {
            // KVC on the class object; selector is setAllowsAutomaticWindowTabbing:
            let sel = NSSelectorFromString("setAllowsAutomaticWindowTabbing:")
            if windowClass.responds(to: sel) {
                // perform with NSNumber boxing for BOOL
                _ = windowClass.perform(sel, with: NSNumber(value: false))
            }
        }
        #endif

        #if os(iOS)
        WatchConnectivityManager.shared.start()
        #endif

        return true
    }

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        // Return configuration for window scene to use SceneDelegate
        let configuration = UISceneConfiguration(
            name: "Default Configuration",
            sessionRole: connectingSceneSession.role
        )
        configuration.delegateClass = SceneDelegate.self
        return configuration
    }
}
