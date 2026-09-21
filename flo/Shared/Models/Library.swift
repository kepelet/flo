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
