//
//  Stats.swift
//  flo
//
//  Created by rizaldy on 25/11/24.
//

struct Stats {
  let topArtist: String
  let topAlbum: String
  let topAlbumArtist: String
  let topAlbumId: String
  let topGenre: String

  var hasNavigableTopArtist: Bool {
    !topArtist.isEmpty && topArtist != "N/A"
  }

  var hasNavigableTopAlbum: Bool {
    (!topAlbumId.isEmpty || !topAlbum.isEmpty) && topAlbum != "N/A"
  }

  var hasTopGenre: Bool {
    !topGenre.isEmpty && topGenre != "N/A"
  }
}
