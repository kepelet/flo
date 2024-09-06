//
//  AlbumViewModel.swift
//  flo
//
//  Created by rizaldy on 07/06/24.
//

import Foundation

class AlbumViewModel: ObservableObject {
  @Published var albums: [Album] = []
  @Published var album: Album = Album()
  @Published var downloadedAlbums: [Album] = []

  @Published var isDownloading = false
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

          self.album.songs.append(contentsOf: remoteSongs)

        case .failure(let error):
          self.error = error
        }
      }
    }

    if checkLocalSongs.first != nil {
      if checkLocalSongs.isEmpty {
        isLoading = true
        AlbumService.shared.getSongFromAlbum(id: id) { result in
          DispatchQueue.main.async {
            self.isLoading = false

            switch result {
            case .success(let songs):
              self.album.songs = songs

            case .failure(let error):
              self.error = error
            }
          }
        }
      }
    } else {
      isLoading = true
      AlbumService.shared.getSongFromAlbum(id: id) { result in
        DispatchQueue.main.async {
          self.isLoading = false

          switch result {
          case .success(let songs):
            self.album.songs = songs

          case .failure(let error):
            self.error = error
          }
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

  //FIXME: this function is mess. refactor later
  func downloadAlbum() {
    self.isDownloading = true

    AlbumService.shared.downloadAlbumCover(
      artistName: self.album.artist, albumId: self.album.id, albumName: self.album.name
    ) { result in
      switch result {
      case .success:
        if !AlbumService.shared.checkIfAlbumDownloaded(albumID: self.album.id) {
          let album = PlaylistEntity(context: CoreDataManager.shared.viewContext)

          album.id = self.album.id
          album.name = self.album.name
          album.genre = self.album.genre
          album.minYear = Int64(self.album.minYear)
          album.artistName = self.album.artist

          CoreDataManager.shared.saveRecord()
        }
      case .failure(let error):
        self.isDownloading = false
        print("Failed to save image: \(error.localizedDescription)")
      }
    }

    let dispatchGroup = DispatchGroup()

    self.isDownloading = true

    for song in self.album.songs {
      dispatchGroup.enter()

      AlbumService.shared.download(
        artistName: self.album.artist, albumName: self.album.name, id: song.id,
        trackNumber: song.trackNumber.description, title: song.title, suffix: song.suffix
      ) { result in
        switch result {
        case .success(let fileURL):
          DispatchQueue.main.async {
            if let fileURL = fileURL {
              AlbumService.shared.saveDownload(
                albumId: self.album.id, albumName: self.album.name, song: song, fileURL: fileURL,
                status: "Downloaded")
            }
          }
        case .failure(let error):
          print(error)
          self.isDownloading = false
        }

        dispatchGroup.leave()
      }
    }

    dispatchGroup.notify(queue: .main) {
      self.fetchSongs(id: self.album.id)
      self.isDownloading = false
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

  func fetchDownloadedAlbums() {
    AlbumService.shared.getDownloadedAlbum { result in
      DispatchQueue.main.async {
        switch result {
        case .success(let albums):
          self.downloadedAlbums = albums
        case .failure(let error):
          self.error = error
        }
      }
    }
  }
}
