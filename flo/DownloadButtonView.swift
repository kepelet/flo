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

  @State private var fakeProgress = 0.0

  var displayProgress: Double {
    if !isDownloading { return 0 }

    return progress > 0.02 ? progress : fakeProgress
  }

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
              isDownloading ? Color.gray.opacity(0.2) : Color("PlayerColor"),
              style: StrokeStyle(lineWidth: 1.5)
            )
            .overlay(
              Circle()
                .trim(from: 0, to: displayProgress)
                .stroke(Color("PlayerColor"), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
            )

          Image(systemName: isDownloading ? "stop.fill" : "arrow.down")
            .resizable()
            .scaledToFit()
            .padding(3.5)
            .frame(width: 17, height: 17)
        }
      }
      .frame(width: 21, height: 21)
      .animation(.easeInOut, value: isDownloaded)
      .animation(.easeInOut, value: progress)
      .onChange(of: isDownloading) { newValue in
        if newValue && progress <= 0.02 {
          withAnimation(.linear(duration: 0.5).repeatForever(autoreverses: false)) {
            fakeProgress = 1.0
          }
        } else {
          withAnimation(.easeInOut) {
            fakeProgress = 0
          }
        }
      }
    }
  }
}
