//
//  AppDelegate.swift
//  flo
//

import AVFoundation
import UIKit
#if targetEnvironment(macCatalyst)
  import ObjectiveC.runtime
#endif

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
        if let windowClass = NSClassFromString("NSWindow") {
            let sel = NSSelectorFromString("setAllowsAutomaticWindowTabbing:")
            if let method = class_getClassMethod(windowClass, sel) {
                typealias Setter = @convention(c) (AnyObject, Selector, Bool) -> Void
                let setter = unsafeBitCast(method_getImplementation(method), to: Setter.self)
                setter(windowClass as AnyObject, sel, false)
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
