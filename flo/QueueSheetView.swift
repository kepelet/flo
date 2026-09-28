//
//  QueueSheetView.swift
//  flo
//
//  Playing queue: fullscreen lazy list with Play Next / Play After /
//  Add to Queue entry points, remove, move-to-top, download, like,
//  go-to-album/artist and clear. Presented like the lyrics screen —
//  full-bleed over the player background, no sheet chrome, no borders.
//  Reorder is always available via press-and-drag on any row.
//

import SwiftUI
import UniformTypeIdentifiers

/// Shared "Play Next / Play After / Add to Queue" buttons for song rows
/// (album songs, playlists, all-songs, liked songs). Long-press menus and
/// Catalyst right-click menus both pick these up.
struct QueueMenuButtons: View {
  @ObservedObject var player: PlayerViewModel

  let songs: [Song]
  let contextName: String
  let isFromLocal: Bool
  let isFromPlaylist: Bool

  init(
    player: PlayerViewModel, songs: [Song], contextName: String, isFromLocal: Bool = false,
    isFromPlaylist: Bool = false
  ) {
    self.player = player
    self.songs = songs
    self.contextName = contextName
    self.isFromLocal = isFromLocal
    self.isFromPlaylist = isFromPlaylist
  }

  init(
    player: PlayerViewModel, song: Song, contextName: String, isFromLocal: Bool = false,
    isFromPlaylist: Bool = false
  ) {
    self.init(
      player: player, songs: [song], contextName: contextName, isFromLocal: isFromLocal,
      isFromPlaylist: isFromPlaylist)
  }

  var body: some View {
    Button {
      player.playNext(
        songs: songs, contextName: contextName, isFromLocal: isFromLocal,
        isFromPlaylist: isFromPlaylist)
    } label: {
      Label("Play Next", systemImage: "text.insert")
    }

    Button {
      player.playAfter(
        songs: songs, contextName: contextName, isFromLocal: isFromLocal,
        isFromPlaylist: isFromPlaylist)
    } label: {
      Label("Play After", systemImage: "text.append")
    }

    Button {
      player.appendToQueue(
        songs: songs, contextName: contextName, isFromLocal: isFromLocal,
        isFromPlaylist: isFromPlaylist)
    } label: {
      Label("Add to Queue", systemImage: "text.badge.plus")
    }
  }
}

struct QueueView: View {
  @ObservedObject var player: PlayerViewModel
  @ObservedObject var albums: AlbumViewModel

  @EnvironmentObject var downloads: DownloadViewModel

  @Binding var isPresented: Bool

  let topSafeInset: CGFloat
  let bottomSafeInset: CGFloat

  var onNavigate: ((LibraryDestination) -> Void)?

  @State private var showClearConfirm = false
  @StateObject private var rowStore = QueueRowStore()
  @State private var draggingIdx: Int?
  @State private var dropTargetIdx: Int?
  @State private var dropEdge: Edge?

  var body: some View {
    VStack(spacing: 0) {
      header
        .padding(.horizontal, 30)
        .padding(.top, topSafeInset + 8)
        .padding(.bottom, 12)
        .gesture(
          DragGesture()
            .onEnded { value in
              if value.translation.height > 80 {
                isPresented = false
              }
            }
        )

      if player.queue.isEmpty {
        Spacer()
        Text("Queue is empty")
          .foregroundColor(.white.opacity(0.7))
          .customFont(.subheadline)
        Spacer()
      } else {
        ScrollView(.vertical, showsIndicators: false) {
          LazyVStack(spacing: 0) {
            ForEach(Array(player.queue.enumerated()), id: \.element.objectID) { idx, song in
              queueRow(idx: idx, song: song)
            }
          }
          .padding(.horizontal, 30)
          .padding(.bottom, max(bottomSafeInset, 12) + 24)
        }
        .onDrop(
          of: [.text],
          delegate: QueueListDropDelegate(
            player: player, draggingIdx: $draggingIdx, dropTargetIdx: $dropTargetIdx,
            dropEdge: $dropEdge))
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .alert("Clear queue?", isPresented: $showClearConfirm) {
      Button("Cancel", role: .cancel) {}
      Button("Clear Queue", role: .destructive) {
        player.clearQueue()
      }
    } message: {
      Text("This removes all songs from the queue and stops playback.")
    }
    .onAppear {
      rowStore.refreshStars()
      rowStore.refreshDownloads(queue: player.queue)
    }
    .onReceive(downloads.$downloadWatcher) { _ in
      rowStore.refreshDownloads(queue: player.queue)
    }
    .onChange(of: player.queue.isEmpty) { isEmpty in
      if isEmpty {
        isPresented = false
      }
    }
  }

  // MARK: - Header

  private var header: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .center, spacing: 12) {
        VStack(alignment: .leading, spacing: 2) {
          Text("Queue")
            .foregroundColor(.white)
            .customFont(.title2)
            .fontWeight(.bold)

          Text(player.queue.isEmpty ? "Nothing queued" : "\(player.queue.count) songs")
            .foregroundColor(.white.opacity(0.7))
            .customFont(.subheadline)
        }

        Spacer()

        Button {
          isPresented = false
        } label: {
          Image(systemName: "chevron.down")
            .font(.title3.weight(.semibold))
            .foregroundColor(.white)
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(.white.opacity(0.15))
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.25), radius: 6, x: 0, y: 3)
        }
        .keyboardShortcut(.escape, modifiers: [])
      }

      HStack(alignment: .center, spacing: 10) {
        Text(
          player.queue.isEmpty
            ? ""
            : "From \(player.nowPlaying.contextName ?? player.nowPlaying.albumName ?? "")"
        )
        .foregroundColor(.white.opacity(0.7))
        .customFont(.subheadline)
        .lineLimit(1)

        Spacer()

        Button {
          showClearConfirm = true
        } label: {
          Image(systemName: "trash")
            .foregroundColor(.white)
            .fontWeight(.bold)
            .padding(5)
        }
        .disabled(player.queue.isEmpty)
        .opacity(player.queue.isEmpty ? 0.4 : 1)

        Button {
          player.shuffleCurrentQueue()
        } label: {
          Image(systemName: "shuffle")
            .foregroundColor(.white)
            .fontWeight(.bold)
            .padding(5)
            .background(
              player.isShuffling ? Color.white.opacity(0.15) : Color.clear
            )
            .cornerRadius(5)
        }

        Button {
          player.setPlaybackMode()
        } label: {
          Image(systemName: "repeat")
            .foregroundColor(.white)
            .fontWeight(.bold)
            .overlay(
              Group {
                Text("1")
                  .font(.caption)
                  .clipShape(Circle())
                  .offset(x: 10, y: -5)
                  .fontWeight(.bold)
              }.opacity(player.playbackMode == PlaybackMode.repeatOnce ? 1 : 0)
            )
            .padding(5)
            .background(
              player.playbackMode == PlaybackMode.defaultPlayback
                ? Color.clear : Color.white.opacity(0.15)
            )
            .cornerRadius(5)
        }
      }
    }
  }

  // MARK: - Rows

  @ViewBuilder
  private func queueRow(idx: Int, song: QueueEntity) -> some View {
    let isActive = player.activeQueueIdx == idx

    HStack(alignment: .center, spacing: 10) {
      Image(systemName: "line.3.horizontal")
        .font(.callout)
        .foregroundColor(.white.opacity(0.55))

      VStack(alignment: .leading, spacing: 2) {
        HStack(alignment: .center, spacing: 6) {
          Text(song.songName ?? "")
            .foregroundColor(isActive ? Color.accentColor : .white)
            .customFont(.callout)
            .fontWeight(.medium)
            .lineLimit(1)

          if ExplicitStatus(from: song.explicitStatus).isExplicit {
            ExplicitBadge(tint: .white.opacity(0.85), size: .compact)
          }
        }

        Text(song.artistName ?? "")
          .foregroundColor(.white.opacity(0.7))
          .customFont(.caption1)
          .lineLimit(1)
      }
      .frame(maxWidth: .infinity, alignment: .leading)

      Text(timeString(for: song.duration))
        .foregroundColor(.white.opacity(0.7))
        .customFont(.caption1)

      Button {
        guard !isActive else { return }
        player.removeFromQueue(at: idx)
      } label: {
        Image(systemName: "minus.circle.fill")
          .font(.title3)
          .foregroundColor(isActive ? .white.opacity(0.25) : .red)
      }
      .disabled(isActive)
      .buttonStyle(.plain)
    }
    .padding(.vertical, 8)
    .padding(.horizontal, 12)
    .background(
      dropTargetIdx == idx
        ? Color.accentColor.opacity(0.25)
        : (isActive ? Color.white.opacity(0.12) : Color.clear),
      in: RoundedRectangle(cornerRadius: 10, style: .continuous)
    )
    .overlay(alignment: dropEdge == .bottom ? .bottom : .top) {
      if dropTargetIdx == idx {
        RoundedRectangle(cornerRadius: 2)
          .fill(Color.accentColor)
          .frame(height: 3)
      }
    }
    .opacity(draggingIdx == idx ? 0.45 : 1)
    .contentShape(Rectangle())
    .onTapGesture {
      player.playFromQueue(idx: idx)
    }
    .onDrag {
      draggingIdx = idx
      return NSItemProvider(object: String(idx) as NSString)
    }
    .onDrop(
      of: [.text],
      delegate: QueueReorderDropDelegate(
        player: player, targetIdx: idx, draggingIdx: $draggingIdx,
        dropTargetIdx: $dropTargetIdx, dropEdge: $dropEdge))
    .contextMenu {
      QueueRowMenu(
        player: player, albums: albums, store: rowStore, idx: idx, song: song,
        disableActiveRemove: true
      ) { destination in
        isPresented = false
        onNavigate?(destination)
      }
      .environmentObject(downloads)
    }
  }
}
