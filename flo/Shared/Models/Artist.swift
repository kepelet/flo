//
//  Artist.swift
//  flo
//
//  Created by rizaldy on 14/11/24.
//

import Foundation

struct Artist: Codable, Hashable, Identifiable {
  static func == (lhs: Artist, rhs: Artist) -> Bool {
    lhs.id == rhs.id
  }
  
  func hash(into hasher: inout Hasher) {
    hasher.combine(id)
  }
  
  let id, name, orderArtistName: String
  let stats: ArtistStats
  let size, albumCount, songCount: Int
  let missing: Bool
  let createdAt, updatedAt: String
  let sortArtistName: String?
  let playCount: Int?
  let playDate, mbzArtistID, biography: String?
  let smallImageURL, mediumImageURL, largeImageURL: String?
  let externalURL: String?
  let externalInfoUpdatedAt: String?
  let fullText: String?
  
  enum CodingKeys: String, CodingKey {
    case id, name, orderArtistName, stats, size, albumCount, songCount, missing, createdAt, updatedAt, sortArtistName, playCount, playDate, fullText
    case mbzArtistID = "mbzArtistId"
    case biography
    case smallImageURL = "smallImageUrl"
    case mediumImageURL = "mediumImageUrl"
    case largeImageURL = "largeImageUrl"
    case externalURL = "externalUrl"
    case externalInfoUpdatedAt
  }
}

// MARK: - Stats
struct ArtistStats: Codable {
  let producer, composer, artist, maincredit: Albumartist?
  let albumartist, arranger, engineer, performer: Albumartist?
  let mixer, lyricist, conductor: Albumartist?
}

// MARK: - Albumartist
struct Albumartist: Codable {
  let songCount, albumCount, size: Int
}
