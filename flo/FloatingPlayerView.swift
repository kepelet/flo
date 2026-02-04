//
//  FloatingPlayerView.swift
//  flo
//
//  Created by rizaldy on 08/06/24.
//

import NukeUI
import SwiftUI

extension View {
  @ViewBuilder
  func glassedEffect(in shape: some Shape, interactive: Bool = false) -> some View {
    if #available(iOS 26.0, *) {
      self.glassEffect(interactive ? .regular.interactive() : .regular, in: shape)
        .contentShape(shape)
    } else {
      self.background {
        shape.glassed()
      }
    }
  }
}

extension Shape {
  func glassed() -> some View {
    ZStack {
      Color.clear
        .background(.ultraThinMaterial)

      LinearGradient(
        gradient: Gradient(colors: [
          Color.primary.opacity(0.08),
          Color.primary.opacity(0.05),
          Color.primary.opacity(0.01),
          Color.clear,
          Color.clear,
          Color.clear,
        ]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
    }
    .mask(self)
    .overlay(
      self.stroke(Color.primary.opacity(0.2), lineWidth: 0.7)
    )
  }
}

struct FloatingPlayerView: View {
  @ObservedObject var viewModel: PlayerViewModel

  var body: some View {
    ZStack {
      HStack(spacing: 10) {
        Group {
          if let image = UIImage(contentsOfFile: viewModel.getAlbumCoverArt()) {
            Image(uiImage: image)
              .resizable()
              .aspectRatio(contentMode: .fit)
          } else {
            LazyImage(url: URL(string: viewModel.getAlbumCoverArt())) { state in
              if state.isLoading {
                Color.gray.opacity(0.3)
              } else {
                if let image = state.image {
                  image.resizable().aspectRatio(contentMode: .fit)
                } else {
                  Image("placeholder")
                    .resizable()
                    .scaledToFit()
                    .padding(8)
                }
              }
            }
          }
        }
        .frame(width: 40, height: 40)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .shadow(radius: 2)

        VStack(alignment: .leading, spacing: 1) {
          Text(viewModel.nowPlaying.songName ?? "")
            .foregroundColor(.accent)
            .customFont(.callout)
            .fontWeight(.bold)
            .lineLimit(1)

          Text(viewModel.nowPlaying.artistName ?? "")
            .customFont(.caption1)
            .lineLimit(1)
        }

        Spacer()

        HStack(spacing: 16) {
          if viewModel.isMediaLoading {
            ProgressView()
              .progressViewStyle(CircularProgressViewStyle())
              .scaleEffect(0.7)
          } else {
            Button {
              viewModel.isPlaying ? viewModel.pause() : viewModel.play()
            } label: {
              Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                .font(.system(size: 20, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
            }
            .buttonStyle(.plain)
            .opacity(viewModel.isMediaFailed ? 0.3 : 1)
          }
        }
        .padding(.trailing, 8)
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 8)
    }
    .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    .glassedEffect(in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    .shadow(color: .black.opacity(0.15), radius: 16, x: 0, y: 6)
    .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    .padding(.horizontal, 16)
    .padding(.bottom, 8)
  }
}

struct FloatingMusicPlayerView_previews: PreviewProvider {
  @StateObject static var viewModel = PlayerViewModel()

  static var previews: some View {
    FloatingPlayerView(viewModel: viewModel)
  }
}
