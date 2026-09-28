//
//  AirPlayRoutePicker.swift
//  flo
//
//  Created by rizaldy on 03/02/26.
//

import AVKit
import SwiftUI

/// Holds the live `AVRoutePickerView` so other controls (e.g. the device
/// name label above the progress bar) can open the route picker
/// programmatically — `AVRoutePickerView` exposes no public "show" API,
/// so we forward the tap to its internal button.
final class AirPlayPickerRef: ObservableObject {
  weak var pickerView: AVRoutePickerView?

  func presentPicker() {
    guard let pickerView else { return }
    guard let button = Self.routeButton(in: pickerView) else { return }
    Task { @MainActor in
      button.sendActions(for: .touchUpInside)
    }
  }

  private static func routeButton(in view: UIView) -> UIButton? {
    for subview in view.subviews {
      if let button = subview as? UIButton {
        return button
      }
      if let found = routeButton(in: subview) {
        return found
      }
    }
    return nil
  }
}

struct AirPlayRoutePicker: UIViewRepresentable {
  var tintColor: UIColor = .white
  var activeTintColor: UIColor = .white
  var pickerRef: AirPlayPickerRef?

  func makeUIView(context: Context) -> AVRoutePickerView {
    let view = AVRoutePickerView()

    view.backgroundColor = .clear
    view.prioritizesVideoDevices = false
    view.tintColor = tintColor
    view.activeTintColor = activeTintColor

    pickerRef?.pickerView = view

    return view
  }

  func updateUIView(_ uiView: AVRoutePickerView, context: Context) {
    uiView.tintColor = tintColor
    uiView.activeTintColor = activeTintColor
    if pickerRef?.pickerView == nil {
      pickerRef?.pickerView = uiView
    }
  }
}

/// Small active-route badge for the player bars. Mirrors the queue button's
/// repeat badge (accent dot, top-trailing) so the connected state reads the
/// same everywhere without tinting the system AirPlay glyph.
struct AirPlayActiveBadge: View {
  var body: some View {
    Circle()
      .fill(Color.accentColor)
      .frame(width: 10, height: 10)
      .overlay(
        Circle()
          .stroke(Color.black.opacity(0.45), lineWidth: 1.5)
      )
      .offset(x: 10, y: -10)
  }
}
