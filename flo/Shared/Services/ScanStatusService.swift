//
//  ScanStatusService.swift
//  flo
//
//  Created by rizaldy on 14/06/24.
//

import Alamofire
import Foundation

class ScanStatusService {
  static let shared = ScanStatusService()

  func getDownloadedAlbumsCount() -> Int {
    return CoreDataManager.shared.countRecords(entity: PlaylistEntity.self)
  }

  func getDownloadedSongsCount() -> Int {
    return CoreDataManager.shared.countRecords(entity: SongEntity.self)
  }

  func getScanStatus(completion: @escaping (Result<ScanStatusResponse, Error>) -> Void) {
    let params: [String: Any] = [:]

    APIManager.shared.SubsonicEndpointRequest(
      endpoint: API.SubsonicEndpoint.scanStatus, parameters: params
    ) {
      (response: DataResponse<ScanStatusResponse, AFError>) in
      switch response.result {
      case .success(let status):
        completion(.success(status))
      case .failure(let error):
        completion(.failure(error))
      }
    }
  }
}
