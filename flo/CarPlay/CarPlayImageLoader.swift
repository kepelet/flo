//
//  CarPlayImageLoader.swift
//  flo
//

import UIKit

enum CarPlayImageLoader {
  private static let targetSize = CGSize(width: 90, height: 90)
  private static var cache = NSCache<NSString, UIImage>()

  static func loadImage(from path: String, completion: @escaping (UIImage?) -> Void) {
    guard !path.isEmpty else {
      completion(nil)
      return
    }

    if let cached = cache.object(forKey: path as NSString) {
      completion(cached)
      return
    }

    if path.hasPrefix("/") {
      DispatchQueue.global(qos: .utility).async {
        let image = UIImage(contentsOfFile: path)
        let resized = image.flatMap { resize($0, to: targetSize) }
        if let resized = resized {
          cache.setObject(resized, forKey: path as NSString)
        }
        DispatchQueue.main.async {
          completion(resized)
        }
      }
    } else {
      guard let url = URL(string: path) else {
        completion(nil)
        return
      }
      URLSession.shared.dataTask(with: url) { data, _, _ in
        let image = data.flatMap { UIImage(data: $0) }
        let resized = image.flatMap { resize($0, to: targetSize) }
        if let resized = resized {
          cache.setObject(resized, forKey: path as NSString)
        }
        DispatchQueue.main.async {
          completion(resized)
        }
      }.resume()
    }
  }

  private static func resize(_ image: UIImage, to size: CGSize) -> UIImage? {
    let renderer = UIGraphicsImageRenderer(size: size)
    return renderer.image { _ in
      image.draw(in: CGRect(origin: .zero, size: size))
    }
  }
}
