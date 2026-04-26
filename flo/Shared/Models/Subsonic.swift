//
//  Subsonic.swift
//  flo
//
//  Created by rizaldy on 11/01/25.
//

protocol SubsonicResponseData: Codable {
  static var key: String { get }
}

struct BasicResponse: SubsonicResponseData {
  static var key = ""
}

struct SubsonicResponse<T: SubsonicResponseData>: Codable {
  let status: String
  let version: String
  let type: String
  let serverVersion: String
  let openSubsonic: Bool
  let data: T?

  enum CodingKeys: String, CodingKey {
    case status
    case version
    case type
    case serverVersion
    case openSubsonic
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    status = try container.decode(String.self, forKey: .status)
    version = try container.decode(String.self, forKey: .version)
    type = try container.decode(String.self, forKey: .type)
    serverVersion = try container.decode(String.self, forKey: .serverVersion)
    openSubsonic = try container.decode(Bool.self, forKey: .openSubsonic)

    let rootContainer = try decoder.container(keyedBy: ExtraField.self)
    data = try rootContainer.decodeIfPresent(T.self, forKey: ExtraField(stringValue: T.key))
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)

    try container.encode(status, forKey: .status)
    try container.encode(version, forKey: .version)
    try container.encode(type, forKey: .type)
    try container.encode(serverVersion, forKey: .serverVersion)
    try container.encode(openSubsonic, forKey: .openSubsonic)

    if let data = data, let dynamicKey = CodingKeys(rawValue: T.key) {
      try container.encode(data, forKey: dynamicKey)
    }
  }
}

extension SubsonicResponse {
  struct ExtraField: CodingKey {
    let stringValue: String
    let intValue: Int?

    init(stringValue: String) {
      self.stringValue = stringValue
      self.intValue = nil
    }

    init?(intValue: Int) {
      self.stringValue = "\(intValue)"
      self.intValue = intValue
    }
  }
}

typealias BasicSubsonicResponse = SubsonicResponse<BasicResponse>

struct Starred2Response: Codable {
  struct SubsonicResponseBody: Codable {
    struct Starred2: Codable {
      let song: [SubsonicSong]?
    }

    let starred2: Starred2?
  }

  let subsonicResponse: SubsonicResponseBody

  enum CodingKeys: String, CodingKey {
    case subsonicResponse = "subsonic-response"
  }

  var songs: [Song] {
    return (subsonicResponse.starred2?.song ?? []).map { $0.toSong() }
  }
}

struct SubsonicSong: Codable {
  let id: String
  let title: String
  let artist: String?
  let albumId: String?
  let album: String?
  let track: Int?
  let discNumber: Int?
  let bitRate: Int?
  let samplingRate: Int?
  let suffix: String?
  let duration: Int?

  func toSong() -> Song {
    return Song(
      id: id, title: title, albumId: albumId ?? "", albumName: album ?? "",
      artist: artist ?? "", trackNumber: track ?? 0, discNumber: discNumber ?? 0,
      bitRate: bitRate ?? 0, sampleRate: samplingRate ?? 0, suffix: suffix ?? "",
      duration: Double(duration ?? 0), mediaFileId: id)
  }
}
