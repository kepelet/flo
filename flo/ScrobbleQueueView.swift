import SwiftUI

struct ScrobbleQueueView: View {
  @ObservedObject private var queue = ScrobbleQueueManager.shared
  @Environment(\.dismiss) private var dismiss
  @State private var showClearAllConfirmation = false

  var body: some View {
    NavigationStack {
      Group {
        if queue.scrobbles.isEmpty {
          emptyState
        } else {
          scrobbleList
        }
      }
      .navigationTitle("Offline Scrobbles")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button("Done") {
            dismiss()
          }
        }

        ToolbarItem(placement: .navigationBarTrailing) {
          if queue.sentCount > 0 {
            Button("Clear Sent") {
              queue.clearSent()
            }
          }
        }
      }
    }
  }

  private var emptyState: some View {
    VStack(spacing: 10) {
      Text("No offline scrobbles").font(.headline)

      Text(
        "Plays tracked while the server is offline will appear here and be submitted automatically once it is reachable again."
      )
      .font(.caption)
      .foregroundColor(.gray)
      .multilineTextAlignment(.center)
      .padding(.horizontal, 24)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private var scrobbleList: some View {
    List {
      if queue.pendingCount > 0 {
        Section {
          if let nextRetryAt = queue.nextRetryAt {
            Label {
              (Text("Next retry ") + Text(nextRetryAt, style: .relative))
                .font(.subheadline)
            } icon: {
              Image(systemName: "clock.arrow.circlepath")
            }
            .foregroundColor(.secondary)
          } else {
            Label {
              Text("Waiting for the server to be reachable").font(.subheadline)
            } icon: {
              Image(systemName: "wifi.exclamationmark")
            }
            .foregroundColor(.secondary)
          }
        }
      }

      ForEach(queue.scrobbles, id: \.objectID) { entry in
        ScrobbleQueueRow(entry: entry)
          .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if entry.status == ScrobbleQueueStatus.failed {
              Button {
                queue.retry(entry)
              } label: {
                Label("Retry", systemImage: "arrow.clockwise")
              }
              .tint(.blue)
            }

            Button(role: .destructive) {
              queue.remove(entry)
            } label: {
              Label("Delete", systemImage: "trash")
            }
          }
      }

      Section {
        Button(action: {
          queue.flush()
        }) {
          HStack {
            Text("Retry now")

            if queue.isFlushing {
              Spacer()
              ProgressView().controlSize(.small)
            }
          }
          .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .disabled(queue.pendingCount == 0 || queue.isFlushing)

        Button(
          role: .destructive,
          action: {
            showClearAllConfirmation = true
          }
        ) {
          HStack {
            Text("Clear all")

            Spacer()
          }
          .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .tint(.red)
      } footer: {
        Text(
          "Waiting and failed scrobbles are retried automatically every few minutes while the server is unreachable. Use Retry now to submit immediately."
        )
      }
    }
    .confirmationDialog(
      "Clear all scrobbles?", isPresented: $showClearAllConfirmation,
      titleVisibility: .visible
    ) {
      Button("Clear all", role: .destructive) {
        queue.clearAll()
      }

      Button("Cancel", role: .cancel) {}
    } message: {
      Text("This removes every pending, failed, and submitted scrobble from the queue.")
    }
  }
}

private struct ScrobbleQueueRow: View {
  @ObservedObject var entry: ScrobbleEntity

  private var status: (label: String, color: Color) {
    switch entry.status {
    case ScrobbleQueueStatus.sent:
      return ("Sent", .green)
    case ScrobbleQueueStatus.failed:
      return ("Failed", .red)
    default:
      return ("Waiting", .orange)
    }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      HStack {
        Text(entry.trackName ?? entry.songId ?? "Unknown track")
          .font(.headline)
          .lineLimit(1)

        Spacer()

        Text(status.label)
          .font(.caption.weight(.semibold))
          .foregroundColor(status.color)
      }

      if let artist = entry.artistName, !artist.isEmpty {
        Text(artist)
          .font(.subheadline)
          .foregroundColor(.secondary)
          .lineLimit(1)
      }

      HStack {
        if let album = entry.albumName, !album.isEmpty {
          Text(album)
        }

        Spacer()

        if let listenTime = entry.listenTime {
          Text(listenTime, format: .dateTime.month(.abbreviated).day().hour().minute())
        }
      }
      .font(.caption)
      .foregroundColor(.gray)

      if entry.status == ScrobbleQueueStatus.failed {
        Text(entry.errorReason ?? "Unknown error")
          .font(.caption)
          .foregroundColor(.red)
          .lineLimit(2)
      }
    }
    .padding(.vertical, 2)
  }
}
