//
//  DownloadViewModel.swift
//  flo
//
//  Created by rizaldy on 12/01/25.
//

import Alamofire
import SwiftUI

enum DownloadStatus {
  case idle
  case queued
  case downloading
  case completed
  case failed
  case cancelled
}

struct DownloadItem: Identifiable {
  let id: String
  let album: String
  let title: String
  let song: Song
  var progress: Double = 0
  var status: DownloadStatus = .idle
}

struct DownloadTrackCount: Identifiable {
  let id: String
  let name: String
  var elapsed: Double
  let total: Int
}

class DownloadViewModel: ObservableObject {
  @Published private(set) var downloadItems: [DownloadItem] = []
  @Published private(set) var currentDownloads: Set<String> = []
  @Published var downloadedTrackCount: [DownloadTrackCount] = []

  @Published var downloadWatcher: Bool = true

  private var activeDownloads: [String: DownloadRequest] = [:]

  func isDownloading() -> Bool {
    return downloadItems.filter({ $0.status == .downloading }).count > 0
  }

  func getRemainingDownloadItems() -> Int {
    return downloadItems.count - downloadItems.filter({ $0.status == .completed }).count
  }

  func addItem(_ album: Album, forceAll: Bool = false) {
    let songs = forceAll ? album.songs : album.songs.filter { $0.fileUrl.isEmpty }

    let downloadingAlbum = DownloadTrackCount(id: album.id, name: album.name, elapsed: 0, total: 1)
    downloadedTrackCount.append(downloadingAlbum)

    songs.forEach { song in
      guard !downloadItems.contains(where: { $0.id == song.id }) else {
        retryDownload(song.id)
        return
      }

      let queue = DownloadItem(
        id: song.id, album: album.name, title: "\(song.artist) - \(song.title)", song: song)
      downloadItems.append(queue)
    }

    processQueue()
  }

  func addIndividualItem(album: Album, song: Song) {
    guard !downloadItems.contains(where: { $0.id == song.id }) else { return }

    let queue = DownloadItem(
      id: song.id, album: album.name, title: "\(song.artist) - \(song.title)", song: song)
    downloadItems.append(queue)

    processQueue()
  }

  func processQueue() {
    let maxConcurrentDownloads = ProcessInfo.processInfo.activeProcessorCount / 2

    guard currentDownloads.count < maxConcurrentDownloads else { return }

    let availableSlots = maxConcurrentDownloads - currentDownloads.count

    let pendingDownloads =
      downloadItems
      .enumerated()
      .filter { $0.element.status == .idle || $0.element.status == .queued }
      .prefix(availableSlots)

    for (index, _) in pendingDownloads {
      startDownload(index: index)
    }
  }

  func getDownloadedTrackProgress(albumName: String) -> Double {
    if let index = self.downloadedTrackCount.firstIndex(where: { $0.name == albumName }) {
      return self.downloadedTrackCount[index].elapsed * 10
    } else {
      return .zero
    }
  }

  private func startDownload(index: Int) {
    let item = downloadItems[index]

    guard item.status != .downloading && item.status != .completed else { return }

    currentDownloads.insert(item.id)

    var hasPassedThreshold = false

    let progressUpdate: (Double) -> Void = { progress in
      self.updateItemProgress(itemId: item.id, progress: progress)

      if let index = self.downloadedTrackCount.firstIndex(where: {
        $0.name == item.album && $0.total == 1
      }) {
        self.downloadedTrackCount[index].elapsed = progress / 10
      }

      if progress >= 80.0 && !hasPassedThreshold {
        hasPassedThreshold = true

        Task { @MainActor in
          // TODO: intinya disini klo udah 80%, tambahin si elapsed untuk `item.album`, jadi
          // klo elapsed 8 dan total 10, berarti 80% (i guess)
        }
      }
    }

    self.updateItemStatus(itemId: item.id, status: DownloadStatus.downloading)

    Task(priority: .background) {
      do {
        let downloadRequest = AlbumService.shared.downloadNew(
          artistName: item.song.artist,
          albumName: item.album,
          id: item.id,
          trackNumber: item.song.trackNumber.description,
          title: item.song.title,
          suffix: item.song.suffix,
          progressUpdate: progressUpdate
        ) { [weak self] result in
          Task { @MainActor in
            switch result {
            case .success(let fileURL):

              if fileURL != nil {
                AlbumService.shared.saveDownload(
                  albumId: item.song.albumId,
                  albumName: item.album,
                  song: item.song,
                  status: "Downloaded"
                )
                self?.updateItemStatus(itemId: item.id, status: DownloadStatus.completed)
                self?.currentDownloads.remove(item.id)
                self?.processQueue()
                self?.downloadWatcher = true

                if let index = self?.downloadedTrackCount.firstIndex(where: {
                  $0.name == item.album && $0.total == 1
                }) {
                  self?.downloadedTrackCount.remove(at: index)
                }
              }

            case .failure(let error):
              if let afError = error.asAFError, case .explicitlyCancelled = afError {
                self?.updateItemStatus(itemId: item.id, status: .cancelled)

                if let index = self?.downloadedTrackCount.firstIndex(where: {
                  $0.name == item.album && $0.total == 1
                }) {
                  self?.downloadedTrackCount[index].elapsed = 0
                }
              } else {
                print(error)
                self?.updateItemStatus(itemId: item.id, status: .failed)
              }
            }
          }
        }

        activeDownloads[item.id] = downloadRequest
      }
    }
  }

  func clearCurrentAlbumDownload(albumName: String) {
    let newDownloadItems = downloadItems.filter {
      $0.album != albumName
    }

    downloadItems = newDownloadItems
  }

  func cancelCurrentAlbumDownload(albumName: String) {
    downloadItems
      .filter { $0.album == albumName }
      .forEach { cancelDownload($0.id) }
  }

  func cancelDownload(_ itemId: String) {
    if let request = activeDownloads[itemId] {
      request.cancel()

      if let index = downloadItems.firstIndex(where: { $0.id == itemId }) {
        downloadItems[index].status = .cancelled
        downloadItems[index].progress = .zero

        currentDownloads.remove(itemId)
      }

      activeDownloads.removeValue(forKey: itemId)
      self.processQueue()
    }
  }

  func retryDownload(_ itemId: String) {
    if let index = downloadItems.firstIndex(where: { $0.id == itemId }) {
      downloadItems[index].status = .queued
      self.processQueue()
    }
  }

  func hasDownloadQueue() -> Bool {
    return !downloadItems.isEmpty
  }

  func removeFromQueue(_ itemId: String) {
    let newDownloadItems = downloadItems.filter { $0.id != itemId }

    downloadItems = newDownloadItems
  }

  func retryAllFailedQueue() {
    downloadItems
      .filter { $0.status == .failed }
      .forEach { self.updateItemStatus(itemId: $0.id, status: .queued) }

    processQueue()
  }

  func clearCompletedQueue() {
    let newDownloadItems = downloadItems.filter {
      $0.status != .completed && $0.status != .cancelled
    }

    downloadItems = newDownloadItems
  }

  func downloadedAlbumProgress(album: String) -> Double {
    let albumInQueue =
      downloadItems
      .enumerated()
      .filter { $0.element.album == album }

    let downloadedAlbum = albumInQueue.filter { $0.element.status == .completed }
    let progress = Double(downloadedAlbum.count) / Double(albumInQueue.count)

    return min(max(progress * 100, 0), 100)
  }

  private func updateItemProgress(itemId: String, progress: Double) {
    if let index = downloadItems.firstIndex(where: { $0.id == itemId }) {
      downloadItems[index].progress = progress
    }
  }

  private func updateItemStatus(itemId: String, status: DownloadStatus) {
    if let index = downloadItems.firstIndex(where: { $0.id == itemId }) {
      downloadItems[index].status = status
    }
  }
}
