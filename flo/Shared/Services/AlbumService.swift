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
    if let localStream = CoreDataManager.shared.getRecordByKey(
      entity: SongEntity.self, key: \SongEntity.id, value: id
    ).first {
      guard let fileUrl = LocalFileManager.shared.fileURL(for: localStream.fileURL ?? "") else {
        return ""
      }

      return fileUrl.absoluteString
    } else {
      let streamUrl =
        "\(UserDefaultsManager.serverBaseURL)\(API.SubsonicEndpoint.stream)\(AuthService.shared.getCreds(key: "subsonicToken"))&id=\(id)"

      return streamUrl
    }
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

  func getDownloadedAlbum(completion: @escaping (Result<[Album], Error>) -> Void) {
    completion(
      .success(
        CoreDataManager.shared.getRecordsByEntity(entity: PlaylistEntity.self).map(Album.init)))
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

  func getSongsByAlbumId(albumId: String, limit: Int = 0) -> [Song] {
    return CoreDataManager.shared.getRecordByKey(
      entity: SongEntity.self, key: \SongEntity.albumId, value: albumId
    ).map(Song.init)
  }

  func getAlbumCover(artistName: String, albumName: String, albumId: String = "") -> String {
    let target = "Media/\(artistName)/\(albumName)/cover.png"

    if LocalFileManager.shared.fileExists(fileName: target) {
      return LocalFileManager.shared.fileURL(for: target)?.path ?? ""
    } else {
      return
        "\(UserDefaultsManager.serverBaseURL)\(API.SubsonicEndpoint.coverArt)\(AuthService.shared.getCreds(key: "subsonicToken"))&id=al-\(albumId)&size=300"
    }
  }

  func downloadAlbumCover(
    artistName: String, albumId: String, albumName: String,
    completion: @escaping (Result<URL?, Error>) -> Void
  ) {
    let params: [String: Any] = ["id": "al-\(albumId)", "size": 300]

    APIManager.shared.SubsonicEndpointDownload(
      endpoint: API.SubsonicEndpoint.coverArt, parameters: params
    ) { result in
      switch result {
      case .success(let data):
        guard
          let target = LocalFileManager.shared.documentsDirectory?.appendingPathComponent("Media")
            .appendingPathComponent(artistName).appendingPathComponent(albumName)
        else {
          return
        }
        LocalFileManager.shared.saveFile(
          target: target, fileName: "cover.png", content: data, completion: completion)
      case .failure(let error):
        completion(.failure(error))
      }
    }
  }

  func saveDownload(albumId: String?, albumName: String?, song: Song, fileURL: URL?, status: String)
  {
    if let checkExisting = CoreDataManager.shared.getRecordByKey(
      entity: SongEntity.self, key: \SongEntity.albumId, value: albumId
    ).first {
      checkExisting.fileURL =
        "Media/\(song.artist)/\(albumName ?? "Unknown Albums")/\(Int16(song.trackNumber)) \(song.title).\(song.suffix)"
      checkExisting.status = status

      CoreDataManager.shared.saveRecord()
    } else {
      let downloadedSong = SongEntity(context: CoreDataManager.shared.viewContext)

      downloadedSong.albumId = albumId
      downloadedSong.id = song.id
      downloadedSong.title = song.title
      downloadedSong.artistName = song.artist
      downloadedSong.bitRate = Int64(song.bitRate)
      downloadedSong.sampleRate = Int32(song.sampleRate)
      downloadedSong.discNumber = Int16(song.discNumber)
      downloadedSong.trackNumber = Int16(song.trackNumber)
      downloadedSong.suffix = song.suffix
      downloadedSong.duration = song.duration
      downloadedSong.fileURL =
        "Media/\(song.artist)/\(albumName ?? "Unknown Albums")/\(Int16(song.trackNumber)) \(song.title).\(song.suffix)"
      downloadedSong.status = status

      CoreDataManager.shared.saveRecord()
    }
  }

  func checkIfAlbumDownloaded(albumID: String) -> Bool {
    let isPlaylistEntityExist = CoreDataManager.shared.getRecordByKey(
      entity: PlaylistEntity.self, key: \PlaylistEntity.id, value: albumID, limit: 1)

    if isPlaylistEntityExist.isEmpty {
      return false
    } else {
      return CoreDataManager.shared.getRecordByKey(
        entity: SongEntity.self, key: \SongEntity.albumId, value: albumID, limit: 1
      ).first != nil
    }
  }

  // FIXME: the parameters are so damn long
  func download(
    artistName: String, albumName: String, id: String, bitrate: Int = 0, trackNumber: String,
    title: String, suffix: String, completion: @escaping (Result<URL?, Error>) -> Void
  ) {
    let params: [String: Any] = ["id": id, "format": "raw", "bitrate": bitrate]

    APIManager.shared.SubsonicEndpointDownload(
      endpoint: API.SubsonicEndpoint.download, parameters: params
    ) { result in
      switch result {
      case .success(let data):
        guard
          let target = LocalFileManager.shared.documentsDirectory?.appendingPathComponent("Media")
            .appendingPathComponent(artistName).appendingPathComponent(albumName)
        else {
          return
        }

        LocalFileManager.shared.saveFile(
          target: target, fileName: "\(trackNumber) \(title).\(suffix)", content: data,
          completion: completion)
      case .failure(let error):
        completion(.failure(error))
      }
    }
  }
}
