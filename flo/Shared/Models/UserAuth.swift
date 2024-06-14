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
}
