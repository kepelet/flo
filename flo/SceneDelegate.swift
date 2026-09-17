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
    fileprivate struct CatalystResizeState {
      var didBindMinSize = false
      var isApplyingClamp = false
      var lastClampedFrame: CGRect?
      var consecutiveClampAttempts = 0
    }

    fileprivate static var catalystResizeObserver: NSObjectProtocol?
    fileprivate static var catalystResizeStates: [ObjectIdentifier: CatalystResizeState] = [:]
    fileprivate static var connectedCatalystScenes = 0
    fileprivate static var didLogResizeClass = false
  #endif

  func scene(
    _ scene: UIScene,
    willConnectTo _: UISceneSession,
    options _: UIScene.ConnectionOptions
  ) {
    guard let windowScene = scene as? UIWindowScene else { return }

    #if targetEnvironment(macCatalyst)
      windowScene.title = "flo"
      if let titlebar = windowScene.titlebar {
        titlebar.titleVisibility = .visible
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

      SceneDelegate.connectedCatalystScenes += 1
      SceneDelegate.installCatalystResizeObserverIfNeeded()
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
      SceneDelegate.connectedCatalystScenes = max(
        0, SceneDelegate.connectedCatalystScenes - 1)
      DispatchQueue.main.async {
        SceneDelegate.pruneCatalystResizeStates()
        SceneDelegate.removeCatalystResizeObserverIfUnused()
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
    static func installCatalystResizeObserverIfNeeded() {
      guard catalystResizeObserver == nil else { return }
      catalystResizeObserver = NotificationCenter.default.addObserver(
        forName: NSNotification.Name("NSWindowDidResizeNotification"),
        object: nil,
        queue: .main
      ) { note in
        guard let win = note.object as? NSObject else { return }
        handleCatalystResize(of: win)
      }
      #if DEBUG
        print("[Catalyst] resize observer registered (global NSWindowDidResizeNotification)")
        fflush(stdout)
      #endif
    }

    static func removeCatalystResizeObserverIfUnused() {
      guard connectedCatalystScenes == 0, let observer = catalystResizeObserver else { return }
      NotificationCenter.default.removeObserver(observer)
      catalystResizeObserver = nil
      catalystResizeStates.removeAll()
      #if DEBUG
        print("[Catalyst] removed resize observer")
        fflush(stdout)
      #endif
    }

    static func handleCatalystResize(of win: NSObject) {
      #if DEBUG
        if !didLogResizeClass {
          didLogResizeClass = true
          print("[Catalyst] resize note object class=\(NSStringFromClass(type(of: win)))")
          fflush(stdout)
        }
      #endif
      // Scope to the app's own windows only. This observer is global
      // (object: nil), so without this guard the 900x500 minimum is forced
      // onto every AppKit window in the process — including NSPopupMenuWindow
      // and popovers — blowing every Menu and context menu up to 900x500
      // (issue #158: menu content stays 112x34 while its window is clamped).
      guard NSStringFromClass(type(of: win)).hasPrefix("UINS") else { return }
      guard win.responds(to: NSSelectorFromString("setContentMinSize:")) else { return }
      guard let frame = catalystFrame(of: win) else { return }

      let windowID = ObjectIdentifier(win)
      var state = catalystResizeStates[windowID] ?? CatalystResizeState()

      if !state.didBindMinSize {
        state.didBindMinSize = true
        var minSize = CGSize(width: 900, height: 500)
        let minValue = NSValue(bytes: &minSize, objCType: "{CGSize=dd}")
        win.setValue(minValue, forKey: "contentMinSize")
        win.setValue(minValue, forKey: "minSize")
        #if DEBUG
          let contentMinSize = win.value(forKey: "contentMinSize")
          let minWindowSize = win.value(forKey: "minSize")
          print("[Catalyst] contentMinSize after set = \(String(describing: contentMinSize)) (expected 900x500) minSize=\(String(describing: minWindowSize))")
          fflush(stdout)
        #endif
      }

      guard frame.width < 900 || frame.height < 500 else {
        state.lastClampedFrame = nil
        state.consecutiveClampAttempts = 0
        catalystResizeStates[windowID] = state
        return
      }
      guard !state.isApplyingClamp else { return }
      guard state.lastClampedFrame != frame else { return }
      guard state.consecutiveClampAttempts < 5 else { return }

      state.isApplyingClamp = true
      catalystResizeStates[windowID] = state
      DispatchQueue.main.async {
        guard var state = catalystResizeStates[windowID] else { return }
        defer {
          state.isApplyingClamp = false
          catalystResizeStates[windowID] = state
        }
        guard let current = catalystFrame(of: win) else { return }
        guard current.width < 900 || current.height < 500 else {
          state.lastClampedFrame = nil
          state.consecutiveClampAttempts = 0
          return
        }

        state.consecutiveClampAttempts += 1
        #if DEBUG
          print("[Catalyst] clamp: \(Int(current.width))x\(Int(current.height)) -> 900x500")
          fflush(stdout)
        #endif
        let newWidth = max(current.width, 900)
        let newHeight = max(current.height, 500)
        var newFrame = CGRect(
          x: current.origin.x, y: current.origin.y, width: newWidth, height: newHeight)

        var screenFrame: CGRect?
        if let screen = win.value(forKey: "screen") as? NSObject {
          if let visibleFrame = screen.value(forKey: "visibleFrame") as? NSValue {
            screenFrame = visibleFrame.cgRectValue
          } else if let visibleFrame = screen.value(forKey: "visibleFrame") as? CGRect {
            screenFrame = visibleFrame
          }
        }
        if screenFrame == nil {
          screenFrame = UIScreen.main.bounds
        }
        if let screenFrame, screenFrame != .zero {
          if newFrame.maxX > screenFrame.maxX {
            newFrame.origin.x = max(
              screenFrame.minX, screenFrame.maxX - newFrame.width - 16)
          }
          if newFrame.maxY > screenFrame.maxY {
            newFrame.origin.y = max(
              screenFrame.minY, screenFrame.maxY - newFrame.height - 16)
          }
          if newFrame.minX < screenFrame.minX { newFrame.origin.x = screenFrame.minX + 16 }
          if newFrame.minY < screenFrame.minY { newFrame.origin.y = screenFrame.minY + 16 }
        }

        state.lastClampedFrame = newFrame
        var rect = newFrame
        let rectValue = NSValue(bytes: &rect, objCType: "{CGRect={CGPoint=dd}{CGSize=dd}}")
        win.setValue(rectValue, forKey: "frame")
        #if DEBUG
          print("[Catalyst] clamp: applied clamped frame \(newFrame)")
          fflush(stdout)
        #endif
      }
    }

    static func pruneCatalystResizeStates() {
      guard connectedCatalystScenes > 0 else {
        catalystResizeStates.removeAll()
        return
      }
      guard let windows = catalystWindows() else { return }
      let activeWindowIDs = Set(windows.map { ObjectIdentifier($0) })
      catalystResizeStates = catalystResizeStates.filter { activeWindowIDs.contains($0.key) }
    }

    static func catalystWindows() -> [NSObject]? {
      guard let nsAppClass = NSClassFromString("NSApplication") as? NSObjectProtocol,
        let nsAppValue = nsAppClass.perform(NSSelectorFromString("sharedApplication")),
        let nsApp = nsAppValue.takeUnretainedValue() as? NSObject,
        let windowsValue = nsApp.perform(NSSelectorFromString("windows"))
      else { return nil }

      let rawWindows = windowsValue.takeUnretainedValue()
      if let windows = rawWindows as? [Any] {
        return windows.compactMap { $0 as? NSObject }
      }
      if let windows = rawWindows as? NSArray {
        return windows.compactMap { $0 as? NSObject }
      }
      return nil
    }

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

    static func catalystFrame(of win: NSObject) -> CGRect? {
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
