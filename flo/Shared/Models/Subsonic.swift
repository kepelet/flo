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
