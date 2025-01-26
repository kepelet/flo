//
//  Song.swift
//  flo
//
//  Created by rizaldy on 09/06/24.
//

import Foundation

struct Song: Codable, Identifiable, Hashable {
  let id: String
  let title: String
  let artist: String
  let albumId: String
  let trackNumber: Int
  let discNumber: Int
  let bitRate: Int
  let sampleRate: Int
  let suffix: String
  let duration: Double

  var mediaFileId: String = ""
  var fileUrl: String = ""

  enum CodingKeys: CodingKey {
    case id
    case title
    case artist
    case albumId
    case trackNumber
    case discNumber
    case bitRate
    case sampleRate
    case suffix
    case duration
    case mediaFileId
  }

  init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    self.id = try container.decode(String.self, forKey: .id)
    self.title = try container.decode(String.self, forKey: .title)
    self.artist = try container.decode(String.self, forKey: .artist)
    self.albumId = try container.decode(String.self, forKey: .albumId)
    self.trackNumber = try container.decode(Int.self, forKey: .trackNumber)
    self.discNumber = try container.decode(Int.self, forKey: .discNumber)
    self.bitRate = try container.decode(Int.self, forKey: .bitRate)
    self.sampleRate = try container.decode(Int.self, forKey: .sampleRate)
    self.suffix = try container.decode(String.self, forKey: .suffix)
    self.duration = try container.decode(Double.self, forKey: .duration)
    self.mediaFileId = try container.decodeIfPresent(String.self, forKey: .mediaFileId) ?? ""
  }

  init(
    id: String, title: String, albumId: String, artist: String, trackNumber: Int, discNumber: Int,
    bitRate: Int,
    sampleRate: Int,
    suffix: String, duration: Double, mediaFileId: String
  ) {
    self.id = id
    self.title = title
    self.artist = artist
    self.albumId = albumId
    self.trackNumber = Int(trackNumber)
    self.discNumber = Int(discNumber)
    self.bitRate = Int(bitRate)
    self.sampleRate = Int(sampleRate)
    self.suffix = suffix
    self.duration = duration
    self.mediaFileId = mediaFileId
  }

  init(from song: SongEntity) {
    self.id = song.id ?? ""
    self.title = song.title ?? "N/A"
    self.artist = song.artistName ?? "N/A"
    self.albumId = song.albumId ?? ""
    self.trackNumber = Int(song.trackNumber)
    self.discNumber = Int(song.discNumber)
    self.bitRate = Int(song.bitRate)
    self.sampleRate = Int(song.sampleRate)
    self.suffix = song.suffix ?? "N/A"
    self.duration = song.duration
    self.fileUrl = song.fileURL ?? ""
    self.mediaFileId = song.mediaFileId ?? ""
  }
}
