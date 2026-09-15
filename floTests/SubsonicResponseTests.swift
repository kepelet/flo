//
//  SubsonicResponseTests.swift
//  floTests
//

import XCTest

@testable import flo

// MARK: - Concrete response type for testing

private struct TestData: SubsonicResponseData {
  static var key: String { "testData" }

  let message: String
  let count: Int
}

final class SubsonicResponseTests: XCTestCase {

  // MARK: - Generic response decoding

  func testDecode_responseWithData() throws {
    let json = """
      {
        "status": "ok",
        "version": "1.16.1",
        "type": "flo",
        "serverVersion": "0.52.0",
        "openSubsonic": true,
        "testData": {
          "message": "hello",
          "count": 42
        }
      }
      """

    let response = try JSONDecoder().decode(
      SubsonicResponse<TestData>.self, from: Data(json.utf8))

    XCTAssertEqual(response.status, "ok")
    XCTAssertEqual(response.version, "1.16.1")
    XCTAssertEqual(response.type, "flo")
    XCTAssertEqual(response.serverVersion, "0.52.0")
    XCTAssertTrue(response.openSubsonic)
    XCTAssertNotNil(response.data)
    XCTAssertEqual(response.data?.message, "hello")
    XCTAssertEqual(response.data?.count, 42)
  }

  func testDecode_responseWithoutData() throws {
    let json = """
      {
        "status": "failed",
        "version": "1.16.1",
        "type": "flo",
        "serverVersion": "0.52.0",
        "openSubsonic": false,
        "error": {
          "code": 40,
          "message": "Wrong username or password"
        }
      }
      """

    // When the data key is absent, decodeIfPresent should return nil
    let response = try JSONDecoder().decode(
      SubsonicResponse<TestData>.self, from: Data(json.utf8))

    XCTAssertEqual(response.status, "failed")
    XCTAssertNil(response.data)
  }

  func testDecode_BasicSubsonicResponse() throws {
    let json = """
      {
        "status": "ok",
        "version": "1.16.1",
        "type": "flo",
        "serverVersion": "0.52.0",
        "openSubsonic": true
      }
      """

    let response = try JSONDecoder().decode(
      BasicSubsonicResponse.self, from: Data(json.utf8))

    XCTAssertEqual(response.status, "ok")
    XCTAssertTrue(response.openSubsonic)
  }

  // MARK: - Starred2Response

  func testDecode_starred2Response_withSongs() throws {
    let json = """
      {
        "subsonic-response": {
          "starred2": {
            "song": [
              {
                "id": "song1",
                "title": "Starred Song",
                "artist": "Artist",
                "albumId": "album1",
                "album": "Album",
                "track": 1,
                "discNumber": 1,
                "bitRate": 320,
                "samplingRate": 44100,
                "suffix": "mp3",
                "duration": 200
              }
            ]
          }
        }
      }
      """

    let response = try JSONDecoder().decode(Starred2Response.self, from: Data(json.utf8))

    XCTAssertEqual(response.songs.count, 1)
    XCTAssertEqual(response.songs[0].title, "Starred Song")
    XCTAssertEqual(response.songs[0].artist, "Artist")
  }

  func testDecode_starred2Response_emptySongs() throws {
    let json = """
      {
        "subsonic-response": {
          "starred2": {
            "song": []
          }
        }
      }
      """

    let response = try JSONDecoder().decode(Starred2Response.self, from: Data(json.utf8))

    XCTAssertEqual(response.songs.count, 0)
  }

  func testDecode_starred2Response_noSongs() throws {
    let json = """
      {
        "subsonic-response": {
          "starred2": null
        }
      }
      """

    let response = try JSONDecoder().decode(Starred2Response.self, from: Data(json.utf8))

    XCTAssertEqual(response.songs.count, 0)
  }

  // MARK: - SubsonicSong toSong conversion

  func testSubsonicSong_toSong() {
    let subsonicSong = SubsonicSong(
      id: "s1",
      title: "Test Song",
      artist: "Artist",
      albumId: "a1",
      album: "Album",
      track: 3,
      discNumber: 1,
      bitRate: 256,
      samplingRate: 48000,
      suffix: "flac",
      duration: 300,
      explicitStatus: "explicit"
    )

    let song = subsonicSong.toSong()

    XCTAssertEqual(song.id, "s1")
    XCTAssertEqual(song.title, "Test Song")
    XCTAssertEqual(song.artist, "Artist")
    XCTAssertEqual(song.albumId, "a1")
    XCTAssertEqual(song.albumName, "Album")
    XCTAssertEqual(song.trackNumber, 3)
    XCTAssertEqual(song.discNumber, 1)
    XCTAssertEqual(song.bitRate, 256)
    XCTAssertEqual(song.sampleRate, 48000)
    XCTAssertEqual(song.suffix, "flac")
    XCTAssertEqual(song.duration, 300.0)
    XCTAssertEqual(song.explicitStatus, .explicit)
  }

  func testSubsonicSong_toSong_withNilFields() {
    let subsonicSong = SubsonicSong(
      id: "s1",
      title: "Minimal",
      artist: nil,
      albumId: nil,
      album: nil,
      track: nil,
      discNumber: nil,
      bitRate: nil,
      samplingRate: nil,
      suffix: nil,
      duration: nil,
      explicitStatus: nil
    )

    let song = subsonicSong.toSong()

    XCTAssertEqual(song.title, "Minimal")
    XCTAssertEqual(song.artist, "")
    XCTAssertEqual(song.albumId, "")
    XCTAssertEqual(song.albumName, "")
    XCTAssertEqual(song.trackNumber, 0)
    XCTAssertEqual(song.bitRate, 0)
    XCTAssertEqual(song.suffix, "")
    XCTAssertEqual(song.duration, 0.0)
    XCTAssertEqual(song.explicitStatus, .unknown)
  }
}
