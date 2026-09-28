//
//  QueueEmptyCrashTests.swift
//  floTests
//
//  Regression tests: emptying the queue (removing the last item or clearing
//  it) must never trap. `nowPlaying` used to force-subscript the queue, so
//  any reader evaluating during the teardown window — after `queue` empties
//  but before the presence gates flip — crashed with Index out of range.
//

import CoreData
import XCTest

@testable import flo

final class QueueEmptyCrashTests: XCTestCase {

  private var originalContainer: NSPersistentContainer!
  private var storeURL: URL!

  override func setUp() {
    super.setUp()

    // Isolate Core Data in a temp SQLite store (mirrors PlaybackServiceTests).
    let shared = CoreDataManager.shared
    originalContainer = shared.persistentContainer

    storeURL = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
      .appendingPathExtension("sqlite")

    let desc = NSPersistentStoreDescription(url: storeURL)
    desc.shouldAddStoreAsynchronously = false

    let model = originalContainer.managedObjectModel
    let container = NSPersistentContainer(name: "flo", managedObjectModel: model)
    container.persistentStoreDescriptions = [desc]

    let expect = expectation(description: "load stores")
    container.loadPersistentStores { _, error in
      XCTAssertNil(error, "Failed to load store: \(error?.localizedDescription ?? "")")
      expect.fulfill()
    }
    wait(for: [expect], timeout: 5)
    container.viewContext.automaticallyMergesChangesFromParent = true

    CoreDataManager.shared.persistentContainer = container
  }

  override func tearDown() {
    PlaybackService.shared.clearQueue()
    CoreDataManager.shared.persistentContainer = originalContainer
    originalContainer = nil

    if let url = storeURL {
      let shm = URL(fileURLWithPath: url.path + "-shm")
      let wal = URL(fileURLWithPath: url.path + "-wal")
      for u in [url, shm, wal] {
        try? FileManager.default.removeItem(at: u)
      }
    }
    storeURL = nil
    super.tearDown()
  }

  // MARK: - Empty queue is always readable

  func testNowPlayingDoesNotTrapOnEmptyQueue() {
    let vm = PlayerViewModel()
    vm.queue = []
    vm.activeQueueIdx = 0

    XCTAssertFalse(vm.hasNowPlaying())
    // Pre-fix: fatal error (Index out of range) on each of these.
    _ = vm.nowPlaying
    XCTAssertEqual(vm.getAlbumCoverArt(), "")
    XCTAssertFalse(vm.isLiveRadio)
  }

  func testRemoveLastItemLeavesSafeState() {
    seedQueue(songCount: 1)
    let vm = PlayerViewModel()
    vm.queue = PlaybackService.shared.getQueue()
    vm.activeQueueIdx = 0
    XCTAssertEqual(vm.queue.count, 1)

    vm.removeFromQueue(at: 0)

    XCTAssertTrue(vm.queue.isEmpty)
    XCTAssertFalse(vm.hasNowPlaying())
    _ = vm.nowPlaying
    XCTAssertEqual(vm.getAlbumCoverArt(), "")
    XCTAssertFalse(vm.isLiveRadio)
  }

  func testClearQueueLeavesSafeState() {
    seedQueue(songCount: 2)
    let vm = PlayerViewModel()
    vm.queue = PlaybackService.shared.getQueue()
    vm.activeQueueIdx = 1
    XCTAssertEqual(vm.queue.count, 2)

    vm.clearQueue()

    XCTAssertTrue(vm.queue.isEmpty)
    XCTAssertEqual(vm.activeQueueIdx, 0)
    XCTAssertFalse(vm.hasNowPlaying())
    _ = vm.nowPlaying
    XCTAssertEqual(vm.getAlbumCoverArt(), "")
    XCTAssertFalse(vm.isLiveRadio)
  }

  // MARK: - Helpers

  private func seedQueue(songCount: Int) {
    let songs = (0..<songCount).map { i in
      Song(
        id: "q\(i)", title: "Track \(i)", albumId: "a1", albumName: "Album",
        artist: "Artist", trackNumber: i + 1, discNumber: 1,
        bitRate: 320, sampleRate: 44100,
        suffix: "mp3", duration: 100, mediaFileId: "q\(i)")
    }
    let album = Album(
      id: "a1", name: "Album", albumArtist: "Artist", artist: "Artist",
      songs: songs)
    _ = PlaybackService.shared.addToQueue(item: album)
  }
}
