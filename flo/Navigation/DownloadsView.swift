//
//  DownloadsView.swift
//  flo
//
//  Created by rizaldy on 08/06/24.
//

import SwiftUI

struct DownloadsView: View {
  @ObservedObject var viewModel: AlbumViewModel

  let columns = [
    GridItem(.flexible()),
    GridItem(.flexible()),
  ]

  var body: some View {
    NavigationView {
      ScrollView {
        if viewModel.downloadedAlbums.isEmpty {
          VStack(alignment: .leading) {
            Image("Downloads").resizable().aspectRatio(contentMode: .fit).frame(width: 300)
              .padding()
              .padding(.bottom, 10)
            Group {
              Text("Going off the grid?")
                .customFont(.title1)
                .fontWeight(.bold)
                .multilineTextAlignment(.leading)
                .padding(.bottom, 10)
              Text(
                "Bring your music anywhere, even when you're offline. Your downloaded music will be here."
              )
              .customFont(.subheadline)

            }.padding(.horizontal, 20).foregroundColor(.accent)
          }
        }

        LazyVGrid(columns: columns, spacing: 20) {
          ForEach(viewModel.downloadedAlbums) { album in
            NavigationLink(
              destination:
                AlbumView(viewModel: viewModel, isDownloadScreen: true).onAppear {
                  viewModel.setActiveAlbum(album: album)
                }
            ) {
              AlbumsView(viewModel: viewModel, album: album, isDownloadScreen: true)
            }
          }
        }.padding(.top, 10).padding(.bottom, 100).navigationTitle("Downloads")
      }
    }
  }
}

struct DownloadsView_Previews: PreviewProvider {
  @StateObject static var viewModel: AlbumViewModel = AlbumViewModel()

  static var previews: some View {
    DownloadsView(viewModel: viewModel)
  }
}
