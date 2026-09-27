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

  private static let positionSort = [NSSortDescriptor(key: "position", ascending: true)]

  func getQueue() -> [QueueEntity] {
    return CoreDataManager.shared.getRecordsByEntity(
      entity: QueueEntity.self, sortDescriptors: Self.positionSort)
  }

  func clearQueue() {
    CoreDataManager.shared.deleteRecords(entity: QueueEntity.self)
  }

  func shuffleQueue(currentIdx: Int) -> [QueueEntity] {
    let queue = getQueue()

    guard currentIdx < queue.count else { return queue }

    let head = Array(queue[...currentIdx])
    let tail = Array(queue[(currentIdx + 1)...]).shuffled()

    return head + tail
  }

  /// Builds the Core Data dictionary for a single song, mirroring `addToQueue`.
  func queueObject(
    from song: Song, contextName: String, isFromLocal: Bool = false, position: Int = 0
  ) -> [String: Any] {
    return [
      "id": song.mediaFileId == "" ? song.id : song.mediaFileId,
      "albumId": song.albumId,
      "albumName": song.albumName.isEmpty ? contextName : song.albumName,
      "contextName": contextName,
      "artistName": song.artist,
      "bitRate": song.bitRate,
      "sampleRate": song.sampleRate,
      "songName": song.title,
      "suffix": song.suffix,
      "isFromPlaylist": false,
      "isFromLocal": isFromLocal,
      "duration": song.duration,
      "explicitStatus": song.explicitStatus.rawValue,
      "position": position,
    ] as [String: Any]
  }

  /// Snapshots in-memory queue entities into plain dictionaries, normalizing
  /// `position` to the array order so the persisted order always matches
  /// what the user arranged on screen.
  func snapshotObjects(from queue: [QueueEntity]) -> [[String: Any]] {
    return queue.enumerated().map { idx, item in
      return [
        "id": item.id ?? "",
        "albumId": item.albumId ?? "",
        "albumCover": item.albumCover ?? "",
        "albumName": item.albumName ?? "",
        "contextName": item.contextName ?? "",
        "artistName": item.artistName ?? "",
        "bitRate": Int(item.bitRate),
        "sampleRate": Int(item.sampleRate),
        "songName": item.songName ?? "",
        "suffix": item.suffix ?? "",
        "isFromPlaylist": item.isFromPlaylist,
        "isFromLocal": item.isFromLocal,
        "duration": item.duration,
        "explicitStatus": item.explicitStatus ?? "",
        "position": idx,
      ] as [String: Any]
    }
  }

  /// Replaces the whole persisted queue with the given objects (in order)
  /// and returns the freshly fetched entities.
  @discardableResult
  func replaceQueue(objects: [[String: Any]]) -> [QueueEntity] {
    self.clearQueue()

    guard !objects.isEmpty else { return [] }

    let request = NSBatchInsertRequest(entity: QueueEntity.entity(), objects: objects)
    _ = try? CoreDataManager.shared.viewContext.execute(request)

    return self.getQueue()
  }

  func addToQueue<T: Playable>(item: T, isFromLocal: Bool = false) -> [QueueEntity] {
    let isPlaylist = item is Playlist
    let isPlaylistAlbum =
      (item as? Album).map { album in
        album.artist == "Various Artists" && album.albumArtist == "Various Artists"
          && album.genre.contains(" by ")
      } ?? false

    let isFromPlaylist = isPlaylist || isPlaylistAlbum

    let objects = item.songs.enumerated().map { idx, song in
      var object = queueObject(
        from: song, contextName: item.name, isFromLocal: isFromLocal, position: idx)
      object["isFromPlaylist"] = isFromPlaylist
      return object
    }

    return self.replaceQueue(objects: objects)
  }
}
