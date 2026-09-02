//
//  PlayerSidePanelView.swift
//  flo — right sidebar for pad/mac floating player (lyrics + queue)
//

import NukeUI
import SwiftUI

private struct SidePanelHeaderModifier: ViewModifier {
  func body(content: Content) -> some View {
    content
      .padding(.horizontal, 14)
      .padding(.vertical, 8)
      .background(Color(.secondarySystemBackground))
  }
}

private extension View {
  func sidePanelHeader() -> some View { modifier(SidePanelHeaderModifier()) }
}

struct PlayerSidePanelView: View {
  @Environment(\.colorScheme) private var colorScheme
  @Binding var activePanel: FloatingPlayerPanel?
  @ObservedObject var viewModel: PlayerViewModel

  // MARK: - Lyrics font (bypass customFont accent injection)
  private func lyricsFont(_ style: TextStyle) -> Font {
    switch style {
    case .largeTitle:
      return .custom("Plus Jakarta Sans", size: 34)
    case .title, .title1:
      return .custom("Plus Jakarta Sans", size: 28)
    case .title2:
      return .custom("Plus Jakarta Sans", size: 22)
    case .title3:
      return .custom("Plus Jakarta Sans", size: 20)
    case .headline:
      return .custom("Plus Jakarta Sans", size: 17).weight(.bold)
    case .body:
      return .custom("Plus Jakarta Sans", size: 17)
    case .callout:
      return .custom("Plus Jakarta Sans", size: 16)
    case .subheadline:
      return .custom("Plus Jakarta Sans", size: 15)
    case .footnote:
      return .custom("Plus Jakarta Sans", size: 13)
    case .caption1:
      return .custom("Plus Jakarta Sans", size: 12)
    case .caption2:
      return .custom("Plus Jakarta Sans", size: 11)
    }
  }

  var body: some View {
    ZStack(alignment: .topLeading) {
      Color(.systemBackground).ignoresSafeArea()
      // Leading-edge separator — 1pt primary 0.35, full height, above background
      HStack(spacing: 0) {
        Rectangle()
          .fill(Color.primary.opacity(0.20))
          .frame(width: 1)
        Spacer()
      }
      .frame(maxHeight: .infinity)
      .allowsHitTesting(false)
      .zIndex(1)

      VStack(spacing: 0) {
        if activePanel == .lyrics {
          lyricsContent
        } else if activePanel == .queue {
          queueContent
        }
      }
    }
    .frame(width: 380)
    .frame(maxHeight: .infinity)
    .background(Color(.systemBackground).ignoresSafeArea())
    .ignoresSafeArea()
    .transition(.move(edge: .trailing).combined(with: .opacity))
  }

  // MARK: Lyrics — systemBackground, explicit scheme label colors (no accent)

  private var lyricsContent: some View {
    VStack(alignment: .leading, spacing: 0) {
      // Header pinned above ScrollView — unified with queue header (same height/background/metrics)
      HStack(alignment: .center, spacing: 10) {
        if let sourceName = viewModel.lyricsSourceName {
          Text("Lyrics from: \(sourceName)")
            .font(lyricsFont(.subheadline))
            .foregroundColor(.secondary)
            .lineLimit(1)
        } else {
          Text("")
            .font(lyricsFont(.subheadline))
            .foregroundColor(.secondary)
        }
        Spacer()
      }
      .sidePanelHeader()

      Divider().opacity(0.06)

      Group {
        if viewModel.isLoadingLyrics && viewModel.lyrics.isEmpty && (viewModel.lyricsError == nil || viewModel.lyricsError!.isEmpty) {
          VStack {
            Spacer()
            ProgressView()
              .scaleEffect(1.1)
              .tint(colorScheme == .dark ? Color.white : Color.black)
            Text("Loading lyrics…")
              .font(lyricsFont(.caption1))
              .padding(.top, 8)
              .foregroundColor(.secondary)
            Spacer()
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.lyrics.isEmpty {
          VStack(spacing: 10) {
            Spacer()
            Text("No lyrics available")
              .font(lyricsFont(.callout))
              .foregroundColor(.secondary)
            Spacer()
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.lyrics.count == 1 {
          // Plain (unsynced) lyrics — single block, explicit scheme color
          ScrollView {
            Text(viewModel.lyrics[0].text)
              .font(lyricsFont(.callout))
              .multilineTextAlignment(.leading)
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding(16)
              .foregroundColor(colorScheme == .dark ? Color.white : Color.black)
          }
        } else {
          ScrollViewReader { proxy in
            ScrollView {
              LazyVStack(spacing: 14) {
                ForEach(Array(viewModel.lyrics.enumerated()), id: \.element.id) { idx, line in
                  let isCurrent = idx == viewModel.currentLyricsLineIndex
                  Text(line.text)
                    .font(lyricsFont(isCurrent ? .title3 : .body))
                    .fontWeight(isCurrent ? .semibold : .regular)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
                    .lineSpacing(6)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 3)
                    .foregroundColor(isCurrent ? (colorScheme == .dark ? Color.white : Color.black) : (colorScheme == .dark ? Color.white.opacity(0.45) : Color.black.opacity(0.45)))
                    .animation(.easeInOut(duration: 0.22), value: viewModel.currentLyricsLineIndex)
                    .id(idx)
                    .onTapGesture {
                      let progress = line.timestamp / max(viewModel.nowPlaying.duration, 0.1)
                      let clamped = min(max(progress, 0), 1)
                      viewModel.seek(to: clamped)
                      viewModel.play()
                    }
                }
                Spacer().frame(height: 120)
              }
              .padding(.vertical, 12)
            }
            .onAppear {
              guard viewModel.currentLyricsLineIndex >= 0 else { return }
              proxy.scrollTo(viewModel.currentLyricsLineIndex, anchor: .center)
            }
            .onChange(of: viewModel.currentLyricsLineIndex) { newIndex in
              guard newIndex >= 0 else { return }
              withAnimation(.easeInOut(duration: 0.45)) {
                proxy.scrollTo(newIndex, anchor: .center)
              }
            }
          }
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .background(Color(.systemBackground))
  }

  // MARK: Queue — mirror PlayerView "Playing Next" list (no header, sub-row aligned, no leading bar)

  private var queueContent: some View {
    VStack(alignment: .leading, spacing: 0) {
      // Single subheader row: "From <context>" leading + shuffle/repeat trailing on one HStack
      HStack(alignment: .center, spacing: 10) {
        if viewModel.queue.isEmpty {
          Text("")
            .font(lyricsFont(.subheadline))
            .foregroundColor(.secondary)
        } else {
          Text("From \(viewModel.nowPlaying.contextName ?? viewModel.nowPlaying.albumName ?? "")")
            .font(lyricsFont(.subheadline))
            .foregroundColor(.secondary)
            .lineLimit(1)
        }
        Spacer()
        HStack(spacing: 8) {
          Button {
            viewModel.shuffleCurrentQueue()
          } label: {
            Image(systemName: "shuffle")
              .foregroundColor(Color.accentColor)
              .fontWeight(.bold)
              .padding(6)
              .background(viewModel.isShuffling ? Color.gray.opacity(0.18) : Color(.systemBackground))
              .cornerRadius(6)
          }
          .buttonStyle(.plain)
          Button {
            viewModel.setPlaybackMode()
          } label: {
            Image(systemName: "repeat")
              .foregroundColor(Color.accentColor)
              .fontWeight(.bold)
              .overlay(
                Group {
                  Text("1").font(.caption).clipShape(Circle()).offset(x: 10, y: -5).fontWeight(.bold)
                }.opacity(viewModel.playbackMode == PlaybackMode.repeatOnce ? 1 : 0)
              )
              .padding(6)
              .background(viewModel.playbackMode == PlaybackMode.defaultPlayback ? Color(.systemBackground) : Color.gray.opacity(0.18))
              .cornerRadius(6)
          }
          .buttonStyle(.plain)
        }
      }
      .sidePanelHeader()

      Divider().opacity(0.06)

      ScrollView {
        LazyVStack(alignment: .leading, spacing: 0) {
          ForEach(Array(viewModel.queue.enumerated()), id: \.offset) { idx, song in
            HStack(alignment: .top, spacing: 10) {
              VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .center, spacing: 6) {
                  Text(song.songName ?? "")
                    .customFont(.callout)
                    .fontWeight(.medium)
                    .lineLimit(1)
                  if ExplicitStatus(from: song.explicitStatus).isExplicit {
                    ExplicitBadge(size: .compact)
                  }
                }
                Text(song.artistName ?? "")
                  .customFont(.caption1)
                  .foregroundColor(.secondary)
                  .lineLimit(1)
              }
              .frame(maxWidth: .infinity, alignment: .leading)
              Spacer()
              Text(timeString(for: song.duration))
                .customFont(.caption1)
                .foregroundColor(.secondary)
                .padding(.top, 2)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 14)
            .background(viewModel.activeQueueIdx == idx ? Color.accentColor.opacity(0.10) : Color.clear)
            .contentShape(Rectangle())
            .onTapGesture {
              viewModel.playFromQueue(idx: idx)
            }
            Divider().opacity(0.06)
          }
        }
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .background(Color(.systemBackground))
  }
}
