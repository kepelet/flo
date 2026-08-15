import CoreData
import Foundation
import UIKit

enum ScrobbleQueueStatus {
  static let pending = "pending"
  static let failed = "failed"
  static let sent = "sent"
}

final class ScrobbleQueueManager: ObservableObject {
  static let shared = ScrobbleQueueManager()

  @Published private(set) var scrobbles: [ScrobbleEntity] = []
  @Published private(set) var isFlushing = false

  private init() {
    NotificationCenter.default.addObserver(
      self, selector: #selector(handleNetworkBecameOnline), name: .networkBecameOnline, object: nil)
    NotificationCenter.default.addObserver(
      self, selector: #selector(handleAppBecameActive),
      name: UIApplication.didBecomeActiveNotification, object: nil)

    purgeSent()
    reload()

    if UIApplication.shared.applicationState == .active {
      flush()
    }
  }

  var pendingCount: Int {
    scrobbles.filter { $0.status != ScrobbleQueueStatus.sent }.count
  }

  var sentCount: Int {
    scrobbles.filter { $0.status == ScrobbleQueueStatus.sent }.count
  }

  func enqueue(nowPlaying: QueueEntity) {
    guard let songId = nowPlaying.id, !songId.isEmpty else { return }

    let entry = ScrobbleEntity(context: CoreDataManager.shared.viewContext)

    entry.songId = songId
    entry.trackName = nowPlaying.songName
    entry.artistName = nowPlaying.artistName
    entry.albumName = nowPlaying.albumName
    entry.listenTime = Date()
    entry.queuedAt = Date()
    entry.status = ScrobbleQueueStatus.pending

    CoreDataManager.shared.saveRecord()
    reload()
  }

  func reload() {
    scrobbles = CoreDataManager.shared.getRecordsByEntity(
      entity: ScrobbleEntity.self,
      sortDescriptors: [NSSortDescriptor(key: "queuedAt", ascending: true)])
  }

  func flush() {
    guard !isFlushing, NetworkMonitor.shared.isOnline else { return }

    let pending = scrobbles.filter { $0.status != ScrobbleQueueStatus.sent }

    guard !pending.isEmpty else { return }

    isFlushing = true

    FloooViewModel.shared.fetchAccountLinkStatus { [weak self] result in
      guard let self = self else { return }

      switch result {
      case .success(true):
        self.submitPending(pending)

      case .success(false):
        pending.forEach { CoreDataManager.shared.viewContext.delete($0) }

        CoreDataManager.shared.saveRecord()

        self.isFlushing = false
        self.reload()

      case .failure:
        self.isFlushing = false
      }
    }
  }

  func remove(_ entry: ScrobbleEntity) {
    CoreDataManager.shared.viewContext.delete(entry)
    CoreDataManager.shared.saveRecord()
    reload()
  }

  func clearSent() {
    let sent = scrobbles.filter { $0.status == ScrobbleQueueStatus.sent }

    guard !sent.isEmpty else { return }

    sent.forEach { CoreDataManager.shared.viewContext.delete($0) }

    CoreDataManager.shared.saveRecord()
    reload()
  }

  private func submitPending(_ entries: [ScrobbleEntity]) {
    guard let entry = entries.first else {
      isFlushing = false
      reload()
      return
    }

    let remaining = Array(entries.dropFirst())

    guard let songId = entry.songId, !songId.isEmpty else {
      CoreDataManager.shared.viewContext.delete(entry)
      CoreDataManager.shared.saveRecord()
      submitPending(remaining)
      return
    }

    FloooService.shared.scrobbleToBuiltinEndpoint(
      submission: true, songId: songId, time: entry.listenTime ?? Date()
    ) { [weak self] result in
      guard let self = self else { return }

      switch result {
      case .success:
        entry.status = ScrobbleQueueStatus.sent
        entry.sentAt = Date()

        CoreDataManager.shared.saveRecord()

        self.submitPending(remaining)

      case .failure:
        entry.status = ScrobbleQueueStatus.failed

        CoreDataManager.shared.saveRecord()

        self.isFlushing = false
        self.reload()
      }
    }
  }

  private func purgeSent() {
    let sent = CoreDataManager.shared.getRecordsByEntity(entity: ScrobbleEntity.self)
      .filter { $0.status == ScrobbleQueueStatus.sent }

    guard !sent.isEmpty else { return }

    sent.forEach { CoreDataManager.shared.viewContext.delete($0) }

    CoreDataManager.shared.saveRecord()
  }

  @objc private func handleNetworkBecameOnline() {
    flush()
  }

  @objc private func handleAppBecameActive() {
    flush()
  }
}
