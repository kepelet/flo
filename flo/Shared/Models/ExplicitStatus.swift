//
//  ExplicitStatus.swift
//  flo
//

import Foundation

enum ExplicitStatus: String, Codable, Hashable {
  case unknown = ""
  case explicit = "explicit"
  case clean = "clean"

  var isExplicit: Bool {
    self == .explicit
  }

  init(from raw: String?) {
    switch raw?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
    case "e", "explicit", "1", "4":
      self = .explicit
    case "c", "clean", "2":
      self = .clean
    default:
      self = .unknown
    }
  }

  func annotatedTitle(_ title: String) -> String {
    isExplicit ? "\(title) 🅴" : title
  }
}
