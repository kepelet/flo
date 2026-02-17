//
//  WatchCoverArtView.swift
//  flo
//
//  Created by Codex on 17/02/26.
//

#if os(watchOS)
import SwiftUI

struct WatchCoverArtView: View {
  let coverArt: String
  let size: CGFloat

  var body: some View {
    if let url = coverArtURL {
      AsyncImage(url: url) { phase in
        switch phase {
        case .empty:
          placeholder
        case .success(let image):
          image
            .resizable()
            .scaledToFill()
        case .failure:
          placeholder
        @unknown default:
          placeholder
        }
      }
      .frame(width: size, height: size)
      .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    } else {
      placeholder
    }
  }

  private var coverArtURL: URL? {
    guard !coverArt.isEmpty else {
      return nil
    }

    if coverArt.hasPrefix("/") {
      return URL(fileURLWithPath: coverArt)
    }

    return URL(string: coverArt)
  }

  private var placeholder: some View {
    RoundedRectangle(cornerRadius: 6, style: .continuous)
      .fill(Color.gray.opacity(0.3))
      .frame(width: size, height: size)
      .overlay(
        Image(systemName: "music.note")
          .foregroundColor(.secondary)
      )
  }
}
#endif
