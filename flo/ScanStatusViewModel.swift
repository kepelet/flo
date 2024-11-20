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

  @Published var localDirectorySize: String = "0 MB"

  func getLocalStorageInformation() {
    self.downloadedAlbums = ScanStatusService.shared.getDownloadedAlbumsCount()
    self.downloadedSongs = ScanStatusService.shared.getDownloadedSongsCount()

    Task {
      do {
        let calculateDirectorySize = try await LocalFileManager.shared.calculateDirectorySize()

        await MainActor.run {
          self.localDirectorySize = calculateDirectorySize
        }
      } catch {
        print("Error: \(error)")
      }
    }
  }

  func optimizeLocalStorage() {
    LocalFileManager.shared.deleteDownloadedAlbums { result in
      switch result {
      case .success(let shouldProceed):
        if shouldProceed {
          CoreDataManager.shared.clearEverything()
        }

        self.getLocalStorageInformation()

      case .failure(let error):
        print("error in optimizeLocalStorage>>>", error)
      }
    }
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
