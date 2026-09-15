//
//  AlbumViewModelNavigationTests.swift
//  floTests
//

import XCTest

@testable import flo

final class AlbumViewModelNavigationTests: XCTestCase {

  var sut: AlbumViewModel!

  // MARK: - artistForNavigation

  func testArtistForNavigation_byId_exactMatch() {
    let artist = Artist.placeholder(id: "art1", name: "Test Artist")
    sut = AlbumViewModel()
    sut.artists = [artist]

    let result = sut.artistForNavigation(id: "art1", name: "")

    XCTAssertNotNil(result)
    XCTAssertEqual(result?.id, "art1")
  }

  func testArtistForNavigation_byName_caseInsensitive() {
    let artist = Artist.placeholder(id: "art1", name: "Test Artist")
    sut = AlbumViewModel()
    sut.artists = [artist]

    let result = sut.artistForNavigation(name: "test artist")

    XCTAssertNotNil(result)
    XCTAssertEqual(result?.id, "art1")
  }

  func testArtistForNavigation_idTakesPriorityOverName() {
    let artistByName = Artist.placeholder(id: "by-name", name: "Shared Name")
    let artistById = Artist.placeholder(id: "by-id", name: "Different Name")
    sut = AlbumViewModel()
    sut.artists = [artistByName, artistById]

    // Searches with valid id should match by id first
    let result = sut.artistForNavigation(id: "by-id", name: "Shared Name")

    XCTAssertEqual(result?.id, "by-id")
  }

  func testArtistForNavigation_noMatch_returnsPlaceholder() {
    sut = AlbumViewModel()
    sut.artists = []

    let result = sut.artistForNavigation(id: "missing", name: "Unknown")

    XCTAssertNotNil(result)
    XCTAssertEqual(result?.id, "missing")
    XCTAssertEqual(result?.name, "Unknown")
  }

  func testArtistForNavigation_nameIsNA_ignored() {
    sut = AlbumViewModel()
    sut.artists = []

    let result = sut.artistForNavigation(name: "N/A")

    XCTAssertNil(result)
  }

  func testArtistForNavigation_emptyName_emptyId_returnsNil() {
    sut = AlbumViewModel()
    sut.artists = []

    let result = sut.artistForNavigation(name: "")

    XCTAssertNil(result)
  }

  func testArtistForNavigation_trimsWhitespace() {
    let artist = Artist.placeholder(id: "art1", name: "Artist Name")
    sut = AlbumViewModel()
    sut.artists = [artist]

    let result = sut.artistForNavigation(name: "  Artist Name  ")

    XCTAssertNotNil(result)
    XCTAssertEqual(result?.id, "art1")
  }

  // MARK: - albumForNavigation

  func testAlbumForNavigation_byId_exactMatch() {
    let album = Album(
      id: "alb1", name: "Test Album", albumArtist: "Artist 1", artist: "Artist 1")
    sut = AlbumViewModel(album: Album(), albums: [album])

    let result = sut.albumForNavigation(id: "alb1", name: "")

    XCTAssertNotNil(result)
    XCTAssertEqual(result?.id, "alb1")
  }

  func testAlbumForNavigation_byName_exactMatch() {
    let album = Album(
      id: "alb1", name: "Test Album", albumArtist: "Artist 1", artist: "Artist 1")
    sut = AlbumViewModel(album: Album(), albums: [album])

    let result = sut.albumForNavigation(name: "Test Album")

    XCTAssertNotNil(result)
    XCTAssertEqual(result?.id, "alb1")
  }

  func testAlbumForNavigation_byName_caseInsensitive() {
    let album = Album(
      id: "alb1", name: "Test Album", albumArtist: "Artist 1", artist: "Artist 1")
    sut = AlbumViewModel(album: Album(), albums: [album])

    let result = sut.albumForNavigation(name: "test album")

    XCTAssertNotNil(result)
  }

  func testAlbumForNavigation_prefersAlbumArtistMatch() {
    let matchingArtist = Album(
      id: "alb1", name: "Same Name", albumArtist: "Correct Artist", artist: "Correct Artist")
    let otherArtist = Album(
      id: "alb2", name: "Same Name", albumArtist: "Other", artist: "Other")
    sut = AlbumViewModel(album: Album(), albums: [otherArtist, matchingArtist])

    let result = sut.albumForNavigation(name: "Same Name", artist: "Correct Artist")

    XCTAssertEqual(result?.id, "alb1")
  }

  func testAlbumForNavigation_fallsBackToFirstMatch() {
    let first = Album(
      id: "first", name: "Same Name", albumArtist: "Wrong", artist: "Wrong")
    let second = Album(
      id: "second", name: "Same Name", albumArtist: "Also Wrong", artist: "Also Wrong")
    sut = AlbumViewModel(album: Album(), albums: [first, second])

    let result = sut.albumForNavigation(name: "Same Name", artist: "Nonexistent")

    // Falls back to first match when artist doesn't match any
    XCTAssertEqual(result?.id, "first")
  }

  func testAlbumForNavigation_noMatch_returnsPlaceholder() {
    sut = AlbumViewModel(album: Album(), albums: [])

    let result = sut.albumForNavigation(id: "new1", name: "New Album", artist: "New Artist")

    XCTAssertNotNil(result)
    XCTAssertEqual(result?.id, "new1")
    XCTAssertEqual(result?.name, "New Album")
  }

  func testAlbumForNavigation_nameIsNA_returnsNil() {
    sut = AlbumViewModel(album: Album(), albums: [])

    let result = sut.albumForNavigation(name: "N/A")

    XCTAssertNil(result)
  }

  // MARK: - ifNotSharable / ifNotDownloadable

  func testIfNotSharable_onDownloadScreen_returnsTrue() {
    sut = AlbumViewModel()

    XCTAssertTrue(sut.ifNotSharable(isDownloadScreen: true))
  }

  func testIfNotSharable_notOnDownloadScreen_returnsFalse() {
    sut = AlbumViewModel()

    XCTAssertFalse(sut.ifNotSharable(isDownloadScreen: false))
  }

  func testIfNotDownloadable_whenDownloaded_returnsTrue() {
    sut = AlbumViewModel()
    sut.isDownloaded = true

    XCTAssertTrue(sut.ifNotDownloadable())
  }

  func testIfNotDownloadable_whenNotDownloaded_returnsFalse() {
    sut = AlbumViewModel()
    sut.isDownloaded = false

    XCTAssertFalse(sut.ifNotDownloadable())
  }
}
