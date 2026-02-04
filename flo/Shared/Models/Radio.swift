//
//  Radio.swift
//  flo
//
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
    return RadioEntity(id: id, name: name, songs: [Song(id: id, title: name, albumId: "", albumName: "", artist: streamUrl, trackNumber: 1, discNumber: 1, bitRate: .zero, sampleRate: 1, suffix: "", duration: .infinity, mediaFileId: id)], artist: streamUrl)
  }
  
}

struct RadioEntity: Playable {
  var id: String
  
  var name: String
  
  var songs: [Song]
  
  var artist: String
}
