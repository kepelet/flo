//
//  WatchRadiosView.swift
//  flo
//
//  Created by Codex on 17/02/26.
//

#if os(watchOS)
import SwiftUI

struct WatchRadiosView: View {
  @ObservedObject var libraryViewModel: WatchLibraryViewModel
  @ObservedObject var playerViewModel: WatchPlayerViewModel

  var body: some View {
    List {
      if libraryViewModel.isLoading {
        ProgressView()
      }

      if let errorMessage = libraryViewModel.errorMessage {
        Text(errorMessage)
          .foregroundColor(.red)
      }

      ForEach(libraryViewModel.radios) { radio in
        Button {
          playerViewModel.playRadio(radio)
        } label: {
          VStack(alignment: .leading, spacing: 2) {
            Text(radio.name)
              .font(.body)
              .lineLimit(1)
            Text(displayHost(radio.streamUrl))
              .font(.caption)
              .foregroundColor(.secondary)
              .lineLimit(1)
          }
        }
      }
    }
    .navigationTitle("Radios")
    .onAppear {
      if libraryViewModel.radios.isEmpty {
        libraryViewModel.loadRadios()
      }
    }
  }

  private func displayHost(_ urlString: String) -> String {
    guard let url = URL(string: urlString), let host = url.host, !host.isEmpty else {
      return urlString
    }

    return host
  }
}
#endif
