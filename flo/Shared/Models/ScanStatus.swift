//
//  ScanStatus.swift
//  flo
//
//  Created by rizaldy on 14/06/24.
//

import Foundation

struct ScanStatusResponse: Codable {
  struct SubsonicResponse: Codable {
    struct ScanStatus: Codable {
      let scanning: Bool
      let count: Int
      let folderCount: Int
      let lastScan: String
    }

    let status: String
    let version: String
    let type: String
    let serverVersion: String
    let openSubsonic: Bool
    let scanStatus: ScanStatus
  }

  let subsonicResponse: SubsonicResponse

  enum CodingKeys: String, CodingKey {
    // FIXME: constants?
    case subsonicResponse = "subsonic-response"
  }
}
