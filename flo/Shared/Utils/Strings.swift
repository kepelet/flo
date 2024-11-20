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

func bytesToMBOrGB(_ bytes: Int64) -> String {
  let gigabyte: Int64 = 1024 * 1024 * 1024
  let megabyte: Int64 = 1024 * 1024

  if bytes >= gigabyte {
    let gb = Double(bytes) / Double(gigabyte)

    return String(format: "%.0f GB", gb)
  } else {
    let mb = Double(bytes) / Double(megabyte)

    return String(format: "%.0f MB", mb)
  }
}
