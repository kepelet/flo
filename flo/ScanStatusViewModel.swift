//
//  ScanStatusViewModel.swift
//  flo
//
//  Created by rizaldy on 14/06/24.
//

import SwiftUI

class ScanStatusViewModel: ObservableObject {
  @Published var scanStatus: ScanStatusResponse.SubsonicResponse? = nil

  private let scanStatusService = ScanStatusService()

  func checkScanStatus() {
    scanStatusService.getScanStatus { [weak self] result in
      DispatchQueue.main.async {
        switch result {
        case .success(let status):
          self?.scanStatus = status.subsonicResponse
        case .failure(let error):
          print("error>>>", error)
        }
      }
    }
  }
}
