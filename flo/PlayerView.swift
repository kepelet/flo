//
//  PlayerView.swift
//  flo
//
//  Created by rizaldy on 01/06/24.
//

import NukeUI
import SwiftUI
import UIKit

struct PlayerView: View {
  @Binding var isExpanded: Bool

  @ObservedObject var viewModel: PlayerViewModel

  @State private var offset = CGSize.zero
  @State private var isDragging = false

  @State private var showQueue = false

  @GestureState private var queueDragOffset: CGSize = .zero

  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  var body: some View {
    GeometryReader { proxy in
      let size = proxy.size
      let topSafeInset = max(proxy.safeAreaInsets.top, windowTopSafeInset)
      let bottomSafeInset = proxy.safeAreaInsets.bottom
      let imageSize: CGFloat = horizontalSizeClass == .regular ? min(400, size.width * 0.4) : 300
      let isIPadPortrait = UIDevice.current.userInterfaceIdiom == .pad && size.height > size.width
      let queueSheetHeight = isIPadPortrait ? min(700, max(500, size.height * 0.62)) : 500

      ZStack {
        playerBackground()
          .offset(y: offset.height)

        ZStack {
          // Keep interactive content draggable while preserving full-bleed background.
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
                    Text(
                      "From \(viewModel.nowPlaying.contextName ?? viewModel.nowPlaying.albumName ?? "")"
                    ).customFont(.subheadline)
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
              ? size.height - queueSheetHeight + queueDragOffset.height : size.height
          )
          .frame(height: queueSheetHeight)
          .animation(.spring(duration: 0.2), value: showQueue)

          ZStack {
            if viewModel.isLyricsMode {
              LyricsView(
                viewModel: viewModel,
                showQueue: $showQueue,
                imageSize: imageSize,
                topSafeInset: topSafeInset,
                bottomSafeInset: bottomSafeInset
              ).transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            if !viewModel.isLyricsMode {
              mainPlayerView(
                size: size,
                imageSize: imageSize,
                topSafeInset: topSafeInset,
                bottomSafeInset: bottomSafeInset
              ).transition(.opacity)
            }
          }
          .frame(maxHeight: .infinity)
          .onChange(of: viewModel.isLiveRadio) { isLive in
            if isLive {
              showQueue = false
            }
          }
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
    }
    .foregroundColor(.white)
  }

  private var windowTopSafeInset: CGFloat {
    UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap(\.windows)
      .first(where: \.isKeyWindow)?
      .safeAreaInsets.top ?? 0
  }

  @ViewBuilder
  private func mainPlayerView(
    size: CGSize,
    imageSize: CGFloat,
    topSafeInset: CGFloat,
    bottomSafeInset: CGFloat
  ) -> some View {
    VStack {
      Rectangle()
        .foregroundColor(Color.gray.opacity(0.8))
        .frame(width: 50, height: 5)
        .cornerRadius(30)
        .padding(.top, topSafeInset + 8)

      Spacer()
      let coverArtUrl = viewModel.getAlbumCoverArt()
      if let image = UIImage(contentsOfFile: coverArtUrl) {
        Image(uiImage: image)
          .resizable()
          .aspectRatio(contentMode: .fit)
          .frame(width: imageSize, height: imageSize)
          .clipShape(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
          )
      } else {
        LazyImage(url: URL(string: coverArtUrl)) { state in
          if state.isLoading {
            Color.gray.opacity(0.3)
              .frame(width: imageSize, height: imageSize)
              .clipShape(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
              )
          } else {
            if let image = state.image {
              image
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: imageSize, height: imageSize)
                .clipShape(
                  RoundedRectangle(cornerRadius: 15, style: .continuous)
                )
            } else if state.error != nil {
              Image("placeholder")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: imageSize, height: imageSize)
                .clipShape(
                  RoundedRectangle(cornerRadius: 15, style: .continuous)
                )
            }
          }
        }
      }

      Spacer().frame(height: horizontalSizeClass == .regular ? 44 : 36)

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
      .padding(.horizontal, 30)

      Spacer()

      if viewModel.isLiveRadio {
        HStack {
          Spacer()

          Button {
            viewModel.isPlaying ? viewModel.pause() : viewModel.play()
          } label: {
            Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
              .font(.system(size: 50))
          }
          .foregroundColor(viewModel.isMediaLoading ? .gray : .white)
          .disabled(viewModel.isMediaLoading)

          Spacer()
        }
      } else {
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
      }

      Spacer()

      VStack {
        if viewModel.isLiveRadio {
          liveProgressBar()
        } else {
          PlayerCustomSlider(
            isMediaLoading: viewModel.isMediaLoading,
            isSeeking: $viewModel.isSeeking, value: $viewModel.progress, range: 0...1
          ) { newValue in
            viewModel.seek(to: newValue)
          }
        }

        HStack {
          Text(viewModel.isLiveRadio ? "" : viewModel.currentTimeString)
            .foregroundColor(.white)
            .customFont(.caption2)
            .frame(width: 60, alignment: .leading)

          Spacer()

          Text(
            viewModel.isLiveRadio
              ? "LIVE"
              : (viewModel.isPlayFromSource
                ? "\(viewModel.nowPlaying.suffix ?? "")   \(viewModel.nowPlaying.bitRate.description)"
                : "\(TranscodingSettings.targetFormat)   \(UserDefaultsManager.maxBitRate)")
          )
          .foregroundColor(.white)
          .customFont(.caption2)
          .fontWeight(.bold)
          .textCase(.uppercase)
          .frame(maxWidth: .infinity, alignment: .center)

          Spacer()

          Text(viewModel.isLiveRadio ? "" : viewModel.totalTimeString)
            .foregroundColor(.white)
            .customFont(.caption2)
            .frame(width: 60, alignment: .trailing)
        }
      }
      .padding(.horizontal, 30)

      bottomControlBar(showQueue: $showQueue)
        .padding(.top, 16)
        .padding(.horizontal, 18)
        .padding(.bottom, max(bottomSafeInset, 12))
    }
    .frame(maxWidth: horizontalSizeClass == .regular ? 500 : .infinity)
    .frame(maxWidth: .infinity)
  }

  @ViewBuilder
  private func bottomControlBar(showQueue: Binding<Bool>) -> some View {
    let isLyricsDisabled =
      viewModel.isLiveRadio || (viewModel.lyrics.isEmpty && (viewModel.lyricsError != nil))

    let isQueueDisabled = viewModel.isLiveRadio

    HStack(spacing: 0) {
      Button {
        viewModel.toggleLyricsMode()
      } label: {
        Image(systemName: "quote.bubble")
          .font(.title2)
          .foregroundColor(isLyricsDisabled ? .white.opacity(0.4) : .white)
      }
      .disabled(isLyricsDisabled)
      .frame(width: 44, height: 44)

      Spacer(minLength: 0)

      Button {
        viewModel.toggleStar()
      } label: {
        Image(systemName: viewModel.isStarred ? "heart.fill" : "heart")
          .font(.title2)
          .foregroundColor(.white)
      }
      .disabled(viewModel.isLiveRadio)
      .opacity(viewModel.isLiveRadio ? 0.4 : 1)
      .frame(width: 44, height: 44)

      Spacer(minLength: 0)

      AirPlayRoutePicker(tintColor: UIColor.white, activeTintColor: UIColor.white)
        .frame(width: 36, height: 36)
        .frame(width: 44, height: 44)
        .overlay(alignment: .bottom) {
          if let outputName = viewModel.externalOutputName {
            Text(outputName)
              .foregroundColor(.white)
              .customFont(.caption2)
              .fontWeight(.bold)
              .lineLimit(2)
              .multilineTextAlignment(.center)
              .frame(maxWidth: 260)
              .fixedSize(horizontal: false, vertical: true)
              .offset(y: 13)
          }
        }

      Spacer(minLength: 0)

      Button {
        if !isQueueDisabled {
          showQueue.wrappedValue.toggle()
        }
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
      .disabled(isQueueDisabled)
      .opacity(isQueueDisabled ? 0.4 : 1)
      .frame(width: 44, height: 44)
    }
    .frame(height: 44)
  }

  @ViewBuilder
  private func playerBackground() -> some View {
    ZStack {
      if UserDefaultsManager.playerBackground == PlayerBackground.translucent {
        if let image = UIImage(contentsOfFile: viewModel.getAlbumCoverArt()) {
          Image(uiImage: image)
            .resizable()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .blur(radius: 50, opaque: true)
        } else {
          LazyImage(url: URL(string: viewModel.getAlbumCoverArt())) { state in
            if let image = state.image {
              image
                .resizable()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .blur(radius: 50, opaque: true)
            }
          }
        }

        Rectangle().fill(.thinMaterial)
      } else {
        Rectangle().fill(Color("PlayerColor"))
      }
    }
    .environment(\.colorScheme, .dark)
    .ignoresSafeArea()
  }

  @ViewBuilder
  private func liveProgressBar() -> some View {
    GeometryReader { geometry in
      ZStack(alignment: .leading) {
        Capsule()
          .fill(Color.gray.opacity(0.8))
          .frame(height: 5)

        Capsule()
          .fill(Color.white)
          .frame(width: geometry.size.width, height: 4)
      }
    }
    .frame(height: 20)
  }
}

struct PlayerView_previews: PreviewProvider {
  @StateObject static var viewModel = PlayerViewModel()
  @State static var isExpanded: Bool = true

  static var previews: some View {
    PlayerView(isExpanded: $isExpanded, viewModel: viewModel)
  }
}

/// A shape that rounds only the top-left and top-right corners,
/// leaving the bottom edges straight so the background extends
/// fully into the bottom safe area.
struct TopRoundedRectangle: Shape {
    var cornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + cornerRadius))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + cornerRadius, y: rect.minY),
            control: CGPoint(x: rect.minX, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.maxX - cornerRadius, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + cornerRadius),
            control: CGPoint(x: rect.maxX, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
