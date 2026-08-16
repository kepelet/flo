import SwiftUI

struct ScrobbleQueueView: View {
  @ObservedObject private var queue = ScrobbleQueueManager.shared
  @Environment(\.dismiss) private var dismiss

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
      ForEach(queue.scrobbles, id: \.objectID) { entry in
        ScrobbleQueueRow(entry: entry, nextRetryAt: queue.nextRetryAt)
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
        }
        .disabled(queue.pendingCount == 0 || queue.isFlushing)
      } footer: {
        Text(
          "Waiting and failed scrobbles are retried automatically every few minutes while the server is unreachable. Use Retry now to submit immediately."
        )
      }
    }
  }
}

private struct ScrobbleQueueRow: View {
  @ObservedObject var entry: ScrobbleEntity
  let nextRetryAt: Date?

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

      if entry.status != ScrobbleQueueStatus.sent {
        if let nextRetryAt = nextRetryAt {
          (Text("Next retry ") + Text(nextRetryAt, style: .relative))
            .font(.caption)
            .foregroundColor(.gray)
        } else {
          Text("Waiting for the server to be reachable")
            .font(.caption)
            .foregroundColor(.gray)
        }
      }
    }
    .padding(.vertical, 2)
  }
}
