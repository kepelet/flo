//
//  ScanStatus.swift
//  flo
//
//  Created by rizaldy on 14/06/24.
//

import Foundation

struct ScanStatus: SubsonicResponseData {
  let scanning: Bool
  let count: Int
  let folderCount: Int
  let lastScan: String

  static var key: String {
    return "scanStatus"
  }
}

struct ScanStatusResponse: Codable {
  let subsonicResponse: SubsonicResponse<ScanStatus>

  private enum CodingKeys: String, CodingKey {
    case subsonicResponse = "subsonic-response"
  }
}
