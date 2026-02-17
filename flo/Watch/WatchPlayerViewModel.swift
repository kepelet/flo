//
//  WatchPlayerViewModel.swift
//  flo
//
//  Created by Codex on 17/02/26.
//

#if os(watchOS)
  import Combine
  import Foundation

  @MainActor
  final class WatchPlayerViewModel: ObservableObject {
    @Published var nowPlayingTitle: String = ""
    @Published var nowPlayingArtist: String = ""
    @Published var contextTitle: String = ""
    @Published var isPlaying: Bool = false
    @Published var coverArt: String = ""

    private let connectivity = WatchConnectivityManager.shared

    func playAlbum(_ album: Album, songs: [Song]) {
      contextTitle = album.name
      nowPlayingTitle = songs.first?.title ?? album.name
      nowPlayingArtist = songs.first?.artist ?? album.artist
      coverArt = album.albumCover

      isPlaying = true

      connectivity.sendMessage([
        "action": "playAlbum",
        "id": album.id,
        "name": album.name,
        "artist": album.artist,
      ])

      refreshNowPlaying()
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

      refreshNowPlaying()
    }

    func playSong(_ song: Song, inAlbum album: Album) {
      contextTitle = album.name
      nowPlayingTitle = song.title
      nowPlayingArtist = song.artist
      coverArt = album.albumCover

      isPlaying = true

      connectivity.sendMessage([
        "action": "playSong",
        "contextType": "album",
        "contextId": album.id,
        "contextName": album.name,
        "songId": song.mediaFileId.isEmpty ? song.id : song.mediaFileId,
      ])

      refreshNowPlaying()
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

      refreshNowPlaying()
    }

    func playSongAll(_ song: Song) {
      contextTitle = "All Songs"
      nowPlayingTitle = song.title
      nowPlayingArtist = song.artist

      isPlaying = true

      connectivity.sendMessage([
        "action": "playSong",
        "contextType": "allSongs",
        "contextId": "allSongs",
        "contextName": "All Songs",
        "songId": song.mediaFileId.isEmpty ? song.id : song.mediaFileId,
      ])

      refreshNowPlaying()
    }

    func playRadio(_ radio: Radio) {
      contextTitle = "Radio"
      nowPlayingTitle = radio.name
      nowPlayingArtist = radio.streamUrl

      isPlaying = true

      connectivity.sendMessage([
        "action": "playRadio",
        "id": radio.id,
        "name": radio.name,
        "streamUrl": radio.streamUrl,
      ])

      refreshNowPlaying()
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
      refreshNowPlaying()
    }

    func pause() {
      isPlaying = false
      connectivity.sendMessage(["action": "pause"])
      refreshNowPlaying()
    }

    func next() {
      connectivity.sendMessage(["action": "next"])
      refreshNowPlaying()
    }

    func previous() {
      connectivity.sendMessage(["action": "previous"])
      refreshNowPlaying()
    }

    func refreshNowPlaying() {
      connectivity.requestNowPlaying { result in
        DispatchQueue.main.async {
          switch result {
          case .success(let payload):
            self.applyNowPlayingPayload(payload)
          case .failure:
            break
          }
        }
      }
    }

    private func applyNowPlayingPayload(_ payload: [String: Any]) {
      let hasNowPlaying = payload["hasNowPlaying"] as? Bool ?? false

      guard hasNowPlaying else {
        nowPlayingTitle = ""
        nowPlayingArtist = ""
        contextTitle = ""
        coverArt = ""
        isPlaying = false
        return
      }

      nowPlayingTitle = payload["title"] as? String ?? ""
      nowPlayingArtist = payload["artistName"] as? String ?? ""
      contextTitle = payload["contextName"] as? String ?? ""
      coverArt = payload["coverArt"] as? String ?? ""
      isPlaying = payload["isPlaying"] as? Bool ?? false
    }
  }
#endif
