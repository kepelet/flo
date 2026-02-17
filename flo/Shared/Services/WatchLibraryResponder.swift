//
//  WatchLibraryResponder.swift
//  flo
//
//  Created by Codex on 17/02/26.
//

import Foundation

final class WatchLibraryResponder {
  static let shared = WatchLibraryResponder()

  private init() {}

  func handle(message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
    guard let request = message["request"] as? String else {
      replyHandler(["result": "error", "message": "Invalid request."])

      return
    }

    switch request {
    case "albums":
      AlbumService.shared.getAlbum { result in
        switch result {
        case .success(let albums):
          let mapped = albums.map { album -> Album in
            var updated = album
            updated.albumCover = self.coverArtUrl(albumId: album.id)

            return updated
          }

          self.reply(with: mapped, replyHandler: replyHandler)
        case .failure:
          replyHandler(["result": "error", "message": "Failed to load albums."])
        }
      }
    case "artists":
      AlbumService.shared.getArtists { result in
        switch result {
        case .success(let artists):
          self.reply(with: artists, replyHandler: replyHandler)
        case .failure:
          replyHandler(["result": "error", "message": "Failed to load artists."])
        }
      }
    case "playlists":
      AlbumService.shared.getPlaylists { result in
        switch result {
        case .success(let playlists):
          self.reply(with: playlists, replyHandler: replyHandler)
        case .failure:
          replyHandler(["result": "error", "message": "Failed to load playlists."])
        }
      }
    case "songs":
      AlbumService.shared.getAllSongs { result in
        switch result {
        case .success(let songs):
          self.reply(with: songs, replyHandler: replyHandler)
        case .failure:
          replyHandler(["result": "error", "message": "Failed to load songs."])
        }
      }
    case "radios":
      RadioService.shared.getAllRadios { result in
        switch result {
        case .success(let radios):
          self.reply(with: radios, replyHandler: replyHandler)
        case .failure:
          replyHandler(["result": "error", "message": "Failed to load radios."])
        }
      }
    case "albumSongs":
      guard let albumId = message["id"] as? String else {
        replyHandler(["result": "error", "message": "Missing album id."])

        return
      }
      AlbumService.shared.getSongFromAlbum(id: albumId) { result in
        switch result {
        case .success(let songs):
          self.reply(with: songs, replyHandler: replyHandler)
        case .failure:
          replyHandler(["result": "error", "message": "Failed to load songs."])
        }
      }
    case "playlistSongs":
      guard let playlistId = message["id"] as? String else {
        replyHandler(["result": "error", "message": "Missing playlist id."])

        return
      }
      AlbumService.shared.getSongsByPlaylist(id: playlistId) { result in
        switch result {
        case .success(let songs):
          self.reply(with: songs, replyHandler: replyHandler)
        case .failure:
          replyHandler(["result": "error", "message": "Failed to load songs."])
        }
      }
    case "artistAlbums":
      guard let artistId = message["id"] as? String else {
        replyHandler(["result": "error", "message": "Missing artist id."])

        return
      }
      AlbumService.shared.getAlbumsByArtist(id: artistId) { result in
        switch result {
        case .success(let albums):
          let mapped = albums.map { album -> Album in
            var updated = album
            updated.albumCover = self.coverArtUrl(albumId: album.id)

            return updated
          }

          self.reply(with: mapped, replyHandler: replyHandler)
        case .failure:
          replyHandler(["result": "error", "message": "Failed to load albums."])
        }
      }
    case "nowPlaying":
      let payload = PlaybackCoordinator.shared.currentNowPlayingPayload()

      replyHandler(["result": "ok", "data": payload])
    case "ping":
      replyHandler(["result": "ok"])
    case "serverStatus":
      ScanStatusService.shared.getScanStatus { result in
        switch result {
        case .success:
          replyHandler(["result": "ok", "data": ["isOnline": true]])
        case .failure(let error):
          replyHandler([
            "result": "ok",
            "data": [
              "isOnline": false,
              "message": error.localizedDescription,
            ],
          ])
        }
      }
    default:
      replyHandler(["result": "error", "message": "Unknown request."])
    }
  }

  private func reply<T: Encodable>(with payload: T, replyHandler: @escaping ([String: Any]) -> Void)
  {
    guard let json = encodeToJSON(payload) else {
      replyHandler(["result": "error", "message": "Failed to encode response."])

      return
    }

    replyHandler(["result": "ok", "data": json])
  }

  private func encodeToJSON<T: Encodable>(_ payload: T) -> Any? {
    guard let data = try? JSONEncoder().encode(payload) else {
      return nil
    }

    return try? JSONSerialization.jsonObject(with: data)
  }

  private func coverArtUrl(albumId: String) -> String {
    let token = AuthService.shared.getCreds(key: "subsonicToken")

    return
      "\(UserDefaultsManager.serverBaseURL)\(API.SubsonicEndpoint.coverArt)\(token)&id=al-\(albumId)&size=300"
  }
}
