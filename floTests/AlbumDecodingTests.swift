//
//  AlbumDecodingTests.swift
//  floTests
//

import XCTest

@testable import flo

final class AlbumDecodingTests: XCTestCase {

  // MARK: - Full JSON decoding

  func testDecode_fullAlbumJSON() throws {
    let json = """
      {
        "id": "album1",
        "name": "Test Album",
        "albumArtist": "Album Artist",
        "artist": "Track Artist",
        "artistId": "artist1",
        "albumArtistId": "albumartist1",
        "albumCover": "cover123",
        "genre": "Rock",
        "minYear": 2024,
        "songs": [
          {
            "id": "song1",
            "title": "Song One",
            "artist": "Track Artist",
            "albumId": "album1",
            "album": "Test Album",
            "trackNumber": 1,
            "discNumber": 1,
            "bitRate": 320,
            "sampleRate": 44100,
            "suffix": "mp3",
            "duration": 180.0
          }
        ],
        "explicitStatus": "explicit"
      }
      """

    let album = try JSONDecoder().decode(Album.self, from: Data(json.utf8))

    XCTAssertEqual(album.id, "album1")
    XCTAssertEqual(album.name, "Test Album")
    XCTAssertEqual(album.albumArtist, "Album Artist")
    XCTAssertEqual(album.artist, "Track Artist")
    XCTAssertEqual(album.artistId, "artist1")
    XCTAssertEqual(album.albumArtistId, "albumartist1")
    XCTAssertEqual(album.albumCover, "cover123")
    XCTAssertEqual(album.genre, "Rock")
    XCTAssertEqual(album.minYear, 2024)
    XCTAssertEqual(album.songs.count, 1)
    XCTAssertEqual(album.songs[0].title, "Song One")
    XCTAssertEqual(album.explicitStatus, .explicit)
  }

  func testDecode_minimalAlbumJSON() throws {
    let json = """
      {
        "id": "album1",
        "name": "Test Album",
        "albumArtist": "Artist",
        "genre": "Rock",
        "minYear": 2024
      }
      """

    let album = try JSONDecoder().decode(Album.self, from: Data(json.utf8))

    XCTAssertEqual(album.id, "album1")
    XCTAssertEqual(album.name, "Test Album")
    XCTAssertEqual(album.artistId, "")
    XCTAssertEqual(album.albumArtistId, "")
    XCTAssertEqual(album.albumCover, "")
    XCTAssertEqual(album.songs.count, 0)
    XCTAssertEqual(album.explicitStatus, .unknown)
  }

  // MARK: - Pre-BFR compatibility (artist field fallback)

  func testDecode_artistFallbackToAlbumArtist() throws {
    // When artist field is missing, it should fall back to albumArtist
    let json = """
      {
        "id": "album1",
        "name": "Test Album",
        "albumArtist": "The Artist",
        "genre": "Rock",
        "minYear": 2024
      }
      """

    let album = try JSONDecoder().decode(Album.self, from: Data(json.utf8))

    // artist should be set to albumArtist since the "artist" field is absent
    XCTAssertEqual(album.artist, "The Artist")
  }

  // MARK: - resolvedArtistId

  func testResolvedArtistId_prefersAlbumArtistId() {
    let album = Album(
      id: "1", name: "Album", albumArtist: "AA", artist: "A",
      artistId: "artist1", albumArtistId: "aa1"
    )

    XCTAssertEqual(album.resolvedArtistId, "aa1")
  }

  func testResolvedArtistId_fallsBackToArtistId() {
    let album = Album(
      id: "1", name: "Album", albumArtist: "AA", artist: "A",
      artistId: "artist1", albumArtistId: ""
    )

    XCTAssertEqual(album.resolvedArtistId, "artist1")
  }

  func testResolvedArtistId_emptyBoth() {
    let album = Album(
      id: "1", name: "Album", albumArtist: "AA", artist: "A",
      artistId: "", albumArtistId: ""
    )

    XCTAssertEqual(album.resolvedArtistId, "")
  }

  // MARK: - isExplicit propagation

  func testIsExplicit_albumExplicit_returnsTrue() {
    let album = Album(
      id: "1", name: "Album", albumArtist: "AA", artist: "A",
      explicitStatus: .explicit
    )

    XCTAssertTrue(album.isExplicit)
  }

  func testIsExplicit_albumClean_noExplicitSongs_returnsFalse() {
    let album = Album(
      id: "1", name: "Album", albumArtist: "AA", artist: "A",
      explicitStatus: .clean
    )

    XCTAssertFalse(album.isExplicit)
  }

  func testIsExplicit_albumClean_hasExplicitSong_returnsTrue() {
    let explicitSong = Song(
      id: "s1", title: "T", albumId: "a1", albumName: "Album",
      artist: "A", trackNumber: 1, discNumber: 1,
      bitRate: 320, sampleRate: 44100,
      suffix: "mp3", duration: 100, mediaFileId: "m1",
      explicitStatus: .explicit
    )

    let album = Album(
      id: "1", name: "Album", albumArtist: "AA", artist: "A",
      songs: [explicitSong], explicitStatus: .clean
    )

    XCTAssertTrue(album.isExplicit)
  }

  func testIsExplicit_unknown_noExplicitSongs_returnsFalse() {
    let cleanSong = Song(
      id: "s1", title: "T", albumId: "a1", albumName: "Album",
      artist: "A", trackNumber: 1, discNumber: 1,
      bitRate: 320, sampleRate: 44100,
      suffix: "mp3", duration: 100, mediaFileId: "m1",
      explicitStatus: .clean
    )

    let album = Album(
      id: "1", name: "Album", albumArtist: "AA", artist: "A",
      songs: [cleanSong], explicitStatus: .unknown
    )

    XCTAssertFalse(album.isExplicit)
  }

  // MARK: - Init from Playlist

  func testInitFromPlaylist() {
    let playlist = Playlist(
      id: "p1", name: "My Playlist", comment: "A comment",
      isPublic: true, ownerName: "Owner", songs: []
    )

    let album = Album(from: playlist)

    XCTAssertEqual(album.id, "p1")
    XCTAssertEqual(album.name, "My Playlist")
    XCTAssertEqual(album.albumArtist, "Various Artists")
    XCTAssertEqual(album.artist, "Various Artists")
    XCTAssertEqual(album.genre, "A comment by Owner")
    XCTAssertEqual(album.minYear, 0)
    XCTAssertEqual(album.albumCover, "")
  }
}

final class AlbumLibraryScopeTests: XCTestCase {
  private let libraries = [Library(id: 1, name: "Music"), Library(id: 2, name: "Jazz"),
    Library(id: 3, name: "Audioplays")]
  private let albums = [Album(id: "music", libraryId: 1), Album(id: "jazz", libraryId: 2),
    Album(id: "story", libraryId: 3), Album(id: "legacy")]

  func testAllLibrariesExcludesAudioplaysButKeepsLegacyAlbums() {
    let scope = AlbumLibraryScope(libraries: libraries, selectedLibraryId: 0, audioplayLibraryId: 3)
    XCTAssertEqual(scope.musicAlbums(from: albums).map(\.id), ["music", "jazz", "legacy"])
    XCTAssertEqual(scope.audioplays(from: albums).map(\.id), ["story"])
    XCTAssertEqual(scope.selectableLibraries.map(\.id), [1, 2])
  }

  func testSelectedLibraryFiltersMusicWithoutChangingAudioplays() {
    let scope = AlbumLibraryScope(libraries: libraries, selectedLibraryId: 2, audioplayLibraryId: 3)
    XCTAssertEqual(scope.musicAlbums(from: albums).map(\.id), ["jazz"])
    XCTAssertEqual(scope.audioplays(from: albums).map(\.id), ["story"])
  }

  func testReassignedOrRemovedSelectionFallsBackToAllMusic() {
    for id in [3, 99] {
      let scope = AlbumLibraryScope(libraries: libraries, selectedLibraryId: id, audioplayLibraryId: 3)
      XCTAssertEqual(scope.effectiveLibraryId, 0)
      XCTAssertEqual(scope.musicAlbums(from: albums).map(\.id), ["music", "jazz", "legacy"])
    }
  }

  func testOfflineSelectionSurvivesUnavailableLibraryList() {
    let scope = AlbumLibraryScope(libraries: [], selectedLibraryId: 2, audioplayLibraryId: 3)
    XCTAssertEqual(scope.musicAlbums(from: albums).map(\.id), ["jazz"])
  }

  func testDisablingAudioplaysRestoresAllAlbums() {
    let scope = AlbumLibraryScope(libraries: libraries, selectedLibraryId: 0, audioplayLibraryId: 0)
    XCTAssertEqual(scope.musicAlbums(from: albums).map(\.id), albums.map(\.id))
    XCTAssertTrue(scope.audioplays(from: albums).isEmpty)
  }

  func testLibraryMetadataSurvivesAlbumCacheRoundTrip() throws {
    let album = Album(id: "story", libraryId: 3, libraryName: "Audioplays")
    let restored = try JSONDecoder().decode(Album.self, from: JSONEncoder().encode(album))
    XCTAssertEqual(restored.libraryId, 3)
    XCTAssertEqual(restored.libraryName, "Audioplays")
  }
}
