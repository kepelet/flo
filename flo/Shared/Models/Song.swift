//
//  Song.swift
//  flo
//
//  Created by rizaldy on 09/06/24.
//

import Foundation

struct Song: Codable, Identifiable, Hashable {
  let id: String
  let title: String
  let artist: String
  let trackNumber: Int
  let discNumber: Int
  let bitRate: Int
  let suffix: String
  let duration: Double
}
