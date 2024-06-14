//
//  AlbumViewModel.swift
//  flo
//
//  Created by rizaldy on 07/06/24.
//

import Foundation

class AlbumViewModel: ObservableObject {
  @Published var albums: [Album] = []
  @Published var songs: [Song] = []
  @Published var album: Album = Album()

  @Published var isLoading = false
  @Published var error: Error?

  private let albumService = AlbumService()

  init(albums: [Album] = [Album()], songs: [Song] = []) {
    self.albums = albums
    self.songs = songs
  }

  func fetchSongs(id: String) {
    isLoading = true
    albumService.getSongFromAlbum(id: id) { [weak self] result in
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

  func getStreamUrl(id: String) -> String {
    return albumService.getStreamUrl(id: id)
  }

  func getAlbumArt(id: String) -> String {
    return albumService.getCoverArt(id: id)
  }

  func fetchAlbums() {
    isLoading = true
    albumService.getAlbum { [weak self] result in
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
