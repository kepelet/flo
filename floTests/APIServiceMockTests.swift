//
//  APIServiceMockTests.swift
//  floTests
//

import XCTest

@testable import flo

/// Network tests backed by `MockURLProtocol` instead of a live Navidrome
/// server. These exercise the same endpoint surface as the old
/// NavidromeIntegrationTests without requiring credentials.
final class APIServiceMockTests: XCTestCase {

  private let baseURL = "https://mock.example"

  // MARK: - Fixtures

  private static let userAuthJSON =
    #"{"id":"u1","name":"Test User","username":"testuser","isAdmin":true,"subsonicSalt":"salt","subsonicToken":"token-123","token":"nd-token-123"}"#

  private static let albumsJSON =
    #"[{"id":"al1","name":"Test Album","albumArtist":"Test Artist","artist":"Test Artist","genre":"Rock","minYear":2020}]"#

  private static let artistsJSON =
    #"[{"id":"ar1","name":"Test Artist","orderArtistName":"Test Artist","stats":{"producer":null,"composer":null,"artist":null,"maincredit":null,"albumartist":null,"arranger":null,"engineer":null,"performer":null,"mixer":null,"lyricist":null,"conductor":null},"size":0,"albumCount":1,"songCount":10,"missing":false,"createdAt":"2024-01-01T00:00:00Z","updatedAt":"2024-01-01T00:00:00Z"}]"#

  private static let songsJSON =
    #"[{"id":"song1","title":"Test Song","artist":"Test Artist","albumId":"al1","album":"Test Album","trackNumber":1,"discNumber":1,"bitRate":320,"sampleRate":44100,"suffix":"mp3","duration":180.0,"mediaFileId":"song1","starred":true}]"#

  private static let playlistsJSON =
    #"[{"id":"pl1","name":"Test Playlist","comment":"A comment","public":false,"ownerName":"Test User","coverArtId":"pl1"}]"#

  private static let radiosJSON =
    #"{"subsonic-response":{"status":"ok","version":"1.16.1","type":"flo","serverVersion":"0.54.0","openSubsonic":true,"internetRadioStations":{"internetRadioStation":[{"id":"r1","name":"Radio 1","streamUrl":"https://example.com/stream"}]}}}"#

  private static let scanStatusJSON =
    #"{"subsonic-response":{"status":"ok","version":"1.16.1","type":"flo","serverVersion":"0.54.0","openSubsonic":true,"scanStatus":{"scanning":false,"count":100,"folderCount":10,"lastScan":"2024-01-01T00:00:00Z"}}}"#

  // MARK: - Setup

  override func setUp() {
    super.setUp()

    UserDefaultsManager.serverBaseURL = baseURL

    // Simulate a logged-in session so Subsonic URLs (star/unstar/scan) are well-formed.
    let auth = UserAuth(
      id: "u1", username: "testuser", name: "Test User", isAdmin: true,
      subsonicSalt: "salt", subsonicToken: "token-123", token: "nd-token-123")
    AuthService.shared.setCreds(auth)

    MockURLProtocol.reset()
    registerStubs()

    APIManager.extraProtocolClasses = [MockURLProtocol.self]
    APIManager.shared.reconfigureSession()
  }

  override func tearDown() {
    MockURLProtocol.reset()
    APIManager.extraProtocolClasses = []
    APIManager.shared.reconfigureSession()

    UserDefaultsManager.removeObject(key: UserDefaultsKeys.serverURL)
    try? KeychainManager.removeAuthCreds()
    try? KeychainManager.removeAuthPassword()

    super.tearDown()
  }

  private func registerStubs() {
    MockURLProtocol.stub("POST", "/auth/login") { request in
      let body = Self.requestBody(request)

      if body.contains("invalid_user") {
        return .init(statusCode: 401, json: #"{"error":"invalid username or password"}"#)
      }

      return .init(json: Self.userAuthJSON)
    }

    MockURLProtocol.stubJSON("GET", "/api/album", json: Self.albumsJSON)
    MockURLProtocol.stubJSON("GET", "/api/artist", json: Self.artistsJSON)
    MockURLProtocol.stubJSON("GET", "/api/song", json: Self.songsJSON)
    MockURLProtocol.stubJSON("GET", "/api/playlist", json: Self.playlistsJSON)
    MockURLProtocol.stubJSON("GET", "/rest/getInternetRadioStations", json: Self.radiosJSON)
    MockURLProtocol.stubJSON("GET", "/rest/getScanStatus", json: Self.scanStatusJSON)
    MockURLProtocol.stubJSON("GET", "/rest/star", json: "{}")
    MockURLProtocol.stubJSON("GET", "/rest/unstar", json: "{}")
  }

  private static func requestBody(_ request: URLRequest) -> String {
    if let body = request.httpBody {
      return String(data: body, encoding: .utf8) ?? ""
    }

    if let stream = request.httpBodyStream {
      stream.open()
      defer { stream.close() }

      var data = Data()
      let bufferSize = 4096
      let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
      defer { buffer.deallocate() }

      while stream.hasBytesAvailable {
        let count = stream.read(buffer, maxLength: bufferSize)
        if count <= 0 { break }
        data.append(buffer, count: count)
      }

      return String(data: data, encoding: .utf8) ?? ""
    }

    return ""
  }

  // MARK: - Auth

  func testLogin_success() {
    let exp = expectation(description: "login")
    var loginResult: AuthResult<UserAuth>?

    AuthService.shared.login(serverUrl: baseURL, username: "testuser", password: "secret") {
      result in
      loginResult = result
      exp.fulfill()
    }

    wait(for: [exp], timeout: 5)

    guard let result = loginResult else {
      return XCTFail("No login result")
    }

    switch result {
    case .success(let auth):
      XCTAssertFalse(auth.id.isEmpty)
      XCTAssertFalse(auth.username.isEmpty)
      XCTAssertFalse(auth.subsonicToken.isEmpty)

      AuthService.shared.setCreds(auth)
      XCTAssertFalse(AuthService.shared.getCreds(key: "NDToken").isEmpty)
      XCTAssertTrue(AuthService.shared.getCreds(key: "subsonicToken").contains(auth.username))

    case .failure(let error):
      XCTFail("Login failed: \(error)")
    }
  }

  func testLogin_invalidCredentials() {
    let exp = expectation(description: "login")
    var loginResult: AuthResult<UserAuth>?

    AuthService.shared.login(
      serverUrl: baseURL, username: "invalid_user", password: "wrong"
    ) { result in
      loginResult = result
      exp.fulfill()
    }

    wait(for: [exp], timeout: 5)

    guard let result = loginResult else {
      return XCTFail("No login result")
    }

    switch result {
    case .success:
      XCTFail("Expected login to fail with bad credentials")
    case .failure:
      break
    }
  }

  // MARK: - Albums

  func testGetAlbums() {
    let exp = expectation(description: "get albums")
    var albumsResult: Result<[Album], Error>?

    AlbumService.shared.getAlbum { result in
      albumsResult = result
      exp.fulfill()
    }

    wait(for: [exp], timeout: 5)

    guard case .success(let albums) = albumsResult else {
      return XCTFail("getAlbum failed")
    }

    XCTAssertFalse(albums.isEmpty)
    XCTAssertFalse(albums[0].id.isEmpty)
    XCTAssertFalse(albums[0].name.isEmpty)
  }

  // MARK: - Artists

  func testGetArtists() {
    let exp = expectation(description: "get artists")
    var artistsResult: Result<[Artist], Error>?

    AlbumService.shared.getArtists { result in
      artistsResult = result
      exp.fulfill()
    }

    wait(for: [exp], timeout: 5)

    guard case .success(let artists) = artistsResult else {
      return XCTFail("getArtists failed")
    }

    XCTAssertFalse(artists.isEmpty)
    XCTAssertFalse(artists[0].id.isEmpty)
    XCTAssertFalse(artists[0].name.isEmpty)
  }

  // MARK: - Songs

  func testGetAllSongs() {
    let exp = expectation(description: "get all songs")
    var songsResult: Result<[Song], Error>?

    AlbumService.shared.getAllSongs { result in
      songsResult = result
      exp.fulfill()
    }

    wait(for: [exp], timeout: 5)

    guard case .success(let songs) = songsResult else {
      return XCTFail("getAllSongs failed")
    }

    XCTAssertFalse(songs.isEmpty)
    XCTAssertFalse(songs[0].id.isEmpty)
    XCTAssertFalse(songs[0].title.isEmpty)
  }

  // MARK: - Playlists

  func testGetPlaylists() {
    let exp = expectation(description: "get playlists")
    var playlistsResult: Result<[Playlist], Error>?

    AlbumService.shared.getPlaylists { result in
      playlistsResult = result
      exp.fulfill()
    }

    wait(for: [exp], timeout: 5)

    guard case .success(let playlists) = playlistsResult else {
      return XCTFail("getPlaylists failed")
    }

    XCTAssertFalse(playlists.isEmpty)
    XCTAssertFalse(playlists[0].id.isEmpty)
    XCTAssertFalse(playlists[0].name.isEmpty)
  }

  // MARK: - Albums by artist

  func testGetAlbumsByArtist() {
    let exp = expectation(description: "get albums by artist")
    var albumsResult: Result<[Album], Error>?

    AlbumService.shared.getAlbumsByArtist(id: "ar1") { result in
      albumsResult = result
      exp.fulfill()
    }

    wait(for: [exp], timeout: 5)

    guard case .success = albumsResult else {
      return XCTFail("getAlbumsByArtist failed")
    }
  }

  // MARK: - Radios

  func testGetRadios() {
    let exp = expectation(description: "get radios")
    var radiosResult: Result<[Radio], Error>?

    RadioService.shared.getAllRadios { result in
      radiosResult = result
      exp.fulfill()
    }

    wait(for: [exp], timeout: 5)

    guard case .success(let radios) = radiosResult else {
      return XCTFail("getAllRadios failed")
    }

    XCTAssertFalse(radios.isEmpty)
    XCTAssertFalse(radios[0].id.isEmpty)
    XCTAssertFalse(radios[0].name.isEmpty)
    XCTAssertFalse(radios[0].streamUrl.isEmpty)
  }

  // MARK: - Stream URL

  func testBuildRemoteStreamUrl_containsCorrectParams() {
    let url = AlbumService.shared.buildRemoteStreamUrl(id: "test-song-id")

    XCTAssertTrue(url.contains(baseURL))
    XCTAssertTrue(url.contains("test-song-id"))
    XCTAssertTrue(url.contains("maxBitRate="))
    XCTAssertTrue(url.contains("format="))
  }

  // MARK: - Cover art URL

  func testGetAlbumCover_returnsValidURL() {
    let coverURL = AlbumService.shared.getAlbumCover(
      artistName: "Test Artist", albumName: "Test Album", albumId: "test-album-id")

    XCTAssertFalse(coverURL.isEmpty)
  }

  // MARK: - Scan status

  func testScanStatus() {
    let exp = expectation(description: "get scan status")
    var statusResult: Result<ScanStatusResponse, Error>?

    ScanStatusService.shared.getScanStatus { result in
      statusResult = result
      exp.fulfill()
    }

    wait(for: [exp], timeout: 5)

    guard case .success(let response) = statusResult else {
      return XCTFail("getScanStatus failed")
    }

    XCTAssertEqual(response.subsonicResponse.status, "ok")
  }

  // MARK: - Star / Unstar

  func testStarUnstarLifecycle() {
    let songsExp = expectation(description: "get songs")
    var songsResult: Result<[Song], Error>?

    AlbumService.shared.getAllSongs { result in
      songsResult = result
      songsExp.fulfill()
    }

    wait(for: [songsExp], timeout: 5)

    guard case .success(let songs) = songsResult, let testSong = songs.first else {
      return XCTFail("No songs available")
    }

    let starExp = expectation(description: "star")
    var starSuccess = false
    AlbumService.shared.starSong(id: testSong.id) { success in
      starSuccess = success
      starExp.fulfill()
    }
    wait(for: [starExp], timeout: 5)
    XCTAssertTrue(starSuccess)

    let checkExp = expectation(description: "check starred")
    var isNowStarred = false
    AlbumService.shared.isStarred(songId: testSong.id) { starred in
      isNowStarred = starred
      checkExp.fulfill()
    }
    wait(for: [checkExp], timeout: 5)
    XCTAssertTrue(isNowStarred)

    let unstarExp = expectation(description: "unstar")
    var unstarSuccess = false
    AlbumService.shared.unstarSong(id: testSong.id) { success in
      unstarSuccess = success
      unstarExp.fulfill()
    }
    wait(for: [unstarExp], timeout: 5)
    XCTAssertTrue(unstarSuccess)
  }
}
