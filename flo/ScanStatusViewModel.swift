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

  @Published var stats: Stats?
  @Published var totalPlay: Int = 0

  @Published var isListenBrainzLinked: Bool = false
  @Published var isLastFmLinked: Bool = false

  @Published var userDefaultsItems: [String: Any] = [:]
  @Published var keychainItems: [String: Any] = [:]

  private var isGeneratingStats = false

  func getUserDefaults() {
    userDefaultsItems = UserDefaultsManager.getAll()
    keychainItems = KeychainManager.getAuthCredsAndPasswords()
  }

  // FIXME: i think everything that is related to listening history
  // and stats should live in FloooViewModel
  func getListeningHistory() {
    // TODO: is this ok?
    Task { @MainActor in
      let totalListens = await FloooService.shared.getListeningHistory()

      self.totalPlay = totalListens.count

      guard !isGeneratingStats else { return }
      isGeneratingStats = true

      self.stats = await FloooService.shared.generateStats(totalListens)
    }
  }

  func clearListeningHistory() {
    FloooService.shared.clearListeningHistory()
  }

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

  func checkAccountLinkStatus() {
    FloooService.shared.getAccountLinkStatuses { result in
      switch result {
      case .success(let status):
        self.isListenBrainzLinked = status.listenBrainz
        self.isLastFmLinked = status.lastFM

      case .failure(let error):
        print("error>>>>", error)
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
