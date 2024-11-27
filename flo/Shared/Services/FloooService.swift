//
//  FloooService.swift
//  flo
//
//  Created by rizaldy on 22/11/24.
//
import Foundation

class FloooService {
  static let shared: FloooService = FloooService()

  func getListeningHistory() async -> [HistoryEntity] {
    return await CoreDataManager.shared.getRecordsByEntityBatched(entity: HistoryEntity.self)
  }

  func saveListeningHistory(payload: QueueEntity) {
    let currentSession = HistoryEntity(context: CoreDataManager.shared.viewContext)

    currentSession.albumId = payload.albumId
    currentSession.artistName = payload.artistName
    currentSession.trackName = payload.songName
    currentSession.albumName = payload.albumName
    currentSession.artistName = payload.artistName
    currentSession.timestamp = Date()

    CoreDataManager.shared.saveRecord()
  }

  func clearListeningHistory() {
    CoreDataManager.shared.deleteRecords(entity: HistoryEntity.self)
  }

  func generateStats(_ listeningActivity: [HistoryEntity]) async -> Stats? {
    return await Task.detached(priority: .userInitiated) {
      let albumCounts = Dictionary(grouping: listeningActivity) { scrobble in
        let album = scrobble.value(forKey: "albumName") as? String ?? ""
        let artist = scrobble.value(forKey: "artistName") as? String ?? ""

        return "\(album)|\(artist)"
      }
      .mapValues { $0.count }

      let topAlbum = albumCounts.max(by: { $0.value < $1.value })

      let artistCounts = Dictionary(grouping: listeningActivity) { scrobble in
        scrobble.value(forKey: "artistName") as? String ?? ""
      }
      .mapValues { $0.count }

      let topArtist = artistCounts.max(by: { $0.value < $1.value })

      let components = topAlbum?.key.split(separator: "|")
      let album = String(components?[0] ?? "N/A")
      let artist = String(components?[1] ?? "N/A")

      let stats = Stats(topArtist: topArtist?.key ?? "N/A", topAlbum: album, topAlbumArtist: artist)

      return stats
    }.value
  }
}
