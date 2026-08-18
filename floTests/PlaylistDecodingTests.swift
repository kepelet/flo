//
//  PlaylistDecodingTests.swift
//  floTests
//

import XCTest

@testable import flo

final class PlaylistDecodingTests: XCTestCase {

  // MARK: - Decoding

  func testDecode_fullPlaylistJSON() throws {
    let json = """
      {
        "id": "playlist1",
        "name": "My Playlist",
        "comment": "A test playlist",
        "public": true,
        "ownerName": "testuser",
        "coverArtId": "cover123",
        "songs": [
          {
            "id": "song1",
            "title": "Song One",
            "artist": "Artist",
            "albumId": "album1",
            "album": "Album",
            "trackNumber": 1,
            "discNumber": 1,
            "bitRate": 320,
            "sampleRate": 44100,
            "suffix": "mp3",
            "duration": 180.0
          }
        ]
      }
      """

    let playlist = try JSONDecoder().decode(Playlist.self, from: Data(json.utf8))

    XCTAssertEqual(playlist.id, "playlist1")
    XCTAssertEqual(playlist.name, "My Playlist")
    XCTAssertEqual(playlist.comment, "A test playlist")
    XCTAssertTrue(playlist.isPublic)
    XCTAssertEqual(playlist.ownerName, "testuser")
    XCTAssertEqual(playlist.coverArtId, "cover123")
    XCTAssertEqual(playlist.artist, "testuser")  // artist = ownerName
    XCTAssertEqual(playlist.songs.count, 1)
    XCTAssertEqual(playlist.songs[0].title, "Song One")
  }

  func testDecode_minimalPlaylistJSON() throws {
    let json = """
      {
        "id": "playlist1",
        "name": "Minimal",
        "comment": "",
        "public": false,
        "ownerName": "user"
      }
      """

    let playlist = try JSONDecoder().decode(Playlist.self, from: Data(json.utf8))

    XCTAssertEqual(playlist.id, "playlist1")
    XCTAssertEqual(playlist.name, "Minimal")
    XCTAssertFalse(playlist.isPublic)
    XCTAssertNil(playlist.coverArtId)
    XCTAssertEqual(playlist.songs.count, 0)
  }

  // MARK: - artist derivation

  func testDecode_artistEqualsOwnerName() throws {
    let json = """
      {
        "id": "p1",
        "name": "Playlist",
        "comment": "",
        "public": false,
        "ownerName": "john_doe"
      }
      """

    let playlist = try JSONDecoder().decode(Playlist.self, from: Data(json.utf8))

    // The artist property is derived from ownerName
    XCTAssertEqual(playlist.artist, "john_doe")
  }

  // MARK: - Convenience init

  func testConvenienceInit_defaults() {
    let playlist = Playlist()

    XCTAssertEqual(playlist.id, "")
    XCTAssertEqual(playlist.name, "")
    XCTAssertEqual(playlist.comment, "")
    XCTAssertFalse(playlist.isPublic)
    XCTAssertEqual(playlist.ownerName, "")
    XCTAssertNil(playlist.coverArtId)
    XCTAssertEqual(playlist.songs.count, 0)
    XCTAssertEqual(playlist.artist, "")  // artist = ownerName = ""
  }

  func testConvenienceInit_withSongs() {
    let song = Song(
      id: "s1", title: "T", albumId: "a1", albumName: "A",
      artist: "Art", trackNumber: 1, discNumber: 1,
      bitRate: 320, sampleRate: 44100,
      suffix: "mp3", duration: 100, mediaFileId: "m1"
    )

    let playlist = Playlist(
      id: "p1", name: "Playlist", comment: "C", isPublic: true,
      ownerName: "owner", coverArtId: "ca1", songs: [song]
    )

    XCTAssertEqual(playlist.songs.count, 1)
    XCTAssertEqual(playlist.songs[0].id, "s1")
  }
}
