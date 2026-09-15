//
//  AlbumServicePlaylistTests.swift
//  floTests
//

import CoreData
import XCTest

@testable import flo

final class AlbumServicePlaylistTests: XCTestCase {

  var sut: CoreDataManager!
  private var storeURL: URL!
  private var originalContainer: NSPersistentContainer!

  override func setUp() {
    super.setUp()

    sut = CoreDataManager.shared
    originalContainer = sut.persistentContainer

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

    sut.persistentContainer = container
  }

  override func tearDown() {
    sut.persistentContainer = originalContainer
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

  // MARK: - isPlaylistDownload

  func testIsPlaylistDownload_trueForPlaylistPrefixedSongId() {
    makeSong(id: "pl:pl1:mf1", albumId: "pl1", mediaFileId: "mf1")
    sut.saveRecord()

    XCTAssertTrue(AlbumService.shared.isPlaylistDownload(id: "pl1"))
  }

  func testIsPlaylistDownload_falseForAlbumSongId() {
    makeSong(id: "song-1", albumId: "al1", mediaFileId: "song-1")
    sut.saveRecord()

    XCTAssertFalse(AlbumService.shared.isPlaylistDownload(id: "al1"))
  }

  func testIsPlaylistDownload_falseWhenNoSongs() {
    XCTAssertFalse(AlbumService.shared.isPlaylistDownload(id: "missing"))
  }

  // MARK: - getPlaylistSongs ordering

  func testGetPlaylistSongs_sortedByPosition() {
    makeSong(id: "pl:pl1:mf2", albumId: "pl1", mediaFileId: "mf2", position: 2, title: "Second")
    makeSong(id: "pl:pl1:mf0", albumId: "pl1", mediaFileId: "mf0", position: 0, title: "Zeroth")
    makeSong(id: "pl:pl1:mf1", albumId: "pl1", mediaFileId: "mf1", position: 1, title: "First")
    sut.saveRecord()

    let songs = AlbumService.shared.getPlaylistSongs(playlistId: "pl1")

    XCTAssertEqual(songs.map(\.mediaFileId), ["mf0", "mf1", "mf2"])
  }

  func testGetPlaylistSongs_unknownPositionFallsBackToTrackNumber() {
    // Position defaults to 0 for pre-fix downloads; trackNumber is the tiebreaker.
    makeSong(
      id: "pl:pl1:mf2", albumId: "pl1", mediaFileId: "mf2", position: 0, trackNumber: 3,
      title: "Third")
    makeSong(
      id: "pl:pl1:mf1", albumId: "pl1", mediaFileId: "mf1", position: 0, trackNumber: 1,
      title: "First")
    makeSong(
      id: "pl:pl1:mf0", albumId: "pl1", mediaFileId: "mf0", position: 0, trackNumber: 2,
      title: "Second")
    sut.saveRecord()

    let songs = AlbumService.shared.getPlaylistSongs(playlistId: "pl1")

    XCTAssertEqual(songs.map(\.mediaFileId), ["mf1", "mf0", "mf2"])
  }

  // MARK: - updatePlaylistPositions

  func testUpdatePlaylistPositions_backfillsExistingDownloads() {
    // Pre-fix downloads all share position 0.
    makeSong(id: "pl:pl1:mf0", albumId: "pl1", mediaFileId: "mf0", position: 0, title: "Zero")
    makeSong(id: "pl:pl1:mf1", albumId: "pl1", mediaFileId: "mf1", position: 0, title: "One")
    sut.saveRecord()

    // Server-ordered merged array: mf1 comes before mf0.
    let orderedSongs = [
      makeLocalSong(id: "pl:pl1:mf1", mediaFileId: "mf1"),
      makeLocalSong(id: "pl:pl1:mf0", mediaFileId: "mf0"),
    ]

    AlbumService.shared.updatePlaylistPositions(playlistId: "pl1", songs: orderedSongs)

    let fetched = AlbumService.shared.getPlaylistSongs(playlistId: "pl1")
    XCTAssertEqual(fetched.map(\.mediaFileId), ["mf1", "mf0"])
  }

  func testUpdatePlaylistPositions_noChangeWhenAlreadyCorrect() {
    makeSong(id: "pl:pl1:mf0", albumId: "pl1", mediaFileId: "mf0", position: 0, title: "Zero")
    makeSong(id: "pl:pl1:mf1", albumId: "pl1", mediaFileId: "mf1", position: 1, title: "One")
    sut.saveRecord()

    let orderedSongs = [
      makeLocalSong(id: "pl:pl1:mf0", mediaFileId: "mf0"),
      makeLocalSong(id: "pl:pl1:mf1", mediaFileId: "mf1"),
    ]

    AlbumService.shared.updatePlaylistPositions(playlistId: "pl1", songs: orderedSongs)

    let fetched = AlbumService.shared.getPlaylistSongs(playlistId: "pl1")
    XCTAssertEqual(fetched.map(\.mediaFileId), ["mf0", "mf1"])
  }

  // MARK: - Helpers

  @discardableResult
  private func makeSong(
    id: String,
    albumId: String,
    mediaFileId: String,
    position: Int32 = -1,
    trackNumber: Int16 = 0,
    title: String = "Title"
  ) -> SongEntity {
    let song = SongEntity(context: sut.viewContext)
    song.id = id
    song.albumId = albumId
    song.mediaFileId = mediaFileId
    song.position = position
    song.trackNumber = trackNumber
    song.title = title
    song.artistName = "Artist"
    song.suffix = "mp3"
    return song
  }

  private func makeLocalSong(id: String, mediaFileId: String) -> Song {
    return Song(
      id: id, title: "Title", albumId: "pl1", albumName: "Album",
      artist: "Artist", trackNumber: 1, discNumber: 1,
      bitRate: 320, sampleRate: 44100,
      suffix: "mp3", duration: 100, mediaFileId: mediaFileId)
  }
}
