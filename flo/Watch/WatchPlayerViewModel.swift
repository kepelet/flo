//
//  WatchPlayerViewModel.swift
//  flo
//
//  Created by Codex on 17/02/26.
//

#if os(watchOS)
import Foundation

@MainActor
final class WatchPlayerViewModel: ObservableObject {
  @Published var nowPlayingTitle: String = ""
  @Published var nowPlayingArtist: String = ""
  @Published var contextTitle: String = ""
  @Published var isPlaying: Bool = false

  private let connectivity = WatchConnectivityManager.shared

  func playAlbum(_ album: Album, songs: [Song]) {
    contextTitle = album.name
    nowPlayingTitle = songs.first?.title ?? album.name
    nowPlayingArtist = songs.first?.artist ?? album.artist
    isPlaying = true

    connectivity.sendMessage([
      "action": "playAlbum",
      "id": album.id,
      "name": album.name,
      "artist": album.artist,
    ])
  }

  func playPlaylist(_ playlist: Playlist, songs: [Song]) {
    contextTitle = playlist.name
    nowPlayingTitle = songs.first?.title ?? playlist.name
    nowPlayingArtist = songs.first?.artist ?? playlist.ownerName
    isPlaying = true

    connectivity.sendMessage([
      "action": "playPlaylist",
      "id": playlist.id,
      "name": playlist.name,
      "ownerName": playlist.ownerName,
    ])
  }

  func playSong(_ song: Song, inAlbum album: Album) {
    contextTitle = album.name
    nowPlayingTitle = song.title
    nowPlayingArtist = song.artist
    isPlaying = true

    connectivity.sendMessage([
      "action": "playSong",
      "contextType": "album",
      "contextId": album.id,
      "contextName": album.name,
      "songId": song.mediaFileId.isEmpty ? song.id : song.mediaFileId,
    ])
  }

  func playSong(_ song: Song, inPlaylist playlist: Playlist) {
    contextTitle = playlist.name
    nowPlayingTitle = song.title
    nowPlayingArtist = song.artist
    isPlaying = true

    connectivity.sendMessage([
      "action": "playSong",
      "contextType": "playlist",
      "contextId": playlist.id,
      "contextName": playlist.name,
      "ownerName": playlist.ownerName,
      "songId": song.mediaFileId.isEmpty ? song.id : song.mediaFileId,
    ])
  }

  func togglePlayPause() {
    if isPlaying {
      pause()
    } else {
      play()
    }
  }

  func play() {
    isPlaying = true
    connectivity.sendMessage(["action": "play"])
  }

  func pause() {
    isPlaying = false
    connectivity.sendMessage(["action": "pause"])
  }

  func next() {
    connectivity.sendMessage(["action": "next"])
  }

  func previous() {
    connectivity.sendMessage(["action": "previous"])
  }
}
#endif
