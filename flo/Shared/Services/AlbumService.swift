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
      entity: SongEntity.self, key: \SongEntity.mediaFileId, value: id
    ).first {
      guard let fileUrl = LocalFileManager.shared.fileURL(for: localStream.fileURL ?? "") else {
        return ""
      }

      return fileUrl.absoluteString
    } else {
      let maxBitrate = UserDefaultsManager.maxBitRate
      let format =
        maxBitrate == TranscodingSettings.sourceBitRate
        ? TranscodingSettings.sourceFormat : TranscodingSettings.targetFormat

      let streamUrl =
        "\(UserDefaultsManager.serverBaseURL)\(API.SubsonicEndpoint.stream)\(AuthService.shared.getCreds(key: "subsonicToken"))&id=\(id)&maxBitRate=\(maxBitrate)&format=\(format)"

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
    // FIXME: now we fetch all albums. let's see if this will affect performance
    let params: [String: Any] = ["_start": 0, "_end": 0, "_order": "ASC", "_sort": "name"]

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

  func getArtists(completion: @escaping (Result<[Artist], Error>) -> Void) {
    let params: [String: Any] = ["_start": 0, "_end": 0, "_order": "ASC", "_sort": "name"]

    APIManager.shared.NDEndpointRequest(endpoint: API.NDEndpoint.getArtists, parameters: params) {
      (response: DataResponse<[Artist], AFError>) in
      switch response.result {
      case .success(let artists):
        completion(.success(artists))
      case .failure(let error):
        completion(.failure(error))
      }
    }
  }

  func getAlbumsByArtist(id: String, completion: @escaping (Result<[Album], Error>) -> Void) {
    // TODO: now we fetch all albums. let's see if this will affect performance
    let params: [String: Any] = [
      "_start": 0, "_end": 0, "_order": "ASC", "_sort": "max_year desc,date desc", "artist_id": id,
    ]

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

  func getPlaylists(completion: @escaping (Result<[Playlist], Error>) -> Void) {
    let params: [String: Any] = ["_start": 0, "_end": 0, "_order": "ASC", "_sort": "name"]

    APIManager.shared.NDEndpointRequest(endpoint: API.NDEndpoint.getPlaylists, parameters: params) {
      (response: DataResponse<[Playlist], AFError>) in
      switch response.result {
      case .success(let playlists):
        completion(.success(playlists))
      case .failure(let error):
        completion(.failure(error))
      }
    }
  }

  // FIXME: currently we can't stream from the local (offline) one :)
  func getSongsByPlaylist(id: String, completion: @escaping (Result<[Song], Error>) -> Void) {
    let params: [String: Any] = [
      "playlist_id": id, "_start": 0, "_end": 0, "_order": "ASC", "_sort": "id",
    ]

    let endpoint = "\(API.NDEndpoint.getPlaylists)/\(id)/tracks"

    APIManager.shared.NDEndpointRequest(
      endpoint: endpoint, parameters: params
    ) {
      (response: DataResponse<[Song], AFError>) in
      switch response.result {
      case .success(let songs):
        completion(.success(songs))
      case .failure(let error):
        completion(.failure(error))
      }
    }
  }

  func getAllSongs(completion: @escaping (Result<[Song], Error>) -> Void) {
    // FIXME: load it all!!!
    let params: [String: Any] = ["_start": "0", "_end": "0", "_order": "ASC", "_sort": "title"]

    APIManager.shared.NDEndpointRequest(
      endpoint: API.NDEndpoint.getSong, parameters: params
    ) {
      (response: DataResponse<[Song], AFError>) in
      switch response.result {
      case .success(let status):
        completion(.success(status))
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
    let sortByTrackNumber = NSSortDescriptor(key: "trackNumber", ascending: true)

    return CoreDataManager.shared.getRecordByKey(
      entity: SongEntity.self, key: \SongEntity.albumId, value: albumId,
      sortDescriptors: [sortByTrackNumber]
    ).map(Song.init)
  }

  func getAlbumCover(
    artistName: String, albumName: String, albumId: String = "", trackId: String = ""
  ) -> String {
    let target = "Media/\(artistName)/\(albumName)/cover.png"
    let anotherTarget = "Media/Various Artists/\(albumName)/cover/\(trackId).png"

    if LocalFileManager.shared.fileExists(fileName: target) {
      return LocalFileManager.shared.fileURL(for: target)?.path ?? ""
    } else if LocalFileManager.shared.fileExists(fileName: anotherTarget) {
      return LocalFileManager.shared.fileURL(for: anotherTarget)?.path ?? ""
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
      case .success(let tempFile):
        guard
          let target = LocalFileManager.shared.documentsDirectory?.appendingPathComponent("Media")
            .appendingPathComponent(artistName).appendingPathComponent(albumName)
            .appendingPathComponent("cover.png")
        else {
          return
        }
        LocalFileManager.shared.moveFile(source: tempFile, target: target, completion: completion)
      case .failure(let error):
        completion(.failure(error))
      }
    }
  }

  func downloadAlbumCoverForPlaylist(
    albumId: String,
    playlistName: String,
    trackId: String,
    completion: @escaping (Result<URL?, Error>) -> Void
  ) {
    let params: [String: Any] = ["id": "al-\(albumId)", "size": 300]

    APIManager.shared.SubsonicEndpointDownload(
      endpoint: API.SubsonicEndpoint.coverArt, parameters: params
    ) { result in
      switch result {
      case .success(let tempFile):
        guard
          let target = LocalFileManager.shared.documentsDirectory?.appendingPathComponent("Media")
            .appendingPathComponent("Various Artists").appendingPathComponent(playlistName)
            .appendingPathComponent("cover")
            .appendingPathComponent("\(trackId).png")
        else {
          return
        }

        LocalFileManager.shared.moveFile(
          source: tempFile, target: target, forceOverride: false, completion: completion)
      case .failure(let error):
        completion(.failure(error))
      }
    }
  }

  func saveDownload(
    albumId: String, albumName: String?, song: Song, status: String, isFromPlaylist: Bool = false
  ) {
    let songId = isFromPlaylist ? "pl:\(albumId):\(song.mediaFileId)" : song.id

    let checkExistingSong = CoreDataManager.shared.getRecordByKey(
      entity: SongEntity.self, key: \SongEntity.id, value: songId, limit: 1)

    let fileURL =
      "Media/\(isFromPlaylist ? "Various Artists" : song.artist)/\(albumName ?? "Unknown Albums")/\(Int16(song.trackNumber)) \(song.title).\(song.suffix)"

    if let existingSong = checkExistingSong.first {
      existingSong.fileURL =
        "Media/\(isFromPlaylist ? "Various Artists" : song.artist)/\(albumName ?? "Unknown Albums")/\(Int16(song.trackNumber)) \(song.title).\(song.suffix)"
      existingSong.status = status
    } else {
      let downloadedSong = SongEntity(context: CoreDataManager.shared.viewContext)

      downloadedSong.albumId = albumId
      downloadedSong.id = songId
      downloadedSong.title = song.title
      downloadedSong.artistName = song.artist
      downloadedSong.bitRate = Int64(song.bitRate)
      downloadedSong.sampleRate = Int32(song.sampleRate)
      downloadedSong.discNumber = Int16(song.discNumber)
      downloadedSong.trackNumber = Int16(song.trackNumber)
      downloadedSong.suffix = song.suffix
      downloadedSong.duration = song.duration
      downloadedSong.fileURL = fileURL
      downloadedSong.status = status
      downloadedSong.mediaFileId = isFromPlaylist ? song.mediaFileId : song.id
    }

    CoreDataManager.shared.saveRecord()
  }

  func saveAlbum(_ albumToDownload: Album) {
    let album = PlaylistEntity(context: CoreDataManager.shared.viewContext)

    album.id = albumToDownload.id
    album.name = albumToDownload.name
    album.genre = albumToDownload.genre
    album.minYear = Int64(albumToDownload.minYear)
    album.artistName = albumToDownload.artist
    album.albumArtist = albumToDownload.albumArtist

    CoreDataManager.shared.saveRecord()
  }

  func savePlaylist(_ playlistToDownload: Playlist) {
    let playlist = PlaylistEntity(context: CoreDataManager.shared.viewContext)

    playlist.id = playlistToDownload.id
    playlist.name = playlistToDownload.name
    playlist.genre = "\(playlistToDownload.comment) by \(playlistToDownload.ownerName)"

    playlist.albumArtist = "Various Artists"
    playlist.artistName = "Various Artists"

    CoreDataManager.shared.saveRecord()
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

  // FIXME: refactor later
  func downloadNew(
    artistName: String, albumName: String, id: String, bitrate: Int = 0, trackNumber: String,
    title: String, suffix: String, progressUpdate: ((Double) -> Void)?,
    completion: @escaping (Result<URL?, Error>) -> Void
  ) -> DownloadRequest {
    let params: [String: Any] = ["id": id, "format": "raw", "bitrate": bitrate]

    return APIManager.shared.SubsonicEndpointDownloadNew(
      endpoint: API.SubsonicEndpoint.download, parameters: params, progressUpdate: progressUpdate
    ) { result in
      switch result {
      case .success(let tempFile):
        guard
          let target = LocalFileManager.shared.documentsDirectory?.appendingPathComponent("Media")
            .appendingPathComponent(artistName).appendingPathComponent(albumName)
            .appendingPathComponent("\(trackNumber) \(title).\(suffix)")
        else {
          return
        }

        LocalFileManager.shared.moveFile(source: tempFile, target: target, completion: completion)
      case .failure(let error):
        completion(.failure(error))
      }
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
      case .success(let tempFile):
        guard
          let target = LocalFileManager.shared.documentsDirectory?.appendingPathComponent("Media")
            .appendingPathComponent(artistName).appendingPathComponent(albumName)
            .appendingPathComponent("\(trackNumber) \(title).\(suffix)")
        else {
          return
        }

        LocalFileManager.shared.moveFile(source: tempFile, target: target, completion: completion)
      case .failure(let error):
        completion(.failure(error))
      }
    }
  }

  func removeDownloadedAlbum(
    artistName: String, albumId: String, albumName: String,
    completion: @escaping (Result<Bool, Error>) -> Void
  ) {
    let checkExistingAlbum = CoreDataManager.shared.getRecordByKey(
      entity: PlaylistEntity.self, key: \PlaylistEntity.name, value: albumName, limit: 1)

    if checkExistingAlbum.first != nil {
      guard
        let target = LocalFileManager.shared.documentsDirectory?.appendingPathComponent("Media")
          .appendingPathComponent(artistName).appendingPathComponent(albumName)
      else { return }

      LocalFileManager.shared.deleteDownloadedAlbum(target: target) { result in
        switch result {
        case .success(let success):
          if success {
            CoreDataManager.shared.deleteRecordByKey(
              entity: PlaylistEntity.self, key: \PlaylistEntity.name, value: albumName)

            CoreDataManager.shared.deleteRecordByKey(
              entity: SongEntity.self, key: \SongEntity.albumId, value: albumId)
          }

          completion(.success(true))
        case .failure(let error):
          completion(.failure(error))
        }
      }
    }
  }

  func removeDownloadedPlaylist(
    playlistId: String, playlistName: String,
    completion: @escaping (Result<Bool, Error>) -> Void
  ) {
    let checkExistingAlbum = CoreDataManager.shared.getRecordByKey(
      entity: PlaylistEntity.self, key: \PlaylistEntity.name, value: playlistName, limit: 1)

    if checkExistingAlbum.first != nil {
      guard
        let target = LocalFileManager.shared.documentsDirectory?.appendingPathComponent("Media")
          .appendingPathComponent("Various Artists").appendingPathComponent(playlistName)
      else { return }

      LocalFileManager.shared.deleteDownloadedAlbum(target: target) { result in
        switch result {
        case .success(let success):
          if success {
            CoreDataManager.shared.deleteRecordByKey(
              entity: PlaylistEntity.self, key: \PlaylistEntity.name, value: playlistName)

            CoreDataManager.shared.deleteRecordByKey(
              entity: SongEntity.self, key: \SongEntity.albumId, value: playlistId)
          }

          completion(.success(true))
        case .failure(let error):
          completion(.failure(error))
        }
      }
    }
  }

  func removeDownloadedSong(
    albumId: String, songId: String, completion: @escaping (Result<Bool, Error>) -> Void
  ) {
    let checkExistingSong = CoreDataManager.shared.getRecordByKey(
      entity: SongEntity.self, key: \SongEntity.id, value: songId, limit: 1)

    if let existingSong = checkExistingSong.first {
      let localFileExist = LocalFileManager.shared.fileExists(fileName: existingSong.fileURL ?? "")

      if localFileExist {
        LocalFileManager.shared.deleteFile(fileName: existingSong.fileURL ?? "") { result in
          switch result {
          case .success(let success):
            if success {
              CoreDataManager.shared.deleteRecordByKey(
                entity: SongEntity.self, key: \SongEntity.id, value: songId)
            }

            completion(.success(true))
          case .failure(let error):
            completion(.failure(error))
          }
        }
      }
    }
  }
}
