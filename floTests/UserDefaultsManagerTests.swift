//
//  UserDefaultsManagerTests.swift
//  floTests
//

import XCTest

@testable import flo

final class UserDefaultsManagerTests: XCTestCase {

  override func setUp() {
    super.setUp()

    // Clean up UserDefaults to start each test with a known state
    let keys = [
      UserDefaultsKeys.serverURL,
      UserDefaultsKeys.queueActiveIdx,
      UserDefaultsKeys.nowPlayingProgress,
      UserDefaultsKeys.playbackMode,
      UserDefaultsKeys.enableDebug,
      UserDefaultsKeys.enableMaxBitRate,
      UserDefaultsKeys.saveLoginInfo,
      UserDefaultsKeys.LRCLIBServerURL,
      UserDefaultsKeys.floPlus,
      UserDefaultsKeys.streamCacheMaxSize,
    ]

    for key in keys {
      UserDefaults.standard.removeObject(forKey: key)
    }
  }

  override func tearDown() {
    super.tearDown()

    let keys = [
      UserDefaultsKeys.serverURL,
      UserDefaultsKeys.queueActiveIdx,
      UserDefaultsKeys.nowPlayingProgress,
      UserDefaultsKeys.playbackMode,
      UserDefaultsKeys.enableDebug,
      UserDefaultsKeys.enableMaxBitRate,
      UserDefaultsKeys.saveLoginInfo,
      UserDefaultsKeys.LRCLIBServerURL,
      UserDefaultsKeys.floPlus,
      UserDefaultsKeys.streamCacheMaxSize,
    ]

    for key in keys {
      UserDefaults.standard.removeObject(forKey: key)
    }
  }

  // MARK: - serverBaseURL

  func testServerBaseURL_getDefault() {
    XCTAssertEqual(UserDefaultsManager.serverBaseURL, "")
  }

  func testServerBaseURL_setAndGet() {
    UserDefaultsManager.serverBaseURL = "https://music.example.com"

    XCTAssertEqual(UserDefaultsManager.serverBaseURL, "https://music.example.com")
  }

  // MARK: - queueActiveIdx

  func testQueueActiveIdx_getDefault() {
    let _ = UserDefaultsManager.queueActiveIdx  // reads default 0
    // UserDefaults.integer(forKey:) returns 0 for unset keys
    XCTAssertEqual(UserDefaultsManager.queueActiveIdx, 0)
  }

  func testQueueActiveIdx_setAndGet() {
    UserDefaultsManager.queueActiveIdx = 5

    XCTAssertEqual(UserDefaultsManager.queueActiveIdx, 5)
  }

  // MARK: - nowPlayingProgress

  func testNowPlayingProgress_getDefault() {
    XCTAssertEqual(UserDefaultsManager.nowPlayingProgress, 0.0)
  }

  func testNowPlayingProgress_setAndGet() {
    UserDefaultsManager.nowPlayingProgress = 123.45

    XCTAssertEqual(UserDefaultsManager.nowPlayingProgress, 123.45)
  }

  // MARK: - playbackMode

  func testPlaybackMode_getDefault() {
    XCTAssertEqual(UserDefaultsManager.playbackMode, PlaybackMode.defaultPlayback)
  }

  func testPlaybackMode_setAndGet() {
    UserDefaultsManager.playbackMode = PlaybackMode.repeatAlbum

    XCTAssertEqual(UserDefaultsManager.playbackMode, PlaybackMode.repeatAlbum)
  }

  // MARK: - enableDebug

  func testEnableDebug_getDefault() {
    XCTAssertFalse(UserDefaultsManager.enableDebug)
  }

  func testEnableDebug_setAndGet() {
    UserDefaultsManager.enableDebug = true

    XCTAssertTrue(UserDefaultsManager.enableDebug)
  }

  // MARK: - maxBitRate

  func testMaxBitRate_getDefault() {
    XCTAssertEqual(UserDefaultsManager.maxBitRate, TranscodingSettings.sourceBitRate)
  }

  func testMaxBitRate_setAndGet() {
    UserDefaultsManager.maxBitRate = "320"

    XCTAssertEqual(UserDefaultsManager.maxBitRate, "320")
  }

  // MARK: - saveLoginInfo

  func testSaveLoginInfo_getDefault() {
    XCTAssertFalse(UserDefaultsManager.saveLoginInfo)
  }

  func testSaveLoginInfo_setAndGet() {
    UserDefaultsManager.saveLoginInfo = true

    XCTAssertTrue(UserDefaultsManager.saveLoginInfo)
  }

  // MARK: - LRCLIBServerURL

  func testLRCLIBServerURL_getDefault() {
    XCTAssertEqual(UserDefaultsManager.LRCLIBServerURL, "")
  }

  func testLRCLIBServerURL_setAndGet() {
    UserDefaultsManager.LRCLIBServerURL = "https://lrclib.example.com"

    XCTAssertEqual(UserDefaultsManager.LRCLIBServerURL, "https://lrclib.example.com")
  }

  // MARK: - floPlus

  func testFloPlus_getDefault() {
    XCTAssertFalse(UserDefaultsManager.floPlus)
  }

  func testFloPlus_setAndGet() {
    UserDefaultsManager.floPlus = true

    XCTAssertTrue(UserDefaultsManager.floPlus)
  }

  // MARK: - streamCacheMaxSize

  func testStreamCacheMaxSize_getDefault() {
    // Default should be 0 (off) when unset
    XCTAssertEqual(UserDefaultsManager.streamCacheMaxSize, 0)
  }

  func testStreamCacheMaxSize_setAndGet() {
    UserDefaultsManager.streamCacheMaxSize = 1_073_741_824  // 1 GB

    XCTAssertEqual(UserDefaultsManager.streamCacheMaxSize, 1_073_741_824)
  }

  // MARK: - getAll

  func testGetAll_includesSetKeys() {
    UserDefaultsManager.serverBaseURL = "https://example.com"
    UserDefaultsManager.floPlus = true
    UserDefaultsManager.playbackMode = PlaybackMode.repeatOnce

    let all = UserDefaultsManager.getAll()

    XCTAssertEqual(all[UserDefaultsKeys.serverURL] as? String, "https://example.com")
    XCTAssertEqual(all[UserDefaultsKeys.floPlus] as? Bool, true)
    XCTAssertEqual(all[UserDefaultsKeys.playbackMode] as? String, PlaybackMode.repeatOnce)
  }

  // MARK: - removeObject

  func testRemoveObject_clearsValue() {
    UserDefaultsManager.serverBaseURL = "https://example.com"
    UserDefaultsManager.removeObject(key: UserDefaultsKeys.serverURL)

    XCTAssertEqual(UserDefaultsManager.serverBaseURL, "")
  }

  // MARK: - playerBackground

  func testPlayerBackground_alwaysReturnsTranslucent() {
    // per the implementation, playerBackground always returns translucent
    XCTAssertEqual(UserDefaultsManager.playerBackground, PlayerBackground.translucent)
  }
}
