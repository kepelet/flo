//
//  QueueSupport.swift
//  flo
//
//  Shared queue-row logic used by both the phone queue sheet
//  (QueueSheetView) and the pad/Catalyst right sidebar
//  (PlayerSidePanelView): downloads, likes, navigation, the row
//  context menu, and drag-and-drop reorder delegates.
//

import SwiftUI
import UniformTypeIdentifiers

/// Per-container queue-row state (starred/downloaded id sets + actions).
final class QueueRowStore: ObservableObject {
  @Published var starredIds = Set<String>()
  @Published var downloadedIds = Set<String>()

  // MARK: - Converters

  static func song(from item: QueueEntity) -> Song {
    Song(
      id: item.id ?? "", title: item.songName ?? "", albumId: item.albumId ?? "",
      albumName: item.albumName ?? "", artist: item.artistName ?? "",
      trackNumber: 0, discNumber: 0,
      bitRate: Int(item.bitRate), sampleRate: Int(item.sampleRate),
      suffix: item.suffix ?? "", duration: item.duration,
      mediaFileId: item.id ?? "",
      explicitStatus: ExplicitStatus(from: item.explicitStatus))
  }

  static func album(for item: QueueEntity, song: Song) -> Album {
    Album(
      id: item.albumId ?? "", name: item.albumName ?? "",
      albumArtist: item.artistName ?? "", artist: item.artistName ?? "",
      songs: [song])
  }

  // MARK: - Refresh

  func refreshStars() {
    AlbumService.shared.getStarredSongs { result in
      DispatchQueue.main.async {
        if case .success(let songs) = result {
          var ids = Set<String>()
          for song in songs {
            if !song.id.isEmpty { ids.insert(song.id) }
            if !song.mediaFileId.isEmpty { ids.insert(song.mediaFileId) }
          }
          self.starredIds = ids
        }
      }
    }
  }

  func refreshDownloads(queue: [QueueEntity]) {
    var ids = Set<String>()
    for item in queue {
      guard let id = item.id, !id.isEmpty else { continue }
      let records = CoreDataManager.shared.getRecordByKey(
        entity: SongEntity.self, key: \SongEntity.mediaFileId, value: id, limit: 1)
      if let file = records.first?.fileURL, !file.isEmpty,
        LocalFileManager.shared.fileExists(fileName: file)
      {
        ids.insert(id)
      }
    }
    downloadedIds = ids
  }

  func isStarred(_ song: QueueEntity) -> Bool {
    guard let id = song.id else { return false }
    return starredIds.contains(id)
  }

  func isDownloaded(_ song: QueueEntity) -> Bool {
    guard let id = song.id else { return false }
    return downloadedIds.contains(id)
  }

  // MARK: - Actions

  func downloadSong(
    albums: AlbumViewModel, downloads: DownloadViewModel, song: QueueEntity
  ) {
    let single = Self.song(from: song)
    let wrapper = Self.album(for: song, song: single)

    albums.downloadAlbum(wrapper)
    downloads.addIndividualItem(album: wrapper, song: single)
  }

  func removeDownload(song: QueueEntity) {
    guard let songId = song.id, !songId.isEmpty else { return }

    AlbumService.shared.removeDownloadedSong(
      albumId: song.albumId ?? "", songId: songId
    ) { [weak self] _ in
      DispatchQueue.main.async {
        self?.downloadedIds.remove(songId)
      }
    }
  }

  func toggleLike(player: PlayerViewModel, idx: Int, song: QueueEntity) {
    guard let songId = song.id, !songId.isEmpty else { return }
    let currentlyStarred = starredIds.contains(songId)

    let action = currentlyStarred ? AlbumService.shared.unstarSong : AlbumService.shared.starSong
    action(songId) { [weak self] success in
      guard success else { return }
      DispatchQueue.main.async {
        if currentlyStarred {
          self?.starredIds.remove(songId)
        } else {
          self?.starredIds.insert(songId)
        }
        if idx == player.activeQueueIdx {
          player.isStarred = !currentlyStarred
        }
      }
    }
  }
}

/// Long-press / right-click menu for a queue row. Shared by the phone
/// sheet and the pad/Catalyst sidebar.
struct QueueRowMenu: View {
  @ObservedObject var player: PlayerViewModel
  @ObservedObject var albums: AlbumViewModel
  @ObservedObject var store: QueueRowStore

  @EnvironmentObject var downloads: DownloadViewModel

  let idx: Int
  let song: QueueEntity

  var onNavigate: ((LibraryDestination) -> Void)?

  var body: some View {
    let songId = song.id ?? ""
    let starred = store.isStarred(song)
    let downloaded = store.isDownloaded(song)

    Button {
      player.playFromQueue(idx: idx)
    } label: {
      Label("Play", systemImage: "play.fill")
    }

    Button {
      player.moveToTop(idx: idx)
    } label: {
      Label("Move to Top", systemImage: "arrow.up.to.line")
    }
    .disabled(idx == 0)

    if downloaded {
      Button(role: .destructive) {
        store.removeDownload(song: song)
      } label: {
        Label("Remove Download", systemImage: "arrow.down.circle")
      }
    } else {
      Button {
        store.downloadSong(albums: albums, downloads: downloads, song: song)
      } label: {
        Label("Download", systemImage: "arrow.down.circle")
      }
      .disabled(songId.isEmpty)
    }

    Button {
      store.toggleLike(player: player, idx: idx, song: song)
    } label: {
      Label(
        starred ? "Unlike" : "Like",
        systemImage: starred ? "heart.slash" : "heart")
    }
    .disabled(songId.isEmpty)

    Button {
      goToAlbum()
    } label: {
      Label("Go to Album", systemImage: "square.stack")
    }
    .disabled((song.albumId ?? "").isEmpty)

    Button {
      goToArtist()
    } label: {
      Label("Go to Artist", systemImage: "music.mic")
    }
    .disabled((song.artistName ?? "").isEmpty)

    Button(role: .destructive) {
      player.removeFromQueue(at: idx)
    } label: {
      Label("Remove from Queue", systemImage: "trash")
    }
  }

  private func goToAlbum() {
    guard
      let album = albums.albumForNavigation(
        id: song.albumId ?? "", name: song.albumName ?? "", artist: song.artistName ?? "")
    else { return }

    onNavigate?(.album(id: album.id, name: album.name, artist: album.albumArtist))
  }

  private func goToArtist() {
    guard let artist = albums.artistForNavigation(name: song.artistName ?? "") else { return }

    onNavigate?(.artist(id: artist.id, name: artist.name))
  }
}

/// Album-level queue buttons for grid cells (right-click on Catalyst).
/// Songs resolve on tap: downloads play offline, otherwise they stream.
struct AlbumQueueMenu: View {
  @ObservedObject var player: PlayerViewModel
  let album: Album

  var body: some View {
    Button {
      player.playNext(album: album)
    } label: {
      Label("Play Next", systemImage: "text.insert")
    }

    Button {
      player.playAfter(album: album)
    } label: {
      Label("Play After", systemImage: "text.append")
    }

    Button {
      player.appendToQueue(album: album)
    } label: {
      Label("Add to Queue", systemImage: "text.badge.plus")
    }
  }
}

/// Playlist-level queue buttons for grid cells (right-click on Catalyst).
struct PlaylistQueueMenu: View {
  @ObservedObject var player: PlayerViewModel
  let playlist: Playlist

  var body: some View {
    Button {
      player.playNext(playlist: playlist)
    } label: {
      Label("Play Next", systemImage: "text.insert")
    }

    Button {
      player.playAfter(playlist: playlist)
    } label: {
      Label("Play After", systemImage: "text.append")
    }

    Button {
      player.appendToQueue(playlist: playlist)
    } label: {
      Label("Add to Queue", systemImage: "text.badge.plus")
    }
  }
}

// MARK: - Drag-and-drop reorder (Catalyst + pad sidebar)

/// Hover reorders in memory; the drop persists the new order. Persisting
/// mid-drag would recreate the entities and break the drag session.
/// Also drives the drop-target highlight (`dropTargetIdx`/`dropEdge`).
struct QueueReorderDropDelegate: DropDelegate {
  let player: PlayerViewModel
  let targetIdx: Int
  @Binding var draggingIdx: Int?
  @Binding var dropTargetIdx: Int?
  @Binding var dropEdge: Edge?

  func validateDrop(info: DropInfo) -> Bool {
    draggingIdx != nil
  }

  func dropUpdated(info: DropInfo) -> DropProposal? {
    DropProposal(operation: .move)
  }

  func dropEntered(info: DropInfo) {
    guard let from = draggingIdx, from != targetIdx else { return }
    guard player.queue.indices.contains(from),
      player.queue.indices.contains(targetIdx)
    else { return }
    // Hover only previews the landing spot; the reorder commits on release.
    withAnimation(.default) {
      dropEdge = targetIdx > from ? .bottom : .top
      dropTargetIdx = targetIdx
    }
  }

  func dropExited(info: DropInfo) {
    // Only clear our own stale highlight; enter/exit order varies.
    if dropTargetIdx == targetIdx {
      dropTargetIdx = nil
      dropEdge = nil
    }
  }

  func performDrop(info: DropInfo) -> Bool {
    if let from = draggingIdx {
      let target = dropTargetIdx ?? targetIdx
      if from != target, player.queue.indices.contains(from),
        player.queue.indices.contains(target)
      {
        withAnimation(.default) {
          player.moveQueueInMemory(
            from: IndexSet(integer: from),
            to: target > from ? target + 1 : target)
        }
      }
    }
    player.saveQueueOrder()
    draggingIdx = nil
    dropTargetIdx = nil
    dropEdge = nil
    return true
  }
}

/// Fallback so drops into list gaps (e.g. below the last row) still persist.
struct QueueListDropDelegate: DropDelegate {
  let player: PlayerViewModel
  @Binding var draggingIdx: Int?
  @Binding var dropTargetIdx: Int?
  @Binding var dropEdge: Edge?

  func validateDrop(info: DropInfo) -> Bool {
    draggingIdx != nil
  }

  func performDrop(info: DropInfo) -> Bool {
    // Dropped into a gap (e.g. below the last row): move to the end.
    if let from = draggingIdx, player.queue.indices.contains(from),
      from != player.queue.count - 1
    {
      withAnimation(.default) {
        player.moveQueueInMemory(
          from: IndexSet(integer: from), to: player.queue.count)
      }
    }
    player.saveQueueOrder()
    draggingIdx = nil
    dropTargetIdx = nil
    dropEdge = nil
    return true
  }
}
