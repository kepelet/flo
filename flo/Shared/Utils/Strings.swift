//
//  Strings.swift
//  flo
//
//  Created by rizaldy on 09/06/24.
//

import Foundation

func timeString(for seconds: Double) -> String {
  if seconds.isFinite, !seconds.isNaN {
    let minutes = Int(seconds) / 60
    let seconds = Int(seconds) % 60

    return String(format: "%02d:%02d", minutes, seconds)
  }

  return "00:00"
}
