//
//  PlaybackServiceTests.swift
//  floTests
//

import CoreData
import XCTest

@testable import flo

final class PlaybackServiceTests: XCTestCase {

  var sut: PlaybackService!
  private var storeURL: URL!
  private var originalContainer: NSPersistentContainer!

  override func setUp() {
    super.setUp()
    sut = PlaybackService.shared

    // Use the already-resolved managed object model from the shared container
    // and swap in a temp SQLite store for test isolation.
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
    sut.clearQueue()
    CoreDataManager.shared.persistentContainer = originalContainer
    sut = nil
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

  // MARK: - addToQueue with Album

  func testAddToQueue_album_createsQueueEntities() {
    let songs = [
      makeSong(id: "s1", albumName: "Test Album", artist: "Artist", title: "Track 1"),
      makeSong(id: "s2", albumName: "Test Album", artist: "Artist", title: "Track 2"),
    ]
    let album = Album(
      id: "a1", name: "Test Album", albumArtist: "Artist", artist: "Artist",
      songs: songs)

    let queue = sut.addToQueue(item: album)

    XCTAssertEqual(queue.count, 2)
    XCTAssertEqual(queue[0].songName, "Track 1")
    XCTAssertEqual(queue[1].songName, "Track 2")
    XCTAssertEqual(queue[0].albumName, "Test Album")
    XCTAssertEqual(queue[0].contextName, "Test Album")
    XCTAssertEqual(queue[0].artistName, "Artist")
    XCTAssertEqual(queue[0].id, "s1")
    XCTAssertEqual(queue[0].isFromPlaylist, false)
  }

  func testAddToQueue_playlist_marksIsFromPlaylist() {
    let songs = [makeSong(id: "s1", albumName: "Playlist Album", artist: "Artist")]
    let playlist = Playlist(
      id: "p1", name: "My Playlist", comment: "", isPublic: true,
      ownerName: "owner", songs: songs)

    let queue = sut.addToQueue(item: playlist)

    XCTAssertEqual(queue.count, 1)
    XCTAssertTrue(queue[0].isFromPlaylist)
    XCTAssertEqual(queue[0].contextName, "My Playlist")
  }

  // MARK: - clearQueue

  func testClearQueue_removesAll() {
    let album = Album(
      id: "a1", name: "Album", albumArtist: "A", artist: "A",
      songs: [makeSong(id: "s1")])

    _ = sut.addToQueue(item: album)
    XCTAssertEqual(sut.getQueue().count, 1)

    sut.clearQueue()
    XCTAssertEqual(sut.getQueue().count, 0)
  }

  // MARK: - shuffleQueue

  func testShuffleQueue_preservesHead() {
    let songs = (0..<10).map { i in
      makeSong(id: "s\(i)", albumName: "Album", artist: "A", title: "Track \(i)")
    }
    let album = Album(
      id: "a1", name: "Album", albumArtist: "A", artist: "A",
      songs: songs)

    _ = sut.addToQueue(item: album)
    let shuffled = sut.shuffleQueue(currentIdx: 2)

    // Head (indices 0-2) should be preserved in order
    XCTAssertEqual(shuffled[0].songName, "Track 0")
    XCTAssertEqual(shuffled[1].songName, "Track 1")
    XCTAssertEqual(shuffled[2].songName, "Track 2")

    // Total count should remain the same
    XCTAssertEqual(shuffled.count, 10)
  }

  func testShuffleQueue_tailContainsAllSongs() {
    let songs = (0..<10).map { i in
      makeSong(id: "s\(i)", albumName: "Album", artist: "A", title: "Track \(i)")
    }
    let album = Album(
      id: "a1", name: "Album", albumArtist: "A", artist: "A",
      songs: songs)

    _ = sut.addToQueue(item: album)
    let shuffled = sut.shuffleQueue(currentIdx: 2)

    // Verify all songs still present
    let titles = shuffled.compactMap { $0.songName }
    let expected = (0..<10).map { "Track \($0)" }
    XCTAssertEqual(titles.sorted(), expected.sorted())
  }

  // MARK: - addToQueue replaces existing queue

  func testAddToQueue_replacesExistingQueue() {
    let album1 = Album(
      id: "a1", name: "First", albumArtist: "A", artist: "A",
      songs: [makeSong(id: "s1")])
    let album2 = Album(
      id: "a2", name: "Second", albumArtist: "B", artist: "B",
      songs: [makeSong(id: "s2")])

    _ = sut.addToQueue(item: album1)
    _ = sut.addToQueue(item: album2)

    let queue = sut.getQueue()
    XCTAssertEqual(queue.count, 1)
    XCTAssertEqual(queue[0].songName, "Test Title")  // from s2
  }

  // MARK: - Heuristic: playlist-album detection

  func testAddToQueue_variousArtistsAlbum_detectedAsPlaylist() {
    let songs = [makeSong(id: "s1", albumName: "Mix", artist: "Original Artist")]
    let album = Album(
      id: "p1", name: "Greatest Hits", albumArtist: "Various Artists",
      artist: "Various Artists", songs: songs, genre: "Compilation by DJ")

    let queue = sut.addToQueue(item: album)

    XCTAssertTrue(queue[0].isFromPlaylist)
  }

  // MARK: - addToQueue song properties

  func testAddToQueue_preservesSongProperties() {
    let song = Song(
      id: "detailed", title: "Detail Song", albumId: "a1",
      albumName: "Detail Album", artist: "Detail Artist",
      trackNumber: 3, discNumber: 2,
      bitRate: 256, sampleRate: 48000,
      suffix: "flac", duration: 300.5, mediaFileId: "media1",
      explicitStatus: .explicit)

    let album = Album(
      id: "a1", name: "Album", albumArtist: "Artist", artist: "Artist",
      songs: [song])

    let queue = sut.addToQueue(item: album)

    XCTAssertEqual(queue.count, 1)
    XCTAssertEqual(queue[0].bitRate, 256)
    XCTAssertEqual(queue[0].sampleRate, 48000)
    XCTAssertEqual(queue[0].suffix, "flac")
    XCTAssertEqual(queue[0].duration, 300.5)
    XCTAssertEqual(queue[0].explicitStatus, "explicit")
    XCTAssertEqual(queue[0].albumId, "a1")
  }

  // MARK: - Helpers

  private func makeSong(
    id: String, albumName: String = "", artist: String = "", title: String = "Test Title"
  ) -> Song {
    return Song(
      id: id, title: title, albumId: "a1", albumName: albumName,
      artist: artist, trackNumber: 1, discNumber: 1,
      bitRate: 320, sampleRate: 44100,
      suffix: "mp3", duration: 100, mediaFileId: id)
  }
}
