//
//  Album.swift
//  flo
//
//  Created by rizaldy on 07/06/24.
//

import Foundation

struct Album: Codable, Identifiable {
  var id: String = ""
  var name: String = ""
  var artist: String = ""
  var albumCover: String = ""
  var songs: [Song] = []
  var genre: String = ""
  var minYear: Int = 0

  enum CodingKeys: String, CodingKey {
    case id
    case name
    case artist
    case genre
    case minYear
    case songs
  }

  init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    self.id = try container.decode(String.self, forKey: .id)
    self.name = try container.decode(String.self, forKey: .name)
    self.artist = try container.decode(String.self, forKey: .artist)
    self.genre = try container.decode(String.self, forKey: .genre)
    self.minYear = try container.decode(Int.self, forKey: .minYear)
    self.songs = try container.decodeIfPresent([Song].self, forKey: .songs) ?? []
  }

  init(
    id: String = "", name: String = "", artist: String = "", songs: [Song] = [], genre: String = "",
    minYear: Int = 0
  ) {
    self.id = id
    self.name = name
    self.artist = artist
    self.songs = songs
    self.genre = genre
    self.minYear = minYear
  }
}
