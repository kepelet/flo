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
  var pickerRef: AirPlayPickerRef? = nil

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

/// Active-route indicator for the player bars. Same language as the pad
/// floating player's round icon buttons (e.g. the ellipsis): a soft circle
/// behind the glyph when a route is connected, instead of tinting the
/// system AirPlay glyph itself.
struct AirPlayActiveCircle: View {
  var body: some View {
    Circle()
      .fill(Color.primary.opacity(0.12))
      .frame(width: 32, height: 32)
  }
}
