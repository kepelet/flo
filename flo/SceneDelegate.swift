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

      // ---------- DEEP DIAGNOSTICS ----------
      #if DEBUG
        // 1) windows via perform("windows") — raw type/Mirror/count/class names
        var rawWindowsAny: Any?
        var rawWindowsCandidates: [NSObject] = []
        if let windowsValue = nsApp.perform(NSSelectorFromString("windows")) {
          let raw = windowsValue.takeUnretainedValue()
          rawWindowsAny = raw
          let mirror = Mirror(reflecting: raw)
          let typeDesc = String(describing: type(of: raw))
          let valueDesc = String(describing: raw)
          print("[Catalyst] diag: windows perform raw type=\(typeDesc) mirror=\(mirror) subjectType=\(mirror.subjectType) children=\(mirror.children.count) describing=\(valueDesc)")
          if let anyArr = raw as? [Any] {
            print("[Catalyst] diag: windows as [Any] count=\(anyArr.count)")
            for (i, elem) in anyArr.prefix(5).enumerated() {
              let cn: String
              if let nsObj = elem as? NSObject {
                cn = NSStringFromClass(type(of: nsObj))
              } else {
                cn = String(describing: type(of: elem))
              }
              let responds = (elem as? NSObject)?.responds(to: NSSelectorFromString("setContentMinSize:")) ?? false
              print("[Catalyst] diag: windows[\(i)] class=\(cn) responds setContentMinSize=\(responds) value=\(String(describing: elem))")
            }
            rawWindowsCandidates = anyArr.compactMap { $0 as? NSObject }
          } else {
            print("[Catalyst] diag: windows as [Any] cast failed")
            if let nsArr = raw as? NSArray {
              print("[Catalyst] diag: windows as NSArray count=\(nsArr.count)")
              for (i, elem) in nsArr.prefix(5).enumerated() {
                let cn = (elem as? NSObject).map { NSStringFromClass(type(of: $0)) } ?? String(describing: type(of: elem))
                let responds = (elem as? NSObject)?.responds(to: NSSelectorFromString("setContentMinSize:")) ?? false
                print("[Catalyst] diag: windows NSArray[\(i)] class=\(cn) responds setContentMinSize=\(responds)")
              }
              rawWindowsCandidates = nsArr.compactMap { $0 as? NSObject }
            } else {
              print("[Catalyst] diag: windows not [Any] nor NSArray; raw is \(String(describing: type(of: raw)))")
            }
          }

          // Also diagnose [NSObject] cast that the old code used
          if let asNSObjectArr = raw as? [NSObject] {
            print("[Catalyst] diag: windows as [NSObject] succeeded count=\(asNSObjectArr.count)")
          } else {
            print("[Catalyst] diag: windows as [NSObject] failed (empty-or-not-[NSObject] branch)")
          }
          fflush(stdout)
        } else {
          print("[Catalyst] diag: windows perform selector returned nil")
          fflush(stdout)
        }
      #endif
      // ---------- END DEEP DIAGNOSTICS (part 1) ----------

      // Now run ordered path diagnostics + candidate collection for enforcement.
      // We repeat the windows perform extraction for enforcement use (DEBUG already did) so both paths share same extraction.
      var orderedCandidates: [(label: String, obj: NSObject)] = []

      // Helper to extract array candidates from Any?
      func candidates(from maybeAny: Any?, label: String) -> [NSObject] {
        guard let v = maybeAny else { return [] }
        if let arr = v as? [NSObject], !arr.isEmpty { return arr }
        if let arr = v as? [Any] {
          let mapped = arr.compactMap { $0 as? NSObject }
          if !mapped.isEmpty { return mapped }
        }
        if let arr = v as? NSArray {
          let mapped = arr.compactMap { $0 as? NSObject }
          if !mapped.isEmpty { return mapped }
        }
        // Single object case (should not happen for windows, but handle)
        if let single = v as? NSObject { return [single] }
        return []
      }

      // Path 1: perform("windows")
      var performWindowsRaw: Any?
      if let v = nsApp.perform(NSSelectorFromString("windows"))?.takeUnretainedValue() {
        performWindowsRaw = v
        let arr = candidates(from: v, label: "perform windows")
        for o in arr { orderedCandidates.append(("perform(windows)", o)) }
      }

      // Path 2: value(forKey: "windows")
      let vfkWindows: Any? = nsApp.value(forKey: "windows")
      #if DEBUG
        if let v = vfkWindows {
          let typeDesc = String(describing: type(of: v))
          let arr = candidates(from: v, label: "vfk windows")
          print("[Catalyst] diag: nsApp.value(forKey:\"windows\") type=\(typeDesc) candidates=\(arr.count) describing=\(String(describing: v).prefix(500))")
          for (i, o) in arr.prefix(3).enumerated() {
            let cn = NSStringFromClass(type(of: o))
            let resp = o.responds(to: NSSelectorFromString("setContentMinSize:"))
            print("[Catalyst] diag: vfk windows[\(i)] class=\(cn) responds=\(resp) isWindowLike=\(cn.contains("Window"))")
          }
          if arr.isEmpty {
            // Maybe it's a single object that isn't array, print class
            if let single = v as? NSObject {
              let cn = NSStringFromClass(type(of: single))
              print("[Catalyst] diag: vfk windows single object class=\(cn) contains Window=\(cn.contains("Window"))")
            } else {
              print("[Catalyst] diag: vfk windows no candidates, Mirror=\(Mirror(reflecting: v))")
            }
          }
          fflush(stdout)
        } else {
          print("[Catalyst] diag: nsApp.value(forKey:\"windows\") -> nil")
          fflush(stdout)
        }
      #endif
      if let v = vfkWindows {
        let arr = candidates(from: v, label: "value windows")
        for o in arr where !orderedCandidates.contains(where: { $0.obj === o }) {
          orderedCandidates.append(("value(windows)", o))
        }
        // If v was single NSObject but not array, candidates handles it; above covers.
      }

      // Path 3: perform("keyWindow")
      var keyWindowViaPerform: NSObject?
      if let v = nsApp.perform(NSSelectorFromString("keyWindow"))?.takeUnretainedValue() as? NSObject {
        keyWindowViaPerform = v
        orderedCandidates.append(("perform(keyWindow)", v))
      }
      #if DEBUG
        if let o = keyWindowViaPerform {
          let cn = NSStringFromClass(type(of: o))
          let resp = o.responds(to: NSSelectorFromString("setContentMinSize:"))
          print("[Catalyst] diag: nsApp.perform(keyWindow) -> class=\(cn) responds setContentMinSize=\(resp) containsWindow=\(cn.contains("Window")) frame=\(String(describing: _catalystFrame(of: o)))")
        } else {
          print("[Catalyst] diag: nsApp.perform(keyWindow) -> nil")
        }
        fflush(stdout)
      #endif

      // Path 4: value(forKey: "keyWindow")
      var keyWindowViaKVC: NSObject?
      if let v = nsApp.value(forKey: "keyWindow") as? NSObject {
        keyWindowViaKVC = v
        if !orderedCandidates.contains(where: { $0.obj === v }) {
          orderedCandidates.append(("value(keyWindow)", v))
        }
      }
      #if DEBUG
        if let o = keyWindowViaKVC {
          let cn = NSStringFromClass(type(of: o))
          let resp = o.responds(to: NSSelectorFromString("setContentMinSize:"))
          print("[Catalyst] diag: nsApp.value(forKey:\"keyWindow\") -> class=\(cn) responds=\(resp) containsWindow=\(cn.contains("Window")) frame=\(String(describing: _catalystFrame(of: o)))")
        } else {
          print("[Catalyst] diag: nsApp.value(forKey:\"keyWindow\") -> nil")
        }
        fflush(stdout)
      #endif

      // Path 5: perform("mainWindow")
      var mainWindowViaPerform: NSObject?
      if let v = nsApp.perform(NSSelectorFromString("mainWindow"))?.takeUnretainedValue() as? NSObject {
        mainWindowViaPerform = v
        if !orderedCandidates.contains(where: { $0.obj === v }) {
          orderedCandidates.append(("perform(mainWindow)", v))
        }
      }
      #if DEBUG
        if let o = mainWindowViaPerform {
          let cn = NSStringFromClass(type(of: o))
          let resp = o.responds(to: NSSelectorFromString("setContentMinSize:"))
          print("[Catalyst] diag: nsApp.perform(mainWindow) -> class=\(cn) responds=\(resp) containsWindow=\(cn.contains("Window")) frame=\(String(describing: _catalystFrame(of: o)))")
        } else {
          print("[Catalyst] diag: nsApp.perform(mainWindow) -> nil")
        }
        fflush(stdout)
      #endif

      // Path 5b: value(forKey: "mainWindow") — not required but useful for completeness; still diagnosed
      #if DEBUG
        if let v = nsApp.value(forKey: "mainWindow") as? NSObject {
          let cn = NSStringFromClass(type(of: v))
          print("[Catalyst] diag: nsApp.value(forKey:\"mainWindow\") -> class=\(cn) containsWindow=\(cn.contains("Window"))")
        } else {
          print("[Catalyst] diag: nsApp.value(forKey:\"mainWindow\") -> nil")
        }
        fflush(stdout)
      #endif

      // UIWindow-side paths
      let uiWindow = window

      func diagUIWindowPath(label: String, obj: NSObject?) {
        #if DEBUG
          if let o = obj {
            let cn = NSStringFromClass(type(of: o))
            let resp = o.responds(to: NSSelectorFromString("setContentMinSize:"))
            print("[Catalyst] diag: window \(label) -> class=\(cn) containsWindow=\(cn.contains("Window")) responds setContentMinSize=\(resp) frame=\(String(describing: _catalystFrame(of: o)))")
          } else {
            print("[Catalyst] diag: window \(label) -> nil")
          }
          fflush(stdout)
        #endif
      }

      var hostViaNsWindow: NSObject?
      if let v = uiWindow?.value(forKey: "_nsWindow") as? NSObject {
        hostViaNsWindow = v
        orderedCandidates.append(("_nsWindow", v))
      }
      diagUIWindowPath(label: "value(forKey:\"_nsWindow\")", obj: hostViaNsWindow)

      var hostViaNsWindow2: NSObject?
      if let v = uiWindow?.value(forKey: "nsWindow") as? NSObject {
        hostViaNsWindow2 = v
        if !orderedCandidates.contains(where: { $0.obj === v }) {
          orderedCandidates.append(("nsWindow", v))
        }
      }
      diagUIWindowPath(label: "value(forKey:\"nsWindow\")", obj: hostViaNsWindow2)

      var hostViaProxy: NSObject?
      if let v = uiWindow?.value(forKey: "windowProxy") as? NSObject {
        hostViaProxy = v
        if !orderedCandidates.contains(where: { $0.obj === v }) {
          orderedCandidates.append(("windowProxy", v))
        }
      }
      diagUIWindowPath(label: "value(forKey:\"windowProxy\")", obj: hostViaProxy)

      var hostViaHostWindow: NSObject?
      if let raw = uiWindow?.perform(NSSelectorFromString("_hostWindow"))?.takeUnretainedValue() as? NSObject {
        hostViaHostWindow = raw
        if !orderedCandidates.contains(where: { $0.obj === raw }) {
          orderedCandidates.append(("_hostWindow", raw))
        }
      }
      diagUIWindowPath(label: "perform(_hostWindow)", obj: hostViaHostWindow)

      // Summary diagnostics for all candidates
      #if DEBUG
        print("[Catalyst] diag: summary candidates=\(orderedCandidates.count)")
        for (i, entry) in orderedCandidates.enumerated() {
          let cn = NSStringFromClass(type(of: entry.obj))
          let resp = entry.obj.responds(to: NSSelectorFromString("setContentMinSize:"))
          let frame = String(describing: _catalystFrame(of: entry.obj))
          let hasCV = entry.obj.value(forKey: "contentView") != nil
          print("[Catalyst] diag: candidate[\(i)] source=\(entry.label) class=\(cn) containsWindow=\(cn.contains("Window")) responds=\(resp) hasContentView=\(hasCV) frame=\(frame)")
        }
        // Also print performWindowsRaw Mirror again for completeness if not already
        if let raw = performWindowsRaw {
          print("[Catalyst] diag: performWindowsRaw Mirror children=\(Mirror(reflecting: raw).children.count) type=\(String(describing: type(of: raw)))")
        }
        fflush(stdout)
      #endif

      // ---------- SELECT TARGET ----------
      // Prefer candidates whose class name contains "Window" and that respond to setContentMinSize:
      // Then candidates whose class contains "Window", then any candidate.
      let uiFrame = window?.frame ?? .zero
      #if DEBUG
        print("[Catalyst] enforce: uiFrame=\(uiFrame) candidates=\(orderedCandidates.count)")
        fflush(stdout)
      #endif

      var target: NSObject?
      var targetSource: String = ""

      // First, try frame-correlated matching among window-like candidates (preserve old behavior but across expanded set)
      let windowLikeCandidates = orderedCandidates.filter { NSStringFromClass(type(of: $0.obj)).contains("Window") }

      if uiFrame != .zero {
        for entry in windowLikeCandidates {
          let win = entry.obj
          guard let frame = _catalystFrame(of: win), frame != .zero else { continue }
          guard win.value(forKey: "contentView") != nil || win.responds(to: NSSelectorFromString("setContentMinSize:")) else { continue }
          if abs(frame.width - uiFrame.width) < 4, abs(frame.height - uiFrame.height) < 4 {
            target = win
            targetSource = entry.label + " (frame-size match)"
            break
          }
        }
        if target == nil {
          for entry in windowLikeCandidates {
            let win = entry.obj
            guard let frame = _catalystFrame(of: win), frame != .zero else { continue }
            guard win.value(forKey: "contentView") != nil || win.responds(to: NSSelectorFromString("setContentMinSize:")) else { continue }
            if abs(frame.origin.x - uiFrame.origin.x) < 4, abs(frame.origin.y - uiFrame.origin.y) < 4 {
              target = win
              targetSource = entry.label + " (origin match)"
              break
            }
          }
        }
      }

      // Preferred selector: Window + responds
      if target == nil {
        if let found = orderedCandidates.first(where: {
          let cn = NSStringFromClass(type(of: $0.obj))
          return cn.contains("Window") && $0.obj.responds(to: NSSelectorFromString("setContentMinSize:"))
        }) {
          target = found.obj
          targetSource = found.label + " (preferred Window+responds)"
        }
      }
      // Fallback: any Window
      if target == nil {
        if let found = orderedCandidates.first(where: { NSStringFromClass(type(of: $0.obj)).contains("Window") }) {
          target = found.obj
          targetSource = found.label + " (fallback Window)"
        }
      }
      // Fallback: any candidate that responds
      if target == nil {
        if let found = orderedCandidates.first(where: { $0.obj.responds(to: NSSelectorFromString("setContentMinSize:")) }) {
          target = found.obj
          targetSource = found.label + " (fallback responds)"
        }
      }
      // Last resort: first candidate at all
      if target == nil {
        if let first = orderedCandidates.first {
          target = first.obj
          targetSource = first.label + " (last resort first candidate)"
        }
      }

      guard let win = target else {
        #if DEBUG
          print("[Catalyst] enforce: no target matched — uiFrame=\(uiFrame) candidates=\(orderedCandidates.count)")
          // Already printed candidate diagnostics above; add extra context
          var keyWindowDesc = "nil"
          if let kw = nsApp.value(forKey: "keyWindow") as? NSObject {
            keyWindowDesc = NSStringFromClass(type(of: kw))
          }
          print("[Catalyst] enforce: still no window — keyWindow class=\(keyWindowDesc) performWindowsRawIsNil=\(performWindowsRaw == nil)")
          fflush(stdout)
        #endif
        return
      }

      #if DEBUG
        let winClass = NSStringFromClass(type(of: win))
        print("[Catalyst] enforce: matched target source=\(targetSource) class=\(winClass) frame=\(String(describing: _catalystFrame(of: win))) uiFrame=\(uiFrame) responds setContentMinSize=\(win.responds(to: NSSelectorFromString("setContentMinSize:")))")
        fflush(stdout)
      #endif

      // Enforce minimum via KVC (Foundation auto-unboxes NSValue for typed setters).
      var minSize = CGSize(width: 900, height: 500)
      let minValue = NSValue(bytes: &minSize, objCType: "{CGSize=dd}")
      if win.responds(to: NSSelectorFromString("setContentMinSize:")) {
        win.setValue(minValue, forKey: "contentMinSize")
      } else {
        // Still try KVC; may succeed even if responds check is flaky
        win.setValue(minValue, forKey: "contentMinSize")
      }
      // Also try minSize (some windows use this)
      if win.responds(to: NSSelectorFromString("setMinSize:")) {
        win.setValue(minValue, forKey: "minSize")
      } else {
        // Try anyway; KVC will no-op if not present
        // Use try? pattern via value check
        if win.value(forKey: "minSize") != nil || win.responds(to: NSSelectorFromString("setContentMinSize:")) {
          win.setValue(minValue, forKey: "minSize")
        }
      }

      #if DEBUG
        if let rb = win.value(forKey: "contentMinSize") {
          print("[Catalyst] enforce: contentMinSize after set = \(rb) (expected 900x500)")
        } else {
          print("[Catalyst] enforce: contentMinSize after set = nil (KVC readback failed)")
        }
        if let rb2 = win.value(forKey: "minSize") {
          print("[Catalyst] enforce: minSize after set = \(rb2)")
        } else {
          print("[Catalyst] enforce: minSize after set = nil")
        }
        fflush(stdout)
      #endif

      // Register resize observer to clamp EVERY resize below minimum (drag, AX, restore).
      if catalystResizeObserver == nil {
        catalystResizeObserver = NotificationCenter.default.addObserver(
          forName: NSNotification.Name("NSWindowDidResizeNotification"),
          object: win,
          queue: .main
        ) { [weak self] _ in
          guard let self else { return }
          guard let frame = self._catalystFrame(of: win) else { return }
          guard frame.width < 900 || frame.height < 500 else { return }
          #if DEBUG
            print("[Catalyst] clamp: window resized below minimum frame=\(frame) — clamping to 900x500")
            fflush(stdout)
          #endif
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
            screenFrame = self.window?.windowScene?.screen.bounds ?? self.window?.screen.bounds ?? UIScreen.main.bounds
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
          #if DEBUG
            print("[Catalyst] clamp: applied clamped frame \(newFrame)")
            fflush(stdout)
          #endif
        }
        #if DEBUG
          print("[Catalyst] enforce: resize observer registered for window class=\(NSStringFromClass(type(of: win))) source=\(targetSource) frame=\(String(describing: _catalystFrame(of: win)))")
          fflush(stdout)
        #endif
      } else {
        #if DEBUG
          print("[Catalyst] enforce: resize observer already registered — skip (target class=\(NSStringFromClass(type(of: win))) source=\(targetSource))")
          fflush(stdout)
        #endif
      }

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
      #if DEBUG
        print("[Catalyst] enforce: retro-clamped frame from \(frame) to \(newFrame)")
        fflush(stdout)
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
