//
//  SceneDelegate.swift
//  flo
//

import Darwin
import SwiftUI
import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
  var window: UIWindow?
  #if targetEnvironment(macCatalyst)
    var catalystResizeObserver: Any?
    // One-time flags for the global resize observer.
    fileprivate static var didLogResizeClass = false
    fileprivate static var didBindMinSize = false
    // Guards for the deferred (async) min-size clamp. Setting the window frame
    // synchronously inside NSWindowDidResizeNotification re-enters _setFrameCommon,
    // which posts the notification again → unbounded recursion → main-thread stack
    // overflow (EXC_BAD_ACCESS, "Thread stack size exceeded due to excessive
    // recursion"). The clamp must therefore run on a later runloop tick.
    fileprivate static var isApplyingClamp = false
    fileprivate static var lastClampedFrame: CGRect?
    fileprivate static var consecutiveClampAttempts = 0
  #endif

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

      // Global notification-driven discovery: AppKit NSWindows post notifications to
      // NotificationCenter.default even when not in NSApp.windows.
      if catalystResizeObserver == nil {
        catalystResizeObserver = NotificationCenter.default.addObserver(
          forName: NSNotification.Name("NSWindowDidResizeNotification"),
          object: nil,
          queue: .main
        ) { [weak self] note in
          guard let win = note.object as? NSObject else { return }
          #if DEBUG
            if !SceneDelegate.didLogResizeClass {
              SceneDelegate.didLogResizeClass = true
              print("[Catalyst] resize note object class=\(NSStringFromClass(type(of: win)))")
              fflush(stdout)
            }
          #endif
          guard win.responds(to: NSSelectorFromString("setContentMinSize:")) else { return }
          guard let _ = self?._catalystFrame(of: win) else { return }

          // First time: bind OS-native min so subsequent interactive drags respect it.
          if !SceneDelegate.didBindMinSize {
            SceneDelegate.didBindMinSize = true
            var minSize = CGSize(width: 900, height: 500)
            let minValue = NSValue(bytes: &minSize, objCType: "{CGSize=dd}")
            win.setValue(minValue, forKey: "contentMinSize")
            win.setValue(minValue, forKey: "minSize")
            #if DEBUG
              let rb = win.value(forKey: "contentMinSize")
              let rb2 = win.value(forKey: "minSize")
              print("[Catalyst] contentMinSize after set = \(String(describing: rb)) (expected 900x500) minSize=\(String(describing: rb2))")
              fflush(stdout)
            #endif
          }

          // Every notification: clamp if below minimum.
          //
          // Never resize the window synchronously inside this notification:
          // NSWindow._setFrameCommon posts resize notifications synchronously, so
          // setting "frame" here would immediately re-enter this handler and
          // recurse until the main thread's stack overflows (crash on macOS 26
          // beta: EXC_BAD_ACCESS, thousands of NSPerformVisuallyAtomicChange
          // frames). Defer the clamp to the next runloop tick instead.
          guard let self = self else { return }
          guard let frame = self._catalystFrame(of: win) else { return }
          guard frame.width < 900 || frame.height < 500 else {
            // At/above minimum — reset the clamp bookkeeping.
            SceneDelegate.lastClampedFrame = nil
            SceneDelegate.consecutiveClampAttempts = 0
            return
          }
          guard !SceneDelegate.isApplyingClamp else { return }
          guard SceneDelegate.lastClampedFrame != frame else { return }
          guard SceneDelegate.consecutiveClampAttempts < 5 else {
            // Layout keeps fighting the clamp (e.g. OS beta relayout bug).
            // Give up rather than loop forever on the main runloop.
            return
          }

          SceneDelegate.isApplyingClamp = true
          DispatchQueue.main.async {
            defer { SceneDelegate.isApplyingClamp = false }
            guard let current = self._catalystFrame(of: win) else { return }
            guard current.width < 900 || current.height < 500 else {
              SceneDelegate.consecutiveClampAttempts = 0
              return
            }
            SceneDelegate.consecutiveClampAttempts += 1
            #if DEBUG
              print("[Catalyst] clamp: \(Int(current.width))x\(Int(current.height)) -> 900x500")
              fflush(stdout)
            #endif
            let newWidth = max(current.width, 900)
            let newHeight = max(current.height, 500)
            var newFrame = CGRect(x: current.origin.x, y: current.origin.y, width: newWidth, height: newHeight)

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
              screenFrame =
                self.window?.windowScene?.screen.bounds ?? self.window?.screen.bounds
                ?? UIScreen.main.bounds
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

            SceneDelegate.lastClampedFrame = newFrame
            var rect = newFrame
            let rectValue = NSValue(bytes: &rect, objCType: "{CGRect={CGPoint=dd}{CGSize=dd}}")
            win.setValue(rectValue, forKey: "frame")
            #if DEBUG
              print("[Catalyst] clamp: applied clamped frame \(newFrame)")
              fflush(stdout)
            #endif
          }
        }
        #if DEBUG
          print("[Catalyst] resize observer registered (global NSWindowDidResizeNotification)")
          fflush(stdout)
        #endif
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

  func sceneDidDisconnect(_: UIScene) {
    #if targetEnvironment(macCatalyst)
      if let token = catalystResizeObserver {
        NotificationCenter.default.removeObserver(token)
        catalystResizeObserver = nil
        #if DEBUG
          print("[Catalyst] removed resize observer")
          fflush(stdout)
        #endif
      }
    #endif
  }

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
      // No enumeration, no UIWindow private-key probes (KVC throws NSUndefinedKeyException
      // which Swift cannot catch → Abort trap 6). Keep only sizeRestrictions (already set
      // at call sites) + one short windows diagnostic for continuity.
      guard let nsAppClass = NSClassFromString("NSApplication") as? NSObjectProtocol else {
        #if DEBUG
          print("[Catalyst] enforce: NSApplication class not found")
          fflush(stdout)
        #endif
        return
      }
      guard let nsAppValue = nsAppClass.perform(NSSelectorFromString("sharedApplication")) else {
        #if DEBUG
          print("[Catalyst] enforce: sharedApplication selector failed")
          fflush(stdout)
        #endif
        return
      }
      guard let nsApp = nsAppValue.takeUnretainedValue() as? NSObject else {
        #if DEBUG
          print("[Catalyst] enforce: sharedApplication not NSObject")
          fflush(stdout)
        #endif
        return
      }

      #if DEBUG
        if let windowsValue = nsApp.perform(NSSelectorFromString("windows")) {
          let raw = windowsValue.takeUnretainedValue()
          if let anyArr = raw as? [Any] {
            print("[Catalyst] diag: windows as [Any] count=\(anyArr.count)")
          } else if let nsArr = raw as? NSArray {
            print("[Catalyst] diag: windows as NSArray count=\(nsArr.count)")
          } else {
            print("[Catalyst] diag: windows type=\(String(describing: type(of: raw)))")
          }
          fflush(stdout)
        } else {
          print("[Catalyst] diag: windows perform selector returned nil")
          fflush(stdout)
        }
      #endif
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
