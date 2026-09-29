//
//  PinArtworkView.swift
//  flo
//

import NukeUI
import SwiftUI

/// Cover art thumbnail for a pinned item (album, artist or playlist).
/// Handles remote URLs, local file paths and falls back to the app's
/// Navidrome placeholder artwork.
struct PinArtworkView: View {
  let pathOrUrlString: String
  var size: CGFloat = 40
  var cornerRadius: CGFloat = 8

  var body: some View {
    Group {
      if pathOrUrlString.hasPrefix("http://") || pathOrUrlString.hasPrefix("https://") {
        LazyImage(url: URL(string: pathOrUrlString)) { state in
          if let image = state.image {
            image
              .resizable()
              .aspectRatio(contentMode: .fill)
          } else {
            fallback
          }
        }
      } else if !pathOrUrlString.isEmpty,
        let uiImage = UIImage(contentsOfFile: pathOrUrlString)
      {
        Image(uiImage: uiImage)
          .resizable()
          .aspectRatio(contentMode: .fill)
      } else {
        fallback
      }
    }
    .frame(width: size, height: size)
    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
  }

  private var fallback: some View {
    Image(uiImage: UIImage(named: "placeholder") ?? UIImage())
      .resizable()
      .aspectRatio(contentMode: .fill)
      .frame(width: size, height: size)
  }
}
