//
//  StreamCacheManager.swift
//  flo
//

import Alamofire
import CoreData
import Foundation

class StreamCacheManager {
  static let shared = StreamCacheManager()

  private let fileManager = FileManager.default
  private let cacheDirectory: URL?
  private let syncQueue = DispatchQueue(label: "net.faultables.flo.streamcache")
  private var inFlightDownloads: [String: DownloadRequest] = [:]
  private var inFlightProgress: [String: Double] = [:]
  private var inFlightKeys: Set<String> = []
  private var currentlyPlayingSongId: String?

  private init() {
    self.cacheDirectory =
      fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first?
      .appendingPathComponent("StreamCache")

    if let dir = cacheDirectory, !fileManager.fileExists(atPath: dir.path) {
      try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
    }
  }

  // MARK: - Public API

  func cachedFileURL(mediaFileId: String) -> URL? {
    let bitrate = UserDefaultsManager.maxBitRate
    let key = cacheKey(mediaFileId: mediaFileId, bitrate: bitrate)

    guard
      let record = CoreDataManager.shared.getRecordByKey(
        entity: CacheEntity.self, key: \CacheEntity.cacheKey, value: key, limit: 1
      ).first,
      record.state == "ready",
      let filePath = record.filePath,
      let dir = cacheDirectory
    else { return nil }

    let fileURL = dir.appendingPathComponent(filePath)
    guard fileManager.fileExists(atPath: fileURL.path) else {
      CoreDataManager.shared.deleteRecordByKey(
        entity: CacheEntity.self, key: \CacheEntity.cacheKey, value: key)
      return nil
    }

    record.lastAccessedAt = Date()
    CoreDataManager.shared.saveRecord()

    return fileURL
  }

  func cacheSong(mediaFileId: String, originalSuffix: String? = nil) {
    guard UserDefaultsManager.streamCacheMaxSize > 0 else { return }
    guard !mediaFileId.isEmpty else { return }

    let bitrate = UserDefaultsManager.maxBitRate
    let key = cacheKey(mediaFileId: mediaFileId, bitrate: bitrate)

    // Register in-flight atomically — prevents duplicate downloads
    let didRegister: Bool = syncQueue.sync {
      guard !inFlightKeys.contains(key) else { return false }
      inFlightKeys.insert(key)
      return true
    }
    guard didRegister else { return }

    // Already cached?
    let existing = CoreDataManager.shared.getRecordByKey(
      entity: CacheEntity.self, key: \CacheEntity.cacheKey, value: key, limit: 1)
    if !existing.isEmpty {
      syncQueue.async { self.inFlightKeys.remove(key) }
      return
    }

    let format =
      bitrate == TranscodingSettings.sourceBitRate
      ? TranscodingSettings.sourceFormat : TranscodingSettings.targetFormat
    let suffix = format == "raw" ? (originalSuffix ?? "raw") : format

    // Create CacheEntity with downloading state
    let entity = CacheEntity(context: CoreDataManager.shared.viewContext)
    entity.cacheKey = key
    entity.mediaFileId = mediaFileId
    entity.filePath = "\(key).\(suffix)"
    entity.suffix = suffix
    entity.state = "downloading"
    entity.cachedAt = Date()
    entity.lastAccessedAt = Date()
    entity.fileSize = 0
    CoreDataManager.shared.saveRecord()

    let params: [String: Any] = [
      "id": mediaFileId,
      "maxBitRate": bitrate,
      "format": format,
    ]

    let progressUpdate: (Double) -> Void = { [weak self] progress in
      self?.syncQueue.async { self?.inFlightProgress[key] = progress / 100.0 }
    }

    let request = APIManager.shared.SubsonicEndpointDownloadNew(
      endpoint: API.SubsonicEndpoint.stream, parameters: params, progressUpdate: progressUpdate
    ) { [weak self] result in
      guard let self = self else { return }

      self.syncQueue.async {
        self.inFlightDownloads.removeValue(forKey: key)
        self.inFlightProgress.removeValue(forKey: key)
        self.inFlightKeys.remove(key)
      }

      switch result {
      case .success(let tempFile):
        guard let dir = self.cacheDirectory else {
          self.removeCacheRecord(key: key)
          return
        }

        let target = dir.appendingPathComponent("\(key).\(suffix)")

        LocalFileManager.shared.moveFile(source: tempFile, target: target) { moveResult in
          switch moveResult {
          case .success:
            let fileSize =
              (try? self.fileManager.attributesOfItem(atPath: target.path)[.size] as? Int64) ?? 0

            let records = CoreDataManager.shared.getRecordByKey(
              entity: CacheEntity.self, key: \CacheEntity.cacheKey, value: key, limit: 1)
            if let record = records.first {
              record.state = "ready"
              record.fileSize = fileSize
              CoreDataManager.shared.saveRecord()
            }

            self.evictIfNeeded()

          case .failure:
            self.removeCacheRecord(key: key)
          }
        }

      case .failure(let error):
        if let afError = error.asAFError, case .explicitlyCancelled = afError {
          // Cancelled — clean up
        }
        self.removeCacheRecord(key: key)
      }
    }

    syncQueue.sync { self.inFlightDownloads[key] = request }
  }

  func setCurrentlyPlaying(mediaFileId: String) {
    syncQueue.async { self.currentlyPlayingSongId = mediaFileId }
  }

  func cancelAllInFlight() {
    let keysToClean: [String] = syncQueue.sync {
      let keys = Array(inFlightDownloads.keys)
      for (_, request) in inFlightDownloads {
        request.cancel()
      }
      inFlightDownloads.removeAll()
      inFlightProgress.removeAll()
      inFlightKeys.removeAll()
      return keys
    }

    for key in keysToClean {
      removeCacheRecord(key: key)
    }
  }

  func clearCache() {
    // Cancel all downloads
    syncQueue.sync {
      for (_, request) in inFlightDownloads { request.cancel() }
      inFlightDownloads.removeAll()
      inFlightProgress.removeAll()
      inFlightKeys.removeAll()
    }

    // Delete all files
    if let dir = cacheDirectory, fileManager.fileExists(atPath: dir.path) {
      try? fileManager.removeItem(at: dir)
      try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    // Delete all CacheEntity records
    let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "CacheEntity")
    let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
    try? CoreDataManager.shared.viewContext.execute(deleteRequest)
    try? CoreDataManager.shared.viewContext.save()
  }

  func calculateCacheSize() async -> Int64 {
    return await MainActor.run {
      let records = CoreDataManager.shared.getRecordsByEntity(entity: CacheEntity.self)
      return records.filter { $0.state == "ready" }.reduce(0) { $0 + $1.fileSize }
    }
  }

  func reconcile() {
    // Cancel any active downloads first to prevent races
    syncQueue.sync {
      for (_, request) in inFlightDownloads { request.cancel() }
      inFlightDownloads.removeAll()
      inFlightProgress.removeAll()
      inFlightKeys.removeAll()
    }

    let records = CoreDataManager.shared.getRecordsByEntity(entity: CacheEntity.self)

    for record in records {
      if record.state == "downloading" {
        if let filePath = record.filePath, let dir = cacheDirectory {
          let fileURL = dir.appendingPathComponent(filePath)
          try? fileManager.removeItem(at: fileURL)
        }
        CoreDataManager.shared.viewContext.delete(record)
        continue
      }

      if let filePath = record.filePath, let dir = cacheDirectory {
        let fileURL = dir.appendingPathComponent(filePath)
        if !fileManager.fileExists(atPath: fileURL.path) {
          CoreDataManager.shared.viewContext.delete(record)
        }
      } else {
        CoreDataManager.shared.viewContext.delete(record)
      }
    }

    CoreDataManager.shared.saveRecord()

    // Re-fetch surviving records for orphan file cleanup
    let survivingRecords = CoreDataManager.shared.getRecordsByEntity(entity: CacheEntity.self)
    let knownFiles = Set(survivingRecords.compactMap { $0.filePath })

    if let dir = cacheDirectory,
      let files = try? fileManager.contentsOfDirectory(
        at: dir, includingPropertiesForKeys: nil)
    {
      for file in files {
        if !knownFiles.contains(file.lastPathComponent) {
          try? fileManager.removeItem(at: file)
        }
      }
    }
  }

  // MARK: - Private

  private func cacheKey(mediaFileId: String, bitrate: String) -> String {
    return "\(mediaFileId)_\(bitrate)"
  }

  private func removeCacheRecord(key: String) {
    CoreDataManager.shared.deleteRecordByKey(
      entity: CacheEntity.self, key: \CacheEntity.cacheKey, value: key)
  }

  private func evictIfNeeded() {
    let maxSize = UserDefaultsManager.streamCacheMaxSize
    guard maxSize > 0 else { return }

    let sortDescriptor = NSSortDescriptor(key: "lastAccessedAt", ascending: true)
    let records = CoreDataManager.shared.getRecordsByEntity(
      entity: CacheEntity.self, sortDescriptors: [sortDescriptor])

    let totalSize = records.filter { $0.state == "ready" }.reduce(Int64(0)) { $0 + $1.fileSize }
    guard totalSize > maxSize else { return }

    var currentSize = totalSize
    let currentlyPlaying: String? = syncQueue.sync { currentlyPlayingSongId }

    for record in records where record.state == "ready" {
      guard currentSize > maxSize else { break }

      if let playing = currentlyPlaying, record.mediaFileId == playing { continue }

      let size = record.fileSize

      if let filePath = record.filePath, let dir = cacheDirectory {
        let fileURL = dir.appendingPathComponent(filePath)
        try? fileManager.removeItem(at: fileURL)
      }

      CoreDataManager.shared.viewContext.delete(record)
      currentSize -= size
    }

    CoreDataManager.shared.saveRecord()
  }
}
