//
//  AlbumView.swift
//  flo
//
//  Created by rizaldy on 08/06/24.
//

import SwiftUI

struct SongView: View {
  var viewModel: AlbumViewModel
  var playerViewModel: PlayerViewModel

  var albumName: String
  var albumArt: String
  var songs: [Song] = []

  var body: some View {
    ForEach(songs, id: \.self) { song in
      VStack {
        HStack(alignment: .top) {
          Text("\(song.trackNumber.description)")
            .customFont(.caption1)
            .foregroundColor(.gray)
            .padding(.trailing, 5)

          Text(song.title)
            .fontWeight(.medium)

          Spacer()
          Text(timeString(for: song.duration)).customFont(.caption1)

        }
      }
      .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
      .listRowSeparator(.hidden)
      .contentShape(Rectangle())
      .onTapGesture {
        let selectedSong = NowPlaying(
          artistName: song.artist,
          songName: song.title,
          albumName: albumName,
          albumCover: albumArt,
          streamUrl: viewModel.getStreamUrl(id: song.id),
          bitRate: song.bitRate,
          suffix: song.suffix
        )
        playerViewModel.setNowPlaying(data: selectedSong)
      }
    }
    .environment(\.defaultMinListRowHeight, 60)
    .listStyle(PlainListStyle()).padding().customFont(.body)
  }
}

struct AlbumView: View {
  @ObservedObject var viewModel: AlbumViewModel

  var album: Album
  var albumArt: String

  @EnvironmentObject var playerViewModel: PlayerViewModel

  var body: some View {
    ScrollView {
      AsyncImage(url: URL(string: albumArt)) { phase in
        switch phase {
        case .empty:
          ProgressView().frame(width: 200, height: 200)
        case .success(let image):
          image
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 200, height: 200)
            .clipShape(
              RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
            .shadow(radius: 5)

        case .failure:
          Color("PlayerColor").frame(width: 150, height: 150)
            .cornerRadius(5)

        @unknown default:
          EmptyView().frame(width: 150, height: 150)
        }
      }.padding(.bottom, 10)

      VStack {
        Text(album.name)
          .customFont(.title)
          .fontWeight(.bold)
          .multilineTextAlignment(.center)
          .padding(.bottom, 5)

        Text(album.artist)
          .customFont(.title3)
          .multilineTextAlignment(.center)
          .padding(.bottom, 10)

        Text(
          "\(album.genre.isEmpty ? "Unknown genre" : album.genre) • \(album.minYear.description)"
        )
        .customFont(.subheadline)
        .fontWeight(.medium)

        HStack(spacing: 20) {
          Button(action: {
            playerViewModel.playByAlbum()
          }) {
            Text("Play")
              .foregroundColor(.white)
              .customFont(.headline)
              .padding(.vertical, 10)
              .padding(.horizontal, 30)
              .background(Color("PlayerColor"))
              .cornerRadius(5)
          }.disabled(true)
          Button(action: {
            playerViewModel.shuffleByAlbum()
          }) {
            Text("Shuffle")
              .foregroundColor(.white)
              .customFont(.headline)
              .padding(.vertical, 10)
              .padding(.horizontal, 30)
              .background(Color("PlayerColor"))
              .cornerRadius(5)
          }.disabled(true)
        }.padding(10)
      }.padding(10)

      HStack(spacing: 40) {
        Button(action: {}) {
          VStack(spacing: 8) {
            Image(systemName: "info.circle")
              .font(.system(size: 24))
            Text("Album Info")
              .font(.caption)
          }
        }.disabled(true)

        Button(action: {}) {
          VStack(spacing: 8) {
            Image(systemName: "arrow.down.circle")
              .font(.system(size: 24))
            Text("Download")
              .font(.caption)
          }
        }.disabled(true)
        Button(action: {}) {
          VStack(spacing: 8) {
            Image(systemName: "square.and.arrow.up")
              .font(.system(size: 24))
            Text("Share")
              .font(.caption)
          }
        }.disabled(true)
      }

      if viewModel.isLoading {
        ProgressView()
      }

      // FIXME: I think the songs props is fishy
      SongView(
        viewModel: viewModel, playerViewModel: playerViewModel, albumName: album.name,
        albumArt: albumArt,
        songs: album.songs ?? viewModel.album.songs ?? [])

    }.onAppear {
      if album.id != "" {
        viewModel.fetchSongs(id: album.id)
      }
    }.padding(.bottom, 100)
  }
}

struct AlbumViewPreview_Previews: PreviewProvider {
  @StateObject static var viewModel: AlbumViewModel = AlbumViewModel()

  static var songs: [Song] = [
    Song(
      id: "0", title: "Song 1", artist: "Artist Name", trackNumber: 1, discNumber: 0, bitRate: 0,
      suffix: "mp4a", duration: 200),
    Song(
      id: "1", title: "Song 2", artist: "Artist Name", trackNumber: 2, discNumber: 0, bitRate: 0,
      suffix: "mp4a", duration: 200),
    Song(
      id: "2", title: "Song 3", artist: "Artist Name", trackNumber: 3, discNumber: 0, bitRate: 0,
      suffix: "mp4a", duration: 200),
    Song(
      id: "3", title: "Song 4", artist: "Artist Name", trackNumber: 4, discNumber: 0, bitRate: 0,
      suffix: "mp4a", duration: 200),
    Song(
      id: "4", title: "Song 6", artist: "Artist Name", trackNumber: 5, discNumber: 0, bitRate: 0,
      suffix: "mp4a", duration: 200),
    Song(
      id: "5", title: "Song 6", artist: "Artist Name", trackNumber: 6, discNumber: 0, bitRate: 0,
      suffix: "mp4a", duration: 200),
    Song(
      id: "6", title: "Song 7", artist: "Artist Name", trackNumber: 7, discNumber: 0, bitRate: 0,
      suffix: "mp4a", duration: 200),
    Song(
      id: "7", title: "Song 8", artist: "Artist Name", trackNumber: 8, discNumber: 0, bitRate: 0,
      suffix: "mp4a", duration: 200),
  ]

  static var album: Album = Album(
    name: "Album name", artist: "Artist name", songs: songs)

  static var previews: some View {
    AlbumView(viewModel: viewModel, album: album, albumArt: "").environmentObject(
      PlayerViewModel())
  }
}
