//
//  LocalFileManager.swift
//  flo
//
//  Created by rizaldy on 01/08/24.
//

import Foundation

class LocalFileManager {
  static let shared = LocalFileManager()

  let fileManager: FileManager
  let documentsDirectory: URL?

  private init() {
    self.fileManager = FileManager.default
    self.documentsDirectory =
      self.fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
  }

  func fileURL(for fileName: String) -> URL? {
    guard let documentsDirectory = self.documentsDirectory else {
      return nil
    }

    return documentsDirectory.appendingPathComponent(fileName)
  }

  func _calculateDirectorySize() throws -> String {
    var totalSize: Int64 = 0

    guard let folderURL = self.fileURL(for: "Media") else {
      return "0 MB"
    }

    do {
      guard
        let enumerator = fileManager.enumerator(
          at: folderURL,
          includingPropertiesForKeys: [.totalFileAllocatedSizeKey],
          options: [.skipsHiddenFiles])
      else {
        return "0 MB"
      }

      for case let fileURL as URL in enumerator {
        do {
          let resourceValues = try fileURL.resourceValues(forKeys: [.totalFileAllocatedSizeKey])

          if let size = resourceValues.totalFileAllocatedSize {
            totalSize += Int64(size)
          }
        } catch {
          print("Error calculating size for \(fileURL.path): \(error)")
        }
      }

      let formattedSize = bytesToMBOrGB(totalSize)

      return formattedSize
    }
  }

  func calculateDirectorySize() async throws -> String {
    return try await withCheckedThrowingContinuation { continuation in
      DispatchQueue.global(qos: .userInitiated).async {
        do {
          let result = try self._calculateDirectorySize()

          continuation.resume(returning: result)
        } catch {
          continuation.resume(throwing: error)
        }
      }
    }
  }

  func fileExists(fileName: String) -> Bool {
    guard let fileURL = self.fileURL(for: fileName) else {
      return false
    }

    return self.fileManager.fileExists(atPath: fileURL.path)
  }

  func deleteFile(fileName: String, completion: @escaping (Result<Bool, Error>) -> Void) {
    guard let fileURL = self.fileURL(for: fileName) else {
      completion(.success(false))

      return
    }

    do {
      try self.fileManager.removeItem(at: fileURL)
      completion(.success(true))
    } catch {
      completion(.failure(error))
    }
  }

  func saveFile(
    target: URL, fileName: String, content: Data,
    completion: @escaping (Result<URL?, Error>) -> Void
  ) {
    do {
      if !self.fileExists(fileName: target.path) {
        try self.fileManager.createDirectory(
          at: target, withIntermediateDirectories: true, attributes: nil)
      }

      let fileURL = target.appendingPathComponent(fileName)

      try content.write(to: fileURL)
      completion(.success(fileURL))

    } catch {
      completion(.failure(error))
    }
  }

  func deleteDownloadedAlbums(completion: @escaping (Result<Bool, Error>) -> Void) {
    guard let folderURL = self.fileURL(for: "Media") else {
      completion(.success(false))

      return
    }

    do {
      if fileManager.fileExists(atPath: folderURL.path) {
        try fileManager.removeItem(at: folderURL)
        print("Folder media deleted successfully")

        completion(.success(true))
      } else {
        print("Folder media somehow does not exist")

        completion(.success(false))
      }
    } catch {
      print("Error deleting folder: \(error.localizedDescription)")

      completion(.failure(error))
    }
  }
}
