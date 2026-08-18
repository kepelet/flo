//
//  UserAuthDecodingTests.swift
//  floTests
//

import XCTest

@testable import flo

final class UserAuthDecodingTests: XCTestCase {

  // MARK: - Decoding

  func testDecode_fullJSON() throws {
    let json = """
      {
        "id": "user1",
        "name": "Test User",
        "username": "testuser",
        "isAdmin": true,
        "lastFMApiKey": "lfm_key_123",
        "subsonicSalt": "salt_value",
        "subsonicToken": "token_value",
        "token": "nd_token_abc"
      }
      """

    let auth = try JSONDecoder().decode(UserAuth.self, from: Data(json.utf8))

    XCTAssertEqual(auth.id, "user1")
    XCTAssertEqual(auth.name, "Test User")
    XCTAssertEqual(auth.username, "testuser")
    XCTAssertTrue(auth.isAdmin)
    XCTAssertEqual(auth.lastFMApiKey, "lfm_key_123")
    XCTAssertEqual(auth.subsonicSalt, "salt_value")
    XCTAssertEqual(auth.subsonicToken, "token_value")
    XCTAssertEqual(auth.token, "nd_token_abc")
  }

  func testDecode_minimalJSON() throws {
    let json = """
      {
        "id": "user1",
        "name": "Test User",
        "username": "testuser",
        "isAdmin": false,
        "subsonicSalt": "salt",
        "subsonicToken": "token"
      }
      """

    let auth = try JSONDecoder().decode(UserAuth.self, from: Data(json.utf8))

    XCTAssertEqual(auth.id, "user1")
    XCTAssertEqual(auth.lastFMApiKey, "")
    XCTAssertEqual(auth.token, "")
  }

  // MARK: - Convenience init

  func testConvenienceInit_defaults() {
    let auth = UserAuth(
      id: "u1", username: "user", name: "Name", isAdmin: false
    )

    XCTAssertEqual(auth.id, "u1")
    XCTAssertEqual(auth.username, "user")
    XCTAssertEqual(auth.name, "Name")
    XCTAssertFalse(auth.isAdmin)
    XCTAssertEqual(auth.lastFMApiKey, "")
    XCTAssertEqual(auth.subsonicSalt, "")
    XCTAssertEqual(auth.subsonicToken, "")
    XCTAssertEqual(auth.token, "")
  }

  func testConvenienceInit_full() {
    let auth = UserAuth(
      id: "u1", username: "user", name: "Name", isAdmin: true,
      lastFMApiKey: "lfm", subsonicSalt: "salt", subsonicToken: "stok",
      token: "tk"
    )

    XCTAssertEqual(auth.id, "u1")
    XCTAssertTrue(auth.isAdmin)
    XCTAssertEqual(auth.lastFMApiKey, "lfm")
    XCTAssertEqual(auth.subsonicSalt, "salt")
    XCTAssertEqual(auth.subsonicToken, "stok")
    XCTAssertEqual(auth.token, "tk")
  }
}
