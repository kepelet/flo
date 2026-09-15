//
//  ExplicitStatusTests.swift
//  floTests
//

import XCTest

@testable import flo

final class ExplicitStatusTests: XCTestCase {

  // MARK: - init(from:) raw value mapping

  func testInit_fromNil_returnsUnknown() {
    XCTAssertEqual(ExplicitStatus(from: nil), .unknown)
  }

  func testInit_fromEmptyString_returnsUnknown() {
    XCTAssertEqual(ExplicitStatus(from: ""), .unknown)
  }

  func testInit_fromWhitespace_returnsUnknown() {
    XCTAssertEqual(ExplicitStatus(from: "   "), .unknown)
  }

  func testInit_fromExplicit_returnsExplicit() {
    XCTAssertEqual(ExplicitStatus(from: "explicit"), .explicit)
  }

  func testInit_fromExplicitUppercase_returnsExplicit() {
    XCTAssertEqual(ExplicitStatus(from: "EXPLICIT"), .explicit)
  }

  func testInit_fromExplicitWithWhitespace_returnsExplicit() {
    XCTAssertEqual(ExplicitStatus(from: "  explicit  "), .explicit)
  }

  func testInit_fromE_returnsExplicit() {
    XCTAssertEqual(ExplicitStatus(from: "e"), .explicit)
  }

  func testInit_fromNumber1_returnsExplicit() {
    XCTAssertEqual(ExplicitStatus(from: "1"), .explicit)
  }

  func testInit_fromNumber4_returnsExplicit() {
    XCTAssertEqual(ExplicitStatus(from: "4"), .explicit)
  }

  func testInit_fromClean_returnsClean() {
    XCTAssertEqual(ExplicitStatus(from: "clean"), .clean)
  }

  func testInit_fromCleanUppercase_returnsClean() {
    XCTAssertEqual(ExplicitStatus(from: "CLEAN"), .clean)
  }

  func testInit_fromC_returnsClean() {
    XCTAssertEqual(ExplicitStatus(from: "c"), .clean)
  }

  func testInit_fromNumber2_returnsClean() {
    XCTAssertEqual(ExplicitStatus(from: "2"), .clean)
  }

  func testInit_fromUnknownString_returnsUnknown() {
    XCTAssertEqual(ExplicitStatus(from: "garbage"), .unknown)
  }

  // MARK: - isExplicit

  func testIsExplicit_explicitCase_returnsTrue() {
    XCTAssertTrue(ExplicitStatus.explicit.isExplicit)
  }

  func testIsExplicit_cleanCase_returnsFalse() {
    XCTAssertFalse(ExplicitStatus.clean.isExplicit)
  }

  func testIsExplicit_unknownCase_returnsFalse() {
    XCTAssertFalse(ExplicitStatus.unknown.isExplicit)
  }

  // MARK: - annotatedTitle

  func testAnnotatedTitle_explicit_addsBadge() {
    let result = ExplicitStatus.explicit.annotatedTitle("Song Name")
    XCTAssertTrue(result.contains("\u{1F174}"))
    XCTAssertTrue(result.hasPrefix("Song Name"))
  }

  func testAnnotatedTitle_clean_returnsAsIs() {
    let result = ExplicitStatus.clean.annotatedTitle("Song Name")
    XCTAssertEqual(result, "Song Name")
  }

  func testAnnotatedTitle_unknown_returnsAsIs() {
    let result = ExplicitStatus.unknown.annotatedTitle("Song Name")
    XCTAssertEqual(result, "Song Name")
  }
}
