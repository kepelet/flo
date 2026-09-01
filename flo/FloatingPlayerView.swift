//
//  FloatingPlayerView.swift
//  flo
//
//  Created by rizaldy on 08/06/24.
//

import NukeUI
import SwiftUI

extension View {
  @ViewBuilder
  func glassedEffect(in shape: some Shape, interactive: Bool = false) -> some View {
    if #available(iOS 26.0, *) {
      self.glassEffect(interactive ? .regular.interactive() : .regular, in: shape)
        .contentShape(shape)
    } else {
      self.background {
        shape.glassed()
      }
    }
  }
}

extension Shape {
  func glassed() -> some View {
    ZStack {
      Color.clear
        .background(.ultraThinMaterial)

      LinearGradient(
        gradient: Gradient(colors: [
          Color.primary.opacity(0.08),
          Color.primary.opacity(0.05),
          Color.primary.opacity(0.01),
          Color.clear,
          Color.clear,
          Color.clear,
        ]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
    }
    .mask(self)
    .overlay(
      self.stroke(Color.primary.opacity(0.2), lineWidth: 0.7)
    )
  }
}

// MARK: - Compact (iPhone) — byte-identical behavior, do not modify

struct FloatingPlayerView: View {
  @ObservedObject var viewModel: PlayerViewModel

  var body: some View {
    ZStack {
      HStack(spacing: 10) {
        Group {
          if let image = UIImage(contentsOfFile: viewModel.getAlbumCoverArt()) {
            Image(uiImage: image)
              .resizable()
              .aspectRatio(contentMode: .fit)
          } else {
            LazyImage(url: URL(string: viewModel.getAlbumCoverArt())) { state in
              if state.isLoading {
                Color.gray.opacity(0.3)
              } else {
                if let image = state.image {
                  image.resizable().aspectRatio(contentMode: .fit)
                } else {
                  Image("placeholder")
                    .resizable()
                    .scaledToFit()
                    .padding(8)
                }
              }
            }
          }
        }
        .frame(width: 40, height: 40)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .shadow(radius: 2)

        VStack(alignment: .leading, spacing: 1) {
          HStack(alignment: .center, spacing: 6) {
            Text(viewModel.nowPlaying.songName ?? "")
              .foregroundColor(.accent)
              .customFont(.callout)
              .fontWeight(.bold)
              .lineLimit(1)

            if ExplicitStatus(from: viewModel.nowPlaying.explicitStatus).isExplicit {
              ExplicitBadge(size: .compact)
            }
          }

          Text(viewModel.nowPlaying.artistName ?? "")
            .customFont(.caption1)
            .lineLimit(1)
        }

        Spacer()

        HStack(spacing: 16) {
          if viewModel.isMediaLoading {
            ProgressView()
              .progressViewStyle(CircularProgressViewStyle())
              .scaleEffect(0.7)
          } else {
            Button {
              viewModel.isPlaying ? viewModel.pause() : viewModel.play()
            } label: {
              Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                .font(.system(size: 20, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
            }
            .buttonStyle(.plain)
            .opacity(viewModel.isMediaFailed ? 0.3 : 1)
          }
        }
        .padding(.trailing, 8)
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 8)
    }
    .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    .glassedEffect(in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    .shadow(color: .black.opacity(0.15), radius: 16, x: 0, y: 6)
    .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    .padding(.horizontal, 16)
  }
}

// MARK: - Pad / macCatalyst — 3-column redesign (68pt tall, ~720 max width)

enum FloatingPlayerPanel: Equatable {
  case lyrics
  case queue
}

struct PadFloatingPlayerView: View {
  @ObservedObject var viewModel: PlayerViewModel
  @Binding var activePanel: FloatingPlayerPanel?

  @State private var isCenterHovering = false
  @State private var isVolumeOverlayVisible = false

  var body: some View {
    let shape = RoundedRectangle(cornerRadius: 24, style: .continuous)
    ZStack {
      // Base 3-column layout (glassed background sits behind)
      HStack(spacing: 0) {
        // Column 1: transport (left) — fixed compact width
        transportColumn
          .padding(.leading, 14)
          .padding(.trailing, 10)

        Divider().opacity(0.12).frame(height: 44)

        // Column 2: center (flexible)
        centerColumn
          .frame(maxWidth: .infinity)
          .padding(.horizontal, 12)
          .onHover { hovering in
            isCenterHovering = hovering
          }

        Divider().opacity(0.12).frame(height: 44)

        // Column 3: right controls (fixed width, ~210)
        rightColumn
          .frame(width: 210)
          .padding(.leading, 10)
          .padding(.trailing, 14)
          .onHover { hovering in
            if !hovering {
              isVolumeOverlayVisible = false
            }
          }
      }
      .frame(height: 68)
      .padding(.vertical, 4)
    }
    .contentShape(shape)
    .glassedEffect(in: shape)
    .clipShape(shape)
    .shadow(color: .black.opacity(0.15), radius: 16, x: 0, y: 6)
    .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    .padding(.horizontal, 16)
    .padding(.top, 6)
    .overlay(alignment: .topTrailing) {
      Button {
        viewModel.destroyPlayerAndQueue()
      } label: {
        Image(systemName: "xmark")
          .font(.system(size: 10, weight: .bold))
          .foregroundColor(.primary.opacity(0.75))
          .frame(width: 24, height: 24)
          .background(Color.primary.opacity(0.08))
          .clipShape(Circle())
          .overlay(Circle().stroke(Color.primary.opacity(0.12), lineWidth: 0.6))
      }
      .buttonStyle(.plain)
      .contentShape(Circle())
      .padding(.top, 3)
      .padding(.trailing, 8)
      .zIndex(999)
      .accessibilityLabel("Stop playback")
    }
    .zIndex(999)
  }

  // MARK: Column 1 — Transport

  private var transportColumn: some View {
    HStack(spacing: 8) {
      Button {
        viewModel.shuffleCurrentQueue()
      } label: {
        Image(systemName: "shuffle")
          .font(.system(size: 13, weight: .semibold))
          .foregroundColor(viewModel.isShuffling ? Color.accentColor : Color.primary.opacity(0.9))
          .frame(width: 28, height: 28)
          .background(viewModel.isShuffling ? Color.accentColor.opacity(0.14) : Color.clear)
          .clipShape(Circle())
      }
      .buttonStyle(.plain)

      Button {
        viewModel.prevSong()
      } label: {
        Image(systemName: "backward.fill")
          .font(.system(size: 15, weight: .semibold))
          .foregroundColor(.primary)
          .frame(width: 28, height: 28)
      }
      .buttonStyle(.plain)

      Button {
        viewModel.isPlaying ? viewModel.pause() : viewModel.play()
      } label: {
        Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
          .font(.system(size: 22, weight: .semibold))
          .symbolRenderingMode(.hierarchical)
          .foregroundColor(.primary)
          .frame(width: 36, height: 36)
          .background(Color.primary.opacity(0.08))
          .clipShape(Circle())
      }
      .buttonStyle(.plain)
      .opacity(viewModel.isMediaFailed ? 0.35 : 1)

      Button {
        viewModel.nextSong()
      } label: {
        Image(systemName: "forward.fill")
          .font(.system(size: 15, weight: .semibold))
          .foregroundColor(.primary)
          .frame(width: 28, height: 28)
      }
      .buttonStyle(.plain)

      Button {
        viewModel.setPlaybackMode()
      } label: {
        ZStack(alignment: .topTrailing) {
          Image(systemName: "repeat")
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(viewModel.playbackMode == PlaybackMode.defaultPlayback ? Color.primary.opacity(0.9) : Color.accentColor)
            .frame(width: 28, height: 28)
            .background(viewModel.playbackMode == PlaybackMode.defaultPlayback ? Color.clear : Color.accentColor.opacity(0.14))
            .clipShape(Circle())

          if viewModel.playbackMode == PlaybackMode.repeatOnce {
            Text("1")
              .font(.system(size: 7, weight: .bold))
              .foregroundColor(.white)
              .frame(width: 11, height: 11)
              .background(Color.accentColor)
              .clipShape(Circle())
              .offset(x: 3, y: -1)
          }
        }
      }
      .buttonStyle(.plain)
    }
  }

  // MARK: Column 2 — Center (cover + title/artist + progress, hover-overlay seek)

  private var centerColumn: some View {
    ZStack {
      // Base content + small bar (visible when not hovering)
      VStack(alignment: .leading, spacing: 6) {
        HStack(spacing: 10) {
          Group {
            if let image = UIImage(contentsOfFile: viewModel.getAlbumCoverArt()) {
              Image(uiImage: image).resizable().aspectRatio(contentMode: .fill)
            } else {
              LazyImage(url: URL(string: viewModel.getAlbumCoverArt())) { state in
                if let image = state.image {
                  image.resizable().aspectRatio(contentMode: .fill)
                } else if state.isLoading {
                  Color.gray.opacity(0.25)
                } else {
                  Image("placeholder").resizable().scaledToFit().padding(6)
                }
              }
            }
          }
          .frame(width: 48, height: 48)
          .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
          .shadow(color: .black.opacity(0.12), radius: 2, x: 0, y: 1)

          VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .center, spacing: 5) {
              Text(viewModel.nowPlaying.songName ?? "")
                .foregroundColor(.accent)
                .customFont(.callout)
                .fontWeight(.bold)
                .lineLimit(1)
              if ExplicitStatus(from: viewModel.nowPlaying.explicitStatus).isExplicit {
                ExplicitBadge(size: .compact)
              }
            }
            Text(viewModel.nowPlaying.artistName ?? "")
              .customFont(.caption1)
              .foregroundColor(.primary.opacity(0.7))
              .lineLimit(1)
          }
          Spacer(minLength: 0)
        }

        // Small progress bar (always visible on iPad; on Mac hidden while hover overlay shows)
        if !isCenterHovering {
          PadProgressBar(viewModel: viewModel, height: 4, thumbVisible: false, useIsSeeking: true)
            .frame(height: 8)
        } else {
          // Reserve same height so layout does not jump when overlay appears
          Color.clear.frame(height: 8)
        }
      }
      .opacity(isCenterHovering ? 0.18 : 1)

      // Hover overlay — expanded seekable bar covering the content area (Catalyst only)
      if isCenterHovering {
        VStack(spacing: 6) {
          Text(viewModel.nowPlaying.songName ?? "")
            .customFont(.caption1)
            .fontWeight(.semibold)
            .foregroundColor(.primary.opacity(0.85))
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .center)
          PadProgressBar(viewModel: viewModel, height: 6, thumbVisible: true, useIsSeeking: true)
            .frame(height: 16)
          HStack {
            Text(viewModel.currentTimeString)
              .customFont(.caption2)
              .foregroundColor(.secondary)
            Spacer()
            Text(viewModel.totalTimeString)
              .customFont(.caption2)
              .foregroundColor(.secondary)
          }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.primary.opacity(0.08), lineWidth: 0.8))
      }
    }
    .animation(.easeInOut(duration: 0.16), value: isCenterHovering)
    // Keep small bar draggable even when not hovering (iPad) — the ZStack handles hover vs not.
    // For accessibility: if CenterHovering false, the PadProgressBar inside VStack is still draggable.
  }

  // MARK: Column 3 — Right (lyrics/queue/like/AirPlay/volume)

  private var rightColumn: some View {
    ZStack {
      if isVolumeOverlayVisible {
        // Volume overlay: slider LEFT of speaker so speaker stays in place
        HStack(spacing: 8) {
          PadVolumeSlider(viewModel: viewModel)
            .frame(maxWidth: .infinity)

          Button {
            viewModel.toggleMute()
          } label: {
            Image(systemName: volumeIconName)
              .font(.system(size: 15, weight: .semibold))
              .foregroundColor(volumeIconColor)
              .frame(width: 32, height: 32)
              .background(Color.primary.opacity(0.04))
              .clipShape(Circle())
          }
          .buttonStyle(.plain)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.98)))
      } else {
        HStack(spacing: 6) {
          Button {
            togglePanel(.lyrics)
          } label: {
            Image(systemName: activePanel == .lyrics ? "quote.bubble.fill" : "quote.bubble")
              .font(.system(size: 15, weight: .semibold))
              .foregroundColor(activePanel == .lyrics ? Color.accentColor : Color.primary.opacity(0.88))
              .frame(width: 32, height: 32)
              .background(activePanel == .lyrics ? Color.accentColor.opacity(0.14) : Color.clear)
              .clipShape(Circle())
          }
          .buttonStyle(.plain)

          Button {
            togglePanel(.queue)
          } label: {
            Image(systemName: "list.bullet")
              .font(.system(size: 15, weight: .semibold))
              .foregroundColor(activePanel == .queue ? Color.accentColor : Color.primary.opacity(0.88))
              .frame(width: 32, height: 32)
              .background(activePanel == .queue ? Color.accentColor.opacity(0.14) : Color.clear)
              .clipShape(Circle())
          }
          .buttonStyle(.plain)

          Button {
            viewModel.toggleStar()
          } label: {
            Image(systemName: viewModel.isStarred ? "heart.fill" : "heart")
              .font(.system(size: 15, weight: .semibold))
              .foregroundColor(viewModel.isStarred ? Color.red : Color.primary.opacity(0.88))
              .frame(width: 32, height: 32)
              .background(viewModel.isStarred ? Color.red.opacity(0.12) : Color.clear)
              .clipShape(Circle())
          }
          .buttonStyle(.plain)
          .disabled(viewModel.isLiveRadio)
          .opacity(viewModel.isLiveRadio ? 0.35 : 1)

          AirPlayRoutePicker(tintColor: UIColor.label, activeTintColor: UIColor.systemBlue)
            .frame(width: 30, height: 30)
            .frame(width: 32, height: 32)
            .background(Color.primary.opacity(0.04))
            .clipShape(Circle())
            .overlay(alignment: .bottom) {
              if let name = viewModel.externalOutputName, !name.isEmpty {
                Text(name)
                  .customFont(.caption2)
                  .fontWeight(.bold)
                  .lineLimit(1)
                  .multilineTextAlignment(.center)
                  .foregroundColor(.primary.opacity(0.85))
                  .frame(maxWidth: 120)
                  .offset(y: 14)
              }
            }

          Button {
            if isVolumeOverlayVisible {
              viewModel.toggleMute()
            } else {
              withAnimation(.easeInOut(duration: 0.18)) {
                isVolumeOverlayVisible = true
              }
            }
          } label: {
            Image(systemName: volumeIconName)
              .font(.system(size: 15, weight: .semibold))
              .foregroundColor(volumeIconColor)
              .frame(width: 32, height: 32)
              .background(Color.primary.opacity(0.04))
              .clipShape(Circle())
          }
          .buttonStyle(.plain)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.98)))
      }
    }
    .animation(.easeInOut(duration: 0.18), value: isVolumeOverlayVisible)
  }

  private var volumeIconName: String {
    let v = viewModel.playbackVolume
    if v < 0.01 { return "speaker.slash.fill" }
    if v < 0.33 { return "speaker.wave.1.fill" }
    if v < 0.66 { return "speaker.wave.2.fill" }
    return "speaker.wave.3.fill"
  }

  private var volumeIconColor: Color {
    viewModel.playbackVolume < 0.01 ? Color.red.opacity(0.9) : Color.primary.opacity(0.88)
  }

  private func togglePanel(_ panel: FloatingPlayerPanel) {
    withAnimation(.spring(duration: 0.26, bounce: 0.08)) {
      if activePanel == panel {
        activePanel = nil
      } else {
        activePanel = panel
      }
    }
  }
}

// MARK: - Reusable seek/volume bars (finite-safe, guarded like PlayerCustomSlider)

private struct PadProgressBar: View {
  @ObservedObject var viewModel: PlayerViewModel
  var height: CGFloat
  var thumbVisible: Bool
  var useIsSeeking: Bool

  @State private var tempProgress: Double = 0

  var body: some View {
    GeometryReader { geo in
      let safeWidth: CGFloat = (geo.size.width.isFinite && geo.size.width > 0) ? geo.size.width : 0
      let progress: Double = viewModel.isSeeking && useIsSeeking ? tempProgress : viewModel.progress
      let clamped: Double = min(max(progress, 0), 1)
      let normalized: CGFloat = {
        guard clamped.isFinite else { return 0 }
        return CGFloat(min(max(clamped, 0), 1))
      }()
      ZStack(alignment: .leading) {
        Capsule()
          .fill(Color.primary.opacity(0.14))
          .frame(height: height)

        Capsule()
          .fill(Color.accentColor)
          .frame(width: normalized * safeWidth, height: height)

        if thumbVisible || viewModel.isSeeking {
          Circle()
            .fill(Color.accentColor)
            .frame(width: 12, height: 12)
            .shadow(color: .black.opacity(0.18), radius: 2, x: 0, y: 1)
            .offset(x: normalized * safeWidth - 6)
            .opacity(viewModel.isLiveRadio ? 0 : 1)
        } else {
          Circle()
            .fill(Color.accentColor)
            .frame(width: 7, height: 7)
            .offset(x: normalized * safeWidth - 3.5)
            .opacity(viewModel.isLiveRadio ? 0 : (viewModel.isSeeking ? 0 : 0.95))
        }
      }
      .contentShape(Rectangle())
      .gesture(
        DragGesture(minimumDistance: 0)
          .onChanged { g in
            guard !viewModel.isLiveRadio else { return }
            guard safeWidth > 0 else { return }
            let raw = Double(g.location.x / safeWidth)
            guard raw.isFinite else { return }
            let clampedRaw = min(max(raw, 0), 1)
            guard clampedRaw.isFinite else { return }
            tempProgress = clampedRaw
            viewModel.isSeeking = true
          }
          .onEnded { g in
            guard !viewModel.isLiveRadio else { viewModel.isSeeking = false; return }
            guard safeWidth > 0 else { viewModel.isSeeking = false; return }
            let raw = Double(g.location.x / safeWidth)
            guard raw.isFinite else { viewModel.isSeeking = false; return }
            let clampedRaw = min(max(raw, 0), 1)
            guard clampedRaw.isFinite else { viewModel.isSeeking = false; return }
            viewModel.isSeeking = false
            viewModel.seek(to: clampedRaw)
          }
      )
    }
  }
}

private struct PadVolumeSlider: View {
  @ObservedObject var viewModel: PlayerViewModel
  @State private var isDragging = false
  @State private var tempVolume: Float = 1.0

  var body: some View {
    GeometryReader { geo in
      let safeWidth: CGFloat = (geo.size.width.isFinite && geo.size.width > 0) ? geo.size.width : 0
      let displayVolume: Float = isDragging ? tempVolume : viewModel.playbackVolume
      let clamped: CGFloat = CGFloat(min(max(displayVolume, 0), 1))
      ZStack(alignment: .leading) {
        Capsule()
          .fill(Color.primary.opacity(0.14))
          .frame(height: 4)
        Capsule()
          .fill(Color.accentColor)
          .frame(width: clamped * safeWidth, height: 4)
        Circle()
          .fill(Color.accentColor)
          .frame(width: 12, height: 12)
          .shadow(color: .black.opacity(0.18), radius: 2, x: 0, y: 1)
          .offset(x: clamped * safeWidth - 6)
      }
      .contentShape(Rectangle())
      .gesture(
        DragGesture(minimumDistance: 0)
          .onChanged { g in
            guard safeWidth > 0 else { return }
            let raw = Float(g.location.x / safeWidth)
            guard raw.isFinite else { return }
            let clampedRaw = min(max(raw, 0), 1)
            tempVolume = clampedRaw
            isDragging = true
            viewModel.setPlaybackVolume(clampedRaw)
          }
          .onEnded { g in
            guard safeWidth > 0 else { isDragging = false; return }
            let raw = Float(g.location.x / safeWidth)
            guard raw.isFinite else { isDragging = false; return }
            let clampedRaw = min(max(raw, 0), 1)
            viewModel.setPlaybackVolume(clampedRaw)
            isDragging = false
          }
      )
    }
    .frame(height: 16)
  }
}

struct FloatingMusicPlayerView_previews: PreviewProvider {
  @StateObject static var viewModel = PlayerViewModel()

  static var previews: some View {
    Group {
      FloatingPlayerView(viewModel: viewModel)
      PadFloatingPlayerView(viewModel: viewModel, activePanel: .constant(nil))
        .previewDisplayName("Pad 3-col")
        .padding(.vertical, 20)
        .background(Color.gray.opacity(0.12))
      PadFloatingPlayerView(viewModel: viewModel, activePanel: .constant(.queue))
        .previewDisplayName("Pad queue active")
        .padding(.vertical, 20)
        .background(Color.gray.opacity(0.12))
    }
  }
}
