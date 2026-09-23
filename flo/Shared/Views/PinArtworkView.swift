//
//  PinArtworkView.swift
//  flo
//

import NukeUI
import SwiftUI

/// Cover art thumbnail for a pinned item (album, artist or playlist).
/// Handles remote URLs, local file paths and a graceful icon fallback.
struct PinArtworkView: View {
  let pathOrUrlString: String
  let fallbackSystemImage: String
  var size: CGFloat = 40
  var cornerRadius: CGFloat = 8
  var tint: Color = .accentColor

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
    ZStack {
      RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        .fill(tint.opacity(0.35))
      Image(systemName: fallbackSystemImage)
        .foregroundColor(.white.opacity(0.9))
    }
    .frame(width: size, height: size)
  }
}
