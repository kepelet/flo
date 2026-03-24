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
    let rawEntries: [(albumName: String, artistName: String)] = listeningActivity.map {
      (albumName: $0.albumName ?? "", artistName: $0.artistName ?? "")
    }

    return await Task.detached(priority: .userInitiated) {
      let albumCounts = Dictionary(grouping: rawEntries) { entry in
        "\(entry.albumName)|\(entry.artistName)"
      }
      .mapValues { $0.count }

      let topAlbum = albumCounts.max(by: { $0.value < $1.value })

      let artistCounts = Dictionary(grouping: rawEntries) { entry in
        entry.artistName
      }
      .mapValues { $0.count }

      let topArtist = artistCounts.max(by: { $0.value < $1.value })

      let components = topAlbum?.key.split(separator: "|")
      let album = String(components?[0] ?? "N/A")
      let artist = String(components?[1] ?? "N/A")

      return Stats(topArtist: topArtist?.key ?? "N/A", topAlbum: album, topAlbumArtist: artist)
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
      case .failure:
        listenBrainzStatus = false
      }

      group.leave()
    }

    group.enter()

    checkLastFMAccountStatus { result in
      switch result {
      case .success(let status):
        lastFMStatus = status
      case .failure:
        lastFMStatus = false
      }

      group.leave()
    }

    group.notify(queue: .main) {
      completion(
        .success(
          AccountLinkStatus(
            listenBrainz: listenBrainzStatus ?? false,
            lastFM: lastFMStatus ?? false)))
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

  func scrobbleToBuiltinEndpoint(
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
}
