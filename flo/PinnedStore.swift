//
//  PinnedStore.swift
//  flo
//

import Foundation

/// Single source of truth for pinned library items (albums, artists, playlists).
/// Pins are kept in pin order (most recently pinned first) and persisted to
/// UserDefaults so they survive relaunch. One-time migration picks up pins
/// stored by the previous downloads-only format.
class PinnedStore: ObservableObject {
  @Published private(set) var items: [PinnedItem] = []

  init() {
    let stored = UserDefaultsManager.pinnedItems
    if stored.isEmpty {
      let legacy = UserDefaultsManager.pinnedAlbumIds
      if !legacy.isEmpty {
        items = legacy.map { PinnedItem(kind: .album, refId: $0, name: "", subtitle: "") }
        persist()
        UserDefaultsManager.pinnedAlbumIds = []
      }
    } else {
      items = stored
    }
  }

  // MARK: - Queries

  func isPinned(kind: PinnedKind, refId: String) -> Bool {
    guard !refId.isEmpty else { return false }
    return items.contains(where: { $0.kind == kind && $0.refId == refId })
  }

  func isPinned(_ item: PinnedItem) -> Bool {
    isPinned(kind: item.kind, refId: item.refId)
  }

  func isPinned(album: Album) -> Bool {
    isPinned(kind: .album, refId: album.id)
  }

  func isPinned(artist: Artist) -> Bool {
    isPinned(kind: .artist, refId: artist.id)
  }

  func isPinned(playlist: Playlist) -> Bool {
    isPinned(kind: .playlist, refId: playlist.id)
  }

  /// Album pins in pin order, for sorting download grids.
  var albumPinOrder: [String] {
    items.filter { $0.kind == .album }.map(\.refId)
  }

  static func sortedAlbumPinsFirst(albums: [Album], order: [String]) -> [Album] {
    let rank = Dictionary(uniqueKeysWithValues: order.enumerated().map { ($1, $0) })
    return albums.sorted { lhs, rhs in
      switch (rank[lhs.id], rank[rhs.id]) {
      case let (l?, r?): return l < r
      case (_?, nil): return true
      case (nil, _?): return false
      case (nil, nil): return false
      }
    }
  }

  // MARK: - Mutations

  func pin(_ item: PinnedItem) {
    guard !item.refId.isEmpty else { return }
    if let idx = items.firstIndex(where: { $0 == item }) {
      // Refresh the cached display name (library renames, migration backfill).
      if !item.name.isEmpty, items[idx].name != item.name || items[idx].subtitle != item.subtitle {
        items[idx].name = item.name
        items[idx].subtitle = item.subtitle
        persist()
      }
      return
    }
    items.insert(item, at: 0)
    persist()
  }

  func pin(album: Album) {
    pin(PinnedItem(album: album))
  }

  func pin(artist: Artist) {
    pin(PinnedItem(artist: artist))
  }

  func pin(playlist: Playlist) {
    pin(PinnedItem(playlist: playlist))
  }

  func unpin(kind: PinnedKind, refId: String) {
    guard items.contains(where: { $0.kind == kind && $0.refId == refId }) else { return }
    items.removeAll(where: { $0.kind == kind && $0.refId == refId })
    persist()
  }

  func unpin(_ item: PinnedItem) {
    unpin(kind: item.kind, refId: item.refId)
  }

  func toggle(_ item: PinnedItem) {
    if isPinned(item) {
      unpin(item)
    } else {
      pin(item)
    }
  }

  func toggle(album: Album) {
    toggle(PinnedItem(album: album))
  }

  func toggle(artist: Artist) {
    toggle(PinnedItem(artist: artist))
  }

  func toggle(playlist: Playlist) {
    toggle(PinnedItem(playlist: playlist))
  }

  // MARK: - Persistence

  private func persist() {
    UserDefaultsManager.pinnedItems = items
  }
}
