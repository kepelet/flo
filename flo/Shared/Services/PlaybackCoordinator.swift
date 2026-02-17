//
//  PlaybackCoordinator.swift
//  flo
//
//  Created by Codex on 17/02/26.
//

import Foundation

final class PlaybackCoordinator {
  static let shared = PlaybackCoordinator()

  weak var playerViewModel: PlayerViewModel?

  private init() {}

  func attach(playerViewModel: PlayerViewModel) {
    self.playerViewModel = playerViewModel
  }

  func handleWatchCommand(_ message: [String: Any]) {
    guard let action = message["action"] as? String else { return }

    switch action {
    case "play":
      DispatchQueue.main.async {
        self.playerViewModel?.play()
      }
    case "pause":
      DispatchQueue.main.async {
        self.playerViewModel?.pause()
      }
    case "next":
      DispatchQueue.main.async {
        self.playerViewModel?.nextSong()
      }
    case "previous":
      DispatchQueue.main.async {
        self.playerViewModel?.prevSong()
      }
    case "playAlbum":
      handlePlayAlbum(message)
    case "playPlaylist":
      handlePlayPlaylist(message)
    case "playSong":
      handlePlaySong(message)
    case "playRadio":
      handlePlayRadio(message)
    default:
      break
    }
  }

  private func handlePlayAlbum(_ message: [String: Any]) {
    guard let albumId = message["id"] as? String else { return }

    let albumName = message["name"] as? String ?? ""
    let albumArtist = message["artist"] as? String ?? ""

    AlbumService.shared.getSongFromAlbum(id: albumId) { result in
      switch result {
      case .success(let songs):
        let album = Album(
          id: albumId,
          name: albumName,
          albumArtist: albumArtist,
          artist: albumArtist,
          songs: songs
        )
        self.play(item: album, startIndex: 0)
      case .failure:
        break
      }
    }
  }

  private func handlePlayPlaylist(_ message: [String: Any]) {
    guard let playlistId = message["id"] as? String else { return }

    let playlistName = message["name"] as? String ?? ""
    let ownerName = message["ownerName"] as? String ?? ""

    AlbumService.shared.getSongsByPlaylist(id: playlistId) { result in
      switch result {
      case .success(let songs):
        var playlist = Playlist(
          id: playlistId,
          name: playlistName,
          comment: "",
          isPublic: false,
          ownerName: ownerName,
          songs: songs
        )
        playlist.songs = songs
        self.play(item: playlist, startIndex: 0)
      case .failure:
        break
      }
    }
  }

  private func handlePlaySong(_ message: [String: Any]) {
    guard
      let contextId = message["contextId"] as? String,
      let songId = message["songId"] as? String,
      let contextType = message["contextType"] as? String
    else { return }

    if contextType == "album" {
      AlbumService.shared.getSongFromAlbum(id: contextId) { result in
        switch result {
        case .success(let songs):
          let index = Self.resolveSongIndex(songId: songId, in: songs)

          let album = Album(
            id: contextId, name: message["contextName"] as? String ?? "", songs: songs)
          self.play(item: album, startIndex: index)
        case .failure:
          break
        }
      }
    } else if contextType == "playlist" {
      AlbumService.shared.getSongsByPlaylist(id: contextId) { result in
        switch result {
        case .success(let songs):
          let index = Self.resolveSongIndex(songId: songId, in: songs)

          var playlist = Playlist(
            id: contextId,
            name: message["contextName"] as? String ?? "",
            comment: "",
            isPublic: false,
            ownerName: message["ownerName"] as? String ?? "",
            songs: songs
          )
          playlist.songs = songs

          self.play(item: playlist, startIndex: index)
        case .failure:
          break
        }
      }
    } else if contextType == "allSongs" {
      AlbumService.shared.getAllSongs { result in
        switch result {
        case .success(let songs):
          let index = Self.resolveSongIndex(songId: songId, in: songs)

          var playlist = Playlist(
            id: contextId,
            name: message["contextName"] as? String ?? "All Songs",
            comment: "",
            isPublic: false,
            ownerName: "",
            songs: songs
          )
          playlist.songs = songs

          self.play(item: playlist, startIndex: index)
        case .failure:
          break
        }
      }
    }
  }

  private func handlePlayRadio(_ message: [String: Any]) {
    guard
      let radioId = message["id"] as? String,
      let name = message["name"] as? String,
      let streamUrl = message["streamUrl"] as? String
    else { return }

    let radio = Radio(id: radioId, name: name, streamUrl: streamUrl)
    let playable = radio.toPlayable()

    play(item: playable, startIndex: 0)
  }

  private static func resolveSongIndex(songId: String, in songs: [Song]) -> Int {
    if let index = songs.firstIndex(where: { $0.id == songId || $0.mediaFileId == songId }) {
      return index
    }

    return 0
  }

  private func play<T: Playable>(item: T, startIndex: Int) {
    let queue = PlaybackService.shared.addToQueue(item: item)

    DispatchQueue.main.async {
      self.playerViewModel?.addToQueue(idx: startIndex, item: queue, playAudio: true)
    }
  }

  func currentNowPlayingPayload() -> [String: Any] {
    guard let playerViewModel, playerViewModel.hasNowPlaying() else {
      return ["hasNowPlaying": false]
    }

    let nowPlaying = playerViewModel.nowPlaying
    let songId = nowPlaying.id ?? ""
    let albumId = nowPlaying.albumId ?? ""
    let albumName = nowPlaying.albumName ?? ""
    let artistName = nowPlaying.artistName ?? ""
    let title = nowPlaying.songName ?? ""

    let coverArtUrl = Self.coverArtUrl(albumId: albumId)

    return [
      "hasNowPlaying": true,
      "songId": songId,
      "albumId": albumId,
      "albumName": albumName,
      "artistName": artistName,
      "title": title,
      "contextName": nowPlaying.contextName ?? "",
      "isPlaying": playerViewModel.isPlaying,
      "coverArt": coverArtUrl,
    ]
  }

  private static func coverArtUrl(albumId: String) -> String {
    let token = AuthService.shared.getCreds(key: "subsonicToken")

    return
      "\(UserDefaultsManager.serverBaseURL)\(API.SubsonicEndpoint.coverArt)\(token)&id=al-\(albumId)&size=300"
  }
}
