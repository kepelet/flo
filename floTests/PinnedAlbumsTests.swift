//
//  PinnedAlbumsTests.swift
//  floTests
//

import XCTest

@testable import flo

final class PinnedAlbumsTests: XCTestCase {

  override func setUp() {
    super.setUp()
    UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.pinnedItems)
    UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.pinnedAlbums)
  }

  override func tearDown() {
    UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.pinnedItems)
    UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.pinnedAlbums)
    super.tearDown()
  }

  // MARK: - PinnedKind.toggleTitle

  func testToggleTitle_isSpecificPerKind() {
    XCTAssertEqual(PinnedKind.album.toggleTitle(pinned: false), "Pin album")
    XCTAssertEqual(PinnedKind.album.toggleTitle(pinned: true), "Unpin album")
    XCTAssertEqual(PinnedKind.artist.toggleTitle(pinned: false), "Pin artist")
    XCTAssertEqual(PinnedKind.artist.toggleTitle(pinned: true), "Unpin artist")
    XCTAssertEqual(PinnedKind.playlist.toggleTitle(pinned: false), "Pin playlist")
    XCTAssertEqual(PinnedKind.playlist.toggleTitle(pinned: true), "Unpin playlist")
  }

  // MARK: - UserDefaultsManager.pinnedItems

  func testPinnedItems_defaultIsEmpty() {
    XCTAssertEqual(UserDefaultsManager.pinnedItems, [])
  }

  func testPinnedItems_roundTrip() {
    let items = [
      PinnedItem(kind: .album, refId: "a1", name: "Album", subtitle: "Artist"),
      PinnedItem(kind: .artist, refId: "ar1", name: "Artist"),
      PinnedItem(kind: .playlist, refId: "p1", name: "Playlist", subtitle: "Owner"),
    ]
    UserDefaultsManager.pinnedItems = items

    XCTAssertEqual(UserDefaultsManager.pinnedItems, items)
  }

  // MARK: - PinnedStore basics

  func testStore_defaultIsEmpty() {
    XCTAssertEqual(PinnedStore().items, [])
  }

  func testIsPinned_emptyRefId_returnsFalse() {
    XCTAssertFalse(PinnedStore().isPinned(kind: .album, refId: ""))
  }

  func testPinAlbum_addsMostRecentFirst() {
    let store = PinnedStore()
    store.pin(album: Album(id: "a1", name: "A1", albumArtist: "Art", artist: "Art"))
    store.pin(artist: Artist.placeholder(id: "ar1", name: "Artist"))

    XCTAssertEqual(store.items.map(\.refId), ["ar1", "a1"])
    XCTAssertTrue(store.isPinned(kind: .album, refId: "a1"))
    XCTAssertTrue(store.isPinned(kind: .artist, refId: "ar1"))
    XCTAssertFalse(store.isPinned(kind: .playlist, refId: "a1"))
  }

  func testPin_ignoresEmptyRefIdAndDuplicates() {
    let store = PinnedStore()
    store.pin(PinnedItem(kind: .album, refId: "", name: "Nope"))
    store.pin(PinnedItem(kind: .album, refId: "a1", name: "A1"))
    store.pin(PinnedItem(kind: .album, refId: "a1", name: "A1"))

    XCTAssertEqual(store.items.count, 1)
  }

  func testPinExisting_refreshesDisplayName() {
    let store = PinnedStore()
    store.pin(PinnedItem(kind: .album, refId: "a1", name: "Old"))
    store.pin(PinnedItem(kind: .album, refId: "a1", name: "New", subtitle: "Art"))

    XCTAssertEqual(store.items.count, 1)
    XCTAssertEqual(store.items.first?.name, "New")
    XCTAssertEqual(store.items.first?.subtitle, "Art")
  }

  func testToggle_pinsThenUnpins() {
    let store = PinnedStore()
    let item = PinnedItem(kind: .playlist, refId: "p1", name: "Mix")

    store.toggle(item)
    XCTAssertTrue(store.isPinned(item))

    store.toggle(item)
    XCTAssertFalse(store.isPinned(item))
  }

  func testUnpin_removesOnlyMatchingKindAndId() {
    let store = PinnedStore()
    store.pin(PinnedItem(kind: .album, refId: "x", name: "Album X"))
    store.pin(PinnedItem(kind: .playlist, refId: "x", name: "Playlist X"))

    store.unpin(kind: .album, refId: "x")

    XCTAssertFalse(store.isPinned(kind: .album, refId: "x"))
    XCTAssertTrue(store.isPinned(kind: .playlist, refId: "x"))
  }

  func testPins_persistAcrossStores() {
    let store = PinnedStore()
    store.pin(playlist: Playlist(id: "p1", name: "Roadtrip"))

    let relaunched = PinnedStore()
    XCTAssertTrue(relaunched.isPinned(kind: .playlist, refId: "p1"))
    XCTAssertEqual(relaunched.items.first?.name, "Roadtrip")
  }

  // MARK: - Legacy migration

  func testMigration_legacyAlbumIdsBecomeAlbumPins() {
    UserDefaultsManager.pinnedAlbumIds = ["a1", "a2"]

    let store = PinnedStore()

    XCTAssertEqual(store.items.map(\.refId), ["a1", "a2"])
    XCTAssertTrue(store.items.allSatisfy { $0.kind == .album })
    // Legacy key is cleared so migration runs only once.
    XCTAssertEqual(UserDefaultsManager.pinnedAlbumIds, [])
  }

  func testMigration_skippedWhenNewFormatPresent() {
    UserDefaultsManager.pinnedItems = [PinnedItem(kind: .artist, refId: "ar1", name: "Artist")]
    UserDefaultsManager.pinnedAlbumIds = ["a1"]

    let store = PinnedStore()

    XCTAssertEqual(store.items.map(\.refId), ["ar1"])
  }

  // MARK: - Album pin ordering

  func testSortedAlbumPinsFirst_pinsOnTopInPinOrder() {
    let albums = [
      Album(id: "a", name: "A", albumArtist: "Art", artist: "Art"),
      Album(id: "b", name: "B", albumArtist: "Art", artist: "Art"),
      Album(id: "c", name: "C", albumArtist: "Art", artist: "Art"),
    ]

    let sorted = PinnedStore.sortedAlbumPinsFirst(albums: albums, order: ["c", "a"])

    XCTAssertEqual(sorted.map(\.id), ["c", "a", "b"])
  }

  func testAlbumPinOrder_onlyAlbumsInPinOrder() {
    let store = PinnedStore()
    store.pin(album: Album(id: "a1", name: "A1", albumArtist: "Art", artist: "Art"))
    store.pin(artist: Artist.placeholder(id: "ar1", name: "Artist"))
    store.pin(playlist: Playlist(id: "p1", name: "Mix"))

    XCTAssertEqual(store.albumPinOrder, ["a1"])
  }

  // MARK: - AlbumViewModel pin helpers

  func testPlaylistForNavigation_byId() {
    let sut = AlbumViewModel()
    sut.playlists = [Playlist(id: "p1", name: "Chill"), Playlist(id: "p2", name: "Focus")]

    XCTAssertEqual(sut.playlistForNavigation(id: "p2", name: "").id, "p2")
  }

  func testPlaylistForNavigation_byNameFallback() {
    let sut = AlbumViewModel()
    sut.playlists = [Playlist(id: "p1", name: "Chill")]

    XCTAssertEqual(sut.playlistForNavigation(id: "missing", name: "chill").id, "p1")
  }

  func testPlaylistForNavigation_placeholderWhenUnknown() {
    let sut = AlbumViewModel()
    sut.playlists = []

    let playlist = sut.playlistForNavigation(id: "p9", name: "Lost Mix")

    XCTAssertEqual(playlist.id, "p9")
    XCTAssertEqual(playlist.name, "Lost Mix")
  }

  func testDisplayName_prefersStoredNameThenLiveLookup() {
    let sut = AlbumViewModel()
    sut.albums = [Album(id: "a1", name: "Live Name", albumArtist: "Art", artist: "Art")]

    XCTAssertEqual(
      sut.displayName(for: PinnedItem(kind: .album, refId: "a1", name: "Stored")),
      "Stored")
    XCTAssertEqual(
      sut.displayName(for: PinnedItem(kind: .album, refId: "a1", name: "")),
      "Live Name")
    XCTAssertEqual(
      sut.displayName(for: PinnedItem(kind: .album, refId: "unknown", name: "")),
      "unknown")
  }

  func testCoverArtPath_prefersLiveLibraryData() {
    let sut = AlbumViewModel()
    sut.albums = [Album(id: "a1", name: "A1", albumArtist: "Art", artist: "Art")]
    sut.artists = [Artist.placeholder(id: "ar1", name: "Artist")]
    sut.playlists = [Playlist(id: "p1", name: "Mix")]

    XCTAssertTrue(
      sut.coverArtPath(for: PinnedItem(kind: .album, refId: "a1", name: "")).contains("a1"))
    XCTAssertTrue(
      sut.coverArtPath(for: PinnedItem(kind: .artist, refId: "ar1", name: "")).contains("ar1"))
    XCTAssertTrue(
      sut.coverArtPath(for: PinnedItem(kind: .playlist, refId: "p1", name: "")).contains("p1"))
    // Unknown ids still resolve to a remote art URL, never empty.
    XCTAssertFalse(
      sut.coverArtPath(for: PinnedItem(kind: .album, refId: "missing", name: "")).isEmpty)
  }
}
