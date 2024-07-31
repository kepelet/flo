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

  func ifNotDownloadable(isDownloadScreen: Bool) -> Bool {
    //TODO: add logic to check server-side config
    if isDownloadScreen {
      return true
    }

    return false
  }

  func setActiveAlbum(album: Album) {
    self.album = album
    self.album.albumCover = self.getAlbumArt(id: album.id)

    if !album.id.isEmpty {
      self.fetchSongs(id: album.id)
    }
  }

  func fetchSongs(id: String) {
    isLoading = true
    AlbumService.shared.getSongFromAlbum(id: id) { [weak self] result in
      DispatchQueue.main.async {
        self?.isLoading = false

        switch result {
        case .success(let songs):
          self?.album.songs = songs

        case .failure(let error):
          self?.error = error
        }
      }
    }
  }

  func getAlbumInfo() {
    AlbumService.shared.getAlbumInfo(id: self.album.id) { [weak self] result in
      DispatchQueue.main.async {
        switch result {
        case .success(let response):
          if let albumInfo = response.subsonicResponse.albumInfo.notes {
            let regex = try! NSRegularExpression(pattern: "<a href=\".*\">.*</a>\\.")
            let range = NSRange(location: 0, length: albumInfo.utf16.count)

            let stripped = regex.stringByReplacingMatches(
              in: albumInfo, range: range, withTemplate: "")

            self?.album.info = stripped
          } else {
            self?.album.info = "Description Unavailable"
          }

        case .failure(let error):
          self?.error = error
        }
      }
    }
  }

  func getStreamUrl(id: String) -> String {
    return AlbumService.shared.getStreamUrl(id: id)
  }

  func getAlbumArt(id: String) -> String {
    return AlbumService.shared.getCoverArt(id: id)
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

  func fetchAlbums() {
    isLoading = true
    AlbumService.shared.getAlbum { [weak self] result in
      DispatchQueue.main.async {
        self?.isLoading = false
        switch result {
        case .success(let albums):
          self?.albums = albums
        case .failure(let error):
          print("error>>>>", error)
          self?.error = error
        }
      }
    }
  }
}
