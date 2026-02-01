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

  @GestureState private var queueDragOffset: CGSize = .zero

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
        VStack(alignment: .leading) {
          HStack {
            Spacer()

            Rectangle()
              .foregroundColor(Color.gray.opacity(0.3))
              .frame(width: 50, height: 5)
              .cornerRadius(30)
              .padding(.top)

            Spacer()
          }
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
          }
          .padding(.horizontal)
          .padding(.bottom, 5)

          ScrollView {
            LazyVStack(alignment: .leading) {
              ForEach(viewModel.queue.indices, id: \.self) { idx in
                HStack(alignment: .top) {
                  VStack(alignment: .leading) {
                    Text(viewModel.queue[idx].songName ?? "")
                      .customFont(.callout)
                      .fontWeight(.medium)
                      .padding(.bottom, 3)

                    Text(viewModel.queue[idx].artistName ?? "")
                      .customFont(.caption1)
                  }
                  .frame(maxWidth: .infinity, alignment: .leading)

                  Spacer()

                  Text(timeString(for: viewModel.queue[idx].duration)).customFont(.caption1)
                    .padding(.top, 4)
                }
                .padding(.vertical, 5)
                .padding(.horizontal)
                .background(
                  viewModel.activeQueueIdx == idx
                    ? Color.gray.opacity(0.1) : Color(.systemBackground)
                )
                .onTapGesture {
                  viewModel.playFromQueue(idx: idx)
                }
              }
            }
          }.padding(.bottom, 60)
        }
      }
      .gesture(
        DragGesture()
          .updating($queueDragOffset) { value, state, _ in
            if value.translation.height > 0 {
              state = value.translation
            }
          }
          .onEnded { value in
            if value.translation.height > 100 {
              self.showQueue = false
            }
          }
      )
      .animation(.spring(duration: 0.4), value: queueDragOffset.height)
      .foregroundColor(.primary)
      .zIndex(1)
      .offset(
        y: showQueue
          ? UIScreen.main.bounds.height - 500 + queueDragOffset.height : UIScreen.main.bounds.height
      )
      .frame(height: 500)
      .animation(.spring(duration: 0.2), value: showQueue)

      ZStack {
        if viewModel.isLyricsMode {
          LyricsView(
            viewModel: viewModel,
            showQueue: $showQueue,
            imageSize: imageSize
          ).transition(.opacity.combined(with: .move(edge: .bottom)))
        }

        if !viewModel.isLyricsMode {
          mainPlayerView(size: size, imageSize: imageSize).transition(.opacity)
        }
      }
      .frame(maxHeight: .infinity)
      .background {
        ZStack {
          if UserDefaultsManager.playerBackground == PlayerBackground.translucent {
            if let image = UIImage(contentsOfFile: viewModel.getAlbumCoverArt()) {
              Image(uiImage: image)
                .resizable()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .blur(radius: 50, opaque: true)
                .edgesIgnoringSafeArea(.all)
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
          } else {
            Rectangle().fill(Color("PlayerColor")).edgesIgnoringSafeArea(.all)
          }
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
            if !viewModel.isLyricsMode {
              if gesture.translation.height > 0 {
                offset = gesture.translation
                isDragging = true
              }
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

  @ViewBuilder
  private func mainPlayerView(size: CGSize, imageSize: CGFloat) -> some View {
    VStack {
      Rectangle()
        .foregroundColor(Color.gray.opacity(0.8))
        .frame(width: 50, height: 5)
        .cornerRadius(30)
        .padding(.top, 20)

      Spacer()

      if let image = UIImage(contentsOfFile: viewModel.getAlbumCoverArt()) {
        Image(uiImage: image)
          .resizable()
          .aspectRatio(contentMode: .fit)
          .frame(width: imageSize, height: imageSize)
          .clipShape(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
          )
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
          .customFont(.title2)
          .fontWeight(.bold)
          .multilineTextAlignment(.center)
          .lineLimit(3)

        Text(viewModel.nowPlaying.artistName ?? "")
          .foregroundColor(.white.opacity(0.8))
          .customFont(.title3)
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
            viewModel.isPlayFromSource
              ? "\(viewModel.nowPlaying.suffix ?? "")   \(viewModel.nowPlaying.bitRate.description)"
              : "\(TranscodingSettings.targetFormat)   \(UserDefaultsManager.maxBitRate)"
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

      bottomControlBar(showQueue: $showQueue)
    }
    .padding(.horizontal, 30)
  }

  @ViewBuilder
  private func bottomControlBar(showQueue: Binding<Bool>) -> some View {
    HStack {
      Button {
        viewModel.toggleLyricsMode()
      } label: {
        Image(systemName: "quote.bubble")
          .font(.title2)
          .foregroundColor(
            viewModel.lyrics.isEmpty && (viewModel.lyricsError != nil)
              ? .white.opacity(0.4) : .white
          )
          .padding(8)
      }

      Spacer()

      Button {
        // TODO: AirPlay
      } label: {
        Image(systemName: "airplayaudio")
          .font(.title2)
          .foregroundColor(.gray)
      }.disabled(true)

      Spacer()

      Button {
        showQueue.wrappedValue.toggle()
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
}

struct PlayerView_previews: PreviewProvider {
  @StateObject static var viewModel = PlayerViewModel()
  @State static var isExpanded: Bool = true

  static var previews: some View {
    PlayerView(isExpanded: $isExpanded, viewModel: viewModel)
  }
}
