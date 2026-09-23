//
//  PinnedItem.swift
//  flo
//

import Foundation

enum PinnedKind: String, Codable, CaseIterable {
  case album
  case artist
  case playlist

  var label: String {
    switch self {
    case .album: return "Album"
    case .artist: return "Artist"
    case .playlist: return "Playlist"
    }
  }

  var systemImage: String {
    switch self {
    case .album: return "square.stack.fill"
    case .artist: return "music.mic"
    case .playlist: return "music.note.list"
    }
  }

  /// Action title like "Pin album" / "Unpin artist".
  func toggleTitle(pinned: Bool) -> String {
    "\(pinned ? "Unpin" : "Pin") \(label.lowercased())"
  }
}

/// A user-pinned library item (album, artist or playlist).
/// Pins are identity-based (`kind` + `refId`); the stored name/subtitle are
/// display fallbacks so pins still render before (or without) library data.
struct PinnedItem: Codable, Identifiable, Hashable {
  var kind: PinnedKind
  var refId: String
  var name: String
  var subtitle: String

  var id: String {
    "\(kind.rawValue):\(refId)"
  }

  enum CodingKeys: String, CodingKey {
    case kind
    case refId
    case name
    case subtitle
  }

  init(kind: PinnedKind, refId: String, name: String, subtitle: String = "") {
    self.kind = kind
    self.refId = refId
    self.name = name
    self.subtitle = subtitle
  }

  init(album: Album) {
    self.init(kind: .album, refId: album.id, name: album.name, subtitle: album.albumArtist)
  }

  init(artist: Artist) {
    self.init(kind: .artist, refId: artist.id, name: artist.name)
  }

  init(playlist: Playlist) {
    self.init(kind: .playlist, refId: playlist.id, name: playlist.name, subtitle: playlist.ownerName)
  }

  static func == (lhs: PinnedItem, rhs: PinnedItem) -> Bool {
    lhs.kind == rhs.kind && lhs.refId == rhs.refId
  }

  func hash(into hasher: inout Hasher) {
    hasher.combine(kind)
    hasher.combine(refId)
  }
}
