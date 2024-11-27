//
//  UserAuth.swift
//  flo
//
//  Created by rizaldy on 01/06/24.
//

import Foundation

struct UserAuth: Codable {
  let id: String
  let name: String
  let username: String
  let isAdmin: Bool
  let lastFMApiKey: String
  let subsonicSalt: String
  let subsonicToken: String
  let token: String

  init(
    id: String, username: String, name: String, isAdmin: Bool, lastFMApiKey: String = "",
    subsonicSalt: String = "", subsonicToken: String = "", token: String = ""
  ) {
    self.id = id
    self.name = name
    self.username = username
    self.isAdmin = isAdmin
    self.lastFMApiKey = lastFMApiKey
    self.subsonicSalt = subsonicSalt
    self.subsonicToken = subsonicToken
    self.token = token
  }

  init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    self.id = try container.decode(String.self, forKey: .id)
    self.name = try container.decode(String.self, forKey: .name)
    self.username = try container.decode(String.self, forKey: .username)
    self.isAdmin = try container.decode(Bool.self, forKey: .isAdmin)
    self.lastFMApiKey = try container.decodeIfPresent(String.self, forKey: .lastFMApiKey) ?? ""
    self.subsonicSalt = try container.decode(String.self, forKey: .subsonicSalt)
    self.subsonicToken = try container.decode(String.self, forKey: .subsonicToken)
    self.token = try container.decode(String.self, forKey: .token)
  }
}
