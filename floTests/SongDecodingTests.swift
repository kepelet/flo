//
//  SongDecodingTests.swift
//  floTests
//

import XCTest

@testable import flo

final class SongDecodingTests: XCTestCase {

  // MARK: - Full JSON decoding

  func testDecode_fullSongJSON() throws {
    let json = """
      {
        "id": "abc123",
        "title": "Test Song",
        "artist": "Test Artist",
        "albumId": "album1",
        "album": "Test Album",
        "trackNumber": 5,
        "discNumber": 1,
        "bitRate": 320,
        "sampleRate": 44100,
        "suffix": "mp3",
        "duration": 240.5,
        "mediaFileId": "media_abc",
        "starred": true,
        "explicitStatus": "clean"
      }
      """

    let song = try JSONDecoder().decode(Song.self, from: Data(json.utf8))

    XCTAssertEqual(song.id, "abc123")
    XCTAssertEqual(song.title, "Test Song")
    XCTAssertEqual(song.artist, "Test Artist")
    XCTAssertEqual(song.albumId, "album1")
    XCTAssertEqual(song.albumName, "Test Album")
    XCTAssertEqual(song.trackNumber, 5)
    XCTAssertEqual(song.discNumber, 1)
    XCTAssertEqual(song.bitRate, 320)
    XCTAssertEqual(song.sampleRate, 44100)
    XCTAssertEqual(song.suffix, "mp3")
    XCTAssertEqual(song.duration, 240.5)
    XCTAssertEqual(song.mediaFileId, "media_abc")
    XCTAssertTrue(song.starred)
    XCTAssertEqual(song.explicitStatus, .clean)
  }

  func testDecode_minimalSongJSON() throws {
    let json = """
      {
        "id": "abc123",
        "title": "Test Song",
        "artist": "Test Artist",
        "albumId": "album1",
        "trackNumber": 5,
        "discNumber": 1,
        "bitRate": 320,
        "sampleRate": 44100,
        "suffix": "mp3",
        "duration": 240.5
      }
      """

    let song = try JSONDecoder().decode(Song.self, from: Data(json.utf8))

    XCTAssertEqual(song.id, "abc123")
    XCTAssertEqual(song.title, "Test Song")
    XCTAssertEqual(song.albumName, "")  // not present, defaults to ""
    XCTAssertEqual(song.mediaFileId, "")  // not present, defaults to ""
    XCTAssertFalse(song.starred)  // not present, defaults to false
    XCTAssertEqual(song.explicitStatus, .unknown)  // not present
  }

  // MARK: - Album name field compatibility

  func testDecode_albumNameField() throws {
    let json = """
      {
        "id": "abc123",
        "title": "Test",
        "artist": "Artist",
        "albumId": "album1",
        "albumName": "From albumName",
        "trackNumber": 1,
        "discNumber": 1,
        "bitRate": 320,
        "sampleRate": 44100,
        "suffix": "mp3",
        "duration": 100.0
      }
      """

    let song = try JSONDecoder().decode(Song.self, from: Data(json.utf8))

    XCTAssertEqual(song.albumName, "From albumName")
  }

  func testDecode_albumField_oldFormat() throws {
    let json = """
      {
        "id": "abc123",
        "title": "Test",
        "artist": "Artist",
        "albumId": "album1",
        "album": "From album",
        "trackNumber": 1,
        "discNumber": 1,
        "bitRate": 320,
        "sampleRate": 44100,
        "suffix": "mp3",
        "duration": 100.0
      }
      """

    let song = try JSONDecoder().decode(Song.self, from: Data(json.utf8))

    XCTAssertEqual(song.albumName, "From album")
  }

  func testDecode_bothAlbumFields_picksAlbum() throws {
    let json = """
      {
        "id": "abc123",
        "title": "Test",
        "artist": "Artist",
        "albumId": "album1",
        "album": "From album (old)",
        "albumName": "From albumName (new)",
        "trackNumber": 1,
        "discNumber": 1,
        "bitRate": 320,
        "sampleRate": 44100,
        "suffix": "mp3",
        "duration": 100.0
      }
      """

    let song = try JSONDecoder().decode(Song.self, from: Data(json.utf8))

    // "album" is tried first via decodeIfPresent, so it wins
    XCTAssertEqual(song.albumName, "From album (old)")
  }

  // MARK: - Explicit status edge cases

  func testDecode_explicitStatusNil_unknown() throws {
    let json = """
      {
        "id": "abc123",
        "title": "Test",
        "artist": "Artist",
        "albumId": "album1",
        "trackNumber": 1,
        "discNumber": 1,
        "bitRate": 320,
        "sampleRate": 44100,
        "suffix": "mp3",
        "duration": 100.0,
        "explicitStatus": null
      }
      """

    let song = try JSONDecoder().decode(Song.self, from: Data(json.utf8))

    XCTAssertEqual(song.explicitStatus, .unknown)
    XCTAssertFalse(song.isExplicit)
  }

  func testDecode_explicitStatusE_explicit() throws {
    let json = """
      {
        "id": "abc123",
        "title": "Test",
        "artist": "Artist",
        "albumId": "album1",
        "trackNumber": 1,
        "discNumber": 1,
        "bitRate": 320,
        "sampleRate": 44100,
        "suffix": "mp3",
        "duration": 100.0,
        "explicitStatus": "e"
      }
      """

    let song = try JSONDecoder().decode(Song.self, from: Data(json.utf8))

    XCTAssertEqual(song.explicitStatus, .explicit)
    XCTAssertTrue(song.isExplicit)
  }

  // MARK: - Init convenience

  func testConvenienceInit_setsAllProperties() {
    let song = Song(
      id: "id1", title: "Title", albumId: "album1", albumName: "Album",
      artist: "Artist", trackNumber: 3, discNumber: 1,
      bitRate: 256, sampleRate: 48000,
      suffix: "flac", duration: 300.0, mediaFileId: "media1",
      explicitStatus: .explicit
    )

    XCTAssertEqual(song.id, "id1")
    XCTAssertEqual(song.title, "Title")
    XCTAssertEqual(song.albumId, "album1")
    XCTAssertEqual(song.albumName, "Album")
    XCTAssertEqual(song.artist, "Artist")
    XCTAssertEqual(song.trackNumber, 3)
    XCTAssertEqual(song.discNumber, 1)
    XCTAssertEqual(song.bitRate, 256)
    XCTAssertEqual(song.sampleRate, 48000)
    XCTAssertEqual(song.suffix, "flac")
    XCTAssertEqual(song.duration, 300.0)
    XCTAssertEqual(song.mediaFileId, "media1")
    XCTAssertEqual(song.explicitStatus, .explicit)
  }

  // MARK: - Encode round-trip

  func testEncodeDecodeRoundTrip() throws {
    let song = Song(
      id: "id1", title: "Title", albumId: "album1", albumName: "Album",
      artist: "Artist", trackNumber: 3, discNumber: 1,
      bitRate: 256, sampleRate: 48000,
      suffix: "flac", duration: 300.0, mediaFileId: "media1",
      explicitStatus: .explicit
    )

    let encoder = JSONEncoder()
    let data = try encoder.encode(song)
    let decoded = try JSONDecoder().decode(Song.self, from: data)

    XCTAssertEqual(decoded.id, song.id)
    XCTAssertEqual(decoded.title, song.title)
    XCTAssertEqual(decoded.artist, song.artist)
    XCTAssertEqual(decoded.albumId, song.albumId)
    XCTAssertEqual(decoded.albumName, song.albumName)
    XCTAssertEqual(decoded.trackNumber, song.trackNumber)
    XCTAssertEqual(decoded.discNumber, song.discNumber)
    XCTAssertEqual(decoded.bitRate, song.bitRate)
    XCTAssertEqual(decoded.sampleRate, song.sampleRate)
    XCTAssertEqual(decoded.suffix, song.suffix)
    XCTAssertEqual(decoded.duration, song.duration)
    XCTAssertEqual(decoded.mediaFileId, song.mediaFileId)
    XCTAssertEqual(decoded.starred, song.starred)
    XCTAssertEqual(decoded.explicitStatus, song.explicitStatus)
  }
}
