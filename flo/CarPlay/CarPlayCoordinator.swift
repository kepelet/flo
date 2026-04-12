//
//  CarPlayCoordinator.swift
//  flo
//

import CarPlay
import Combine

class CarPlayCoordinator {
  private let interfaceController: CPInterfaceController
  private let playerVM = PlayerViewModel.shared
  private var nowPlayingManager: CarPlayNowPlayingManager?

  init(interfaceController: CPInterfaceController) {
    self.interfaceController = interfaceController
  }

  func start() {
    nowPlayingManager = CarPlayNowPlayingManager(
      playerVM: playerVM, interfaceController: interfaceController)
    nowPlayingManager?.configure()

    let tabBar = CPTabBarTemplate(templates: [
      makeLibraryTab(),
      makePlaylistsTab(),
      makeRadioTab(),
      makeDownloadsTab(),
    ])

    interfaceController.setRootTemplate(tabBar, animated: true, completion: nil)
  }

  func stop() {
    nowPlayingManager?.teardown()
    nowPlayingManager = nil
  }

  // MARK: - Now Playing Navigation

  private func showNowPlaying() {
    if !(interfaceController.topTemplate is CPNowPlayingTemplate) {
      interfaceController.pushTemplate(CPNowPlayingTemplate.shared, animated: true, completion: nil)
    }
  }

  // MARK: - Library Tab

  private func makeLibraryTab() -> CPListTemplate {
    let albumsItem = CPListItem(
      text: String(localized: "Albums"), detailText: nil,
      image: UIImage(systemName: "square.stack")?.withRenderingMode(.alwaysTemplate))
    albumsItem.handler = { [weak self] _, completion in
      self?.showAlbumsList()
      completion()
    }

    let artistsItem = CPListItem(
      text: String(localized: "Artists"), detailText: nil,
      image: UIImage(systemName: "music.mic")?.withRenderingMode(.alwaysTemplate))
    artistsItem.handler = { [weak self] _, completion in
      self?.showArtistsList()
      completion()
    }

    let songsItem = CPListItem(
      text: String(localized: "Songs"), detailText: nil,
      image: UIImage(systemName: "music.note")?.withRenderingMode(.alwaysTemplate))
    songsItem.handler = { [weak self] _, completion in
      self?.showSongsList()
      completion()
    }

    let likedSongsItem = CPListItem(
      text: String(localized: "Liked Songs"), detailText: nil,
      image: UIImage(systemName: "heart.fill")?.withRenderingMode(.alwaysTemplate))
    likedSongsItem.handler = { [weak self] _, completion in
      self?.showLikedSongs()
      completion()
    }

    let section = CPListSection(items: [albumsItem, artistsItem, songsItem, likedSongsItem])
    let template = CPListTemplate(title: String(localized: "Library"), sections: [section])
    template.tabImage = UIImage(systemName: "square.grid.2x2")

    return template
  }

  // MARK: - Albums

  private func showAlbumsList() {
    let loadingTemplate = CPListTemplate(title: String(localized: "Albums"), sections: [])
    interfaceController.pushTemplate(loadingTemplate, animated: true, completion: nil)

    AlbumService.shared.getAlbum { [weak self] result in
      DispatchQueue.main.async {
        guard let self = self else { return }
        switch result {
        case .success(let albums):
          let items = albums.map { album -> CPListItem in
            let item = CPListItem(
              text: album.name,
              detailText: album.albumArtist.isEmpty ? album.artist : album.albumArtist
            )
            item.handler = { [weak self] _, completion in
              self?.showAlbumDetail(album: album, isDownloaded: false)
              completion()
            }
            let coverURL = AlbumService.shared.getAlbumCover(
              artistName: album.albumArtist.isEmpty ? album.artist : album.albumArtist,
              albumName: album.name,
              albumId: album.id,
              albumCover: album.albumCover
            )
            CarPlayImageLoader.loadImage(from: coverURL) { image in
              item.setImage(image)
            }
            return item
          }
          loadingTemplate.updateSections([CPListSection(items: items)])

        case .failure:
          let errorItem = CPListItem(text: String(localized: "Failed to load albums"), detailText: String(localized: "Tap to retry"))
          errorItem.handler = { [weak self] _, completion in
            self?.interfaceController.popTemplate(animated: false, completion: nil)
            self?.showAlbumsList()
            completion()
          }
          loadingTemplate.updateSections([CPListSection(items: [errorItem])])
        }
      }
    }
  }

  // MARK: - Album Detail

  private func showAlbumDetail(album: Album, isDownloaded: Bool) {
    let detailTemplate = CPListTemplate(title: album.name, sections: [])
    interfaceController.pushTemplate(detailTemplate, animated: true, completion: nil)

    AlbumService.shared.getSongFromAlbum(id: album.id) { [weak self] result in
      DispatchQueue.main.async {
        guard let self = self else { return }

        var albumWithSongs = album

        switch result {
        case .success(let songs):
          let localSongs = AlbumService.shared.getSongsByAlbumId(albumId: album.id)
          let remoteSongs = songs.filter { song in
            !localSongs.contains(where: { $0.id == song.id })
          }
          albumWithSongs.songs =
            (localSongs + remoteSongs).sorted {
              if $0.discNumber == $1.discNumber {
                return $0.trackNumber < $1.trackNumber
              }
              return $0.discNumber < $1.discNumber
            }
        case .failure:
          albumWithSongs.songs = AlbumService.shared.getSongsByAlbumId(albumId: album.id)
        }

        self.buildAlbumDetailSections(
          template: detailTemplate,
          album: albumWithSongs,
          isDownloaded: isDownloaded
        )
      }
    }
  }

  private func buildAlbumDetailSections(
    template: CPListTemplate, album: Album, isDownloaded: Bool
  ) {
    let playAllItem = CPListItem(
      text: String(localized: "Play All"),
      detailText: String(localized: "\(album.songs.count) tracks"),
      image: UIImage(systemName: "play.fill")?.withRenderingMode(.alwaysTemplate)
    )
    playAllItem.handler = { [weak self] _, completion in
      self?.playerVM.playItem(item: album, isFromLocal: isDownloaded)
      self?.showNowPlaying()
      completion()
    }

    let shuffleItem = CPListItem(
      text: String(localized: "Shuffle"),
      detailText: nil,
      image: UIImage(systemName: "shuffle")?.withRenderingMode(.alwaysTemplate)
    )
    shuffleItem.handler = { [weak self] _, completion in
      self?.playerVM.shuffleItem(item: album, isFromLocal: isDownloaded)
      self?.showNowPlaying()
      completion()
    }

    let actionSection = CPListSection(items: [playAllItem, shuffleItem])

    let trackItems = album.songs.enumerated().map { (idx, song) -> CPListItem in
      let item = CPListItem(
        text: song.title,
        detailText: song.artist
      )
      item.handler = { [weak self] _, completion in
        self?.playerVM.playBySong(idx: idx, item: album, isFromLocal: isDownloaded)
        self?.showNowPlaying()
        completion()
      }
      return item
    }
    let trackSection = CPListSection(
      items: trackItems,
      header: String(localized: "Tracks"),
      sectionIndexTitle: nil
    )

    template.updateSections([actionSection, trackSection])
  }

  // MARK: - Artists

  private var filterAlbumArtistOnly = true

  private func showArtistsList() {
    let loadingTemplate = CPListTemplate(title: String(localized: "Artists"), sections: [])
    interfaceController.pushTemplate(loadingTemplate, animated: true, completion: nil)

    AlbumService.shared.getArtists { [weak self] result in
      DispatchQueue.main.async {
        guard let self = self else { return }
        switch result {
        case .success(let artists):
          let filteredArtists = artists.filter { artist in
            !self.filterAlbumArtistOnly || artist.stats.albumartist != nil
          }
          let items = filteredArtists.map { artist -> CPListItem in
            let item = CPListItem(
              text: artist.name,
              detailText: String(localized: "\(artist.albumCount) albums")
            )
            item.handler = { [weak self] _, completion in
              self?.showArtistAlbums(artist: artist)
              completion()
            }
            return item
          }
          loadingTemplate.updateSections([CPListSection(items: items)])

        case .failure:
          let errorItem = CPListItem(text: String(localized: "Failed to load artists"), detailText: String(localized: "Tap to retry"))
          errorItem.handler = { [weak self] _, completion in
            self?.interfaceController.popTemplate(animated: false, completion: nil)
            self?.showArtistsList()
            completion()
          }
          loadingTemplate.updateSections([CPListSection(items: [errorItem])])
        }
      }
    }
  }

  private func showArtistAlbums(artist: Artist) {
    let loadingTemplate = CPListTemplate(title: artist.name, sections: [])
    interfaceController.pushTemplate(loadingTemplate, animated: true, completion: nil)

    AlbumService.shared.getAlbumsByArtist(id: artist.id) { [weak self] result in
      DispatchQueue.main.async {
        guard let self = self else { return }
        switch result {
        case .success(let albums):
          let radioItem = CPListItem(
            text: String(localized: "Play Artist Radio"),
            detailText: nil,
            image: UIImage(systemName: "dot.radiowaves.up.forward")
          )
          radioItem.handler = { [weak self] _, completion in
            self?.playArtistRadio(artist: artist)
            completion()
          }

          let topSongsItem = CPListItem(
            text: String(localized: "Play Top Songs"),
            detailText: nil,
            image: UIImage(systemName: "star.fill")
          )
          topSongsItem.handler = { [weak self] _, completion in
            self?.playArtistTopSongs(artist: artist)
            completion()
          }

          let actionSection = CPListSection(items: [radioItem, topSongsItem])

          let albumItems = albums.map { album -> CPListItem in
            let item = CPListItem(
              text: album.name,
              detailText: album.minYear > 0 ? "\(album.minYear)" : nil
            )
            item.handler = { [weak self] _, completion in
              self?.showAlbumDetail(album: album, isDownloaded: false)
              completion()
            }
            let coverURL = AlbumService.shared.getAlbumCover(
              artistName: album.albumArtist,
              albumName: album.name,
              albumId: album.id,
              albumCover: album.albumCover
            )
            CarPlayImageLoader.loadImage(from: coverURL) { image in
              item.setImage(image)
            }
            return item
          }
          let albumSection = CPListSection(
            items: albumItems,
            header: String(localized: "Albums"),
            sectionIndexTitle: nil
          )

          loadingTemplate.updateSections([actionSection, albumSection])

        case .failure:
          loadingTemplate.updateSections([
            CPListSection(items: [
              CPListItem(text: String(localized: "Failed to load albums"), detailText: nil)
            ])
          ])
        }
      }
    }
  }

  // MARK: - Artist Radio & Top Songs

  private func playArtistRadio(artist: Artist) {
    RadioService.shared.getSimilarSongs(id: artist.id) { [weak self] result in
      DispatchQueue.main.async {
        guard let self = self else { return }
        switch result {
        case .success(let songs) where !songs.isEmpty:
          let playable = RadioEntity(
            id: artist.id,
            name: String(localized: "\(artist.name) Radio"),
            songs: songs,
            artist: artist.name
          )
          self.playerVM.playItem(item: playable, isFromLocal: false)
          self.showNowPlaying()
        case .success:
          self.showErrorTemplate(title: String(localized: "No Radio Available"), message: String(localized: "No similar songs found for \(artist.name)."))
        case .failure:
          self.showErrorTemplate(title: String(localized: "Radio Unavailable"), message: String(localized: "Could not load radio for \(artist.name)."))
        }
      }
    }
  }

  private func playArtistTopSongs(artist: Artist) {
    RadioService.shared.getTopSongs(artistName: artist.name, count: 20) { [weak self] result in
      DispatchQueue.main.async {
        guard let self = self else { return }
        switch result {
        case .success(let songs) where !songs.isEmpty:
          let playable = RadioEntity(
            id: artist.id,
            name: String(localized: "\(artist.name) Top Songs"),
            songs: songs,
            artist: artist.name
          )
          self.playerVM.playItem(item: playable, isFromLocal: false)
          self.showNowPlaying()
        case .success:
          self.showErrorTemplate(title: String(localized: "No Top Songs"), message: String(localized: "No top songs found for \(artist.name)."))
        case .failure:
          self.showErrorTemplate(title: String(localized: "Unavailable"), message: String(localized: "Could not load top songs for \(artist.name)."))
        }
      }
    }
  }

  private func showErrorTemplate(title: String, message: String) {
    let item = CPListItem(text: title, detailText: message)
    let template = CPListTemplate(title: title, sections: [CPListSection(items: [item])])
    interfaceController.pushTemplate(template, animated: true, completion: nil)
  }

  // MARK: - Songs

  private func showSongsList() {
    let loadingTemplate = CPListTemplate(title: String(localized: "Songs"), sections: [])
    interfaceController.pushTemplate(loadingTemplate, animated: true, completion: nil)

    AlbumService.shared.getAllSongs { [weak self] result in
      DispatchQueue.main.async {
        guard let self = self else { return }
        switch result {
        case .success(let songs):
          let items = songs.enumerated().map { (idx, song) -> CPListItem in
            let item = CPListItem(
              text: song.title,
              detailText: song.artist
            )
            item.handler = { [weak self] _, completion in
              guard let self = self else { return }
              let allTracks = Playlist(name: String(localized: "All Tracks"), songs: songs)
              self.playerVM.playBySong(idx: idx, item: allTracks, isFromLocal: false)
              self.showNowPlaying()
              completion()
            }
            return item
          }
          loadingTemplate.updateSections([CPListSection(items: items)])

        case .failure:
          let errorItem = CPListItem(text: String(localized: "Failed to load songs"), detailText: String(localized: "Tap to retry"))
          errorItem.handler = { [weak self] _, completion in
            self?.interfaceController.popTemplate(animated: false, completion: nil)
            self?.showSongsList()
            completion()
          }
          loadingTemplate.updateSections([CPListSection(items: [errorItem])])
        }
      }
    }
  }

  // MARK: - Liked Songs

  private func showLikedSongs() {
    let loadingTemplate = CPListTemplate(title: String(localized: "Liked Songs"), sections: [])
    interfaceController.pushTemplate(loadingTemplate, animated: true, completion: nil)

    AlbumService.shared.getStarredSongs { [weak self] result in
      DispatchQueue.main.async {
        guard let self = self else { return }
        switch result {
        case .success(let songs):
          if songs.isEmpty {
            loadingTemplate.updateSections([
              CPListSection(items: [
                CPListItem(text: String(localized: "No liked songs yet"), detailText: nil)
              ])
            ])
            return
          }

          let playAllItem = CPListItem(
            text: String(localized: "Play All"),
            detailText: String(localized: "\(songs.count) songs"),
            image: UIImage(systemName: "play.fill")
          )
          playAllItem.handler = { [weak self] _, completion in
            let collection = SongCollection(id: "liked-songs", name: "Liked Songs", songs: songs)
            self?.playerVM.playItem(item: collection, isFromLocal: false)
            self?.showNowPlaying()
            completion()
          }

          let shuffleItem = CPListItem(
            text: String(localized: "Shuffle"),
            detailText: nil,
            image: UIImage(systemName: "shuffle")
          )
          shuffleItem.handler = { [weak self] _, completion in
            let collection = SongCollection(id: "liked-songs", name: "Liked Songs", songs: songs)
            self?.playerVM.shuffleItem(item: collection, isFromLocal: false)
            self?.showNowPlaying()
            completion()
          }

          let actionSection = CPListSection(items: [playAllItem, shuffleItem])

          let trackItems = songs.enumerated().map { (idx, song) -> CPListItem in
            let item = CPListItem(
              text: song.title,
              detailText: song.artist
            )
            item.handler = { [weak self] _, completion in
              let collection = SongCollection(id: "liked-songs", name: "Liked Songs", songs: songs)
              self?.playerVM.playBySong(idx: idx, item: collection, isFromLocal: false)
              self?.showNowPlaying()
              completion()
            }
            return item
          }
          let trackSection = CPListSection(
            items: trackItems,
            header: String(localized: "Songs"),
            sectionIndexTitle: nil
          )

          loadingTemplate.updateSections([actionSection, trackSection])

        case .failure:
          let errorItem = CPListItem(text: String(localized: "Failed to load liked songs"), detailText: String(localized: "Tap to retry"))
          errorItem.handler = { [weak self] _, completion in
            self?.interfaceController.popTemplate(animated: false, completion: nil)
            self?.showLikedSongs()
            completion()
          }
          loadingTemplate.updateSections([CPListSection(items: [errorItem])])
        }
      }
    }
  }

  // MARK: - Playlists Tab

  private func makePlaylistsTab() -> CPListTemplate {
    let loadingItem = CPListItem(text: String(localized: "Loading playlists…"), detailText: nil)
    loadingItem.isEnabled = false
    let template = CPListTemplate(
      title: String(localized: "Playlists"), sections: [CPListSection(items: [loadingItem])])
    template.tabImage = UIImage(systemName: "music.note.list")

    AlbumService.shared.getPlaylists { [weak self] result in
      DispatchQueue.main.async {
        guard let self = self else { return }
        switch result {
        case .success(let playlists):
          let items = playlists.map { playlist -> CPListItem in
            let item = CPListItem(
              text: playlist.name,
              detailText: playlist.comment.isEmpty ? playlist.ownerName : playlist.comment
            )
            item.handler = { [weak self] _, completion in
              self?.showPlaylistDetail(playlist: playlist)
              completion()
            }
            return item
          }
          template.updateSections([CPListSection(items: items)])

        case .failure:
          template.updateSections([
            CPListSection(items: [
              CPListItem(text: String(localized: "Failed to load playlists"), detailText: nil)
            ])
          ])
        }
      }
    }

    return template
  }

  private func showPlaylistDetail(playlist: Playlist) {
    let detailTemplate = CPListTemplate(title: playlist.name, sections: [])
    interfaceController.pushTemplate(detailTemplate, animated: true, completion: nil)

    AlbumService.shared.getSongsByPlaylist(id: playlist.id) { [weak self] result in
      DispatchQueue.main.async {
        guard let self = self else { return }

        var playlistWithSongs = playlist

        switch result {
        case .success(let songs):
          playlistWithSongs.songs = songs
        case .failure:
          playlistWithSongs.songs = []
        }

        let isDownloaded = AlbumService.shared.checkIfAlbumDownloaded(albumID: playlist.id)
        self.buildPlaylistDetailSections(
          template: detailTemplate,
          playlist: playlistWithSongs,
          isDownloaded: isDownloaded
        )
      }
    }
  }

  private func buildPlaylistDetailSections(
    template: CPListTemplate, playlist: Playlist, isDownloaded: Bool
  ) {
    let playAllItem = CPListItem(
      text: String(localized: "Play All"),
      detailText: String(localized: "\(playlist.songs.count) tracks"),
      image: UIImage(systemName: "play.fill")
    )
    playAllItem.handler = { [weak self] _, completion in
      self?.playerVM.playItem(item: playlist, isFromLocal: isDownloaded)
      self?.showNowPlaying()
      completion()
    }

    let shuffleItem = CPListItem(
      text: String(localized: "Shuffle"),
      detailText: nil,
      image: UIImage(systemName: "shuffle")
    )
    shuffleItem.handler = { [weak self] _, completion in
      self?.playerVM.shuffleItem(item: playlist, isFromLocal: isDownloaded)
      self?.showNowPlaying()
      completion()
    }

    let actionSection = CPListSection(items: [playAllItem, shuffleItem])

    let trackItems = playlist.songs.enumerated().map { (idx, song) -> CPListItem in
      let item = CPListItem(
        text: song.title,
        detailText: song.artist
      )
      item.handler = { [weak self] _, completion in
        self?.playerVM.playBySong(idx: idx, item: playlist, isFromLocal: isDownloaded)
        self?.showNowPlaying()
        completion()
      }
      return item
    }
    let trackSection = CPListSection(
      items: trackItems,
      header: String(localized: "Tracks"),
      sectionIndexTitle: nil
    )

    template.updateSections([actionSection, trackSection])
  }

  // MARK: - Radio Tab

  private func makeRadioTab() -> CPListTemplate {
    let loadingItem = CPListItem(text: String(localized: "Loading stations…"), detailText: nil)
    loadingItem.isEnabled = false
    let template = CPListTemplate(
      title: String(localized: "Radio"), sections: [CPListSection(items: [loadingItem])])
    template.tabImage = UIImage(systemName: "radio")

    RadioService.shared.getAllRadios { [weak self] result in
      DispatchQueue.main.async {
        guard let self = self else { return }
        switch result {
        case .success(let radios):
          if radios.isEmpty {
            template.updateSections([
              CPListSection(items: [
                CPListItem(text: String(localized: "No radio stations"), detailText: nil)
              ])
            ])
            return
          }

          let items = radios.map { radio -> CPListItem in
            let item = CPListItem(
              text: radio.name,
              detailText: nil,
              image: UIImage(systemName: "dot.radiowaves.up.forward")
            )
            item.handler = { [weak self] _, completion in
              self?.playerVM.playRadioItem(radio: radio)
              self?.showNowPlaying()
              completion()
            }
            return item
          }
          template.updateSections([CPListSection(items: items)])

        case .failure:
          template.updateSections([
            CPListSection(items: [
              CPListItem(text: String(localized: "Failed to load radios"), detailText: nil)
            ])
          ])
        }
      }
    }

    return template
  }

  // MARK: - Downloads Tab

  private func makeDownloadsTab() -> CPListTemplate {
    let loadingItem = CPListItem(text: String(localized: "Loading downloads…"), detailText: nil)
    loadingItem.isEnabled = false
    let template = CPListTemplate(
      title: String(localized: "Downloads"), sections: [CPListSection(items: [loadingItem])])
    template.tabImage = UIImage(systemName: "arrow.down.circle")

    AlbumService.shared.getDownloadedAlbum { [weak self] result in
      DispatchQueue.main.async {
        guard let self = self else { return }

        let cachedSongs = StreamCacheManager.shared.getCachedSongs()
        var sections: [CPListSection] = []

        // Cached songs section
        if !cachedSongs.isEmpty {
          let cachedItem = CPListItem(
            text: String(localized: "Cached"),
            detailText: String(localized: "\(cachedSongs.count) songs"),
            image: UIImage(systemName: "music.note.list")?.withRenderingMode(.alwaysTemplate)
          )
          cachedItem.handler = { [weak self] _, completion in
            self?.showCachedSongs(songs: cachedSongs)
            completion()
          }
          sections.append(CPListSection(items: [cachedItem]))
        }

        switch result {
        case .success(let albums):
          let filtered = albums.filter { album in
            !AlbumService.shared.getSongsByAlbumId(albumId: album.id).isEmpty
          }

          if filtered.isEmpty && cachedSongs.isEmpty {
            template.updateSections([
              CPListSection(items: [
                CPListItem(text: String(localized: "No downloads"), detailText: String(localized: "Download music from the app"))
              ])
            ])
            return
          }

          let items = filtered.map { album -> CPListItem in
            let item = CPListItem(
              text: album.name,
              detailText: album.artist
            )
            item.handler = { [weak self] _, completion in
              self?.showAlbumDetail(album: album, isDownloaded: true)
              completion()
            }
            let coverURL = AlbumService.shared.getAlbumCover(
              artistName: album.albumArtist,
              albumName: album.name,
              albumId: album.id,
              albumCover: album.albumCover
            )
            CarPlayImageLoader.loadImage(from: coverURL) { image in
              item.setImage(image)
            }
            return item
          }
          if !items.isEmpty {
            sections.append(CPListSection(
              items: items,
              header: String(localized: "Albums"),
              sectionIndexTitle: nil
            ))
          }
          template.updateSections(sections)

        case .failure:
          if cachedSongs.isEmpty {
            template.updateSections([
              CPListSection(items: [
                CPListItem(text: String(localized: "No downloads available"), detailText: nil)
              ])
            ])
          } else {
            template.updateSections(sections)
          }
        }
      }
    }

    return template
  }

  // MARK: - Cached Songs

  private func showCachedSongs(songs: [Song]) {
    let playAllItem = CPListItem(
      text: String(localized: "Play All"),
      detailText: String(localized: "\(songs.count) songs"),
      image: UIImage(systemName: "play.fill")
    )
    playAllItem.handler = { [weak self] _, completion in
      let collection = SongCollection(id: "cached-songs", name: "Cached", songs: songs)
      self?.playerVM.playItem(item: collection, isFromLocal: true)
      self?.showNowPlaying()
      completion()
    }

    let shuffleItem = CPListItem(
      text: String(localized: "Shuffle"),
      detailText: nil,
      image: UIImage(systemName: "shuffle")
    )
    shuffleItem.handler = { [weak self] _, completion in
      let collection = SongCollection(id: "cached-songs", name: "Cached", songs: songs)
      self?.playerVM.shuffleItem(item: collection, isFromLocal: true)
      self?.showNowPlaying()
      completion()
    }

    let actionSection = CPListSection(items: [playAllItem, shuffleItem])

    let trackItems = songs.enumerated().map { (idx, song) -> CPListItem in
      let item = CPListItem(
        text: song.title,
        detailText: song.artist
      )
      item.handler = { [weak self] _, completion in
        let collection = SongCollection(id: "cached-songs", name: "Cached", songs: songs)
        self?.playerVM.playBySong(idx: idx, item: collection, isFromLocal: true)
        self?.showNowPlaying()
        completion()
      }
      return item
    }
    let trackSection = CPListSection(
      items: trackItems,
      header: String(localized: "Tracks"),
      sectionIndexTitle: nil
    )

    let template = CPListTemplate(title: String(localized: "Cached"), sections: [actionSection, trackSection])
    interfaceController.pushTemplate(template, animated: true, completion: nil)
  }
}
