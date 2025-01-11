//
//  FloooViewModel.swift
//  flo
//
//  Created by rizaldy on 11/01/25.
//

import SwiftUI

class FloooViewModel: ObservableObject {
  @Published var scanStatus: SubsonicResponse<ScanStatus>? = nil
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
  private var isScrobbleAccountStatusChecked = false

  static let shared = FloooViewModel()

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

  func fetchAccountLinkStatus(completion: @escaping (AccountLinkStatus) -> Void) {
    return FloooService.shared.getAccountLinkStatuses { result in
      switch result {
      case .success(let status):
        self.isListenBrainzLinked = status.listenBrainz
        self.isLastFmLinked = status.lastFM
        self.isScrobbleAccountStatusChecked = true

        completion(status)

      case .failure(let error):
        print("error>>>>", error)
      }
    }
  }

  func checkAccountLinkStatus() {
    self.fetchAccountLinkStatus { status in
      self.isListenBrainzLinked = status.listenBrainz
      self.isLastFmLinked = status.lastFM
    }
  }

  func checkScanStatus() {
    ScanStatusService.shared.getScanStatus { [weak self] result in
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

  func saveListeningHistory(nowPlayingData: QueueEntity) {
    FloooService.shared.saveListeningHistory(payload: nowPlayingData)
  }

  func setNowPlayingToScrobbleServer(nowPlaying: QueueEntity) {
    processScrobble(submission: false, nowPlaying: nowPlaying)
  }

  func scrobble(submission: Bool, nowPlaying: QueueEntity) {
    FloooService.shared.saveListeningHistory(payload: nowPlaying)
    processScrobble(submission: submission, nowPlaying: nowPlaying)
  }

  private func processScrobble(submission: Bool, nowPlaying: QueueEntity) {
    guard let songId = nowPlaying.id else { return }

    if isScrobbleAccountStatusChecked {
      let shouldSubmit = isListenBrainzLinked || isLastFmLinked

      if shouldSubmit {
        sendScrobble(submission: submission, songId: songId)
      }
    } else {
      fetchAccountLinkStatus { status in
        let shouldSubmit = status.listenBrainz || status.lastFM

        if shouldSubmit {
          self.sendScrobble(submission: submission, songId: songId)
        }
      }
    }
  }

  private func sendScrobble(submission: Bool, songId: String) {
    FloooService.shared.scrobbleToBuiltinEndpoint(submission: submission, songId: songId) {
      result in
      // TODO: handle when this fail
      // TODO: also, add "check offline mode" later
    }
  }
}
