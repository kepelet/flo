//
//  LyricsLineTests.swift
//  floTests
//

import XCTest

@testable import flo

final class LyricsLineTests: XCTestCase {

  // MARK: - isCurrentLine

  func testIsCurrentLine_exactMatch() {
    let line = LyricsLine(timestamp: 10.0, text: "Test")
    XCTAssertTrue(line.isCurrentLine(currentTime: 10.0))
  }

  func testIsCurrentLine_withinDefaultThreshold() {
    let line = LyricsLine(timestamp: 10.0, text: "Test")
    XCTAssertTrue(line.isCurrentLine(currentTime: 10.3))
    XCTAssertTrue(line.isCurrentLine(currentTime: 9.7))
  }

  func testIsCurrentLine_outsideDefaultThreshold() {
    let line = LyricsLine(timestamp: 10.0, text: "Test")
    XCTAssertFalse(line.isCurrentLine(currentTime: 10.6))
    XCTAssertFalse(line.isCurrentLine(currentTime: 9.4))
  }

  func testIsCurrentLine_boundaryOfThreshold() {
    let line = LyricsLine(timestamp: 10.0, text: "Test")
    // At exactly 0.5 away, abs(10.0 - 10.5) == 0.5, which is NOT < 0.5
    XCTAssertFalse(line.isCurrentLine(currentTime: 10.5))
    XCTAssertFalse(line.isCurrentLine(currentTime: 9.5))
  }

  // MARK: - isCurrentLine with custom threshold

  func testIsCurrentLine_customThreshold_tighter() {
    let line = LyricsLine(timestamp: 10.0, text: "Test")
    XCTAssertTrue(line.isCurrentLine(currentTime: 10.05, threshold: 0.1))
    XCTAssertFalse(line.isCurrentLine(currentTime: 10.2, threshold: 0.1))
  }

  func testIsCurrentLine_customThreshold_wider() {
    let line = LyricsLine(timestamp: 10.0, text: "Test")
    XCTAssertTrue(line.isCurrentLine(currentTime: 10.9, threshold: 1.0))
    XCTAssertFalse(line.isCurrentLine(currentTime: 11.1, threshold: 1.0))
  }
}
