//
//  PlayerView.swift
//  flo
//
//  Created by rizaldy on 01/06/24.
//

import NukeUI
import SwiftUI

struct PlayerView: View {
  @Binding var isExpanded: Bool

  @ObservedObject var viewModel: PlayerViewModel

  @State private var offset = CGSize.zero
  @State private var isDragging = false

  @State private var showQueue = false

  var body: some View {
    GeometryReader {
      let size = $0.size
      let imageSize: CGFloat = 300

      // FIXME: Refactor this?
      ZStack(alignment: .topLeading) {
        Color(.systemBackground)
          .ignoresSafeArea()
          .clipShape(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
          )
          .shadow(radius: 5)
        VStack(alignment: .leading) {
          HStack {
            Text("Queue")
              .customFont(.title2)
              .fontWeight(.bold)
            Spacer()
            Button {
              self.showQueue = false
            } label: {
              Text("Close").customFont(.callout).fontWeight(.medium)
            }
          }.padding()
          VStack(alignment: .leading, spacing: 3) {
            Text("Playing Next").customFont(.headline)

            HStack(alignment: .bottom, spacing: 10) {
              if viewModel.queue.isEmpty {
                Text("").customFont(.subheadline)
              } else {
                Text("From \(viewModel.nowPlaying.albumName ?? "")").customFont(.subheadline)
              }

              Spacer()

              Button {
                viewModel.shuffleCurrentQueue()
              } label: {
                Image(systemName: "shuffle")
                  .foregroundColor(Color.accentColor)
                  .fontWeight(.bold)
                  .padding(5)
                  .background(
                    viewModel.isShuffling ? Color.gray.opacity(0.2) : Color(.systemBackground)
                  )
                  .cornerRadius(5)
              }

              Button {
                viewModel.setPlaybackMode()
              } label: {
                Image(systemName: "repeat")
                  .foregroundColor(Color.accentColor)
                  .fontWeight(.bold)
                  .overlay(
                    Group {
                      Text("1")
                        .font(.caption)
                        .clipShape(Circle())
                        .offset(x: 10, y: -5)
                        .fontWeight(.bold)
                    }.opacity(viewModel.playbackMode == PlaybackMode.repeatOnce ? 1 : 0)
                  )
                  .padding(5)
                  .background(
                    viewModel.playbackMode == PlaybackMode.defaultPlayback
                      ? Color(.systemBackground) : Color.gray.opacity(0.2)
                  )
                  .cornerRadius(5)
              }
            }
          }.padding()

          ScrollView {
            VStack(alignment: .leading) {
              ForEach(viewModel.queue.indices, id: \.self) { idx in
                if viewModel.activeQueueIdx < idx {
                  Text(viewModel.queue[idx].songName ?? "")
                    .customFont(.body)
                    .fontWeight(.medium)
                    .padding(.bottom, 20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .onTapGesture {
                      viewModel.playFromQueue(idx: idx)
                    }
                }
              }
            }.padding()
          }.padding(.bottom, 60)
        }
      }
      .foregroundColor(.primary)
      .zIndex(1)
      .offset(y: showQueue ? UIScreen.main.bounds.height - 666 : UIScreen.main.bounds.height)
      .frame(height: 666)
      .animation(.spring(duration: 0.2), value: showQueue)

      ZStack {
        VStack {

          Rectangle()
            .foregroundColor(Color.gray.opacity(0.8))
            .frame(width: 50, height: 5)
            .cornerRadius(30)
            .padding(.top, 20)

          Spacer()

          if viewModel.nowPlaying.isFromLocal {
            if let image = UIImage(contentsOfFile: viewModel.getAlbumCoverArt()) {
              Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: imageSize, height: imageSize)
                .clipShape(
                  RoundedRectangle(cornerRadius: 15, style: .continuous)
                )
            }
          } else {
            LazyImage(url: URL(string: viewModel.getAlbumCoverArt())) { state in
              if let image = state.image {
                image
                  .resizable()
                  .aspectRatio(contentMode: .fit)
                  .frame(width: imageSize, height: imageSize)
                  .clipShape(
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                  )
              } else {
                Color.gray.opacity(0.3)
                  .frame(width: imageSize, height: imageSize)
                  .clipShape(
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                  )
              }
            }
          }

          Spacer()

          VStack(alignment: .center, spacing: 10) {
            Text(viewModel.nowPlaying.songName ?? "")
              .foregroundColor(.white)
              .customFont(.title1)
              .fontWeight(.bold)
              .shadow(radius: 2)
              .multilineTextAlignment(.center)
              .lineLimit(3)

            Text(viewModel.nowPlaying.artistName ?? "")
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
            .foregroundColor(viewModel.isMediaLoading ? .gray : .white)
            .disabled(viewModel.isMediaLoading)

            Button {
              viewModel.nextSong()
            } label: {
              Image(systemName: "forward.fill").font(.title)
            }
          }

          Spacer()

          VStack {

            PlayerCustomSlider(
              isMediaLoading: viewModel.isMediaLoading,
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

              Text(
                "\(viewModel.nowPlaying.suffix ?? "")   \(viewModel.nowPlaying.bitRate.description)"
              )
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
              self.showQueue.toggle()
            } label: {
              Image(systemName: "list.bullet")
                .font(.title2)
                .overlay(
                  Group {
                    Image(systemName: "repeat")
                      .font(.caption)
                      .overlay(
                        Group {
                          Text("1")
                            .font(.system(size: 8))
                        }
                        .offset(x: 7, y: -4)
                        .opacity(viewModel.playbackMode == PlaybackMode.repeatOnce ? 1 : 0)
                      )
                      .opacity(viewModel.playbackMode == PlaybackMode.defaultPlayback ? 0 : 1)
                  }
                  .padding(5)
                  .background(
                    .black.opacity(viewModel.playbackMode == PlaybackMode.defaultPlayback ? 0 : 0.2)
                  )
                  .clipShape(Circle())
                  .offset(x: 10, y: -10)
                )
            }
          }
        }
        .padding(.horizontal, 30)
      }
      .frame(maxHeight: .infinity)
      .background {
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

        }
        .environment(\.colorScheme, .dark)
        .clipShape(
          RoundedRectangle(cornerRadius: 25, style: .continuous)
        ).edgesIgnoringSafeArea(.all)
      }
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
