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

  func getAccountLinkStatuses(completion: @escaping (Result<AccountLinkStatus, Error>) -> Void) {
    let group = DispatchGroup()

    var listenBrainzStatus: Bool?
    var lastFMStatus: Bool?
    var error: Error?

    group.enter()

    checkListenBrainzAccountStatus { result in
      switch result {
      case .success(let status):
        listenBrainzStatus = status
      case .failure(let err):
        error = err
      }

      group.leave()
    }

    group.enter()

    checkLastFMAccountStatus { result in
      switch result {
      case .success(let status):
        lastFMStatus = status
      case .failure(let err):
        error = err
      }

      group.leave()
    }

    group.notify(queue: .main) {
      if let error = error {
        completion(.failure(error))

        return
      }

      guard let listenBrainz = listenBrainzStatus, let lastFm = lastFMStatus else {
        completion(.failure(NSError(domain: "", code: -1)))

        return
      }

      completion(.success(AccountLinkStatus(listenBrainz: listenBrainz, lastFM: lastFm)))
    }
  }

  func checkListenBrainzAccountStatus(completion: @escaping (Result<Bool, Error>) -> Void) {
    APIManager.shared.NDEndpointRequest(endpoint: API.NDEndpoint.listenBrainzLink, parameters: [:])
    {
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
    APIManager.shared.NDEndpointRequest(endpoint: API.NDEndpoint.lastFMLink, parameters: [:]) {
      (response: DataResponse<AccountStatusResponse, AFError>) in
      switch response.result {
      case .success(let status):
        completion(.success(status.status))
      case .failure(let error):
        completion(.failure(error))
      }
    }
  }

  func scrobbleToBuiltInEndpoint(
    submission: Bool, songId: String,
    completion: @escaping (Result<BasicSubsonicResponse, Error>) -> Void
  ) {
    var params: [String: Any] = ["submission": String(submission), "id": songId]

    if submission {
      params["time"] = Int(Date().timeIntervalSince1970 * 1000)
    }

    APIManager.shared.SubsonicEndpointRequest(
      endpoint: API.SubsonicEndpoint.scrobble, parameters: params
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

  struct AccountLinkStatus: Decodable {
    let listenBrainz: Bool
    let lastFM: Bool
  }
}
