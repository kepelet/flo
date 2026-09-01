//
//  PlayerSidePanelView.swift
//  flo — right sidebar for pad/mac floating player (lyrics + queue)
//

import NukeUI
import SwiftUI

struct PlayerSidePanelView: View {
  @Binding var activePanel: FloatingPlayerPanel?
  @ObservedObject var viewModel: PlayerViewModel

  var body: some View {
    let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
    ZStack(alignment: .top) {
      shape
        .fill(Color(.systemBackground))
        .shadow(color: .black.opacity(0.14), radius: 18, x: -6, y: 8)
        .overlay(shape.stroke(Color.primary.opacity(0.08), lineWidth: 0.8))

      VStack(spacing: 0) {
        header
        Divider().opacity(0.08)
        if activePanel == .lyrics {
          lyricsContent
        } else if activePanel == .queue {
          queueContent
        }
      }
      .clipShape(shape)
    }
    .frame(width: 380)
    // Fixed height: fill window height minus floating player + safe area, but clamp to avoid infinite.
    .frame(maxHeight: .infinity)
    .transition(.move(edge: .trailing).combined(with: .opacity))
  }

  private var header: some View {
    HStack(spacing: 10) {
      if activePanel == .lyrics {
        Image(systemName: "quote.bubble.fill").foregroundColor(.accentColor)
          .font(.system(size: 14, weight: .semibold))
        Text("Lyrics").customFont(.headline)
      } else {
        Image(systemName: "list.bullet").foregroundColor(.accentColor)
          .font(.system(size: 14, weight: .semibold))
        Text("Playing Next").customFont(.headline)
      }
      Spacer()
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 10)
    .background(Color(.secondarySystemBackground).opacity(0.6))
  }

  // MARK: Lyrics — readable list with current line highlighted

  private var lyricsContent: some View {
    Group {
      if viewModel.isLoadingLyrics {
        VStack {
          Spacer()
          ProgressView().scaleEffect(1.1)
          Text("Loading lyrics…").customFont(.caption1).foregroundColor(.secondary).padding(.top, 8)
          Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else if let error = viewModel.lyricsError, !error.isEmpty {
        VStack(spacing: 10) {
          Spacer()
          Image(systemName: "music.note.list").font(.title2).foregroundColor(.secondary.opacity(0.6))
          Text(error).customFont(.callout).foregroundColor(.secondary).multilineTextAlignment(.center).padding(.horizontal, 16)
          Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else if viewModel.lyrics.isEmpty {
        VStack(spacing: 10) {
          Spacer()
          Text("No lyrics available").customFont(.callout).foregroundColor(.secondary)
          Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else if viewModel.lyrics.count == 1 {
        // Plain (unsynced) lyrics — single block
        ScrollView {
          Text(viewModel.lyrics[0].text)
            .customFont(.callout)
            .foregroundColor(.primary.opacity(0.88))
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
        }
      } else {
        ScrollViewReader { proxy in
          ScrollView {
            LazyVStack(spacing: 14) {
              ForEach(Array(viewModel.lyrics.enumerated()), id: \.element.id) { idx, line in
                let isCurrent = idx == viewModel.currentLyricsLineIndex
                Text(line.text)
                  .customFont(isCurrent ? .title3 : .body)
                  .fontWeight(isCurrent ? .semibold : .regular)
                  .foregroundColor(
                    isCurrent ? Color.accentColor : Color.primary.opacity(0.62)
                  )
                  .multilineTextAlignment(.leading)
                  .frame(maxWidth: .infinity, alignment: .leading)
                  .lineSpacing(6)
                  .padding(.horizontal, 14)
                  .padding(.vertical, 3)
                  .scaleEffect(isCurrent ? 1.02 : 1.0)
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

  // MARK: Queue — mirror PlayerView "Playing Next" list

  private var queueContent: some View {
    VStack(alignment: .leading, spacing: 0) {
      // Subheader: context name + shuffle/repeat (like PlayerView)
      HStack(alignment: .bottom, spacing: 10) {
        if viewModel.queue.isEmpty {
          Text("").customFont(.subheadline)
        } else {
          Text("From \(viewModel.nowPlaying.contextName ?? viewModel.nowPlaying.albumName ?? "")")
            .customFont(.subheadline)
            .foregroundColor(.secondary)
            .lineLimit(1)
        }
        Spacer()
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
      .padding(.horizontal, 14)
      .padding(.vertical, 8)
      .background(Color(.secondarySystemBackground).opacity(0.45))

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
            .overlay(
              Rectangle().fill(viewModel.activeQueueIdx == idx ? Color.accentColor.opacity(0.85) : Color.clear)
                .frame(width: 3),
              alignment: .leading
            )
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
  }
}
