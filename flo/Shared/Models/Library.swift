//
//  Library.swift
//  flo
//
//  Represents a Navidrome music library (music folder). Navidrome supports
//  multiple libraries and each album belongs to exactly one of them.
//

import Foundation

struct Library: Codable, Identifiable, Hashable {
  let id: Int
  let name: String

  enum CodingKeys: String, CodingKey {
    case id
    case name
  }

  init(id: Int, name: String) {
    self.id = id
    self.name = name
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    self.id = try container.decode(Int.self, forKey: .id)
    self.name = try container.decodeIfPresent(String.self, forKey: .name) ?? "Library \(self.id)"
  }
}

/// Shared album scope for the library overview and the sidebar album grid.
struct AlbumLibraryScope {
  let libraries: [Library]
  let selectedLibraryId: Int
  let audioplayLibraryId: Int

  var selectableLibraries: [Library] {
    libraries.filter { $0.id != audioplayLibraryId }
  }

  var effectiveLibraryId: Int {
    guard selectedLibraryId != audioplayLibraryId else { return 0 }
    // Keep a saved filter while the library list is still loading/offline.
    guard libraries.isEmpty || selectableLibraries.contains(where: { $0.id == selectedLibraryId }) else {
      return 0
    }
    return selectedLibraryId
  }

  func musicAlbums(from albums: [Album]) -> [Album] {
    let libraryId = effectiveLibraryId
    return albums.filter {
      (audioplayLibraryId == 0 || $0.libraryId != audioplayLibraryId)
        && (libraryId == 0 || $0.libraryId == libraryId)
    }
  }

  func audioplays(from albums: [Album]) -> [Album] {
    albums.filter { audioplayLibraryId != 0 && $0.libraryId == audioplayLibraryId }
  }
}
