//
//  Album.swift
//  flo
//
//  Created by rizaldy on 07/06/24.
//

import Foundation

struct Album: Codable, Identifiable {
  var id: String = ""
  var name: String = ""
  var artist: String = ""
  var songs: [Song]?
  var albumCover: String?
}
