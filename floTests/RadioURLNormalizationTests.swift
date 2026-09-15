//
//  RadioURLNormalizationTests.swift
//  floTests
//

import XCTest

@testable import flo

final class RadioURLNormalizationTests: XCTestCase {

  // MARK: - Radio toPlayable

  func testRadioToPlayable_constructsPlayable() {
    let radio = Radio(id: "r1", name: "Test Radio", streamUrl: "https://example.com/stream")

    let playable = radio.toPlayable()

    XCTAssertEqual(playable.id, "r1")
    XCTAssertEqual(playable.name, "Test Radio")
    XCTAssertEqual(playable.songs.count, 1)
    XCTAssertEqual(playable.songs[0].title, "Test Radio")
    XCTAssertEqual(playable.songs[0].id, "r1")
    // Radio duration should be infinite
    XCTAssertTrue(playable.songs[0].duration.isInfinite)
  }

  func testRadioToPlayable_extractsArtistFromHost() {
    let radio = Radio(
      id: "r1", name: "Jazz FM", streamUrl: "https://jazz.example.com/stream")

    let playable = radio.toPlayable()

    XCTAssertEqual(playable.artist, "jazz.example.com")
  }

  func testRadioToPlayable_invalidURL_artistIsURLString() {
    let radio = Radio(
      id: "r1", name: "Bad URL", streamUrl: "not-a-valid-url")

    let playable = radio.toPlayable()

    // Falls back to the raw string when URL parsing fails
    XCTAssertEqual(playable.artist, "not-a-valid-url")
  }

  // MARK: - Radio init

  func testRadioInit_defaultValues() {
    let radio = Radio(id: "r1", name: "Radio", streamUrl: "https://example.com/stream")

    XCTAssertEqual(radio.id, "r1")
    XCTAssertEqual(radio.name, "Radio")
    XCTAssertEqual(radio.streamUrl, "https://example.com/stream")
  }

  // MARK: - RadioListResponse decoding

  func testRadioListResponse_decode() throws {
    let json = """
      {
        "subsonic-response": {
          "status": "ok",
          "version": "1.16.1",
          "type": "flo",
          "serverVersion": "0.52.0",
          "openSubsonic": true,
          "internetRadioStations": {
            "internetRadioStation": [
              {
                "id": "r1",
                "name": "Jazz Radio",
                "streamUrl": "https://jazz.example.com/stream"
              },
              {
                "id": "r2",
                "name": "Rock Radio",
                "streamUrl": "https://rock.example.com/stream"
              }
            ]
          }
        }
      }
      """

    let response = try JSONDecoder().decode(
      RadioListResponse.self, from: Data(json.utf8))

    XCTAssertEqual(response.radioStations.count, 2)
    XCTAssertEqual(response.radioStations[0].name, "Jazz Radio")
    XCTAssertEqual(response.radioStations[1].name, "Rock Radio")
    XCTAssertEqual(response.radioStations[0].streamUrl, "https://jazz.example.com/stream")
  }

  func testRadioListResponse_emptyStations() throws {
    let json = """
      {
        "subsonic-response": {
          "status": "ok",
          "version": "1.16.1",
          "type": "flo",
          "serverVersion": "0.52.0",
          "openSubsonic": true
        }
      }
      """

    let response = try JSONDecoder().decode(
      RadioListResponse.self, from: Data(json.utf8))

    XCTAssertEqual(response.radioStations.count, 0)
  }
}
