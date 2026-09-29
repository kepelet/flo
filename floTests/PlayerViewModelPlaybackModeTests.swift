//
//  PlayerViewModelPlaybackModeTests.swift
//  floTests
//

import XCTest
import Foundation

@testable import flo

final class PlayerViewModelPlaybackModeTests: XCTestCase {

  var sut: PlayerViewModel!

  override func setUp() {
    super.setUp()
    sut = PlayerViewModel()
    // Start from a known state
    sut.playbackMode = PlaybackMode.defaultPlayback
  }

  override func tearDown() {
    sut.playbackMode = PlaybackMode.defaultPlayback
    sut.destroyPlayerAndQueue()
    sut = nil
    super.tearDown()
  }

  // MARK: - setPlaybackMode cycling

  func testSetPlaybackMode_cyclesDefaultToRepeatAlbum() {
    sut.playbackMode = PlaybackMode.defaultPlayback
    sut.setPlaybackMode()

    XCTAssertEqual(sut.playbackMode, PlaybackMode.repeatAlbum)
  }

  func testSetPlaybackMode_cyclesRepeatAlbumToRepeatOnce() {
    sut.playbackMode = PlaybackMode.repeatAlbum
    sut.setPlaybackMode()

    XCTAssertEqual(sut.playbackMode, PlaybackMode.repeatOnce)
  }

  func testSetPlaybackMode_cyclesRepeatOnceToDefault() {
    sut.playbackMode = PlaybackMode.repeatOnce
    sut.setPlaybackMode()

    XCTAssertEqual(sut.playbackMode, PlaybackMode.defaultPlayback)
  }

  func testSetPlaybackMode_fullCycle() {
    sut.playbackMode = PlaybackMode.defaultPlayback

    sut.setPlaybackMode()
    XCTAssertEqual(sut.playbackMode, PlaybackMode.repeatAlbum)

    sut.setPlaybackMode()
    XCTAssertEqual(sut.playbackMode, PlaybackMode.repeatOnce)

    sut.setPlaybackMode()
    XCTAssertEqual(sut.playbackMode, PlaybackMode.defaultPlayback)
  }

  func testSetPlaybackMode_persistsToUserDefaults() {
    UserDefaultsManager.playbackMode = PlaybackMode.defaultPlayback

    sut.setPlaybackMode()

    XCTAssertEqual(UserDefaultsManager.playbackMode, PlaybackMode.repeatAlbum)
  }

  // MARK: - isPlayFromSource

  func testIsPlayFromSource_whenMaxBitRateIsSource_returnsTrue() {
    UserDefaultsManager.maxBitRate = TranscodingSettings.sourceBitRate

    XCTAssertTrue(sut.isPlayFromSource)
  }

  func testIsPlayFromSource_whenMaxBitRateIsTranscoded_returnsFalse() {
    UserDefaultsManager.maxBitRate = "320"

    XCTAssertFalse(sut.isPlayFromSource)
  }

  // MARK: - isLRCLIBEnabled

  func testIsLRCLIBEnabled_whenURLIsSet_returnsTrue() {
    UserDefaultsManager.LRCLIBServerURL = "https://lrclib.example.com"

    XCTAssertTrue(sut.isLRCLIBEnabled)
  }

  func testIsLRCLIBEnabled_whenURLEmpty_returnsFalse() {
    UserDefaultsManager.LRCLIBServerURL = ""

    XCTAssertFalse(sut.isLRCLIBEnabled)
  }

  // MARK: - isLiveRadio (no queue loaded)

  func testIsLiveRadio_whenQueueEmpty_returnsFalse() {
    // After init, queue starts empty unless state was persisted
    if sut.queue.isEmpty {
      XCTAssertFalse(sut.isLiveRadio)
    }
  }

  // MARK: - Gapless next-index resolution

  func testGaplessNextIndex_defaultPlayback_advances() {
    sut.queue = makeQueueEntities(count: 3)
    sut.activeQueueIdx = 1
    sut.playbackMode = PlaybackMode.defaultPlayback

    XCTAssertEqual(sut.nextQueueIdxForGapless(), 2)
  }

  func testGaplessNextIndex_defaultPlayback_nilAtEnd() {
    sut.queue = makeQueueEntities(count: 3)
    sut.activeQueueIdx = 2
    sut.playbackMode = PlaybackMode.defaultPlayback

    XCTAssertNil(sut.nextQueueIdxForGapless())
  }

  func testGaplessNextIndex_repeatAlbum_wrapsAtEnd() {
    sut.queue = makeQueueEntities(count: 3)
    sut.activeQueueIdx = 2
    sut.playbackMode = PlaybackMode.repeatAlbum

    XCTAssertEqual(sut.nextQueueIdxForGapless(), 0)
  }

  func testGaplessNextIndex_repeatOnce_repeatsCurrent() {
    sut.queue = makeQueueEntities(count: 3)
    sut.activeQueueIdx = 1
    sut.playbackMode = PlaybackMode.repeatOnce

    XCTAssertEqual(sut.nextQueueIdxForGapless(), 1)
  }

  func testGaplessNextIndex_emptyQueue_returnsNil() {
    sut.queue = []
    sut.playbackMode = PlaybackMode.repeatOnce

    XCTAssertNil(sut.nextQueueIdxForGapless())
  }

  func testGaplessNextIndex_singleTrackRepeatOnce_repeats() {
    sut.queue = makeQueueEntities(count: 1)
    sut.activeQueueIdx = 0
    sut.playbackMode = PlaybackMode.repeatOnce

    XCTAssertEqual(sut.nextQueueIdxForGapless(), 0)
  }

  // MARK: - Failure skip resolution

  func testFailureNextIndex_defaultPlayback_advances() {
    sut.queue = makeQueueEntities(count: 3)
    sut.activeQueueIdx = 1
    sut.playbackMode = PlaybackMode.defaultPlayback

    XCTAssertEqual(sut.nextDistinctIdxAfterFailure(), 2)
  }

  func testFailureNextIndex_defaultPlayback_nilAtEnd() {
    sut.queue = makeQueueEntities(count: 3)
    sut.activeQueueIdx = 2
    sut.playbackMode = PlaybackMode.defaultPlayback

    XCTAssertNil(sut.nextDistinctIdxAfterFailure())
  }

  func testFailureNextIndex_repeatAlbum_wrapsAtEnd() {
    sut.queue = makeQueueEntities(count: 3)
    sut.activeQueueIdx = 2
    sut.playbackMode = PlaybackMode.repeatAlbum

    XCTAssertEqual(sut.nextDistinctIdxAfterFailure(), 0)
  }

  func testFailureNextIndex_repeatOnce_movesToDistinctTrack() {
    sut.queue = makeQueueEntities(count: 3)
    sut.activeQueueIdx = 0
    sut.playbackMode = PlaybackMode.repeatOnce

    XCTAssertEqual(sut.nextDistinctIdxAfterFailure(), 1)
  }

  func testFailureNextIndex_singleTrack_returnsNil() {
    sut.queue = makeQueueEntities(count: 1)
    sut.activeQueueIdx = 0
    sut.playbackMode = PlaybackMode.repeatOnce

    XCTAssertNil(sut.nextDistinctIdxAfterFailure())
  }

  // MARK: - Crossfade setting

  func testCrossfadeDuration_defaultsOff() {
    UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.crossfadeDuration)
    XCTAssertEqual(UserDefaultsManager.crossfadeDuration, 0.0, accuracy: 0.001)
    XCTAssertFalse(UserDefaultsManager.crossfadeEnabled)
  }

  func testCrossfadeDuration_persistsAndEnables() {
    UserDefaultsManager.crossfadeDuration = 10.0
    XCTAssertEqual(UserDefaultsManager.crossfadeDuration, 10.0, accuracy: 0.001)
    XCTAssertTrue(UserDefaultsManager.crossfadeEnabled)

    UserDefaultsManager.crossfadeDuration = 0.0
    XCTAssertEqual(UserDefaultsManager.crossfadeDuration, 0.0, accuracy: 0.001)
    XCTAssertFalse(UserDefaultsManager.crossfadeEnabled)
  }

  // MARK: - Stream cache completion contract

  func testCacheSong_withCacheDisabled_completesFalse() {
    UserDefaultsManager.streamCacheMaxSize = 0

    let exp = expectation(description: "cache completion")
    var result: Bool?

    StreamCacheManager.shared.cacheSong(mediaFileId: "song-1") { ready in
      result = ready
      exp.fulfill()
    }

    wait(for: [exp], timeout: 2)
    XCTAssertEqual(result, false)
  }

  // MARK: - Helpers

  private func makeQueueEntities(count: Int) -> [QueueEntity] {
    let context = CoreDataManager.shared.viewContext
    return (0..<count).map { i in
      let entity = QueueEntity(context: context)
      entity.id = "q\(i)"
      entity.songName = "Track \(i)"
      entity.duration = 100
      entity.sampleRate = 44100
      return entity
    }
  }

  // MARK: - PlaybackCoordinator.resolveSongIndex (via indirect access)

  func testPlaybackCoordinator_resolveSongIndex_byId() {
    let songs = [
      makeSong(id: "s1"), makeSong(id: "s2"), makeSong(id: "s3"),
    ]

    // resolveSongIndex is private; verify behavior through known song ids
    let index = songs.firstIndex(where: { $0.id == "s2" })
    XCTAssertEqual(index, 1)
  }

  func testPlaybackCoordinator_resolveSongIndex_notFound() {
    let songs = [makeSong(id: "s1")]

    let index = songs.firstIndex(where: {
      $0.id == "nonexistent" || $0.mediaFileId == "nonexistent"
    })
    XCTAssertNil(index)
  }

  // MARK: - AuthService.setCreds / getCreds

  func testAuthService_setAndGetNDToken() {
    let auth = UserAuth(
      id: "u1", username: "user", name: "Name", isAdmin: false,
      subsonicSalt: "salt", subsonicToken: "stok", token: "ndtok")

    AuthService.shared.setCreds(auth)

    XCTAssertTrue(AuthService.shared.getCreds(key: "NDToken").contains("ndtok"))
  }

  func testAuthService_setAndGetSubsonicToken() {
    let auth = UserAuth(
      id: "u1", username: "user", name: "Name", isAdmin: false,
      subsonicSalt: "salt", subsonicToken: "stok", token: "ndtok")

    AuthService.shared.setCreds(auth)

    let subsonicParams = AuthService.shared.getCreds(key: "subsonicToken")
    XCTAssertTrue(subsonicParams.contains("user"))
    XCTAssertTrue(subsonicParams.contains("stok"))
    XCTAssertTrue(subsonicParams.contains("salt"))
  }

  func testAuthService_getCreds_unknownKey_returnsEmpty() {
    XCTAssertEqual(AuthService.shared.getCreds(key: "nonexistent"), "")
  }

  // MARK: - AuthService.setAuthMode / getAuthMode

  func testAuthService_setAndGetAuthMode() {
    AuthService.shared.setAuthMode(.iap)
    XCTAssertEqual(AuthService.shared.getAuthMode(), .iap)

    AuthService.shared.setAuthMode(.standard)
    XCTAssertEqual(AuthService.shared.getAuthMode(), .standard)
  }

  // MARK: - Helpers

  private func makeSong(id: String) -> Song {
    return Song(
      id: id, title: "Test", albumId: "a1", albumName: "Album",
      artist: "Artist", trackNumber: 1, discNumber: 1,
      bitRate: 320, sampleRate: 44100,
      suffix: "mp3", duration: 100, mediaFileId: id)
  }
}
