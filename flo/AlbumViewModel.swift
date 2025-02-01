//
//  AlbumViewModel.swift
//  flo
//
//  Created by rizaldy on 07/06/24.
//

import Foundation

class AlbumViewModel: ObservableObject {
  @Published var artists: [Artist] = []
  @Published var playlists: [Playlist] = []
  @Published var playlist: Playlist = Playlist()
  @Published var songs: [Song] = []
  @Published var artistAlbums: [Album] = []
  @Published var albums: [Album] = []
  @Published var album: Album = Album()
  @Published var downloadedAlbums: [Album] = []

  @Published var isDownloadingAlbumId: String = ""
  @Published var isDownloaded = false

  @Published var isLoading = false
  @Published var error: Error?

  init(album: Album = Album(), albums: [Album] = []) {
    self.album = album
    self.albums = albums
  }

  func ifNotSharable(isDownloadScreen: Bool) -> Bool {
    //TODO: add logic to check server-side config
    if isDownloadScreen {
      return true
    }

    return false
  }

  func ifNotDownloadable() -> Bool {
    //TODO: add logic to check server-side config
    if isDownloaded {
      return true
    }

    return false
  }

  func setActiveAlbum(album: Album) {
    self.album = album
    self.album.albumCover = self.getAlbumCoverArt(id: album.id)

    if !album.id.isEmpty {
      self.getAlbumById()
      self.fetchSongs(id: album.id)
    }
  }

  func setActivePlaylist(playlist: Playlist) {
    self.playlist = playlist
    self.isDownloaded = AlbumService.shared.checkIfAlbumDownloaded(albumID: playlist.id)
    self.fetchSongsByPlaylist(id: playlist.id)
  }

  func fetchSongs(id: String) {
    let checkLocalSongs = AlbumService.shared.getSongsByAlbumId(albumId: id)

    self.album.songs = checkLocalSongs

    AlbumService.shared.getSongFromAlbum(id: id) { result in
      self.isLoading = true

      DispatchQueue.main.async {
        self.isLoading = false

        switch result {
        case .success(let songs):
          let remoteSongs = songs.filter { song in
            !self.album.songs.contains(where: { $0.id == song.id })
          }

          if id == self.album.id {
            self.album.songs.append(contentsOf: remoteSongs)
          }

          self.album.songs.sort { $0.trackNumber < $1.trackNumber }

        case .failure(let error):
          self.error = error
        }
      }
    }
  }

  func fetchAllSongs() {
    AlbumService.shared.getAllSongs { result in
      self.isLoading = true

      DispatchQueue.main.async {
        self.isLoading = false

        switch result {
        case .success(let songs):
          self.songs = songs

        case .failure(let error):
          self.error = error
        }
      }
    }
  }

  func getAlbumInfo() {
    AlbumService.shared.getAlbumInfo(id: self.album.id) { result in
      DispatchQueue.main.async {
        switch result {
        case .success(let response):
          if let albumInfo = response.subsonicResponse.albumInfo.notes {
            let regex = try! NSRegularExpression(pattern: "<a href=\".*\">.*</a>\\.")
            let range = NSRange(location: 0, length: albumInfo.utf16.count)

            let stripped = regex.stringByReplacingMatches(
              in: albumInfo, range: range, withTemplate: "")

            self.album.info = stripped
          } else {
            self.album.info = "Description Unavailable"
          }

        case .failure(let error):
          self.error = error
        }
      }
    }
  }

  func getAlbumCoverArt(id: String, artistName: String = "", albumName: String = "") -> String {
    return AlbumService.shared.getAlbumCover(
      artistName: artistName, albumName: albumName, albumId: id)
  }

  func shareAlbum(description: String, completion: @escaping (String) -> Void) {
    AlbumService.shared.share(albumId: self.album.id, description: description, downloadable: false)
    { result in
      switch result {
      case .success(let share):
        completion("\(UserDefaultsManager.serverBaseURL)/share/\(share.id)")

      case .failure(let error):
        print("error>>>", error)
      }
    }
  }

  func getAlbumById() {
    self.isDownloaded = AlbumService.shared.checkIfAlbumDownloaded(albumID: self.album.id)
  }

  func downloadAlbum(_ albumToDownload: Album) {
    AlbumService.shared.downloadAlbumCover(
      artistName: albumToDownload.artist, albumId: albumToDownload.id,
      albumName: albumToDownload.name
    ) { [weak self] result in
      guard let self = self else { return }

      switch result {
      case .success:
        DispatchQueue.main.async {
          if !AlbumService.shared.checkIfAlbumDownloaded(albumID: albumToDownload.id) {
            AlbumService.shared.saveAlbum(albumToDownload)
          }
        }
      case .failure(let error):
        DispatchQueue.main.async {
          self.isDownloadingAlbumId = ""
          print("Failed to save image: \(error.localizedDescription)")
        }
      }
    }
  }

  func downloadPlaylist(_ playlistToDownload: Playlist, targetIdx: Int = -1) {
    let maxConcurrentDownloads = ProcessInfo.processInfo.activeProcessorCount / 2
    let downloadSemaphore = DispatchSemaphore(value: maxConcurrentDownloads)
    let downloadGroup = DispatchGroup()

    let songs = targetIdx == -1 ? playlistToDownload.songs : [playlistToDownload.songs[targetIdx]]

    Task(priority: .background) {
      AlbumService.shared.savePlaylist(playlistToDownload)

      songs.forEach { song in
        downloadGroup.enter()

        DispatchQueue.global(qos: .background).async {
          downloadSemaphore.wait()

          AlbumService.shared.downloadAlbumCoverForPlaylist(
            albumId: song.albumId, playlistName: playlistToDownload.name, trackId: song.mediaFileId
          ) { result in
            downloadSemaphore.signal()
            downloadGroup.leave()
          }
        }
      }
    }
  }

  func downloadSong(_ albumToDownload: Album, songIdx: Int) {
    var album = albumToDownload
    let songToDownload = albumToDownload.songs[songIdx]

    album.songs = [songToDownload]

    self.downloadAlbum(album)
  }

  func removeDownloadedAlbum(album: Album) {
    AlbumService.shared.removeDownloadedAlbum(
      artistName: album.artist, albumId: album.id, albumName: album.name
    ) { result in
      DispatchQueue.main.async {
        switch result {
        case .success:
          self.setActiveAlbum(album: album)
        case .failure(let error):
          print("error >>>", error)
        }
      }
    }
  }

  func removeDownloadedPlaylist(playlist: Playlist) {
    AlbumService.shared.removeDownloadedPlaylist(
      playlistId: playlist.id,
      playlistName: playlist.name
    ) { result in
      DispatchQueue.main.async {
        switch result {
        case .success:
          self.setActivePlaylist(playlist: playlist)
        case .failure(let error):
          print("error >>>", error)
        }
      }
    }
  }

  func removeDownloadSong(album: Playable, songId: String, isFromPlaylist: Bool = false) {
    AlbumService.shared.removeDownloadedSong(albumId: album.id, songId: songId) { result in
      DispatchQueue.main.async {
        switch result {
        case .success:
          if isFromPlaylist {
            self.fetchSongsByPlaylist(id: album.id)
          } else {
            self.fetchSongs(id: album.id)
          }
        case .failure(let error):
          print("error >>>", error)
        }
      }
    }
  }

  func fetchAlbums() {
    isLoading = true
    AlbumService.shared.getAlbum { result in
      DispatchQueue.main.async {
        self.isLoading = false
        switch result {
        case .success(let albums):
          self.albums = albums
        case .failure(let error):
          print("error>>>>", error)
          self.error = error
        }
      }
    }
  }

  func fetchAlbumsByArtist(id: String) {
    AlbumService.shared.getAlbumsByArtist(id: id) { result in
      DispatchQueue.main.async {
        switch result {
        case .success(let albums):
          self.artistAlbums = albums
        case .failure(let error):
          self.error = error
        }
      }
    }
  }

  func fetchSongsByPlaylist(id: String) {
    let checkLocalSongs = AlbumService.shared.getSongsByAlbumId(albumId: id)

    self.playlist.songs = checkLocalSongs

    AlbumService.shared.getSongsByPlaylist(id: id) { result in
      DispatchQueue.main.async {
        switch result {
        case .success(let songs):
          let remoteSongs = songs.filter { song in
            !self.playlist.songs.contains(where: { $0.mediaFileId == song.mediaFileId })
          }

          self.playlist.songs.append(contentsOf: remoteSongs)
          self.playlist.songs.sort { $0.trackNumber < $1.trackNumber }

        case .failure(let error):
          self.error = error
        }
      }
    }
  }

  func getPlaylists() {
    AlbumService.shared.getPlaylists { result in
      DispatchQueue.main.async {
        switch result {
        case .success(let playlists):
          self.playlists = playlists
        case .failure(let error):
          self.error = error
        }
      }
    }
  }

  func getArtists() {
    AlbumService.shared.getArtists { result in
      DispatchQueue.main.async {
        switch result {
        case .success(let artists):
          self.artists = artists
        case .failure(let error):
          self.error = error
        }
      }
    }
  }

  func fetchDownloadedAlbums() {
    AlbumService.shared.getDownloadedAlbum { result in
      DispatchQueue.main.async {
        switch result {
        case .success(let albums):
          // TODO: is this expensive?
          self.downloadedAlbums = albums.filter { album in
            let songs = AlbumService.shared.getSongsByAlbumId(albumId: album.id)

            return !songs.isEmpty
          }

        case .failure(let error):
          self.error = error
        }
      }
    }
  }
}
