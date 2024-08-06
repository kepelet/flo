//
//  ScanStatusViewModel.swift
//  flo
//
//  Created by rizaldy on 14/06/24.
//

import SwiftUI

class ScanStatusViewModel: ObservableObject {
  @Published var scanStatus: ScanStatusService.status = nil
  @Published var downloadedAlbums: Int = 0
  @Published var downloadedSongs: Int = 0

  func getLocalStorageInformation() {
    self.downloadedAlbums = ScanStatusService.shared.getDownloadedAlbumsCount()
    self.downloadedSongs = ScanStatusService.shared.getDownloadedSongsCount()
  }

  func optimizeLocalStorage() {
    print("checking all songs")
    print("checking missing songs")
    print("deleting missing songs")
  }

  func checkScanStatus() {
    ScanStatusService.shared.getScanStatus { [weak self] result in
      DispatchQueue.main.async {
        switch result {
        case .success(let status):
          self?.scanStatus = status
        case .failure(let error):
          print("error>>>", error)
        }
      }
    }
  }
}
