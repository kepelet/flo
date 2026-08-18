//
//  MergePlaylistSongsTests.swift
//  floTests
//

import XCTest

@testable import flo

final class MergePlaylistSongsTests: XCTestCase {

  // MARK: - mergePlaylistSongs

  func testMerge_emptyLocal_emptyRemote() {
    let result = merge(local: [], remote: [])
    XCTAssertEqual(result.count, 0)
  }

  func testMerge_emptyLocal_preservesRemoteOrder() {
    let remote = [
      makeSong(id: "r1", mediaFileId: "mf1"),
      makeSong(id: "r2", mediaFileId: "mf2"),
      makeSong(id: "r3", mediaFileId: "mf3"),
    ]

    let result = merge(local: [], remote: remote)

    XCTAssertEqual(result.map(\.id), ["r1", "r2", "r3"])
  }

  func testMerge_localSongReplacesRemoteByMediaFileId() {
    let local = [makeSong(id: "local-s1", mediaFileId: "mf1", fileUrl: "/local/s1.mp3")]
    let remote = [
      makeSong(id: "r1", mediaFileId: "mf1"),
      makeSong(id: "r2", mediaFileId: "mf2"),
    ]

    let result = merge(local: local, remote: remote)

    XCTAssertEqual(result.map(\.id), ["local-s1", "r2"])
    // Verify the local song kept its fileUrl
    XCTAssertEqual(result[0].fileUrl, "/local/s1.mp3")
  }

  func testMerge_multipleLocalsReplaceCorrespondingRemotes() {
    let locals = [
      makeSong(id: "local-1", mediaFileId: "mf1", fileUrl: "/local/1.mp3"),
      makeSong(id: "local-2", mediaFileId: "mf3", fileUrl: "/local/2.mp3"),
    ]
    let remotes = [
      makeSong(id: "r1", mediaFileId: "mf1"),
      makeSong(id: "r2", mediaFileId: "mf2"),
      makeSong(id: "r3", mediaFileId: "mf3"),
    ]

    let result = merge(local: locals, remote: remotes)

    XCTAssertEqual(result.map(\.id), ["local-1", "r2", "local-2"])
  }

  func testMerge_localNotInRemote_appendedToEnd() {
    let locals = [
      makeSong(id: "orphan-1", mediaFileId: "mf-orphan", fileUrl: "/local/orphan.mp3")
    ]
    let remotes = [
      makeSong(id: "r1", mediaFileId: "mf1"),
      makeSong(id: "r2", mediaFileId: "mf2"),
    ]

    let result = merge(local: locals, remote: remotes)

    // Orphaned local songs appended after remote order
    XCTAssertEqual(result.map(\.id), ["r1", "r2", "orphan-1"])
  }

  func testMerge_duplicateLocalMediaFileIds_usesFirstOnly() {
    let locals = [
      makeSong(id: "first-dup", mediaFileId: "mf1"),
      makeSong(id: "second-dup", mediaFileId: "mf1"),  // same mediaFileId
    ]
    let remotes = [
      makeSong(id: "r1", mediaFileId: "mf1")
    ]

    let result = merge(local: locals, remote: remotes)

    // Only the first local with mf1 replaces the remote; the duplicate
    // is dropped because its mediaFileId was already consumed.
    XCTAssertEqual(result.count, 1)
    XCTAssertEqual(result[0].id, "first-dup")
  }

  func testMerge_multipleOrphans_appendedInInputOrder() {
    let locals = [
      makeSong(id: "orphan-a", mediaFileId: "mf-a"),
      makeSong(id: "orphan-b", mediaFileId: "mf-b"),
    ]
    let remotes = [makeSong(id: "r1", mediaFileId: "mf1")]

    let result = merge(local: locals, remote: remotes)

    XCTAssertEqual(result.map(\.id), ["r1", "orphan-a", "orphan-b"])
  }

  // MARK: - Private helper

  private func merge(local: [Song], remote: [Song]) -> [Song] {
    return AlbumViewModel.mergePlaylistSongs(local: local, remote: remote)
  }

  private func makeSong(id: String, mediaFileId: String, fileUrl: String = "") -> Song {
    var song = Song(
      id: id, title: "T", albumId: "a1", albumName: "A",
      artist: "Art", trackNumber: 1, discNumber: 1,
      bitRate: 320, sampleRate: 44100,
      suffix: "mp3", duration: 100, mediaFileId: mediaFileId)
    song.fileUrl = fileUrl
    return song
  }
}
