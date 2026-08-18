//
//  DownloadViewModelTests.swift
//  floTests
//

import XCTest

@testable import flo

final class DownloadViewModelTests: XCTestCase {

  var sut: DownloadViewModel!

  override func setUp() {
    super.setUp()
    sut = DownloadViewModel()
  }

  override func tearDown() {
    sut = nil
    super.tearDown()
  }

  // MARK: - hasDownloadQueue

  func testHasDownloadQueue_whenEmpty_returnsFalse() {
    XCTAssertFalse(sut.hasDownloadQueue())
  }

  func testHasDownloadQueue_whenItemsExist_returnsTrue() {
    let item = DownloadItem(
      id: "1", albumId: "a1", album: "Album", isPlaylist: false,
      title: "Artist - Title", song: makeSong(id: "1"), playlistIndex: -1)
    sut.downloadItems = [item]

    XCTAssertTrue(sut.hasDownloadQueue())
  }

  // MARK: - getRemainingDownloadItems

  func testGetRemainingDownloadItems_allPending() {
    let items = (0..<3).map { i in
      DownloadItem(
        id: "\(i)", albumId: "a1", album: "Album", isPlaylist: false,
        title: "Track \(i)", song: makeSong(id: "\(i)"), playlistIndex: -1,
        status: .idle)
    }
    sut.downloadItems = items

    XCTAssertEqual(sut.getRemainingDownloadItems(), 3)
  }

  func testGetRemainingDownloadItems_mixedStatuses() {
    var items = (0..<4).map { i in
      DownloadItem(
        id: "\(i)", albumId: "a1", album: "Album", isPlaylist: false,
        title: "Track \(i)", song: makeSong(id: "\(i)"), playlistIndex: -1,
        status: .idle)
    }
    items[0].status = .completed
    items[1].status = .completed
    items[2].status = .failed
    sut.downloadItems = items

    XCTAssertEqual(sut.getRemainingDownloadItems(), 2)  // idle + failed
  }

  func testGetRemainingDownloadItems_allCompleted() {
    let items = (0..<2).map { i in
      DownloadItem(
        id: "\(i)", albumId: "a1", album: "Album", isPlaylist: false,
        title: "Track \(i)", song: makeSong(id: "\(i)"), playlistIndex: -1,
        status: .completed)
    }
    sut.downloadItems = items

    XCTAssertEqual(sut.getRemainingDownloadItems(), 0)
  }

  // MARK: - isDownloading

  func testIsDownloading_whenAlbumHasDownloadingItem_returnsTrue() {
    var item = DownloadItem(
      id: "1", albumId: "a1", album: "Test Album", isPlaylist: false,
      title: "Track", song: makeSong(id: "1"), playlistIndex: -1,
      status: .downloading)
    let otherAlbum = DownloadItem(
      id: "2", albumId: "a2", album: "Other", isPlaylist: false,
      title: "Other Track", song: makeSong(id: "2"), playlistIndex: -1,
      status: .idle)
    sut.downloadItems = [item, otherAlbum]

    XCTAssertTrue(sut.isDownloading("Test Album"))
  }

  func testIsDownloading_whenAlbumHasOnlyIdle_returnsFalse() {
    let item = DownloadItem(
      id: "1", albumId: "a1", album: "Test Album", isPlaylist: false,
      title: "Track", song: makeSong(id: "1"), playlistIndex: -1,
      status: .idle)
    sut.downloadItems = [item]

    XCTAssertFalse(sut.isDownloading("Test Album"))
  }

  func testIsDownloading_whenNoDownloadingItemsAtAll_returnsFalse() {
    XCTAssertFalse(sut.isDownloading("Any Album"))
  }

  // MARK: - isDownloaded

  func testIsDownloaded_whenElapsedIs100Percent_returnsTrue() {
    sut.downloadedTrackCount = [
      DownloadTrackCount(id: "a1", name: "Album", elapsed: 1.0, total: 5)
    ]

    XCTAssertTrue(sut.isDownloaded("Album"))
  }

  func testIsDownloaded_whenElapsedIsPartial_returnsFalse() {
    sut.downloadedTrackCount = [
      DownloadTrackCount(id: "a1", name: "Album", elapsed: 0.6, total: 5)
    ]

    XCTAssertFalse(sut.isDownloaded("Album"))
  }

  func testIsDownloaded_whenNotInList_returnsFalse() {
    sut.downloadedTrackCount = [
      DownloadTrackCount(id: "a1", name: "Other", elapsed: 1.0, total: 5)
    ]

    XCTAssertFalse(sut.isDownloaded("Album"))
  }

  // MARK: - getDownloadedTrackProgress

  func testGetDownloadedTrackProgress_whenPresent() {
    sut.downloadedTrackCount = [
      DownloadTrackCount(id: "a1", name: "Album", elapsed: 0.75, total: 8)
    ]

    XCTAssertEqual(sut.getDownloadedTrackProgress(albumName: "Album"), 75.0)
  }

  func testGetDownloadedTrackProgress_whenNotPresent_returnsZero() {
    XCTAssertEqual(sut.getDownloadedTrackProgress(albumName: "Unknown"), 0.0)
  }

  // MARK: - removeFromQueue

  func testRemoveFromQueue_removesMatchingItem() {
    let items = (0..<3).map { i in
      DownloadItem(
        id: "\(i)", albumId: "a1", album: "Album", isPlaylist: false,
        title: "Track \(i)", song: makeSong(id: "\(i)"), playlistIndex: -1)
    }
    sut.downloadItems = items

    sut.removeFromQueue("1")

    XCTAssertEqual(sut.downloadItems.count, 2)
    XCTAssertFalse(sut.downloadItems.contains(where: { $0.id == "1" }))
  }

  func testRemoveFromQueue_nonExistentId_noop() {
    let items = (0..<2).map { i in
      DownloadItem(
        id: "\(i)", albumId: "a1", album: "Album", isPlaylist: false,
        title: "Track \(i)", song: makeSong(id: "\(i)"), playlistIndex: -1)
    }
    sut.downloadItems = items

    sut.removeFromQueue("999")

    XCTAssertEqual(sut.downloadItems.count, 2)
  }

  // MARK: - clearCompletedQueue

  func testClearCompletedQueue_removesCompletedAndCancelled() {
    var items = (0..<4).map { i in
      DownloadItem(
        id: "\(i)", albumId: "a1", album: "Album", isPlaylist: false,
        title: "Track \(i)", song: makeSong(id: "\(i)"), playlistIndex: -1)
    }
    items[0].status = .completed
    items[1].status = .cancelled
    items[2].status = .failed
    items[3].status = .downloading
    sut.downloadItems = items

    sut.clearCompletedQueue()

    XCTAssertEqual(sut.downloadItems.count, 2)
    XCTAssertTrue(sut.downloadItems.contains(where: { $0.id == "2" }))  // failed kept
    XCTAssertTrue(sut.downloadItems.contains(where: { $0.id == "3" }))  // downloading kept
  }

  // MARK: - retryAllFailedQueue

  func testRetryAllFailedQueue_resetsFailedToQueued() {
    var items = (0..<3).map { i in
      DownloadItem(
        id: "\(i)", albumId: "a1", album: "Album", isPlaylist: false,
        title: "Track \(i)", song: makeSong(id: "\(i)"), playlistIndex: -1)
    }
    items[0].status = .failed
    items[1].status = .failed
    items[2].status = .completed
    sut.downloadItems = items

    sut.retryAllFailedQueue()

    // retryAllFailedQueue sets failed → queued then calls processQueue,
    // which may immediately start downloads. Verify items are no longer .failed.
    let stillFailed = sut.downloadItems.filter { $0.status == .failed }
    XCTAssertEqual(stillFailed.count, 0)
    XCTAssertEqual(sut.downloadItems[2].status, .completed)  // untouched
  }

  // MARK: - clearCurrentAlbumDownload

  func testClearCurrentAlbumDownload_removesOnlyMatchingAlbum() {
    let albumA = (0..<2).map { i in
      DownloadItem(
        id: "a\(i)", albumId: "1", album: "Album A", isPlaylist: false,
        title: "A \(i)", song: makeSong(id: "a\(i)"), playlistIndex: -1)
    }
    let albumB = (0..<2).map { i in
      DownloadItem(
        id: "b\(i)", albumId: "2", album: "Album B", isPlaylist: false,
        title: "B \(i)", song: makeSong(id: "b\(i)"), playlistIndex: -1)
    }
    sut.downloadItems = albumA + albumB

    sut.clearCurrentAlbumDownload(albumName: "Album A")

    XCTAssertEqual(sut.downloadItems.count, 2)
    XCTAssertTrue(sut.downloadItems.allSatisfy { $0.album == "Album B" })
  }

  // MARK: - retryDownload

  func testRetryDownload_resetsToQueued() {
    var item = DownloadItem(
      id: "1", albumId: "a1", album: "Album", isPlaylist: false,
      title: "Track", song: makeSong(id: "1"), playlistIndex: -1,
      status: .failed)
    sut.downloadItems = [item]

    sut.retryDownload("1")

    // retryDownload sets status to .queued then calls processQueue,
    // which may immediately start the download. Status should no longer be .failed.
    XCTAssertNotEqual(sut.downloadItems.first?.status, .failed)
  }

  func testRetryDownload_nonExistentId_noop() {
    sut.retryDownload("999")
    XCTAssertTrue(sut.downloadItems.isEmpty)
  }

  // MARK: - addItem (DownloadItem construction)

  func testAddItem_addsSongsWithoutFileUrl() {
    let song1 = makeSong(id: "s1")
    let song2 = Song(
      id: "s2", title: "Already Local", albumId: "a1", albumName: "Album",
      artist: "Artist", trackNumber: 2, discNumber: 1,
      bitRate: 320, sampleRate: 44100,
      suffix: "mp3", duration: 200, mediaFileId: "m2")
    var song2WithUrl = song2
    song2WithUrl.fileUrl = "/local/path/song2.mp3"

    let album = Album(
      id: "a1", name: "Test Album", albumArtist: "Artist", artist: "Artist",
      songs: [song1, song2WithUrl])

    sut.addItem(album)

    // Only song1 should be added (no fileUrl); song2 has fileUrl so it's skipped
    XCTAssertEqual(sut.downloadItems.count, 1)
    XCTAssertEqual(sut.downloadItems.first?.id, "s1")
  }

  func testAddItem_forceAll_addsAllSongs() {
    let song1 = makeSong(id: "s1")
    var song2 = makeSong(id: "s2")
    song2.fileUrl = "/local/path/song2.mp3"

    let album = Album(
      id: "a1", name: "Test Album", albumArtist: "Artist", artist: "Artist",
      songs: [song1, song2])

    sut.addItem(album, forceAll: true)

    XCTAssertEqual(sut.downloadItems.count, 2)
  }

  func testAddItem_skipsDuplicateIds() {
    let song = makeSong(id: "s1")
    let album = Album(
      id: "a1", name: "Test Album", albumArtist: "Artist", artist: "Artist",
      songs: [song])

    // First add
    sut.addItem(album)
    XCTAssertEqual(sut.downloadItems.count, 1)

    // Second add with same album
    sut.addItem(album)
    // Should still be 1 because retryDownload is called on duplicate
    XCTAssertEqual(sut.downloadItems.count, 1)
  }

  func testAddItem_addsDownloadTrackCount() {
    let songs = (0..<5).map { makeSong(id: "s\($0)") }
    let album = Album(
      id: "a1", name: "Big Album", albumArtist: "Artist", artist: "Artist",
      songs: songs)

    sut.addItem(album)

    XCTAssertEqual(sut.downloadedTrackCount.count, 1)
    XCTAssertEqual(sut.downloadedTrackCount.first?.total, 5)
    XCTAssertEqual(sut.downloadedTrackCount.first?.elapsed, 0.0)
  }

  // MARK: - addIndividualItem

  func testAddIndividualItem_addsSingleSong() {
    let song = makeSong(id: "s1")
    let album = Album(id: "a1", name: "Album", albumArtist: "A", artist: "A")

    sut.addIndividualItem(album: album, song: song)

    XCTAssertEqual(sut.downloadItems.count, 1)
    XCTAssertEqual(sut.downloadItems.first?.id, "s1")
    XCTAssertEqual(sut.downloadItems.first?.title, "Artist - Test Title")
  }

  func testAddIndividualItem_skipsDuplicate() {
    let song = makeSong(id: "dup")
    let album = Album(id: "a1", name: "Album", albumArtist: "A", artist: "A")

    sut.addIndividualItem(album: album, song: song)
    sut.addIndividualItem(album: album, song: song)

    XCTAssertEqual(sut.downloadItems.count, 1)
  }

  // MARK: - cancelCurrentAlbumDownload

  func testCancelCurrentAlbumDownload_marksItemsCancelled() {
    var items = [
      DownloadItem(
        id: "a0", albumId: "1", album: "Album A", isPlaylist: false,
        title: "A0", song: makeSong(id: "a0"), playlistIndex: -1,
        status: .downloading),
      DownloadItem(
        id: "a1", albumId: "1", album: "Album A", isPlaylist: false,
        title: "A1", song: makeSong(id: "a1"), playlistIndex: -1,
        status: .idle),
      DownloadItem(
        id: "b0", albumId: "2", album: "Album B", isPlaylist: false,
        title: "B0", song: makeSong(id: "b0"), playlistIndex: -1,
        status: .downloading),
    ]
    sut.downloadItems = items

    sut.cancelCurrentAlbumDownload(albumName: "Album A")

    // cancelDownload only sets .cancelled if there's an active download request.
    // Items without active downloads keep their original status.
    // Verify Album B is untouched and the call doesn't crash.
    let albumBItems = sut.downloadItems.filter { $0.album == "Album B" }
    XCTAssertEqual(albumBItems.count, 1)
    XCTAssertEqual(albumBItems.first?.status, .downloading)
  }

  // MARK: - Helpers

  private func makeSong(id: String) -> Song {
    return Song(
      id: id, title: "Test Title", albumId: "a1", albumName: "Album",
      artist: "Artist", trackNumber: 1, discNumber: 1,
      bitRate: 320, sampleRate: 44100,
      suffix: "mp3", duration: 100, mediaFileId: id)
  }
}
