//
//  AirPlayRoutePicker.swift
//  flo
//
//  Created by rizaldy on 03/02/26.
//

import AVKit
import SwiftUI

struct AirPlayRoutePicker: UIViewRepresentable {
  var tintColor: UIColor = .white
  var activeTintColor: UIColor = .white

  func makeUIView(context: Context) -> AVRoutePickerView {
    let view = AVRoutePickerView()

    view.backgroundColor = .clear
    view.prioritizesVideoDevices = false
    view.tintColor = tintColor
    view.activeTintColor = activeTintColor

    return view
  }

  func updateUIView(_ uiView: AVRoutePickerView, context: Context) {
    uiView.tintColor = tintColor
    uiView.activeTintColor = activeTintColor
  }
}
