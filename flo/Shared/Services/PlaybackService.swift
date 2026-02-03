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

    let isPlaylist = item is Playlist
    let isPlaylistAlbum =
      (item as? Album).map { album in
        album.artist == "Various Artists" && album.albumArtist == "Various Artists"
          && album.genre.contains(" by ")
      } ?? false

    let isFromPlaylist = isPlaylist || isPlaylistAlbum

    let objects = item.songs.map { song in
      return [
        "id": song.mediaFileId == "" ? song.id : song.mediaFileId,
        "albumId": song.albumId,
        "albumName": song.albumName.isEmpty ? item.name : song.albumName,
        "contextName": item.name,
        "artistName": song.artist,
        "bitRate": song.bitRate,
        "sampleRate": song.sampleRate,
        "songName": song.title,
        "suffix": song.suffix,
        "isFromPlaylist": isFromPlaylist,
        "isFromLocal": isFromLocal,
        "duration": song.duration,
      ] as [String: Any]
    }

    let request = NSBatchInsertRequest(entity: QueueEntity.entity(), objects: objects)
    _ = try? CoreDataManager.shared.viewContext.execute(request)

    return self.getQueue()
  }
}
