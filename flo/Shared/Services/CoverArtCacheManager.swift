//
//  CoverArtCacheManager.swift
//  flo
//

import Foundation

class CoverArtCacheManager {
  static let shared = CoverArtCacheManager()

  private let fileManager = FileManager.default
  private let cacheDirectory: URL?
  private var inFlightIds: Set<String> = []
  private let syncQueue = DispatchQueue(label: "net.faultables.flo.coverartcache")

  private init() {
    self.cacheDirectory =
      fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first?
      .appendingPathComponent("CoverArtCache")

    if let dir = cacheDirectory, !fileManager.fileExists(atPath: dir.path) {
      try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
    }
  }

  func cachedFilePath(albumId: String) -> String? {
    guard let dir = cacheDirectory else { return nil }
    let file = dir.appendingPathComponent("\(albumId).img")
    guard fileManager.fileExists(atPath: file.path) else { return nil }
    return file.path
  }

  func cacheIfNeeded(albumId: String) {
    guard !albumId.isEmpty else { return }

    var shouldDownload = false
    syncQueue.sync {
      if cachedFilePath(albumId: albumId) == nil && !inFlightIds.contains(albumId) {
        inFlightIds.insert(albumId)
        shouldDownload = true
      }
    }
    guard shouldDownload else { return }

    let params: [String: Any] = ["id": "al-\(albumId)", "size": 300]
    APIManager.shared.SubsonicEndpointDownload(
      endpoint: API.SubsonicEndpoint.coverArt, parameters: params
    ) { [weak self] result in
      guard let self = self else { return }
      switch result {
      case .success(let tempFile):
        if let dir = self.cacheDirectory {
          let target = dir.appendingPathComponent("\(albumId).img")
          try? self.fileManager.removeItem(at: target)
          try? self.fileManager.moveItem(at: tempFile, to: target)
        }
      case .failure:
        break
      }
      self.syncQueue.sync {
        self.inFlightIds.remove(albumId)
      }
    }
  }

  func clearCache() {
    guard let dir = cacheDirectory, fileManager.fileExists(atPath: dir.path) else { return }
    try? fileManager.removeItem(at: dir)
    try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
  }
}
