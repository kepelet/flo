//
//  QueueSheetView.swift
//  flo
//
//  Playing queue: reorderable list with Play Next / Play After /
//  Add to Queue entry points, remove, move-to-top, download, like,
//  go-to-album/artist and clear.
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

struct QueueSheetView: View {
  @ObservedObject var player: PlayerViewModel
  @ObservedObject var albums: AlbumViewModel

  @EnvironmentObject var downloads: DownloadViewModel

  @Binding var isPresented: Bool

  var onNavigate: ((LibraryDestination) -> Void)?

  @State private var showClearConfirm = false
  @State private var isEditing = false
  @StateObject private var rowStore = QueueRowStore()
  @State private var draggingIdx: Int?
  @State private var dropTargetIdx: Int?
  @State private var dropEdge: Edge?

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      header
        .padding(.horizontal)
        .padding(.bottom, 5)

      if player.queue.isEmpty {
        Spacer()
        HStack {
          Spacer()
          Text("Queue is empty")
            .customFont(.subheadline)
            .foregroundColor(.secondary)
          Spacer()
        }
        Spacer()
      } else {
        List {
          ForEach(Array(player.queue.enumerated()), id: \.element.objectID) { idx, song in
            queueRow(idx: idx, song: song)
          }
        }
        .listStyle(.plain)
        .onDrop(
          of: [.text],
          delegate: QueueListDropDelegate(
            player: player, draggingIdx: $draggingIdx, dropTargetIdx: $dropTargetIdx,
            dropEdge: $dropEdge))
      }
    }
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
    VStack(alignment: .leading, spacing: 3) {
      HStack {
        Text("Playing Next").customFont(.headline)

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

      if player.queue.isEmpty {
        Text("").customFont(.subheadline)
      } else {
        Text(
          "From \(player.nowPlaying.contextName ?? player.nowPlaying.albumName ?? "")"
        ).customFont(.subheadline)
      }
    }
  }

  // MARK: - Rows

  @ViewBuilder
  private func queueRow(idx: Int, song: QueueEntity) -> some View {
    let isActive = player.activeQueueIdx == idx

    HStack(alignment: .center, spacing: 8) {
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
          .customFont(.caption1)
          .foregroundColor(.secondary)
          .lineLimit(1)
      }
      .frame(maxWidth: .infinity, alignment: .leading)

      Text(timeString(for: song.duration))
        .customFont(.caption1)
        .foregroundColor(.secondary)

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
    .padding(.horizontal)
    .padding(.vertical, 7)
    .modifier(
      CatalystQueueReorderModifier(
        idx: idx, player: player, isEditing: isEditing, draggingIdx: $draggingIdx,
        dropTargetIdx: $dropTargetIdx, dropEdge: $dropEdge))
    .overlay(alignment: dropEdge == .bottom ? .bottom : .top) {
      if dropTargetIdx == idx {
        RoundedRectangle(cornerRadius: 2)
          .fill(Color.accentColor)
          .frame(height: 4)
      }
    }
    .opacity(draggingIdx == idx ? 0.45 : 1)
    .contentShape(Rectangle())
    .listRowInsets(EdgeInsets())
    .listRowBackground(
      dropTargetIdx == idx
        ? Color.accentColor.opacity(0.25)
        : (isActive ? Color.gray.opacity(0.1) : Color(.systemBackground)))
    .onTapGesture {
      guard !isEditing else { return }
      player.playFromQueue(idx: idx)
    }
    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
      Button(role: .destructive) {
        player.removeFromQueue(at: idx)
      } label: {
        Label("Remove", systemImage: "trash")
      }
      .disabled(isActive || isEditing)
    }
    .swipeActions(edge: .leading, allowsFullSwipe: false) {
      Button {
        player.moveToTop(idx: idx)
      } label: {
        Label("Top", systemImage: "arrow.up.to.line")
      }
      .tint(.accentColor)
      .disabled(idx == 0 || isEditing)
    }
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

  // MARK: - Catalyst drag-and-drop reorder

  /// Drag source / drop target for queue reorder. Catalyst has no List
  /// edit-mode reorder handles, so rows reorder via native drag-and-drop
  /// there; on iOS drag only applies while editing so the reorder grip stays
  /// on the left and the remove control stays on the right.
  struct CatalystQueueReorderModifier: ViewModifier {
    let idx: Int
    let player: PlayerViewModel
    var isEditing = false
    @Binding var draggingIdx: Int?
    @Binding var dropTargetIdx: Int?
    @Binding var dropEdge: Edge?

    func body(content: Content) -> some View {
      #if targetEnvironment(macCatalyst)
        content
          .onDrag {
            draggingIdx = idx
            return NSItemProvider(object: String(idx) as NSString)
          }
          .onDrop(
            of: [.text],
            delegate: QueueReorderDropDelegate(
              player: player, targetIdx: idx, draggingIdx: $draggingIdx,
              dropTargetIdx: $dropTargetIdx, dropEdge: $dropEdge))
      #else
        if isEditing {
          content
            .onDrag {
              draggingIdx = idx
              return NSItemProvider(object: String(idx) as NSString)
            }
            .onDrop(
              of: [.text],
              delegate: QueueReorderDropDelegate(
                player: player, targetIdx: idx, draggingIdx: $draggingIdx,
                dropTargetIdx: $dropTargetIdx, dropEdge: $dropEdge))
        } else {
          content
        }
      #endif
    }
  }
}
