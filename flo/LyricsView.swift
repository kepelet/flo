//
//  LyricsView.swift
//  flo
//
//  Created by rizaldy on 02/02/26.
//

import NukeUI
import SwiftUI

@MainActor
class ScrollState: ObservableObject {
  @Published var isScrolling = false
  private var lastOffset: CGFloat = .zero
  private var scrollTask: Task<Void, Never>?
  private var isAutoScrolling = false

  func setAutoScrolling(_ value: Bool) {
    isAutoScrolling = value
  }

  func handleScroll(offset: CGFloat) {
    guard !isAutoScrolling else { return }

    guard abs(offset - lastOffset) > 1.0 else { return }
    lastOffset = offset

    scrollTask?.cancel()

    if !isScrolling {
      withAnimation(.easeOut(duration: 0.15)) {
        isScrolling = true
      }
    }

    scrollTask = Task {
      try? await Task.sleep(nanoseconds: 800_000_000)
      guard !Task.isCancelled else { return }

      self.isScrolling = false
    }
  }
}

struct LyricsView: View {
    @ObservedObject var viewModel: PlayerViewModel
    @Binding var showQueue: Bool
    @Binding var isExpanded: Bool
    @Binding var dragOffset: CGSize
    @StateObject private var scrollState = ScrollState()

    let imageSize: CGFloat
    let topSafeInset: CGFloat
    let bottomSafeInset: CGFloat

  private var isPlainLyrics: Bool {
    return viewModel.lyrics.count == 1
  }

    var body: some View {
      VStack(spacing: 0) {
          HStack {
            Spacer()
            DragHandle(color: .gray.opacity(0.3))
            Spacer()
          }
          .padding(.top, topSafeInset)
          .highPriorityGesture(
            DragGesture(coordinateSpace: .global)
              .onChanged { value in
                if value.translation.height > 0 {
                  dragOffset = value.translation
                }
              }
              .onEnded { value in
                if value.translation.height > UIScreen.main.bounds.height / 6 {
                  isExpanded = false
                } else {
                  withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    dragOffset = .zero
                  }
                }
              }
          )

        HStack(spacing: 16) {
        Group {
          if let image = UIImage(contentsOfFile: viewModel.getAlbumCoverArt()) {
            Image(uiImage: image)
              .resizable()
              .aspectRatio(contentMode: .fit)
          } else {
            LazyImage(url: URL(string: viewModel.getAlbumCoverArt())) { state in
              if let image = state.image {
                image
                  .resizable()
                  .aspectRatio(contentMode: .fit)
              } else {
                Color.gray.opacity(0.3)
              }
            }
          }
        }
        .frame(width: 60, height: 60)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

        VStack(alignment: .leading, spacing: 4) {
          Text(viewModel.nowPlaying.songName ?? "")
            .foregroundColor(.white)
            .customFont(.body)
            .fontWeight(.bold)
            .lineLimit(1)

          Text(viewModel.nowPlaying.artistName ?? "")
            .foregroundColor(.white.opacity(0.7))
            .customFont(.subheadline)
            .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
        
      .padding(.horizontal, 30)
      .padding(.top, 8)
      .padding(.bottom, 16)
      .onTapGesture {
        viewModel.toggleLyricsMode()
      }

      if viewModel.isLoadingLyrics {
        Spacer()
        ProgressView()
          .scaleEffect(1.5)
          .foregroundColor(.white)
        Spacer()
      } else if let error = viewModel.lyricsError {
        Spacer()
        VStack(spacing: 16) {
          Text(error)
            .foregroundColor(.white.opacity(0.7))
            .multilineTextAlignment(.center)
        }
        Spacer()
      } else if viewModel.lyrics.isEmpty {
        Spacer()
        VStack(spacing: 16) {
          Text("No lyrics available").foregroundColor(.white.opacity(0.7))
        }
        Spacer()
      } else {
        ScrollViewReader { proxy in
            if #available(iOS 18.0, *) {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 40) {
                        Spacer().frame(height: 20)
                        ForEach(Array(viewModel.lyrics.enumerated()), id: \.element.id) { index, line in
                            LyricLineView(
                              text: line.text,
                              distance: index - viewModel.currentLyricsLineIndex,
                              isPlainLyrics: isPlainLyrics,
                              suppressBlur: scrollState.isScrolling || !viewModel.isPlaying
                            )
                            .id(index)
                            .onTapGesture {
                                guard !isPlainLyrics else { return }
                                
                                let progress = line.timestamp / viewModel.nowPlaying.duration
                                
                                viewModel.seek(to: progress)
                                viewModel.play()
                            }
                        }
                        
                        Spacer().frame(height: 250)
                    }
                    .padding(.horizontal, 30)
                }
                .onScrollGeometryChange(for: CGFloat.self) { geometry in
                    geometry.contentOffset.y
                } action: { _, newOffset in
                    scrollState.handleScroll(offset: newOffset)
                }
                .mask(
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0.0),
                            .init(color: .black, location: 0.08),
                            .init(color: .black, location: 0.92),
                            .init(color: .clear, location: 1.0),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .onAppear {
                  guard !isPlainLyrics else { return }
                  guard viewModel.currentLyricsLineIndex >= 0 else { return }

                  scrollState.setAutoScrolling(true)
                  proxy.scrollTo(viewModel.currentLyricsLineIndex, anchor: UnitPoint(x: 0.5, y: 0.4))
                  DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    scrollState.setAutoScrolling(false)
                  }
                }
                .onChange(of: viewModel.currentLyricsLineIndex) { newIndex in
                  guard !isPlainLyrics, newIndex >= 0, !scrollState.isScrolling else { return }

                  scrollState.setAutoScrolling(true)
                  withAnimation(.easeInOut(duration: 0.5)) {
                    proxy.scrollTo(newIndex, anchor: UnitPoint(x: 0.5, y: 0.4))
                  }
                  DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    scrollState.setAutoScrolling(false)
                  }
                }
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 40) {
                        Spacer().frame(height: 20)
                        ForEach(Array(viewModel.lyrics.enumerated()), id: \.element.id) { index, line in
                            LyricLineView(
                                text: line.text,
                                distance: index - viewModel.currentLyricsLineIndex,
                                isPlainLyrics: isPlainLyrics,
                                suppressBlur: true
                            )
                            .id(index)
                            .onTapGesture {
                                guard !isPlainLyrics else { return }
                                
                                let progress = line.timestamp / viewModel.nowPlaying.duration
                                
                                viewModel.seek(to: progress)
                                viewModel.play()
                            }
                        }
                        
                        Spacer().frame(height: 250)
                    }
                    .padding(.horizontal, 30)
                }
                .mask(
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0.0),
                            .init(color: .black, location: 0.08),
                            .init(color: .black, location: 0.92),
                            .init(color: .clear, location: 1.0),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .onAppear {
                    guard !isPlainLyrics else { return }
                    guard viewModel.currentLyricsLineIndex >= 0 else { return }
                    
                    scrollState.setAutoScrolling(true)
                    proxy.scrollTo(viewModel.currentLyricsLineIndex, anchor: UnitPoint(x: 0.5, y: 0.4))
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        scrollState.setAutoScrolling(false)
                    }
                }
                .onChange(of: viewModel.currentLyricsLineIndex) { newIndex in
                    guard !isPlainLyrics, newIndex >= 0, !scrollState.isScrolling else { return }
                    
                    scrollState.setAutoScrolling(true)
                    withAnimation(.easeInOut(duration: 0.5)) {
                        proxy.scrollTo(newIndex, anchor: UnitPoint(x: 0.5, y: 0.4))
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        scrollState.setAutoScrolling(false)
                    }
                }
            }
        }
      }

      Spacer()

          HStack(spacing: 50) {
              Button {
                  viewModel.prevSong()
              } label: {
                  Image(systemName: "backward.fill")
                      .font(.title2)
                      .foregroundColor(.white)
              }
              
              Button {
                  viewModel.isPlaying ? viewModel.pause() : viewModel.play()
              } label: {
                  Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                      .font(.system(size: 38))
                      .foregroundColor(.white)
              }
              .disabled(viewModel.isMediaLoading)
              .opacity(viewModel.isMediaLoading ? 0.4 : 1)
              
              Button {
                  viewModel.nextSong()
              } label: {
                  Image(systemName: "forward.fill")
                      .font(.title2)
                      .foregroundColor(.white)
              }
          }
              .padding(.top, 14)

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
                .frame(minWidth: 44, idealWidth: 60, maxWidth: 80, alignment: .leading)

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
              .padding(.top, 30)
              .padding(.horizontal, 30)

              VStack(spacing: 0) {
                HStack(spacing: 0) {
                  Button {
                    viewModel.toggleLyricsMode()
          } label: {
            Image(systemName: "quote.bubble.fill")
              .font(.title2)
              .foregroundColor(.white)
          }
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
                  .lineLimit(1)
                  .fixedSize(horizontal: true, vertical: false)
                  .offset(y: 13)
              }
            }

          Spacer(minLength: 0)

          Button {
            showQueue.toggle()
          } label: {
            Image(systemName: "list.bullet")
              .font(.title2)
              .foregroundColor(.white)
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
          .frame(width: 44, height: 44)
        }
        .padding(.horizontal, 34)
        .padding(.top, 32)
        .padding(.bottom, max(bottomSafeInset, 12) + 20)
      }
    }
  }
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
        .frame(width: geometry.size.width, height: 5)
    }
  }
  .frame(height: 20)
}

struct LyricLineView: View {
    let text: String
    let distance: Int
    let isPlainLyrics: Bool
    let suppressBlur: Bool
    
    private var isCurrentLine: Bool { distance == 0 }
    
    private var blurRadius: CGFloat {
        if isPlainLyrics || suppressBlur { return 0 }
            let d = min(abs(distance), 6)
            return CGFloat(d) * 1.5
    }
    
    var body: some View {
        Text(text)
            .foregroundColor(
                isCurrentLine ? .white : (distance < 0 ? .white.opacity(0.3) : .white.opacity(0.5))
            )
            .customFont(.title)
            .fontWeight(.semibold)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .lineSpacing(6)
            .scaleEffect(isCurrentLine && !isPlainLyrics ? 1.03 : 1.0)
            .blur(radius: blurRadius)
            .animation(.easeInOut(duration: 0.3), value: blurRadius)
            .opacity(isPlainLyrics ? 0.9 : 1.0)
    }
}
