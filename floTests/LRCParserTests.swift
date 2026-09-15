//
//  LRCParserTests.swift
//  floTests
//

import XCTest

@testable import flo

final class LRCParserTests: XCTestCase {

  // MARK: - Basic parsing

  func testParse_singleLine() {
    let lrc = """
      [00:12.34]Hello world
      """

    let result = LRCParser.parse(lrc)

    XCTAssertEqual(result.count, 1)
    XCTAssertEqual(result[0].timestamp, 12.34)
    XCTAssertEqual(result[0].text, "Hello world")
  }

  func testParse_multipleLines() {
    let lrc = """
      [00:01.50]First line
      [00:05.00]Second line
      [00:10.75]Third line
      """

    let result = LRCParser.parse(lrc)

    XCTAssertEqual(result.count, 3)
    XCTAssertEqual(result[0].text, "First line")
    XCTAssertEqual(result[1].text, "Second line")
    XCTAssertEqual(result[2].text, "Third line")
  }

  func testParse_sortedByTimestamp() {
    let lrc = """
      [00:10.00]Later
      [00:01.00]Earlier
      [00:05.00]Middle
      """

    let result = LRCParser.parse(lrc)

    XCTAssertEqual(result.count, 3)
    XCTAssertEqual(result[0].text, "Earlier")
    XCTAssertEqual(result[1].text, "Middle")
    XCTAssertEqual(result[2].text, "Later")
  }

  // MARK: - Timestamp formats

  func testParse_twoDigitMilliseconds() {
    let lrc = """
      [01:23.45]Two digit ms
      """

    let result = LRCParser.parse(lrc)

    XCTAssertEqual(result.count, 1)
    // 45 / 100 = 0.45
    XCTAssertEqual(result[0].timestamp, 83.45, accuracy: 0.01)
  }

  func testParse_threeDigitMilliseconds() {
    let lrc = """
      [01:23.456]Three digit ms
      """

    let result = LRCParser.parse(lrc)

    XCTAssertEqual(result.count, 1)
    // 456 / 1000 = 0.456
    XCTAssertEqual(result[0].timestamp, 83.456, accuracy: 0.001)
  }

  func testParse_largeMinutes() {
    let lrc = """
      [99:59.999]Almost 100 minutes
      """

    let result = LRCParser.parse(lrc)

    XCTAssertEqual(result.count, 1)
    XCTAssertEqual(result[0].timestamp, (99 * 60) + 59.999, accuracy: 0.001)
  }

  func testParse_zeroTimestamp() {
    let lrc = """
      [00:00.00]Start
      """

    let result = LRCParser.parse(lrc)

    XCTAssertEqual(result.count, 1)
    XCTAssertEqual(result[0].timestamp, 0.0)
  }

  // MARK: - Edge cases

  func testParse_emptyString_returnsEmpty() {
    let result = LRCParser.parse("")
    XCTAssertEqual(result.count, 0)
  }

  func testParse_noValidLines_returnsEmpty() {
    let lrc = """
      [ti:Hello]
      [ar:Artist]
      This is not an LRC line
      """

    let result = LRCParser.parse(lrc)

    XCTAssertEqual(result.count, 0)
  }

  func testParse_emptyTextLine_skipped() {
    let lrc = """
      [00:01.00]Valid
      [00:02.00]
      [00:03.00]Also valid
      """

    let result = LRCParser.parse(lrc)

    XCTAssertEqual(result.count, 2)
    XCTAssertEqual(result[0].text, "Valid")
    XCTAssertEqual(result[1].text, "Also valid")
  }

  func testParse_whitespaceOnlyText_skipped() {
    let lrc = """
      [00:01.00]   \t
      [00:02.00]Valid
      """

    let result = LRCParser.parse(lrc)

    XCTAssertEqual(result.count, 1)
    XCTAssertEqual(result[0].text, "Valid")
  }

  func testParse_trimsWhitespace() {
    let lrc = """
      [00:01.00]  padded text
      """

    let result = LRCParser.parse(lrc)

    XCTAssertEqual(result.count, 1)
    XCTAssertEqual(result[0].text, "padded text")
  }

  func testParse_withBracketedContent() {
    let lrc = """
      [00:01.00]This [contains] brackets
      """

    let result = LRCParser.parse(lrc)

    XCTAssertEqual(result.count, 1)
    XCTAssertEqual(result[0].text, "This [contains] brackets")
  }

  // MARK: - Invalid timestamps

  func testParse_malformedTimestamp_ignored() {
    let lrc = """
      [ab:cd.ef]Bad timestamp
      [00:01.00]Good line
      """

    let result = LRCParser.parse(lrc)

    XCTAssertEqual(result.count, 1)
  }

  func testParse_partialTimestamp_ignored() {
    let lrc = """
      [00:01]Missing ms
      [00:01.00]Good line
      """

    let result = LRCParser.parse(lrc)

    XCTAssertEqual(result.count, 1)
  }
}
