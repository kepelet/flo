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
      UserDefaultsKeys.streamCacheMaxSize,
      UserDefaultsKeys.libraryViewV2,
      UserDefaultsKeys.uiFontScale,
      UserDefaultsKeys.libraryV2Segment,
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
      UserDefaultsKeys.streamCacheMaxSize,
      UserDefaultsKeys.libraryViewV2,
      UserDefaultsKeys.uiFontScale,
      UserDefaultsKeys.libraryV2Segment,
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
    UserDefaultsManager.playbackMode = PlaybackMode.repeatOnce

    let all = UserDefaultsManager.getAll()

    XCTAssertEqual(all[UserDefaultsKeys.serverURL] as? String, "https://example.com")
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

  // MARK: - libraryViewV2

  func testLibraryViewV2_getDefault() {
    XCTAssertFalse(UserDefaultsManager.libraryViewV2)
  }

  func testLibraryViewV2_setAndGet() {
    UserDefaultsManager.libraryViewV2 = true
    XCTAssertTrue(UserDefaultsManager.libraryViewV2)
    UserDefaultsManager.libraryViewV2 = false
    XCTAssertFalse(UserDefaultsManager.libraryViewV2)
  }

  // MARK: - uiFontScale

  func testUiFontScale_getDefault() {
    XCTAssertEqual(UserDefaultsManager.uiFontScale, 1.0, accuracy: 0.001)
  }

  func testUiFontScale_setAndGet() {
    UserDefaultsManager.uiFontScale = 1.15
    XCTAssertEqual(UserDefaultsManager.uiFontScale, 1.15, accuracy: 0.001)
  }

  func testUiFontScale_clampingLowerBound() {
    UserDefaultsManager.uiFontScale = 0.5
    XCTAssertEqual(UserDefaultsManager.uiFontScale, 0.8, accuracy: 0.001)
    // persisted value should also be clamped
    XCTAssertEqual(UserDefaults.standard.float(forKey: UserDefaultsKeys.uiFontScale), 0.8, accuracy: 0.001)
  }

  func testUiFontScale_clampingUpperBound() {
    UserDefaultsManager.uiFontScale = 2.0
    XCTAssertEqual(UserDefaultsManager.uiFontScale, 1.4, accuracy: 0.001)
    XCTAssertEqual(UserDefaults.standard.float(forKey: UserDefaultsKeys.uiFontScale), 1.4, accuracy: 0.001)
  }

  func testUiFontScale_persistenceRoundTrip() {
    UserDefaultsManager.uiFontScale = 0.85
    XCTAssertEqual(UserDefaultsManager.uiFontScale, 0.85, accuracy: 0.001)
    UserDefaultsManager.uiFontScale = 1.3
    XCTAssertEqual(UserDefaultsManager.uiFontScale, 1.3, accuracy: 0.001)
    // Simulate fresh read from UserDefaults
    let raw = UserDefaults.standard.float(forKey: UserDefaultsKeys.uiFontScale)
    XCTAssertEqual(raw, 1.3, accuracy: 0.001)
  }

  func testUiFontScale_clampOnRead() {
    // Directly write out-of-bounds value bypassing manager, read should clamp
    UserDefaults.standard.set(Float(0.1), forKey: UserDefaultsKeys.uiFontScale)
    XCTAssertEqual(UserDefaultsManager.uiFontScale, 0.8, accuracy: 0.001)
    UserDefaults.standard.set(Float(5.0), forKey: UserDefaultsKeys.uiFontScale)
    XCTAssertEqual(UserDefaultsManager.uiFontScale, 1.4, accuracy: 0.001)
  }

  // MARK: - libraryV2Segment

  func testLibraryV2Segment_getDefault() {
    XCTAssertEqual(UserDefaultsManager.libraryV2Segment, LibraryV2Segment.library.rawValue)
  }

  func testLibraryV2Segment_setAndGet_library() {
    UserDefaultsManager.libraryV2Segment = LibraryV2Segment.library.rawValue
    XCTAssertEqual(UserDefaultsManager.libraryV2Segment, LibraryV2Segment.library.rawValue)
  }

  func testLibraryV2Segment_setAndGet_downloads() {
    UserDefaultsManager.libraryV2Segment = LibraryV2Segment.downloads.rawValue
    XCTAssertEqual(UserDefaultsManager.libraryV2Segment, LibraryV2Segment.downloads.rawValue)
  }

  func testLibraryV2Segment_persistenceRoundTrip() {
    UserDefaultsManager.libraryV2Segment = LibraryV2Segment.downloads.rawValue
    XCTAssertEqual(UserDefaultsManager.libraryV2Segment, "Downloads")
    let raw = UserDefaults.standard.string(forKey: UserDefaultsKeys.libraryV2Segment)
    XCTAssertEqual(raw, "Downloads")
    UserDefaultsManager.libraryV2Segment = LibraryV2Segment.library.rawValue
    XCTAssertEqual(UserDefaultsManager.libraryV2Segment, "Library")
  }
}
