//
//  CarPlaySceneDelegate.swift
//  flo
//

import UIKit

#if canImport(CarPlay)
  import CarPlay

  class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
    private var coordinator: CarPlayCoordinator?

    func templateApplicationScene(
      _: CPTemplateApplicationScene,
      didConnect interfaceController: CPInterfaceController
    ) {
      coordinator = CarPlayCoordinator(interfaceController: interfaceController)
      coordinator?.start()
    }

    func templateApplicationScene(
      _: CPTemplateApplicationScene,
      didDisconnectInterfaceController _: CPInterfaceController
    ) {
      coordinator?.stop()
      coordinator = nil
    }
  }
#endif
