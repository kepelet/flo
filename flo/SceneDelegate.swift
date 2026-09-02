//
//  SceneDelegate.swift
//  flo
//

import SwiftUI
import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
  var window: UIWindow?

  func scene(
    _ scene: UIScene,
    willConnectTo _: UISceneSession,
    options _: UIScene.ConnectionOptions
  ) {
    guard let windowScene = scene as? UIWindowScene else { return }

    #if targetEnvironment(macCatalyst)
      if let titlebar = windowScene.titlebar {
        titlebar.titleVisibility = .hidden
        titlebar.toolbar = nil
        titlebar.toolbarStyle = .unifiedCompact
        if #available(macCatalyst 16.0, *) {
          titlebar.separatorStyle = .none
        }
      }
      windowScene.sizeRestrictions?.minimumSize = CGSize(width: 900, height: 500)
    #endif

    let window = UIWindow(windowScene: windowScene)
    let contentView = ContentView()
      .environmentObject(InAppPurchaseManager())

    window.rootViewController = UIHostingController(rootView: contentView)
    self.window = window
    window.makeKeyAndVisible()
  }

  func sceneDidDisconnect(_: UIScene) {}

  func sceneDidBecomeActive(_ scene: UIScene) {
    #if targetEnvironment(macCatalyst)
      let minSize = CGSize(width: 900, height: 500)
      // Re-apply at activation — windowScene is definitively bound here (unlike willConnectTo
      // where sizeRestrictions can be nil / not yet attached, making the assignment a silent no-op).
      if let ws = window?.windowScene {
        ws.sizeRestrictions?.minimumSize = minSize
      } else if let ws = scene as? UIWindowScene {
        ws.sizeRestrictions?.minimumSize = minSize
      }
      for s in UIApplication.shared.connectedScenes {
        (s as? UIWindowScene)?.sizeRestrictions?.minimumSize = minSize
      }
      // Retro-clamp: a restored frame (e.g. 693x768) bypasses sizeRestrictions until the next
      // user resize, so grow it to the minimum now. Keep top-left origin, grow right/down,
      // nudging origin only if the enlarged frame would overflow the screen.
      if let w = window {
        let frame = w.frame
        if frame.width < minSize.width || frame.height < minSize.height {
          let newWidth = max(frame.width, minSize.width)
          let newHeight = max(frame.height, minSize.height)
          var newFrame = CGRect(x: frame.origin.x, y: frame.origin.y, width: newWidth, height: newHeight)
          let screenBounds = w.windowScene?.screen.bounds ?? w.screen.bounds
          if newFrame.maxX > screenBounds.maxX {
            newFrame.origin.x = max(screenBounds.minX, screenBounds.maxX - newFrame.width - 16)
          }
          if newFrame.maxY > screenBounds.maxY {
            newFrame.origin.y = max(screenBounds.minY, screenBounds.maxY - newFrame.height - 16)
          }
          w.frame = newFrame
        }
      }
    #endif
  }

  func sceneWillResignActive(_: UIScene) {}

  func sceneWillEnterForeground(_: UIScene) {}

  func sceneDidEnterBackground(_: UIScene) {}
}
