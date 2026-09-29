//    flo

import Foundation
import Combine

class ArtistDetailViewModel: ObservableObject {
  var playableSongs: PassthroughSubject<[Song], Never> = .init()

  @Published var isLoadingRadio = false
  @Published var isLoadingTopSongs = false
  @Published var isLoadingTracks = false
  @Published var errorMessage: String? = nil

  /// Fetches every track across the artist's albums, preserving album order
  /// and sorting songs within each album by disc/track number.
  func fetchArtistSongs(albums: [Album], completion: @escaping ([Song]) -> Void) {
    guard !albums.isEmpty else {
      completion([])
      return
    }

    isLoadingTracks = true

    let group = DispatchGroup()
    var songsByAlbum: [[Song]] = Array(repeating: [], count: albums.count)
    let lock = NSLock()

    for (index, album) in albums.enumerated() {
      group.enter()
      AlbumService.shared.getSongFromAlbum(id: album.id) { result in
        if case .success(let songs) = result {
          let sorted = songs.sorted {
            if $0.discNumber == $1.discNumber {
              return $0.trackNumber < $1.trackNumber
            }
            return $0.discNumber < $1.discNumber
          }
          lock.lock()
          songsByAlbum[index] = sorted
          lock.unlock()
        }
        group.leave()
      }
    }

    group.notify(queue: .main) { [weak self] in
      guard let self else { return }
      self.isLoadingTracks = false
      completion(songsByAlbum.flatMap { $0 })
    }
  }

  func fetchArtistRadio(artist: Artist) {
    isLoadingRadio = true

    RadioService.shared.getSimilarSongs(id: artist.id) { [weak self] result in
      DispatchQueue.main.async {
        guard let self else { return }

        self.isLoadingRadio = false

        switch result {
        case .success(let songs):
          if songs.isEmpty {
            self.errorMessage = "No similar songs found for this artist."
          }

          self.playableSongs.send(songs)
        case .failure(_):
          self.errorMessage = "Failed to load Artist Radio. Please try again."
          self.playableSongs.send([])
        }
      }
    }
  }

  func fetchTopSongs(artist: Artist) {
    isLoadingTopSongs = true

    RadioService.shared.getTopSongs(artistName: artist.name, count: 20) { [weak self] result in
      DispatchQueue.main.async {
        guard let self else { return }

        self.isLoadingTopSongs = false

        switch result {
        case .success(let songs):
          if songs.isEmpty {
            self.errorMessage = "No top songs found for this artist."
          }
          self.playableSongs.send(songs)
        case .failure(_):
          self.errorMessage = "Failed to load Artist Top Songs. Please try again."
          self.playableSongs.send([])
        }
      }
    }
  }
}
