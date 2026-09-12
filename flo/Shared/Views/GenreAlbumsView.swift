//
//  GenreAlbumsView.swift
//  flo
//
//  Created by flo.
//

import SwiftUI

struct GenreAlbumsView: View {
  let genre: Genre
  @EnvironmentObject var albumViewModel: AlbumViewModel
  @EnvironmentObject var downloadViewModel: DownloadViewModel
  private let playerViewModel = PlayerViewModel.shared
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  @State private var albums: [Album] = []
  @State private var isLoading = true

  private var columns: [GridItem] {
    if horizontalSizeClass == .regular { return Array(repeating: GridItem(.flexible(), spacing: 10), count: 4) }
    else { return Array(repeating: GridItem(.flexible(), spacing: 10), count: 2) }
  }

  var body: some View {
    Group {
      if isLoading {
        ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity).padding(.top, 40)
      } else if albums.isEmpty {
        Text("No albums for this genre").customFont(.subheadline).foregroundColor(.secondary).frame(maxWidth: .infinity, maxHeight: .infinity).padding(.top, 40)
      } else {
        ScrollView {
          LazyVGrid(columns: columns, spacing: 10) {
            ForEach(albums) { album in
              NavigationLink {
                AlbumView(viewModel: albumViewModel).environmentObject(downloadViewModel).onAppear { albumViewModel.setActiveAlbum(album: album) }
              } label: {
                AlbumsView(viewModel: albumViewModel, album: album)
              }.buttonStyle(.plain)
            }
          }
          .padding(.horizontal, 10)
          .padding(.top, 8)
          .playerBottomPadding(active: 90, inactive: 12)
        }
      }
    }
    .navigationTitle(genre.name)
    .navigationBarTitleDisplayMode(.large)
    .onAppear { load() }
  }

  private func load() {
    if ProcessInfo.processInfo.arguments.contains("-UITestMockGenres") {
      let base = genre.name
      albums = (1...6).map { i in Album(id: "mock-\(base)-\(i)", name: "\(base) Album \(i)", albumArtist: "\(base) Artist", artist: "\(base) Artist") }
      isLoading = false
      return
    }
    isLoading = true
    AlbumService.shared.getAlbumsByGenre(genre: genre.name) { result in
      DispatchQueue.main.async {
        isLoading = false
        switch result {
        case .success(let fetched): albums = fetched
        case .failure: albums = []
        }
      }
    }
  }
}
