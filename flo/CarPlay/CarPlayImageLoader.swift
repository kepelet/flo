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

    DispatchQueue.global(qos: .utility).async {
      let image: UIImage?

      if path.hasPrefix("/") {
        image = UIImage(contentsOfFile: path)
      } else if let url = URL(string: path), let data = try? Data(contentsOf: url) {
        image = UIImage(data: data)
      } else {
        image = nil
      }

      let resized = image.flatMap { resize($0, to: targetSize) }

      if let resized = resized {
        cache.setObject(resized, forKey: path as NSString)
      }

      DispatchQueue.main.async {
        completion(resized)
      }
    }
  }

  private static func resize(_ image: UIImage, to size: CGSize) -> UIImage? {
    UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
    image.draw(in: CGRect(origin: .zero, size: size))
    let resized = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()
    return resized
  }
}
