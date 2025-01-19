//
//  DownloadButtonView.swift
//  flo
//
//  Created by rizaldy on 12/01/25.
//

import SwiftUI

struct DownloadButton: View {
  var isDownloading = false
  var isDownloaded = false

  var progress: Double = 0

  let action: () async -> Void

  var body: some View {
    Button {
      Task {
        await action()
      }
    } label: {
      ZStack {
        if isDownloaded {
          Image(systemName: "checkmark.circle.fill").transition(.opacity)
        } else {
          Circle()
            .trim(from: 0, to: 1)
            .stroke(
              isDownloading ? Color.gray.opacity(0.2) : Color(.accent),
              style: StrokeStyle(lineWidth: 1.5)
            )
            .overlay(
              Circle()
                .trim(from: 0, to: progress)
                .stroke(Color(.accent), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                .rotationEffect(isDownloading ? .degrees(-90) : .zero)
            )

          Image(systemName: isDownloading ? "stop.fill" : "arrow.down")
            .resizable()
            .scaledToFit()
            .padding(4)
            .frame(width: 17, height: 17)
            .font(.system(size: 17, weight: .bold))
        }
      }
      .frame(width: 21, height: 21)
      .animation(.easeInOut, value: isDownloaded)
      .animation(.easeInOut, value: progress)
    }
  }
}
