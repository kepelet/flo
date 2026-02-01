//
//  LRCParser.swift
//  flo
//
//  Created by rizaldy on 02/02/26.
//

import Foundation

class LRCParser {
  static func parse(_ lrcContent: String) -> [LyricsLine] {
    let pattern = #"\[(\d{2}):(\d{2})\.(\d{2,3})\](.*)"#

    var lines: [LyricsLine] = []

    guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
      return []
    }

    let nsRange = NSRange(lrcContent.startIndex..., in: lrcContent)
    let matches = regex.matches(in: lrcContent, options: [], range: nsRange)

    for match in matches {
      guard let minutesRange = Range(match.range(at: 1), in: lrcContent),
        let secondsRange = Range(match.range(at: 2), in: lrcContent),
        let millisecondsRange = Range(match.range(at: 3), in: lrcContent),
        let textRange = Range(match.range(at: 4), in: lrcContent)
      else {
        continue
      }

      let minutes = Double(lrcContent[minutesRange]) ?? 0
      let seconds = Double(lrcContent[secondsRange]) ?? 0
      let millisString = String(lrcContent[millisecondsRange])

      let millisValue = Double(millisString) ?? 0.0
      let milliseconds = millisValue / (millisString.count == 2 ? 100.0 : 1000.0)

      let timestamp = minutes * 60 + seconds + milliseconds
      let text = String(lrcContent[textRange]).trimmingCharacters(in: .whitespacesAndNewlines)

      if !text.isEmpty {
        lines.append(LyricsLine(timestamp: timestamp, text: text))
      }
    }

    return lines.sorted { $0.timestamp < $1.timestamp }
  }
}
