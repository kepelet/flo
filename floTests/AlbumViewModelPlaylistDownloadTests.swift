//
//  AlbumViewModelPlaylistDownloadTests.swift
//  floTests
//

import CoreData
import XCTest

@testable import flo

/// Verifies that opening a downloaded playlist from the Downloads screen marks
/// the view model so song rows are numbered by playlist position (FLO issue
/// #156), while downloaded albums keep their album track numbers.
final class AlbumViewModelPlaylistDownloadTests: XCTestCase {

  var sut: AlbumViewModel!
  private var storeURL: URL!
  private var originalContainer: NSPersistentContainer!

  override func setUp() {
    super.setUp()

    sut = AlbumViewModel()
    originalContainer = CoreDataManager.shared.persistentContainer

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

    UserDefaultsManager.serverBaseURL = "https://mock.example"
    MockURLProtocol.reset()
    APIManager.extraProtocolClasses = [MockURLProtocol.self]
    APIManager.shared.reconfigureSession()
  }

  override func tearDown() {
    CoreDataManager.shared.persistentContainer = originalContainer
    APIManager.extraProtocolClasses = []
    APIManager.shared.reconfigureSession()
    MockURLProtocol.reset()

    if let url = storeURL {
      let shm = URL(fileURLWithPath: url.path + "-shm")
      let wal = URL(fileURLWithPath: url.path + "-wal")
      for u in [url, shm, wal] {
        try? FileManager.default.removeItem(at: u)
      }
    }
    storeURL = nil
    originalContainer = nil
    sut = nil

    super.tearDown()
  }

  // MARK: - Helpers

  private func makePlaylistSong(
    id: String, albumId: String, trackNumber: Int16, position: Int32, title: String
  ) {
    let song = SongEntity(context: CoreDataManager.shared.viewContext)
    song.id = id
    song.albumId = albumId
    song.albumName = "Test Playlist"
    song.title = title
    song.artistName = "Various Artists"
    song.trackNumber = trackNumber
    song.position = position
    song.status = "Downloaded"

    CoreDataManager.shared.saveRecord()
  }

  // MARK: - isViewingPlaylistDownload

  func testSetActiveAlbum_downloadedPlaylist_marksPlaylistNumbering() {
    makePlaylistSong(
      id: "pl:pl1:mf1", albumId: "pl1", trackNumber: 3, position: 0, title: "First in playlist")
    makePlaylistSong(
      id: "pl:pl1:mf2", albumId: "pl1", trackNumber: 1, position: 1, title: "Second in playlist")

    sut.setActiveAlbum(album: Album(id: "pl1", name: "Test Playlist"))

    XCTAssertTrue(sut.isViewingPlaylistDownload)
    // Songs load locally in playlist position order, not album track order.
    XCTAssertEqual(sut.album.songs.map(\.title), ["First in playlist", "Second in playlist"])
  }

  func testSetActiveAlbum_downloadedAlbum_usesAlbumNumbering() {
    let song = SongEntity(context: CoreDataManager.shared.viewContext)
    song.id = "song-1"
    song.albumId = "al1"
    song.albumName = "Test Album"
    song.title = "Album Track"
    song.artistName = "Artist"
    song.trackNumber = 1
    song.status = "Downloaded"

    CoreDataManager.shared.saveRecord()

    sut.setActiveAlbum(album: Album(id: "al1", name: "Test Album"))

    XCTAssertFalse(sut.isViewingPlaylistDownload)
  }

  func testSetActiveAlbum_noDownloadedSongs_usesAlbumNumbering() {
    sut.setActiveAlbum(album: Album(id: "missing", name: "Missing"))

    XCTAssertFalse(sut.isViewingPlaylistDownload)
  }
}
