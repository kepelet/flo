//
//  NowPlaying.swift
//  flo
//
//  Created by rizaldy on 24/06/24.
//

import Foundation

struct NowPlaying: Codable {
  var artistName: String = "Unknown Artist"
  var songName: String = "Untitled"
  var albumName: String = "Unknown Album"
  var albumCover: String = ""
  var streamUrl: String = ""
  var bitRate: Int = 0
  var suffix: String = ""
}
