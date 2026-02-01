//
//  LRCLIB.swift
//  flo
//
//  Created by rizaldy on 01/02/26.
//

import Foundation

struct LRCLIBLyrics: Codable {
  let id: Int?
  let name: String?
  let trackName: String?
  let artistName: String?
  let albumName: String?
  let instrumental: Bool?
  let plainLyrics: String?
  let syncedLyrics: String?

  private let _duration: Double?

  var duration: Int? {
    guard let dur = _duration else { return nil }

    return Int(dur.rounded())
  }

  enum CodingKeys: String, CodingKey {
    case id
    case name
    case trackName
    case artistName
    case albumName
    case _duration = "duration"
    case instrumental
    case plainLyrics
    case syncedLyrics
  }
}
