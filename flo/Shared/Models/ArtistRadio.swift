//    flo

import Foundation

// MARK: - Similar Songs List

struct SimilarSongsList: SubsonicResponseData {
  static var key: String { "similarSongs2" }
  let song: [Song]

  private enum CodingKeys: String, CodingKey {
    case song
  }

  private enum SubsonicSongKeys: String, CodingKey {
    case id, title, artist, albumId, album, track, discNumber, bitRate, samplingRate, suffix,
      duration, mediaFileId
  }

  init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    guard var songsContainer = try? container.nestedUnkeyedContainer(forKey: .song) else {
      self.song = []
      return
    }

    var songs: [Song] = []
    while !songsContainer.isAtEnd {
      let s = try songsContainer.nestedContainer(keyedBy: SubsonicSongKeys.self)
      songs.append(
        Song(
          id: try s.decode(String.self, forKey: .id),
          title: try s.decode(String.self, forKey: .title),
          albumId: try s.decodeIfPresent(String.self, forKey: .albumId) ?? "",
          albumName: try s.decodeIfPresent(String.self, forKey: .album) ?? "",
          artist: try s.decode(String.self, forKey: .artist),
          trackNumber: try s.decodeIfPresent(Int.self, forKey: .track) ?? 0,
          discNumber: try s.decodeIfPresent(Int.self, forKey: .discNumber) ?? 0,
          bitRate: try s.decodeIfPresent(Int.self, forKey: .bitRate) ?? 0,
          sampleRate: try s.decodeIfPresent(Int.self, forKey: .samplingRate) ?? 0,
          suffix: try s.decodeIfPresent(String.self, forKey: .suffix) ?? "",
          duration: try s.decode(Double.self, forKey: .duration),
          mediaFileId: try s.decodeIfPresent(String.self, forKey: .mediaFileId) ?? ""
        ))
    }
    self.song = songs
  }
}

struct SimilarSongsResponse: Codable {
  let subsonicResponse: SubsonicResponse<SimilarSongsList>

  private enum CodingKeys: String, CodingKey {
    case subsonicResponse = "subsonic-response"
  }

  var songs: [Song] {
    return subsonicResponse.data?.song ?? []
  }
}

// MARK: - Artist Top Songs (getTopSongs)

struct TopSongsList: SubsonicResponseData {
  static var key: String { "topSongs" }
  let song: [Song]
  
  private enum CodingKeys: String, CodingKey {
    case song
  }
  
  private enum SubsonicSongKeys: String, CodingKey {
    case id, title, artist, albumId, album, track, discNumber, bitRate, samplingRate, suffix,
         duration, mediaFileId
  }
  
  init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    
    guard var songsContainer = try? container.nestedUnkeyedContainer(forKey: .song) else {
      self.song = []
      return
    }
    
    var songs: [Song] = []
    while !songsContainer.isAtEnd {
      let s = try songsContainer.nestedContainer(keyedBy: SubsonicSongKeys.self)
      songs.append(
        Song(
          id: try s.decode(String.self, forKey: .id),
          title: try s.decode(String.self, forKey: .title),
          albumId: try s.decodeIfPresent(String.self, forKey: .albumId) ?? "",
          albumName: try s.decodeIfPresent(String.self, forKey: .album) ?? "",
          artist: try s.decode(String.self, forKey: .artist),
          trackNumber: try s.decodeIfPresent(Int.self, forKey: .track) ?? 0,
          discNumber: try s.decodeIfPresent(Int.self, forKey: .discNumber) ?? 0,
          bitRate: try s.decodeIfPresent(Int.self, forKey: .bitRate) ?? 0,
          sampleRate: try s.decodeIfPresent(Int.self, forKey: .samplingRate) ?? 0,
          suffix: try s.decodeIfPresent(String.self, forKey: .suffix) ?? "",
          duration: try s.decode(Double.self, forKey: .duration),
          mediaFileId: try s.decodeIfPresent(String.self, forKey: .mediaFileId) ?? ""
        ))
    }
    self.song = songs
  }
}

struct TopSongsResponse: Codable {
  let subsonicResponse: SubsonicResponse<TopSongsList>
  
  private enum CodingKeys: String, CodingKey {
    case subsonicResponse = "subsonic-response"
  }
  
  var songs: [Song] {
    return subsonicResponse.data?.song ?? []
  }
}
