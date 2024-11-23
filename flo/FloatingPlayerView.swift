//
//  FloatingPlayerView.swift
//  flo
//
//  Created by rizaldy on 08/06/24.
//

import NukeUI
import SwiftUI

struct FloatingPlayerView: View {
  @ObservedObject var viewModel: PlayerViewModel

  var range: ClosedRange<Double> = 0...1

  var body: some View {
    ZStack {
      HStack {
        if viewModel.nowPlaying.isFromLocal {
          if let image = UIImage(contentsOfFile: viewModel.getAlbumCoverArt()) {
            Image(uiImage: image)
              .resizable()
              .aspectRatio(contentMode: .fit)
              .frame(width: 50, height: 50)
              .clipShape(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
              )
          }
        } else {
          LazyImage(url: URL(string: viewModel.getAlbumCoverArt())) { state in
            if let image = state.image {
              image
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 50, height: 50)
                .clipShape(
                  RoundedRectangle(cornerRadius: 5, style: .continuous)
                )
            } else {
              Color.gray.opacity(0.3).frame(width: 50, height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            }
          }
        }

        VStack(alignment: .leading) {
          Text(viewModel.nowPlaying.songName ?? "")
            .foregroundColor(.white)
            .customFont(.headline)
            .lineLimit(1)
          Text(viewModel.nowPlaying.artistName ?? "")
            .foregroundColor(.white)
            .customFont(.subheadline)

          GeometryReader { geometry in
            ZStack(alignment: .leading) {
              Rectangle()
                .foregroundColor(Color.gray.opacity(0.3))
                .frame(height: 3)
                .cornerRadius(10)

              Rectangle()
                .foregroundColor(Color.white)
                .frame(
                  width: CGFloat(
                    (viewModel.progress - range.lowerBound) / (range.upperBound - range.lowerBound))
                    * geometry.size.width, height: 3
                )
                .cornerRadius(10).opacity(viewModel.isMediaLoading ? 0 : 1)
            }.frame(height: 3)
          }.frame(height: 3)
        }

        HStack(spacing: 20) {
          if viewModel.isMediaLoading {
            ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
          } else {
            Button {
              viewModel.isPlaying ? viewModel.pause() : viewModel.play()
            } label: {
              Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                .font(.system(size: 20))
                .disabled(viewModel.isMediaLoading)
            }.opacity(viewModel.isMediaFailed ? 0 : 1)
          }
        }.padding()
      }.padding(8).foregroundColor(.white)
    }.background {
      if UserDefaultsManager.playerBackground == PlayerBackground.translucent {
        ZStack {
          if viewModel.nowPlaying.isFromLocal {
            if let image = UIImage(contentsOfFile: viewModel.getAlbumCoverArt()) {
              Image(uiImage: image)
                .resizable()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .blur(radius: 50, opaque: true)
                .edgesIgnoringSafeArea(.all)
            }
          } else {
            LazyImage(url: URL(string: viewModel.getAlbumCoverArt())) { state in
              if let image = state.image {
                image
                  .resizable()
                  .frame(maxWidth: .infinity, maxHeight: .infinity)
                  .blur(radius: 50, opaque: true)
                  .edgesIgnoringSafeArea(.all)
              }
            }
          }

          Rectangle().fill(.thinMaterial).edgesIgnoringSafeArea(.all)
        }.environment(\.colorScheme, .dark)
      } else {
        Rectangle().fill(Color("PlayerColor"))
      }
    }
    .cornerRadius(10).padding(8).shadow(radius: 5)
  }
}

struct FloatingMusicPlayerView_previews: PreviewProvider {
  @StateObject static var viewModel = PlayerViewModel()

  static var previews: some View {
    FloatingPlayerView(viewModel: viewModel)
  }
}
