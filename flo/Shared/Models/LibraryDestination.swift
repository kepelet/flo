//
//  LibraryDestination.swift
//  flo
//

import Foundation

enum LibraryDestination: Hashable {
  case artist(id: String, name: String)
  case album(id: String, name: String, artist: String)
}
