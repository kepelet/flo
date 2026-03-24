//
//  LibraryCacheManager.swift
//  flo
//

import Foundation

class LibraryCacheManager {
  static let shared = LibraryCacheManager()

  private let fileManager = FileManager.default
  private let cacheDirectory: URL?

  private init() {
    self.cacheDirectory =
      fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first?
      .appendingPathComponent("LibraryCache")

    if let dir = cacheDirectory, !fileManager.fileExists(atPath: dir.path) {
      try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
    }
  }

  func save<T: Encodable>(_ items: T, forKey key: String) {
    guard let dir = cacheDirectory else { return }
    let file = dir.appendingPathComponent("\(key).json")
    guard let data = try? JSONEncoder().encode(items) else { return }
    try? data.write(to: file, options: .atomic)
  }

  func load<T: Decodable>(_ type: T.Type, forKey key: String) -> T? {
    guard let dir = cacheDirectory else { return nil }
    let file = dir.appendingPathComponent("\(key).json")
    guard let data = try? Data(contentsOf: file) else { return nil }
    return try? JSONDecoder().decode(T.self, from: data)
  }

  func clearCache() {
    guard let dir = cacheDirectory, fileManager.fileExists(atPath: dir.path) else { return }
    try? fileManager.removeItem(at: dir)
    try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
  }
}
