//
//  DownloadQueueView.swift
//  flo
//
//  Created by rizaldy on 12/01/25.
//

import SwiftUI

struct DownloadQueueView: View {
  @EnvironmentObject var viewModel: DownloadViewModel

  var range: ClosedRange<Double> = 0...100

  private func iconName(for status: DownloadStatus) -> String {
    switch status {
    case .completed:
      return "checkmark.circle.fill"
    case .failed, .cancelled:
      return "arrow.clockwise.circle.fill"
    case .downloading:
      return "stop.circle.fill"
    default:
      return "xmark.circle.fill"
    }
  }

  private func iconColor(for status: DownloadStatus) -> Color {
    return status == .failed ? .red : .accent
  }

  var body: some View {
    ScrollView {
      Text("Download Queue")
        .customFont(.headline)
        .padding(.horizontal)
        .padding(.top, 10)
        .padding(.bottom, 20)

      Divider()

      LazyVStack {
        ForEach(viewModel.downloadItems, id: \.id) { item in
          VStack(alignment: .center) {
            HStack {
              Text(item.title)
                .customFont(.subheadline)
                .multilineTextAlignment(.leading)
                .lineLimit(2)
                .padding(.top, 5)
                .padding(.horizontal)

              Spacer()

              Text("\(Int64(item.progress).description)%")
                .customFont(.caption1)

              Button(action: {
                if item.status == .cancelled || item.status == .failed {
                  viewModel.retryDownload(item.id)
                } else if item.status == .downloading {
                  viewModel.cancelDownload(item.id)
                } else {
                  viewModel.removeFromQueue(item.id)
                }
              }) {
                Label("", systemImage: iconName(for: item.status))
                  .foregroundColor(iconColor(for: item.status))
                  .customFont(.headline)
              }
            }

            if item.status == DownloadStatus.downloading {
              GeometryReader { geometry in
                ZStack(alignment: .leading) {
                  Rectangle()
                    .foregroundColor(Color.gray.opacity(0.3))
                    .frame(height: 3)
                    .cornerRadius(10)

                  Rectangle()
                    .foregroundColor(Color("PlayerColor"))
                    .frame(
                      width: CGFloat(
                        (item.progress - range.lowerBound) / (range.upperBound - range.lowerBound))
                        * geometry.size.width, height: 3
                    )
                    .cornerRadius(10)
                    .clipped()
                }.frame(height: 3)
              }.frame(height: 3).padding(.horizontal).padding(.bottom, 5)
            }
          }
          .frame(maxWidth: .infinity, alignment: .leading)

          Divider()
        }
      }

      Spacer()

      if viewModel.hasDownloadQueue() {
        Button(action: {
          viewModel.retryAllFailedQueue()
        }) {
          Text("Retry all Failed Queue")
            .foregroundColor(.white)
            .customFont(.headline)
            .padding(.vertical, 10)
            .padding(.horizontal, 30)
            .frame(maxWidth: .infinity)
            .background(Color("PlayerColor"))
            .cornerRadius(5)
        }
        .padding(.top, 10)
        .padding(.horizontal)

        Button(action: {
          viewModel.clearCompletedQueue()
        }) {
          Text("Clear Downloaded/Canceled Queue")
            .customFont(.headline)
            .padding(.vertical, 10)
            .padding(.horizontal, 30)
            .frame(maxWidth: .infinity)
            .cornerRadius(5)
        }
        .padding(.top, 10)
        .padding(.horizontal)
      }
    }.padding(.vertical)
  }
}
