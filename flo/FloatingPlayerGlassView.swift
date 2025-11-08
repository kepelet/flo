//
//  FloatingPlayerGlassView.swift
//  flo
//
//  Created by rizaldy on 23/09/25.
//

import NukeUI
import SwiftUI

@available(iOS 26.0, *)
struct FloatingPlayerGlassView: View {
  @ObservedObject var viewModel: PlayerViewModel
  @State private var angle: Double = 0

  var body: some View {
    ZStack {
      HStack {
        if let image = UIImage(contentsOfFile: viewModel.getAlbumCoverArt()) {
          Image(uiImage: image)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 40, height: 40)
            .clipShape(
              .rect(corners: .concentric(minimum: 48), isUniform: false)
            )
            .padding(.leading, 2)
        } else {
          LazyImage(url: URL(string: viewModel.getAlbumCoverArt())) { state in
            if let image = state.image {
              image
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 40, height: 40)
                .clipShape(
                  .rect(corners: .concentric(minimum: 48), isUniform: false)
                )
                .padding(.leading, 2)
            } else {
              Color.gray.opacity(0.3).frame(width: 40, height: 40)
                .clipShape(.rect(corners: .concentric(minimum: 48), isUniform: false))
                .padding(.leading, 2)
            }
          }
        }

        VStack(alignment: .leading) {
          Text(viewModel.nowPlaying.songName ?? "")
            .customFont(.subheadline)
            .fontWeight(.bold)
            .lineLimit(1)
          Text(viewModel.nowPlaying.artistName ?? "")
            .customFont(.footnote)
            .lineLimit(1)
        }.frame(maxWidth: .infinity, alignment: .leading)

        HStack {
          if viewModel.isMediaLoading {
            ProgressView().progressViewStyle(CircularProgressViewStyle())
          } else {
            Button {
              viewModel.isPlaying ? viewModel.pause() : viewModel.play()
            } label: {
              Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                .font(.system(size: 18))
                .disabled(viewModel.isMediaLoading)
            }.foregroundColor(.accent).opacity(viewModel.isMediaFailed ? 0 : 1)
          }
        }.padding()
      }
    }
  }
}

@available(iOS 26.0, *)
struct FloatingMusicPlayerGlassView_previews: PreviewProvider {
  @StateObject static var viewModel = PlayerViewModel()

  static var previews: some View {
    FloatingPlayerGlassView(viewModel: viewModel)
  }
}
