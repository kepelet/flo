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
