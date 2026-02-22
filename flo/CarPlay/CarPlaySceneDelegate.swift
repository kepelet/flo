//
//  CarPlaySceneDelegate.swift
//  flo
//

import CarPlay
import UIKit

class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
  private var coordinator: CarPlayCoordinator?

  func templateApplicationScene(
    _ templateApplicationScene: CPTemplateApplicationScene,
    didConnect interfaceController: CPInterfaceController
  ) {
    coordinator = CarPlayCoordinator(interfaceController: interfaceController)
    coordinator?.start()
  }

  func templateApplicationScene(
    _ templateApplicationScene: CPTemplateApplicationScene,
    didDisconnectInterfaceController interfaceController: CPInterfaceController
  ) {
    coordinator?.stop()
    coordinator = nil
  }
}
