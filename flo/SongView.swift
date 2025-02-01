//
//  SongView.swift
//  flo
//
//  Created by rizaldy on 26/06/24.
//

import SwiftUI

struct SongView: View {
  @Environment(\.dismiss) private var dismiss
  @EnvironmentObject var downloadViewModel: DownloadViewModel

  @ObservedObject var viewModel: AlbumViewModel
  var playerViewModel: PlayerViewModel
  var isDownloadScreen: Bool = false

  var body: some View {
    VStack {
      ForEach(Array(viewModel.album.songs.enumerated()), id: \.element) { idx, song in
        VStack {
          HStack(alignment: .top) {
            Text("\(song.trackNumber.description)")
              .customFont(.caption1)
              .foregroundColor(.gray)
              .padding(.trailing, 5)

            VStack(alignment: .leading) {
              Text(song.title)
                .fontWeight(.medium)

              if !isDownloadScreen && viewModel.album.albumArtist != viewModel.album.artist {
                Text(song.artist).customFont(.caption1).offset(y: 5)
              }

              Spacer()
            }

            Spacer()

            if !song.fileUrl.isEmpty {
              Image(systemName: "arrow.down.circle.fill")
                .font(.system(size: 14))
            }

            Text(timeString(for: song.duration)).customFont(.caption1)
          }
        }
        .padding()
        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
        .listRowSeparator(.hidden)
        .contentShape(Rectangle())
        .onTapGesture {
          playerViewModel.playBySong(
            idx: idx, item: viewModel.album, isFromLocal: viewModel.isDownloaded)
        }
        .contextMenu {
          VStack {
            if !song.fileUrl.isEmpty {
              Button(role: .destructive) {
                viewModel.removeDownloadSong(album: viewModel.album, songId: song.id)
                viewModel.setActiveAlbum(album: viewModel.album)
                if isDownloadScreen {
                  dismiss()
                  viewModel.fetchDownloadedAlbums()
                }
              } label: {
                HStack {
                  Text("Remove Download")
                  Image(systemName: "arrow.down.circle")
                }
              }
            } else {
              Button {
                viewModel.downloadAlbum(viewModel.album)
                downloadViewModel.addIndividualItem(
                  album: viewModel.album, song: viewModel.album.songs[idx])
              } label: {
                HStack {
                  Text("Download")
                  Image(systemName: "arrow.down.circle")
                }
              }
            }
          }
        }
      }
      .listStyle(PlainListStyle()).customFont(.body)
    }
  }
}

struct SongView_Previews: PreviewProvider {
  static let songs: [Song] = [
    Song(
      id: "0", title: "Song 1", albumId: "", artist: "Artist Name", trackNumber: 1, discNumber: 0,
      bitRate: 0,
      sampleRate: 44100,
      suffix: "mp4a", duration: 200, mediaFileId: "0"),
    Song(
      id: "1", title: "Song 2", albumId: "", artist: "Artist Name", trackNumber: 2, discNumber: 0,
      bitRate: 0,
      sampleRate: 44100,
      suffix: "mp4a", duration: 200, mediaFileId: "1"),
    Song(
      id: "2", title: "Song 3", albumId: "", artist: "Artist Name", trackNumber: 3, discNumber: 0,
      bitRate: 0,
      sampleRate: 44100,
      suffix: "mp4a", duration: 200, mediaFileId: "2"),
    Song(
      id: "3", title: "Song 4", albumId: "", artist: "Artist Name", trackNumber: 4, discNumber: 0,
      bitRate: 0,
      sampleRate: 44100,
      suffix: "mp4a", duration: 200, mediaFileId: "3"),
    Song(
      id: "4", title: "Song 5", albumId: "", artist: "Artist Name", trackNumber: 5, discNumber: 0,
      bitRate: 0,
      sampleRate: 44100,
      suffix: "mp4a", duration: 200, mediaFileId: "4"),
    Song(
      id: "5", title: "Song 6", albumId: "", artist: "Artist Name", trackNumber: 6, discNumber: 0,
      bitRate: 0,
      sampleRate: 44100,
      suffix: "mp4a", duration: 200, mediaFileId: "5"),
    Song(
      id: "6", title: "Song 7", albumId: "", artist: "Artist Name", trackNumber: 7, discNumber: 0,
      bitRate: 0,
      sampleRate: 44100,
      suffix: "mp4a", duration: 200, mediaFileId: "6"),
    Song(
      id: "7", title: "Song 8", albumId: "", artist: "Artist Name", trackNumber: 8, discNumber: 0,
      bitRate: 0,
      sampleRate: 44100,
      suffix: "mp4a", duration: 200, mediaFileId: "7"),
  ]

  static let album: Album = Album(
    name: "Album name", artist: "Artist name", songs: songs)

  @StateObject static var viewModel: AlbumViewModel = AlbumViewModel(album: album)
  @StateObject static var playerViewModel: PlayerViewModel = PlayerViewModel()

  static var previews: some View {
    SongView(viewModel: viewModel, playerViewModel: playerViewModel)
  }
}
