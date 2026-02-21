//
//  Radio.swift
//  flo
//
//  Created by Francesco (f-longobardi)
//

import Foundation

struct RadioList: SubsonicResponseData {
  static var key: String {
    return "internetRadioStations"
  }
  let internetRadioStation: [Radio]
}

struct RadioListResponse: Codable {
  let subsonicResponse: SubsonicResponse<RadioList>

  private enum CodingKeys: String, CodingKey {
    case subsonicResponse = "subsonic-response"
  }
  var radioStations: [Radio] {
    return subsonicResponse.data?.internetRadioStation ?? []
  }
}

struct Radio: Codable, Identifiable, Hashable {
  let id: String
  let name: String
  let streamUrl: String

  enum CodingKeys: CodingKey {
    case id
    case name
    case streamUrl
  }

  init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    self.id = try container.decode(String.self, forKey: .id)
    self.name = try container.decode(String.self, forKey: .name)
    self.streamUrl = try container.decode(String.self, forKey: .streamUrl)
  }

  init(
    id: String,
    name: String,
    streamUrl: String
  ) {
    self.id = id
    self.name = name
    self.streamUrl = streamUrl
  }

  // This function will create a mock 'Playable' entity for the radio station
  func toPlayable() -> RadioEntity {
    let displayHost = Radio.displayHost(from: streamUrl)
    return RadioEntity(
      id: id,
      name: name,
      songs: [
        Song(
          id: id,
          title: name,
          albumId: "",
          albumName: "",
          artist: displayHost,
          trackNumber: 1,
          discNumber: 1,
          bitRate: .zero,
          sampleRate: 1,
          suffix: "",
          duration: .infinity,
          mediaFileId: id
        )
      ],
      artist: displayHost
    )
  }

  private static func displayHost(from urlString: String) -> String {
    guard let url = URL(string: urlString),
      let host = url.host,
      !host.isEmpty
    else {
      return urlString
    }

    return host
  }

}

struct RadioEntity: Playable {
  var id: String
  var name: String
  var songs: [Song]
  var artist: String
}

// MARK: - Artist Radio (getSimilarSongs2)

struct SimilarSongsList: SubsonicResponseData {
  static var key: String { "similarSongs2" }
  let song: [Song]

  private enum CodingKeys: String, CodingKey {
    case song
  }

  private enum SubsonicSongKeys: String, CodingKey {
    case id, title, artist, albumId, album, track, discNumber, bitRate, samplingRate, suffix,
      duration, mediaFileId
  }

  init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    var songsContainer = try container.nestedUnkeyedContainer(forKey: .song)

    var songs: [Song] = []
    while !songsContainer.isAtEnd {
      let s = try songsContainer.nestedContainer(keyedBy: SubsonicSongKeys.self)
      songs.append(
        Song(
          id: try s.decode(String.self, forKey: .id),
          title: try s.decode(String.self, forKey: .title),
          albumId: try s.decodeIfPresent(String.self, forKey: .albumId) ?? "",
          albumName: try s.decodeIfPresent(String.self, forKey: .album) ?? "",
          artist: try s.decode(String.self, forKey: .artist),
          trackNumber: try s.decodeIfPresent(Int.self, forKey: .track) ?? 0,
          discNumber: try s.decodeIfPresent(Int.self, forKey: .discNumber) ?? 0,
          bitRate: try s.decodeIfPresent(Int.self, forKey: .bitRate) ?? 0,
          sampleRate: try s.decodeIfPresent(Int.self, forKey: .samplingRate) ?? 0,
          suffix: try s.decodeIfPresent(String.self, forKey: .suffix) ?? "",
          duration: try s.decode(Double.self, forKey: .duration),
          mediaFileId: try s.decodeIfPresent(String.self, forKey: .mediaFileId) ?? ""
        ))
    }
    self.song = songs
  }
}

struct SimilarSongsResponse: Codable {
  let subsonicResponse: SubsonicResponse<SimilarSongsList>

  private enum CodingKeys: String, CodingKey {
    case subsonicResponse = "subsonic-response"
  }

  var songs: [Song] {
    return subsonicResponse.data?.song ?? []
  }
}

struct ArtistRadioPlayable: Playable {
  var id: String
  var name: String
  var songs: [Song]
  var artist: String
}
