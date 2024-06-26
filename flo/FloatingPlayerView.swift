//
//  FloatingPlayerView.swift
//  flo
//
//  Created by rizaldy on 08/06/24.
//

import SwiftUI

struct FloatingPlayerView: View {
  @ObservedObject var viewModel: PlayerViewModel

  var range: ClosedRange<Double> = 0...1

  var body: some View {
    Group {
      HStack {
        AsyncImage(url: URL(string: viewModel.nowPlaying.albumCover)) { phase in
          switch phase {
          case .empty:
            ProgressView().frame(width: 50, height: 50)
          case .success(let image):
            image
              .resizable()
              .aspectRatio(contentMode: .fit)
              .frame(width: 50, height: 50)
              .clipShape(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
              )

          case .failure:
            Color("PlayerColor").frame(width: 50, height: 50)
          @unknown default:
            EmptyView().frame(width: 50, height: 50)
          }
        }

        VStack(alignment: .leading) {
          Text(viewModel.nowPlaying.songName)
            .foregroundColor(.white)
            .customFont(.headline)
            .lineLimit(1)
          Text(viewModel.nowPlaying.artistName)
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
            }
          }
        }.padding()
      }.padding(8).foregroundColor(.white)
    }.background(Color("PlayerColor")).cornerRadius(10).padding(8).shadow(radius: 5)
  }
}

struct FloatingMusicPlayerView_previews: PreviewProvider {
  @StateObject static var viewModel = PlayerViewModel()

  static var previews: some View {
    FloatingPlayerView(viewModel: viewModel)
  }
}
