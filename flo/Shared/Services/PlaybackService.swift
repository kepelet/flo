//
//  PlaybackService.swift
//  flo
//
//  Created by rizaldy on 28/08/24.
//

import CoreData
import Foundation

class PlaybackService {
  static let shared = PlaybackService()

  func getQueue() -> [QueueEntity] {
    return CoreDataManager.shared.getRecordsByEntity(entity: QueueEntity.self)
  }

  func clearQueue() {
    CoreDataManager.shared.deleteRecords(entity: QueueEntity.self)
  }

  func shuffleQueue(currentIdx: Int) -> [QueueEntity] {
    let queue = getQueue()

    let head = Array(queue[...currentIdx])
    let tail = Array(queue[(currentIdx + 1)...]).shuffled()

    return head + tail
  }

  func addToQueue<T: Playable>(item: T, isFromLocal: Bool = false) -> [QueueEntity] {
    self.clearQueue()

    for song in item.songs {
      let queue = QueueEntity(context: CoreDataManager.shared.viewContext)

      queue.id = song.mediaFileId == "" ? song.id : song.mediaFileId
      queue.albumId = song.albumId
      queue.albumName = item.name
      queue.artistName = song.artist
      queue.bitRate = Int16(song.bitRate)
      queue.sampleRate = Int32(song.sampleRate)
      queue.songName = song.title
      queue.suffix = song.suffix
      queue.isFromLocal = isFromLocal
      queue.duration = song.duration

      CoreDataManager.shared.saveRecord()
    }

    return self.getQueue()
  }
}
