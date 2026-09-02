//
//  SceneDelegate.swift
//  flo
//

import SwiftUI
import UIKit
#if targetEnvironment(macCatalyst)
  import AppKit
#endif

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
      // Belt-and-braces: cheap even if not binding on this OS.
      windowScene.sizeRestrictions?.minimumSize = CGSize(width: 900, height: 500)
    #endif

    let window = UIWindow(windowScene: windowScene)
    let contentView = ContentView()
      .environmentObject(InAppPurchaseManager())

    window.rootViewController = UIHostingController(rootView: contentView)
    self.window = window
    window.makeKeyAndVisible()

    #if targetEnvironment(macCatalyst)
      // NSWindow is the layer Catalyst actually enforces. It may not exist
      // until the next runloop after makeKeyAndVisible, so try now + async.
      enforceCatalystMinSize()
      DispatchQueue.main.async { [weak self] in self?.enforceCatalystMinSize() }
    #endif
  }

  func sceneDidDisconnect(_: UIScene) {}

  func sceneDidBecomeActive(_ scene: UIScene) {
    #if targetEnvironment(macCatalyst)
      let minSize = CGSize(width: 900, height: 500)
      // Keep sizeRestrictions in sync (harmless belt-and-braces).
      if let ws = window?.windowScene {
        ws.sizeRestrictions?.minimumSize = minSize
      } else if let ws = scene as? UIWindowScene {
        ws.sizeRestrictions?.minimumSize = minSize
      }
      for s in UIApplication.shared.connectedScenes {
        (s as? UIWindowScene)?.sizeRestrictions?.minimumSize = minSize
      }
      enforceCatalystMinSize()
      // NSWindow may still be resolving right after activation; retry once.
      DispatchQueue.main.async { [weak self] in self?.enforceCatalystMinSize() }
    #endif
  }

  func sceneWillResignActive(_: UIScene) {}

  func sceneWillEnterForeground(_: UIScene) {}

  func sceneDidEnterBackground(_: UIScene) {}
}

#if targetEnvironment(macCatalyst)
  private extension SceneDelegate {
    /// Find the AppKit NSWindow backing the Catalyst UIWindowScene.
    /// Prefer a frame-size match (within a few pt); fallback to keyWindow,
    /// then first titled/contentView window.
    func resolveCatalystNSWindow() -> NSWindow? {
      let candidates = NSApplication.shared.windows
      if let uiWindow = window {
        let uf = uiWindow.frame
        // Prefer size match within 4pt and with a contentView (real app window).
        if let m = candidates.first(where: {
          abs($0.frame.width - uf.width) < 4 && abs($0.frame.height - uf.height) < 4
            && $0.contentView != nil
        }) {
          return m
        }
        // Fallback: origin match (covers coordinate-system flips).
        if let m = candidates.first(where: {
          abs($0.frame.origin.x - uf.origin.x) < 4
            && abs($0.frame.origin.y - uf.origin.y) < 4 && $0.contentView != nil
        }) {
          return m
        }
      }
      if let key = NSApplication.shared.keyWindow, key.contentView != nil {
        return key
      }
      // First titled window that looks like the main app window.
      if let titled = candidates.first(where: {
        $0.contentView != nil && $0.styleMask.contains(.titled)
      }) {
        return titled
      }
      return candidates.first(where: { $0.contentView != nil })
    }

    /// Enforce 900×500 minimum via NSWindow (the layer macOS actually clamps).
    /// Sets both `contentMinSize` and `minSize`, then retro-clamps a restored
    /// sub-minimum frame with `setFrame` (writable at AppKit layer where
    /// UIWindow.frame is not for Catalyst-managed windows).
    func enforceCatalystMinSize() {
      guard let nsWindow = resolveCatalystNSWindow() else { return }
      let minNS = NSSize(width: 900, height: 500)
      nsWindow.contentMinSize = minNS
      nsWindow.minSize = minNS

      // Retro-clamp: restored frame (e.g. 693×768) bypasses restrictions until
      // the next user resize, so grow it now. Keep origin, expand right/up,
      // nudging only if the enlarged frame would overflow the screen.
      let frame = nsWindow.frame
      guard frame.width < minNS.width || frame.height < minNS.height else { return }
      let newWidth = max(frame.width, minNS.width)
      let newHeight = max(frame.height, minNS.height)
      var newFrame = NSRect(x: frame.origin.x, y: frame.origin.y, width: newWidth, height: newHeight)

      if let screenFrame = nsWindow.screen?.visibleFrame ?? NSScreen.main?.visibleFrame {
        if newFrame.maxX > screenFrame.maxX {
          newFrame.origin.x = max(screenFrame.minX, screenFrame.maxX - newFrame.width - 16)
        }
        if newFrame.maxY > screenFrame.maxY {
          newFrame.origin.y = max(screenFrame.minY, screenFrame.maxY - newFrame.height - 16)
        }
        if newFrame.minX < screenFrame.minX { newFrame.origin.x = screenFrame.minX + 16 }
        if newFrame.minY < screenFrame.minY { newFrame.origin.y = screenFrame.minY + 16 }
      } else if let uiBounds = window?.windowScene?.screen.bounds ?? window?.screen.bounds {
        // Fallback to UIKit screen bounds (same size, different origin convention
        // but maxX/maxY overflow check still prevents off-screen placement).
        if newFrame.maxX > uiBounds.maxX {
          newFrame.origin.x = max(uiBounds.minX, uiBounds.maxX - newFrame.width - 16)
        }
        if newFrame.maxY > uiBounds.maxY {
          newFrame.origin.y = max(uiBounds.minY, uiBounds.maxY - newFrame.height - 16)
        }
      }
      nsWindow.setFrame(newFrame, display: true)
    }
  }
#endif
