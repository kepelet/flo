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
      // sizeRestrictions may be nil on this OS — log so we learn why it no-ops.
      // Some Catalyst reports indicate restrictions only bind when both min+max set.
      if let restrictions = windowScene.sizeRestrictions {
        restrictions.minimumSize = CGSize(width: 900, height: 500)
        restrictions.maximumSize = CGSize(width: 10000, height: 10000)
        print("[Catalyst] sizeRestrictions set: min=\(restrictions.minimumSize) max=\(restrictions.maximumSize)")
      } else {
        print("[Catalyst] sizeRestrictions is nil — cannot set minimumSize (system no-ops)")
      }
    #endif

    let window = UIWindow(windowScene: windowScene)
    let contentView = ContentView()
      .environmentObject(InAppPurchaseManager())

    window.rootViewController = UIHostingController(rootView: contentView)
    self.window = window
    window.makeKeyAndVisible()

    #if targetEnvironment(macCatalyst)
      enforceCatalystMinSize()
      DispatchQueue.main.async { [weak self] in self?.enforceCatalystMinSize() }
    #endif
  }

  func sceneDidDisconnect(_: UIScene) {}

  func sceneDidBecomeActive(_ scene: UIScene) {
    #if targetEnvironment(macCatalyst)
      let minSize = CGSize(width: 900, height: 500)
      let maxSize = CGSize(width: 10000, height: 10000)
      // Keep sizeRestrictions in sync (harmless belt-and-braces).
      var didLogRestrictions = false
      func applyRestrictions(to ws: UIWindowScene?) {
        guard let r = ws?.sizeRestrictions else {
          if !didLogRestrictions {
            print("[Catalyst] sceneDidBecomeActive: sizeRestrictions is nil — no-op")
            didLogRestrictions = true
          }
          return
        }
        r.minimumSize = minSize
        r.maximumSize = maxSize
        if !didLogRestrictions {
          print("[Catalyst] sceneDidBecomeActive: sizeRestrictions refreshed min=\(r.minimumSize) max=\(r.maximumSize)")
          didLogRestrictions = true
        }
      }
      applyRestrictions(to: window?.windowScene)
      if window?.windowScene == nil {
        applyRestrictions(to: scene as? UIWindowScene)
      }
      for s in UIApplication.shared.connectedScenes {
        applyRestrictions(to: s as? UIWindowScene)
      }
      enforceCatalystMinSize()
      DispatchQueue.main.async { [weak self] in self?.enforceCatalystMinSize() }
    #endif
  }

  func sceneWillResignActive(_: UIScene) {}

  func sceneWillEnterForeground(_: UIScene) {}

  func sceneDidEnterBackground(_: UIScene) {}
}

#if targetEnvironment(macCatalyst)
  private extension SceneDelegate {
    func enforceCatalystMinSize() {
      guard let nsAppClass = NSClassFromString("NSApplication") as? NSObjectProtocol else { return }
      guard let nsAppValue = nsAppClass.perform(NSSelectorFromString("sharedApplication")) else { return }
      guard let nsApp = nsAppValue.takeUnretainedValue() as? NSObject else { return }
      guard let windowsValue = nsApp.perform(NSSelectorFromString("windows")) else { return }
      guard let candidates = windowsValue.takeUnretainedValue() as? [NSObject], !candidates.isEmpty else { return }

      // Resolve the NSWindow backing this UIWindowScene/UIWindow.
      let uiFrame = window?.frame ?? .zero
      var target: NSObject?

      if uiFrame != .zero {
        for win in candidates {
          guard let frame = _catalystFrame(of: win), frame != .zero else { continue }
          guard win.value(forKey: "contentView") != nil else { continue }
          if abs(frame.width - uiFrame.width) < 4, abs(frame.height - uiFrame.height) < 4 {
            target = win
            break
          }
        }
        if target == nil {
          for win in candidates {
            guard let frame = _catalystFrame(of: win), frame != .zero else { continue }
            guard win.value(forKey: "contentView") != nil else { continue }
            if abs(frame.origin.x - uiFrame.origin.x) < 4, abs(frame.origin.y - uiFrame.origin.y) < 4 {
              target = win
              break
            }
          }
        }
      }

      if target == nil, let keyWin = nsApp.value(forKey: "keyWindow") as? NSObject,
         _catalystFrame(of: keyWin) != nil, _catalystFrame(of: keyWin) != .zero,
         keyWin.value(forKey: "contentView") != nil
      {
        target = keyWin
      }

      if target == nil {
        target = candidates.first(where: {
          guard let f = _catalystFrame(of: $0), f != .zero else { return false }
          return $0.value(forKey: "contentView") != nil
        })
      }

      guard let win = target else { return }

      // Enforce minimum via KVC (Foundation auto-unboxes NSValue for typed setters).
      var minSize = CGSize(width: 900, height: 500)
      let minValue = NSValue(bytes: &minSize, objCType: "{CGSize=dd}")
      win.setValue(minValue, forKey: "contentMinSize")
      win.setValue(minValue, forKey: "minSize")

      // Retro-clamp restored sub-minimum frame (e.g. 693×768) — expands right/up,
      // nudging only if the enlarged frame would overflow the screen.
      guard let frame = _catalystFrame(of: win) else { return }
      guard frame.width < 900 || frame.height < 500 else { return }
      let newWidth = max(frame.width, 900)
      let newHeight = max(frame.height, 500)
      var newFrame = CGRect(x: frame.origin.x, y: frame.origin.y, width: newWidth, height: newHeight)

      // Keep on screen — prefer AppKit visibleFrame via runtime, fallback to UIKit bounds.
      var screenFrame: CGRect?
      if let screen = win.value(forKey: "screen") as? NSObject {
        if let vf = screen.value(forKey: "visibleFrame") as? NSValue {
          screenFrame = vf.cgRectValue
        } else if let vfRect = screen.value(forKey: "visibleFrame") as? CGRect {
          screenFrame = vfRect
        }
      }
      if screenFrame == nil {
        screenFrame = window?.windowScene?.screen.bounds ?? window?.screen.bounds ?? UIScreen.main.bounds
      }
      if let sf = screenFrame, sf != .zero {
        if newFrame.maxX > sf.maxX {
          newFrame.origin.x = max(sf.minX, sf.maxX - newFrame.width - 16)
        }
        if newFrame.maxY > sf.maxY {
          newFrame.origin.y = max(sf.minY, sf.maxY - newFrame.height - 16)
        }
        if newFrame.minX < sf.minX { newFrame.origin.x = sf.minX + 16 }
        if newFrame.minY < sf.minY { newFrame.origin.y = sf.minY + 16 }
      }

      var rect = newFrame
      let rectValue = NSValue(bytes: &rect, objCType: "{CGRect={CGPoint=dd}{CGSize=dd}}")
      win.setValue(rectValue, forKey: "frame")
    }

    func _catalystFrame(of win: NSObject) -> CGRect? {
      // KVC auto-unboxes NSValue → CGRect on some OS versions; handle both.
      if let rect = win.value(forKey: "frame") as? CGRect { return rect }
      if let value = win.value(forKey: "frame") as? NSValue { return value.cgRectValue }
      // Fallback via perform(selector:)
      if let val = win.perform(NSSelectorFromString("frame"))?.takeUnretainedValue() as? NSValue {
        return val.cgRectValue
      }
      if let rect = win.perform(NSSelectorFromString("frame"))?.takeUnretainedValue() as? CGRect {
        return rect
      }
      return nil
    }
  }
#endif
