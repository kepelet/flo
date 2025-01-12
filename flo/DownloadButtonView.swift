//
//  DownloadButtonView.swift
//  flo
//
//  Created by rizaldy on 12/01/25.
//

import SwiftUI

struct DownloadButton: View {
  var isDownloaded = false
  var progress: Double = 0

  let action: () async -> Void

  var body: some View {
    Button(action: {
      Task {
        // FIXME: remember me again why is this necessary?
        await action()
      }
    }) {
      ZStack {
        if progress >= 1.0 {
          Image(systemName: "checkmark.circle.fill")
            .transition(.opacity)
        } else {
          Circle()
            .stroke(lineWidth: 2)
            .foregroundColor(Color("PlayerColor").opacity(0.3))

          Circle()
            .trim(from: 0, to: progress)
            .stroke(Color("PlayerColor"), style: StrokeStyle(lineWidth: 2, lineCap: .round))
            .rotationEffect(.degrees(-90))

          Image(systemName: progress > 0.02 ? "stop.circle" : "arrow.down.circle")
        }
      }
      .frame(width: 24, height: 24)
      .animation(.easeInOut, value: isDownloaded)
    }
  }
}
