//    flo

import Foundation
import Combine

class ArtistDetailViewModel: ObservableObject {
  var playableSongs: PassthroughSubject<[Song], Never> = .init()

  @Published var isLoadingRadio = false
  @Published var isLoadingTopSongs = false
  @Published var errorMessage: String? = nil

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
