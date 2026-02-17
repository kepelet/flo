//
//  WatchLibraryViewModel.swift
//  flo
//
//  Created by Codex on 17/02/26.
//

#if os(watchOS)
import Foundation

@MainActor
final class WatchLibraryViewModel: ObservableObject {
  @Published var albums: [Album] = []
  @Published var artists: [Artist] = []
  @Published var playlists: [Playlist] = []
  @Published var albumSongs: [String: [Song]] = [:]
  @Published var playlistSongs: [String: [Song]] = [:]
  @Published var artistAlbums: [String: [Album]] = [:]
  @Published var isLoading = false
  @Published var errorMessage: String?

  private let connectivity = WatchConnectivityManager.shared

  func loadAlbums() {
    requestLibrary(type: "albums") { (result: Result<[Album], Error>) in
      switch result {
      case .success(let albums):
        self.albums = albums
      case .failure(let error):
        self.errorMessage = error.localizedDescription
      }
    }
  }

  func loadArtists() {
    requestLibrary(type: "artists") { (result: Result<[Artist], Error>) in
      switch result {
      case .success(let artists):
        self.artists = artists
      case .failure(let error):
        self.errorMessage = error.localizedDescription
      }
    }
  }

  func loadPlaylists() {
    requestLibrary(type: "playlists") { (result: Result<[Playlist], Error>) in
      switch result {
      case .success(let playlists):
        self.playlists = playlists
      case .failure(let error):
        self.errorMessage = error.localizedDescription
      }
    }
  }

  func loadSongs(for album: Album) {
    if albumSongs[album.id] != nil {
      return
    }

    requestLibrary(type: "albumSongs", parameters: ["id": album.id]) { (result: Result<[Song], Error>) in
      switch result {
      case .success(let songs):
        self.albumSongs[album.id] = songs
      case .failure(let error):
        self.errorMessage = error.localizedDescription
      }
    }
  }

  func loadSongs(for playlist: Playlist) {
    if playlistSongs[playlist.id] != nil {
      return
    }

    requestLibrary(type: "playlistSongs", parameters: ["id": playlist.id]) { (result: Result<[Song], Error>) in
      switch result {
      case .success(let songs):
        self.playlistSongs[playlist.id] = songs
      case .failure(let error):
        self.errorMessage = error.localizedDescription
      }
    }
  }

  func loadAlbums(for artist: Artist) {
    if artistAlbums[artist.id] != nil {
      return
    }

    requestLibrary(type: "artistAlbums", parameters: ["id": artist.id]) { (result: Result<[Album], Error>) in
      switch result {
      case .success(let albums):
        self.artistAlbums[artist.id] = albums
      case .failure(let error):
        self.errorMessage = error.localizedDescription
      }
    }
  }

  private func requestLibrary<T: Decodable>(
    type: String,
    parameters: [String: Any] = [:],
    completion: @escaping (Result<[T], Error>) -> Void
  ) {
    isLoading = true
    errorMessage = nil

    connectivity.requestLibrary(type: type, parameters: parameters) { result in
      DispatchQueue.main.async {
        self.isLoading = false
        switch result {
        case .success(let payload):
          guard let items: [T] = Self.decodeArray(from: payload) else {
            completion(.failure(NSError(domain: "flo.watch", code: -1)))
            return
          }
          completion(.success(items))
        case .failure(let error):
          completion(.failure(error))
        }
      }
    }
  }

  private static func decodeArray<T: Decodable>(from payload: Any) -> [T]? {
    guard let data = try? JSONSerialization.data(withJSONObject: payload) else {
      return nil
    }

    return try? JSONDecoder().decode([T].self, from: data)
  }
}
#endif
