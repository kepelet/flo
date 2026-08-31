//
//  LibraryNavigation.swift
//  flo
//

import SwiftUI

enum AppTab: Hashable {
  case home
  case library
  case libraryAlbums
  case libraryArtists
  case likedSongs
  case playlists
  case songs
  case radios
  case downloads
  case preferences
  case debug
  case search
}

final class LibraryRouter: ObservableObject {
  @Published var selectedTab: AppTab = .home
  @Published var homePath = NavigationPath()
  @Published var libraryPath = NavigationPath()
  @Published var artistsPath = NavigationPath()
}

struct LibraryDestinationView: View {
  let destination: LibraryDestination

  @ObservedObject var albumViewModel: AlbumViewModel
  @ObservedObject var playerViewModel: PlayerViewModel
  @ObservedObject var downloadViewModel: DownloadViewModel

  var body: some View {
    switch destination {
    case .artist(let id, let name):
      if let artist = albumViewModel.artistForNavigation(id: id, name: name) {
        ArtistDetailView(artist: artist)
          .environmentObject(albumViewModel)
          .environmentObject(playerViewModel)
          .environmentObject(downloadViewModel)
      } else {
        Text("Artist unavailable")
          .foregroundColor(.secondary)
      }
    case .album(let id, let name, let artist):
      if let album = albumViewModel.albumForNavigation(id: id, name: name, artist: artist) {
        AlbumView(viewModel: albumViewModel)
          .environmentObject(playerViewModel)
          .environmentObject(downloadViewModel)
          .onAppear {
            albumViewModel.setActiveAlbum(album: album)
          }
      } else {
        Text("Album unavailable")
          .foregroundColor(.secondary)
      }
    }
  }
}
