//
//  User.swift
//  flo
//
//  Created by rizaldy on 09/06/24.
//

import Foundation

struct User: Codable {
  let id: String
  let username: String
  let name: String
  let isAdmin: Bool
  let lastFMApiKey: String
}
