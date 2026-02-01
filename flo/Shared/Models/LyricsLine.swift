//
//  LyricsLine.swift
//  flo
//
//  Created by rizaldy on 02/02/26.
//

import Foundation

struct LyricsLine: Identifiable {
  let id = UUID()
  let timestamp: TimeInterval
  let text: String

  func isCurrentLine(currentTime: TimeInterval, threshold: TimeInterval = 0.5) -> Bool {
    return abs(currentTime - timestamp) < threshold
  }
}
