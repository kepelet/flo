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
  @Published var streamCacheSize: String = "0 MB"

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
        let cacheSize = await StreamCacheManager.shared.calculateCacheSize()

        await MainActor.run {
          self.localDirectorySize = calculateDirectorySize
          self.streamCacheSize = bytesToMBOrGB(cacheSize)
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

  func fetchAccountLinkStatus(completion: @escaping (Result<Bool, Error>) -> Void) {
    return FloooService.shared.getAccountLinkStatuses { result in
      switch result {
      case .success(let status):
        self.isListenBrainzLinked = status.listenBrainz
        self.isLastFmLinked = status.lastFM
        self.isScrobbleAccountStatusChecked = true

        completion(.success(status.listenBrainz || status.lastFM))

      case .failure(let error):
        completion(.failure(error))
      }
    }
  }

  func checkAccountLinkStatus() {
    self.fetchAccountLinkStatus { _ in }
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
    guard let songId = nowPlaying.id, !songId.isEmpty else { return }

    if !NetworkMonitor.shared.isOnline || !NetworkMonitor.shared.isServerReachable {
      if isScrobbleAccountStatusChecked && !(isListenBrainzLinked || isLastFmLinked) {
        return
      }

      if submission {
        ScrobbleQueueManager.shared.enqueue(nowPlaying: nowPlaying)
      }

      return
    }

    if isScrobbleAccountStatusChecked {
      if isListenBrainzLinked || isLastFmLinked {
        sendScrobble(submission: submission, nowPlaying: nowPlaying)
      }
    } else {
      fetchAccountLinkStatus { [weak self] result in
        guard let self = self else { return }

        switch result {
        case .success(true):
          self.sendScrobble(submission: submission, nowPlaying: nowPlaying)

        case .success(false):
          break

        case .failure:
          if submission {
            ScrobbleQueueManager.shared.enqueue(nowPlaying: nowPlaying)
          }
        }
      }
    }
  }

  private func sendScrobble(submission: Bool, nowPlaying: QueueEntity) {
    guard let songId = nowPlaying.id else { return }

    FloooService.shared.scrobbleToBuiltinEndpoint(submission: submission, songId: songId) {
      result in
      switch result {
      case .success:
        break

      case .failure:
        if submission {
          ScrobbleQueueManager.shared.enqueue(nowPlaying: nowPlaying)
        }
      }
    }
  }
}
