import Alamofire
import Foundation

//
//  FloooService.swift
//  flo
//
//  Created by rizaldy on 22/11/24.
//

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

  @MainActor
  func generateStats(_ listeningActivity: [HistoryEntity]) async -> Stats? {
    // Extract values on the main thread — NSManagedObjects must not cross thread boundaries
    let rawEntries: [(albumId: String, albumName: String, artistName: String, trackName: String)] =
      listeningActivity.map {
        (
          albumId: $0.albumId ?? "",
          albumName: $0.albumName ?? "",
          artistName: $0.artistName ?? "",
          trackName: $0.trackName ?? ""
        )
      }

    // Build genre lookup from local caches on the main thread.
    // HistoryEntity has no genre; we resolve via cached albums/songs.
    var albumIdToGenre: [String: String] = [:]
    var albumNameToGenre: [String: String] = [:]

    // 1) Downloaded albums (PlaylistEntity stores album genre)
    let playlistEntities = CoreDataManager.shared.getRecordsByEntity(entity: PlaylistEntity.self)
    for entity in playlistEntities {
      if let id = entity.id, !id.isEmpty, let genre = entity.genre, !genre.isEmpty,
        genre != "Unknown Genre"
      {
        if albumIdToGenre[id] == nil {
          albumIdToGenre[id] = genre
        }
      }
      if let name = entity.name, !name.isEmpty, let genre = entity.genre, !genre.isEmpty,
        genre != "Unknown Genre"
      {
        if albumNameToGenre[name] == nil {
          albumNameToGenre[name] = genre
        }
      }
    }

    // 2) Library cache (albums fetched from server) — covers non-downloaded listening history
    if let cachedAlbums: [Album] = LibraryCacheManager.shared.load([Album].self, forKey: "albums") {
      for album in cachedAlbums where !album.genre.isEmpty && album.genre != "Unknown Genre" {
        if !album.id.isEmpty, albumIdToGenre[album.id] == nil {
          albumIdToGenre[album.id] = album.genre
        }
        if !album.name.isEmpty, albumNameToGenre[album.name] == nil {
          albumNameToGenre[album.name] = album.genre
        }
      }
    }

    return await Task.detached(priority: .userInitiated) {
      let albumGroups = Dictionary(grouping: rawEntries) { entry in
        "\(entry.albumName)|\(entry.artistName)"
      }

      let topAlbumGroup = albumGroups.max(by: { $0.value.count < $1.value.count })

      let artistCounts = Dictionary(grouping: rawEntries) { entry in
        entry.artistName
      }
      .mapValues { $0.count }

      let topArtist = artistCounts.max(by: { $0.value < $1.value })

      let components = topAlbumGroup?.key.split(separator: "|")
      let album = String(components?[0] ?? "N/A")
      let artist = String(components?[1] ?? "N/A")
      let albumId = topAlbumGroup?.value.first(where: { !$0.albumId.isEmpty })?.albumId ?? ""

      // Most-played genre via lookup against local song/album cache
      var genreCounts: [String: Int] = [:]
      for entry in rawEntries {
        var genre: String?
        if !entry.albumId.isEmpty {
          genre = albumIdToGenre[entry.albumId]
        }
        if genre == nil, !entry.albumName.isEmpty {
          genre = albumNameToGenre[entry.albumName]
        }
        if let g = genre, !g.isEmpty, g != "N/A", g != "Unknown Genre", g != "Unknown" {
          genreCounts[g, default: 0] += 1
        }
      }
      let topGenre = genreCounts.max(by: { $0.value < $1.value })?.key ?? "N/A"

      return Stats(
        topArtist: topArtist?.key ?? "N/A",
        topAlbum: album,
        topAlbumArtist: artist,
        topAlbumId: albumId,
        topGenre: topGenre
      )
    }.value
  }

  func getAccountLinkStatuses(completion: @escaping (Result<AccountLinkStatus, Error>) -> Void) {
    let group = DispatchGroup()

    var listenBrainzStatus: Bool?
    var lastFMStatus: Bool?
    var requestError: Error?

    group.enter()

    checkListenBrainzAccountStatus { result in
      switch result {
      case .success(let status):
        listenBrainzStatus = status
      case .failure(let error):
        requestError = error
      }

      group.leave()
    }

    group.enter()

    checkLastFMAccountStatus { result in
      switch result {
      case .success(let status):
        lastFMStatus = status
      case .failure(let error):
        requestError = error
      }

      group.leave()
    }

    group.notify(queue: .main) {
      if listenBrainzStatus == nil || lastFMStatus == nil, let requestError = requestError {
        completion(.failure(requestError))
        return
      }

      completion(
        .success(
          AccountLinkStatus(
            listenBrainz: listenBrainzStatus ?? false,
            lastFM: lastFMStatus ?? false)))
    }
  }

  func checkListenBrainzAccountStatus(completion: @escaping (Result<Bool, Error>) -> Void) {
    APIManager.shared.NDEndpointRequest(
      endpoint: API.NDEndpoint.listenBrainzLink, parameters: [:], timeout: 8
    ) {
      (response: DataResponse<AccountStatusResponse, AFError>) in
      switch response.result {
      case .success(let status):
        completion(.success(status.status))
      case .failure(let error):
        completion(.failure(error))
      }
    }
  }

  func checkLastFMAccountStatus(completion: @escaping (Result<Bool, Error>) -> Void) {
    APIManager.shared.NDEndpointRequest(
      endpoint: API.NDEndpoint.lastFMLink, parameters: [:], timeout: 8
    ) {
      (response: DataResponse<AccountStatusResponse, AFError>) in
      switch response.result {
      case .success(let status):
        completion(.success(status.status))
      case .failure(let error):
        completion(.failure(error))
      }
    }
  }

  func scrobbleToBuiltinEndpoint(
    submission: Bool, songId: String, time: Date? = nil, timeout: TimeInterval? = nil,
    completion: @escaping (Result<BasicSubsonicResponse, Error>) -> Void
  ) {
    var params: [String: Any] = ["submission": String(submission), "id": songId]

    if submission {
      params["time"] = Int((time ?? Date()).timeIntervalSince1970 * 1000)
    }

    APIManager.shared.SubsonicEndpointRequest(
      endpoint: API.SubsonicEndpoint.scrobble, parameters: params, timeout: timeout
    ) {
      (response: DataResponse<BasicSubsonicResponse, AFError>) in
      switch response.result {
      case .success(let response):
        completion(.success(response))
      case .failure(let error):
        completion(.failure(error))
      }
    }
  }
}

extension FloooService {
  struct AccountStatusResponse: Decodable {
    let status: Bool
  }
}

extension AFError {
  var receivedServerResponse: Bool {
    switch self {
    case .responseValidationFailed, .responseSerializationFailed:
      return true
    default:
      return false
    }
  }
}

extension FloooService {
  func shouldQueueOfflineScrobble(_ error: Error) -> Bool {
    guard let afError = error as? AFError else { return true }
    return !afError.receivedServerResponse
  }
}
