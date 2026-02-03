//
//  LyricsView.swift
//  flo
//
//  Created by rizaldy on 02/02/26.
//

import SwiftUI
import NukeUI

struct LyricsView: View {
  @ObservedObject var viewModel: PlayerViewModel
  @Binding var showQueue: Bool

  let imageSize: CGFloat

  private var isPlainLyrics: Bool {
    return viewModel.lyrics.count == 1
  }

  var body: some View {
    VStack(spacing: 0) {
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
      .padding(.top, 16)
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
          ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 20) {
              ForEach(Array(viewModel.lyrics.enumerated()), id: \.element.id) { index, line in
                LyricLineView(
                  text: line.text,
                  isCurrentLine: index == viewModel.currentLyricsLineIndex,
                  isPastLine: index < viewModel.currentLyricsLineIndex,
                  isPlainLyrics: isPlainLyrics
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
          .onAppear {
            if !isPlainLyrics {
              proxy.scrollTo(viewModel.currentLyricsLineIndex, anchor: .center)
            }
          }
          .onChange(of: viewModel.currentLyricsLineIndex) { newIndex in
            withAnimation(.easeInOut(duration: 0.5)) {
              if !isPlainLyrics {
                proxy.scrollTo(newIndex, anchor: .center)
              }
            }
          }
        }
      }

      Spacer()

      VStack(spacing: 0) {
        HStack(spacing: 0) {
          Button {
            viewModel.toggleLyricsMode()
          } label: {
            Image(systemName: "quote.bubble.fill")
              .font(.title2)
              .foregroundColor(.white)
          }
          .frame(width: 56, alignment: .leading)

          AirPlayRoutePicker(tintColor: UIColor.white, activeTintColor: UIColor.white)
            .frame(width: 36, height: 36, alignment: .center)
            .frame(maxWidth: .infinity, alignment: .center)
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
          .frame(width: 56, alignment: .trailing)
        }
        .padding(.horizontal, 30)
        .padding(.top, 10)
      }
    }
  }
}

struct LyricLineView: View {
  let text: String

  let isCurrentLine: Bool
  let isPastLine: Bool
  let isPlainLyrics: Bool

  var body: some View {
    Text(text)
      .foregroundColor(
        isCurrentLine ? .white : (isPastLine ? .white.opacity(0.3) : .white.opacity(0.5))
      )
      .customFont(.title)
      .fontWeight(.semibold)
      .multilineTextAlignment(.leading)
      .frame(maxWidth: .infinity, alignment: .leading)
      .lineSpacing(6)
      .scaleEffect(isCurrentLine && !isPlainLyrics ? 1.03 : 1.0)
      .animation(.easeInOut(duration: 0.3), value: isCurrentLine)
      .opacity(isPlainLyrics ? 0.9 : 1.0)
  }
}
