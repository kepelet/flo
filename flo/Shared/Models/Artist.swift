//
//  Artist.swift
//  flo
//
//  Created by rizaldy on 14/11/24.
//

import Foundation

struct Artist: Codable, Identifiable, Hashable {
  let id: String
  let name: String
  let fullText: String
  let biography: String

  init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    self.id = try container.decode(String.self, forKey: .id)
    self.name = try container.decode(String.self, forKey: .name)
    self.fullText = try container.decodeIfPresent(String.self, forKey: .fullText) ?? ""
    self.biography = try container.decodeIfPresent(String.self, forKey: .biography) ?? ""
  }
}
