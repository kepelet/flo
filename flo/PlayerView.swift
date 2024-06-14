//
//  PlayerView.swift
//  flo
//
//  Created by rizaldy on 01/06/24.
//

import SwiftUI

struct PlayerView: View {
  @Binding var isExpanded: Bool

  @ObservedObject var viewModel: PlayerViewModel

  @State private var offset = CGSize.zero
  @State private var isDragging = false

  var body: some View {
    GeometryReader {
      let size = $0.size
      let imageSize: CGFloat = 300

      ZStack {
        AsyncImage(url: URL(string: viewModel.nowPlaying.albumCover)) { phase in
          switch phase {
          case .empty:
            Color("PlayerColor")
          case .success(let image):
            image
              .resizable()
              .scaledToFill()
              .frame(width: size.width, height: size.height)
              .clipped()
              .blur(radius: 80)
              .opacity(0.5)
              .edgesIgnoringSafeArea(.all)

          case .failure:
            Color("PlayerColor")
          @unknown default:
            EmptyView()
              .frame(width: imageSize, height: imageSize)
          }
        }.background(Color("PlayerColor"))

        VStack {

          Rectangle()
            .foregroundColor(Color.gray.opacity(0.8))
            .frame(width: 50, height: 5)
            .cornerRadius(30)
            .padding(.top, 20)

          Spacer()

          AsyncImage(url: URL(string: viewModel.nowPlaying.albumCover)) { phase in
            switch phase {
            case .empty:
              Color.gray.opacity(0.3)
                .frame(width: imageSize, height: imageSize)
                .clipShape(
                  RoundedRectangle(cornerRadius: 15, style: .continuous)
                )
                .shadow(radius: 10)
            case .success(let image):
              image
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: imageSize, height: imageSize)
                .clipShape(
                  RoundedRectangle(cornerRadius: 15, style: .continuous)
                )
                .shadow(radius: 10)
            case .failure:
              Color.gray.opacity(0.3)
                .frame(width: imageSize, height: imageSize)
                .clipShape(
                  RoundedRectangle(cornerRadius: 15, style: .continuous)
                )
                .shadow(radius: 10)
            @unknown default:
              EmptyView()
                .frame(width: imageSize, height: imageSize)
            }
          }

          Spacer()

          VStack(alignment: .center, spacing: 10) {
            Text(viewModel.nowPlaying.songName)
              .foregroundColor(.white)
              .customFont(.title1)
              .fontWeight(.bold)
              .shadow(radius: 2)
              .multilineTextAlignment(.center)
              .lineLimit(3)

            Text(viewModel.nowPlaying.artistName)
              .foregroundColor(.white.opacity(0.8))
              .customFont(.title3)
              .shadow(radius: 2)
              .multilineTextAlignment(.center)
              .lineLimit(2)
          }

          Spacer()

          HStack(spacing: size.width * 0.15) {
            Button {
              viewModel.prevSong()
            } label: {
              Image(systemName: "backward.fill").font(.title)
            }

            Button {
              viewModel.isPlaying ? viewModel.pause() : viewModel.play()
            } label: {
              Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                .font(.system(size: 50))
            }

            Button {
              viewModel.nextSong()
            } label: {
              Image(systemName: "forward.fill").font(.title)
            }
          }

          Spacer()

          VStack {

            PlayerCustomSlider(
              isSeeking: $viewModel.isSeeking, value: $viewModel.progress, range: 0...1
            ) { newValue in
              viewModel.seek(to: newValue)
            }

            HStack {
              Text(viewModel.currentTimeString)
                .foregroundColor(.white)
                .customFont(.caption2)
                .frame(width: 60, alignment: .leading)

              Spacer()

              Text("\(viewModel.nowPlaying.suffix)   \(viewModel.nowPlaying.bitRate.description)")
                .foregroundColor(.white)
                .customFont(.caption2)
                .fontWeight(.bold)
                .textCase(.uppercase)
                .frame(maxWidth: .infinity, alignment: .center)

              Spacer()

              Text(viewModel.totalTimeString)
                .foregroundColor(.white)
                .customFont(.caption2)
                .frame(width: 60, alignment: .trailing)
            }
          }

          Spacer()

          HStack {
            Button {

            } label: {
              Image(systemName: "quote.bubble")
                .font(.title2)
                .foregroundColor(.gray)
            }.disabled(true)

            Spacer()

            Button {

            } label: {
              Image(systemName: "airplayaudio")
                .font(.title2)
                .foregroundColor(.gray)
            }.disabled(true)

            Spacer()

            Button {

            } label: {
              Image(systemName: "list.bullet")
                .font(.title2)
                .foregroundColor(.gray)
                .overlay(
                  Group {
                    Image(systemName: "repeat")
                      .font(.caption)
                      .clipShape(Circle())
                      .foregroundColor(.gray)
                      .offset(x: 10, y: -10)
                  }
                )
            }.disabled(true)
          }
        }
        .padding(.horizontal, 30)
      }
      .frame(maxHeight: .infinity)
      .offset(y: offset.height)
      .gesture(
        DragGesture()
          .onChanged { gesture in
            if gesture.translation.height > 0 {
              offset = gesture.translation
              isDragging = true
            }
          }
          .onEnded { _ in
            if offset.height > size.height / 3 {
              isExpanded = false
            }
            offset = .zero
            isDragging = false
          }
      )

    }
    .foregroundColor(.white)
  }
}

struct PlayerView_previews: PreviewProvider {
  @StateObject static var viewModel = PlayerViewModel()
  @State static var isExpanded: Bool = true

  static var previews: some View {
    PlayerView(isExpanded: $isExpanded, viewModel: viewModel)
  }
}
