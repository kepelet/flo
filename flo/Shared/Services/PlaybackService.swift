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
    
  func getQueueAsSongs() -> [Song] {
      let queue = self.getQueue()
      return queue.map {
          return Song(id: $0.id ?? "", title: $0.songName ?? "", albumId: $0.albumId ?? "", albumName: $0.albumName ?? "", artist: $0.artistName ?? "", trackNumber: 0, discNumber: 0, bitRate: Int($0.bitRate), sampleRate: Int($0.sampleRate), suffix: $0.suffix ?? "", duration: $0.duration, mediaFileId: $0.id ?? "")
      }      
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

    
  func setQueue<T: Playable>(item: T, isFromLocal: Bool = false) -> [QueueEntity] {
    self.clearQueue()

    for song in item.songs {
      let queue = QueueEntity(context: CoreDataManager.shared.viewContext)

      queue.id = song.mediaFileId == "" ? song.id : song.mediaFileId
      queue.albumId = song.albumId
        queue.albumName = song.album
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
    
    func setQueueSongs(songs: [Song], isFromLocal: Bool = false) {
      self.clearQueue()

      for song in songs {
        let queue = QueueEntity(context: CoreDataManager.shared.viewContext)

        queue.id = song.mediaFileId == "" ? song.id : song.mediaFileId
        queue.albumId = song.albumId
        queue.albumName = song.album
        queue.artistName = song.artist
        queue.bitRate = Int16(song.bitRate)
        queue.sampleRate = Int32(song.sampleRate)
        queue.songName = song.title
        queue.suffix = song.suffix
        queue.isFromLocal = isFromLocal
        queue.duration = song.duration

        CoreDataManager.shared.saveRecord()
      }
    }

}
