//
//  QueueSheetView.swift
//  flo
//
//  Playing queue: fullscreen lazy list with Play Next / Play After /
//  Add to Queue entry points, remove, move-to-top, download, like,
//  go-to-album/artist and clear. Presented like the lyrics screen but on
//  the system background (white/black per theme). Reorder works anytime
//  via long-press drag; edit mode adds the grip + remove controls.
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
  @State private var isEditing = false
  @StateObject private var rowStore = QueueRowStore()
  @State private var draggingIdx: Int?
  @State private var dropTargetIdx: Int?
  @State private var dropEdge: Edge?

  var body: some View {
    VStack(spacing: 0) {
      header
        .padding(.horizontal)
        .padding(.top, topSafeInset + 8)
        .padding(.bottom, 8)
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
          .foregroundColor(.secondary)
          .customFont(.subheadline)
        Spacer()
      } else {
        ScrollView(.vertical, showsIndicators: false) {
          LazyVStack(spacing: 0) {
            ForEach(Array(player.queue.enumerated()), id: \.element.objectID) { idx, song in
              if isEditing {
                queueRow(idx: idx, song: song)
              } else {
                queueRow(idx: idx, song: song)
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
          }
          .padding(.horizontal, 4)
          .padding(.bottom, max(bottomSafeInset, 12) + 24)
        }
        .onDrop(
          of: [.text],
          delegate: QueueListDropDelegate(
            player: player, draggingIdx: $draggingIdx, dropTargetIdx: $dropTargetIdx,
            dropEdge: $dropEdge))
      }

      bottomBar
        .padding(.horizontal, 18)
        .padding(.top, 10)
        .padding(.bottom, max(bottomSafeInset, 12))
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color(.systemBackground).ignoresSafeArea())
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
        isEditing = false
        isPresented = false
      }
    }
  }

  // MARK: - Header

  private var header: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(alignment: .center, spacing: 12) {
        VStack(alignment: .leading, spacing: 2) {
          Text("Queue")
            .customFont(.title2)
            .fontWeight(.bold)

          Text(player.queue.isEmpty ? "Nothing queued" : "\(player.queue.count) songs")
            .foregroundColor(.secondary)
            .customFont(.subheadline)
        }

        Spacer()

        Button {
          isPresented = false
        } label: {
          Image(systemName: "chevron.down")
            .font(.title3.weight(.semibold))
            .foregroundColor(.primary)
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color.primary.opacity(0.08))
            .clipShape(Capsule())
        }
        .keyboardShortcut(.escape, modifiers: [])
      }

      HStack(alignment: .center, spacing: 10) {
        Text(
          player.queue.isEmpty
            ? ""
            : "From \(player.nowPlaying.contextName ?? player.nowPlaying.albumName ?? "")"
        )
        .foregroundColor(.secondary)
        .customFont(.subheadline)
        .lineLimit(1)

        Spacer()

        Button {
          if !player.queue.isEmpty {
            isEditing.toggle()
          }
        } label: {
          Image(systemName: isEditing ? "checkmark" : "pencil")
            .foregroundColor(Color.accentColor)
            .fontWeight(.bold)
            .padding(5)
            .background(
              isEditing ? Color.gray.opacity(0.2) : Color.clear
            )
            .cornerRadius(5)
        }
        .disabled(player.queue.isEmpty)

        Button {
          showClearConfirm = true
        } label: {
          Image(systemName: "trash")
            .foregroundColor(Color.accentColor)
            .fontWeight(.bold)
            .padding(5)
        }
        .disabled(player.queue.isEmpty)

        Button {
          player.shuffleCurrentQueue()
        } label: {
          Image(systemName: "shuffle")
            .foregroundColor(Color.accentColor)
            .fontWeight(.bold)
            .padding(5)
            .background(
              player.isShuffling ? Color.gray.opacity(0.2) : Color.clear
            )
            .cornerRadius(5)
        }

        Button {
          player.setPlaybackMode()
        } label: {
          Image(systemName: "repeat")
            .foregroundColor(Color.accentColor)
            .fontWeight(.bold)
            .overlay(
              Group {
                Text("1")
                  .foregroundColor(Color.accentColor)
                  .font(.caption)
                  .clipShape(Circle())
                  .offset(x: 10, y: -5)
                  .fontWeight(.bold)
              }.opacity(player.playbackMode == PlaybackMode.repeatOnce ? 1 : 0)
            )
            .padding(5)
            .background(
              player.playbackMode == PlaybackMode.defaultPlayback
                ? Color.clear : Color.gray.opacity(0.2)
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
      if isEditing {
        Image(systemName: "line.3.horizontal")
          .font(.callout)
          .foregroundColor(.secondary)
      }

      VStack(alignment: .leading, spacing: 2) {
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
          .foregroundColor(.secondary)
          .customFont(.caption1)
          .lineLimit(1)
      }
      .frame(maxWidth: .infinity, alignment: .leading)

      Text(timeString(for: song.duration))
        .foregroundColor(.secondary)
        .customFont(.caption1)

      if isEditing {
        Button {
          guard !isActive else { return }
          player.removeFromQueue(at: idx)
        } label: {
          Image(systemName: "minus.circle.fill")
            .font(.title3)
            .foregroundColor(isActive ? .gray.opacity(0.4) : .red)
        }
        .disabled(isActive)
        .buttonStyle(.plain)
      }
    }
    .padding(.vertical, 8)
    .padding(.horizontal, 12)
    .background(
      dropTargetIdx == idx
        ? Color.accentColor.opacity(0.25)
        : (isActive ? Color.gray.opacity(0.1) : Color.clear),
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
      guard !isEditing else { return }
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
  }

  // MARK: - Bottom bar (mirrors the lyrics screen)

  @ViewBuilder
  private var bottomBar: some View {
    let isLyricsDisabled =
      player.isLiveRadio || (player.lyrics.isEmpty && (player.lyricsError != nil))

    HStack(spacing: 0) {
      Button {
        isPresented = false
        if !player.isLyricsMode {
          player.toggleLyricsMode()
        }
      } label: {
        Image(systemName: player.isLyricsMode ? "quote.bubble.fill" : "quote.bubble")
          .font(.title2)
          .foregroundColor(isLyricsDisabled ? .secondary.opacity(0.5) : .primary)
      }
      .disabled(isLyricsDisabled)
      .frame(width: 44, height: 44)

      Spacer(minLength: 0)

      Button {
        player.toggleStar()
      } label: {
        Image(systemName: player.isStarred ? "heart.fill" : "heart")
          .font(.title2)
          .foregroundColor(player.isStarred ? .red : .primary)
      }
      .disabled(player.isLiveRadio)
      .opacity(player.isLiveRadio ? 0.4 : 1)
      .frame(width: 44, height: 44)

      Spacer(minLength: 0)

      AirPlayRoutePicker(tintColor: UIColor.label, activeTintColor: UIColor.label)
        .frame(width: 36, height: 36)
        .frame(width: 44, height: 44)
        .background {
          if player.externalOutputName != nil {
            AirPlayActiveCircle()
          }
        }

      Spacer(minLength: 0)

      Button {
        isPresented = false
      } label: {
        Image(systemName: "list.bullet")
          .font(.title2)
          .foregroundColor(.primary)
          .overlay(
            Group {
              Image(systemName: "repeat")
                .font(.caption)
                .foregroundColor(.primary)
                .overlay(
                  Group {
                    Text("1")
                      .foregroundColor(.primary)
                      .font(.system(size: 8))
                  }
                  .offset(x: 7, y: -4)
                  .opacity(player.playbackMode == PlaybackMode.repeatOnce ? 1 : 0)
                )
                .opacity(player.playbackMode == PlaybackMode.defaultPlayback ? 0 : 1)
            }
            .padding(5)
            .background(
              Color.primary.opacity(
                player.playbackMode == PlaybackMode.defaultPlayback ? 0 : 0.08)
            )
            .clipShape(Circle())
            .offset(x: 10, y: -10)
          )
      }
      .frame(width: 44, height: 44)
    }
    .frame(height: 44)
  }
}
