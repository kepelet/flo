//
//  LRCLIBService.swift
//  flo
//
//  Created by rizaldy on 01/02/26.
//

import Alamofire
import Foundation

class LRCLIBService {
  static let shared = LRCLIBService()

  func fetchLyrics(
    trackName: String,
    artistName: String,
    albumName: String? = nil,
    duration: Double? = nil,
    completion: @escaping (Result<LRCLIBLyrics, Error>) -> Void
  ) {
    var parameters: [String: String] = [
      "track_name": trackName,
      "artist_name": artistName,
    ]

    if let albumName = albumName {
      parameters["album_name"] = albumName
    }

    if let duration = duration {
      parameters["duration"] = String(Int(duration.rounded()))
    }

    let request: (DataResponse<LRCLIBLyrics, AFError>) -> Void = { response in
      completion(response.result.mapError { $0 as Error })
    }

    APIManager.shared.externalRequest(
      url: "\(UserDefaultsManager.LRCLIBServerURL)/api/get",
      parameters: parameters,
      completion: request
    )
  }
}
