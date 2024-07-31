//
//  AlbumService.swift
//  flo
//
//  Created by rizaldy on 08/06/24.
//

import Alamofire
import Foundation

class AlbumService {
  static let shared = AlbumService()

  func getStreamUrl(id: String) -> String {
    let streamUrl =
      "\(UserDefaultsManager.serverBaseURL)\(API.SubsonicEndpoint.stream)\(AuthService.shared.getCreds(key: "subsonicToken"))&id=\(id)"

    return streamUrl
  }

  func getCoverArt(id: String) -> String {
    let coverArt =
      "\(UserDefaultsManager.serverBaseURL)\(API.SubsonicEndpoint.coverArt)\(AuthService.shared.getCreds(key: "subsonicToken"))&id=al-\(id)&size=300"

    return coverArt
  }

  func getSongFromAlbum(id: String, completion: @escaping (Result<[Song], Error>) -> Void) {
    // FIXME: get all songs for now
    let params: [String: Any] = [
      "_start": 0, "_end": 0, "_order": "ASC", "_sort": "album", "album_id": id,
    ]

    APIManager.shared.NDEndpointRequest(endpoint: API.NDEndpoint.getSong, parameters: params) {
      (response: DataResponse<[Song], AFError>) in
      switch response.result {
      case .success(let song):
        completion(.success(song))
      case .failure(let error):
        completion(.failure(error))
      }
    }
  }

  func getAlbum(completion: @escaping (Result<[Album], Error>) -> Void) {
    // FIXME: get last 100 albums for now
    let params: [String: Any] = ["_start": 0, "_end": 100, "_order": "ASC", "_sort": "name"]

    APIManager.shared.NDEndpointRequest(endpoint: API.NDEndpoint.getAlbum, parameters: params) {
      (response: DataResponse<[Album], AFError>) in
      switch response.result {
      case .success(let albums):
        completion(.success(albums))
      case .failure(let error):
        completion(.failure(error))
      }
    }
  }

  func getAlbumInfo(id: String, completion: @escaping (Result<AlbumInfo, Error>) -> Void) {
    let params: [String: Any] = ["id": id]

    APIManager.shared.SubsonicEndpointRequest(
      endpoint: API.SubsonicEndpoint.albuminfo, parameters: params
    ) {
      (response: DataResponse<AlbumInfo, AFError>) in
      switch response.result {
      case .success(let status):
        completion(.success(status))
      case .failure(let error):
        completion(.failure(error))
      }
    }
  }

  func share(
    albumId: String, description: String, downloadable: Bool,
    completion: @escaping (Result<AlbumShare, Error>) -> Void
  ) {
    let params: [String: Any] = [
      "description": description, "resourceIds": albumId, "downloadable": downloadable,
      "resourceType": "album",
    ]

    APIManager.shared.NDEndpointRequest(
      endpoint: API.NDEndpoint.shareAlbum, method: .post, parameters: params,
      encoding: JSONEncoding.default
    ) {
      (response: DataResponse<AlbumShare, AFError>) in
      switch response.result {
      case .success(let id):
        completion(.success(id))
      case .failure(let error):
        completion(.failure(error))
      }
    }
  }
}
