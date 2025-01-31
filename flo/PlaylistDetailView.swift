//
//  PlaylistDetailView.swift
//  flo
//
//  Created by rizaldy on 16/11/24.
//

import SwiftUI

struct PlaylistDetailView: View {
  @EnvironmentObject private var viewModel: AlbumViewModel
  @EnvironmentObject private var playerViewModel: PlayerViewModel
  @EnvironmentObject private var downloadViewModel: DownloadViewModel

  @State private var showDownloadSheet: Bool = false
  @State private var showDeleteAlbumAlert: Bool = false

  var body: some View {
    ScrollView {
      VStack {
        if let image = UIImage(named: "placeholder") {
          Image(uiImage: image)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 300, height: 300)
            .clipShape(
              RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
            .shadow(radius: 5)
            .padding(.top, 10)
        }

        Text(viewModel.playlist.name)
          .customFont(.title)
          .fontWeight(.bold)
          .multilineTextAlignment(.center)
          .padding(.bottom, 5)

        Text(viewModel.playlist.comment)
          .customFont(.body)
          .multilineTextAlignment(.center)
          .padding(.bottom, 10)

        Text(
          "by \(viewModel.playlist.ownerName) (\(viewModel.playlist.isPublic ? "public" : "private"))"
        )
        .customFont(.caption1)
        .multilineTextAlignment(.center)
        .padding(.bottom, 10)

        HStack(spacing: 20) {
          Button(action: {
            playerViewModel.playItem(
              item: viewModel.playlist,
              isFromLocal: false)

          }) {
            Text("Play")
              .foregroundColor(.white)
              .customFont(.headline)
              .padding(.vertical, 10)
              .padding(.horizontal, 30)
              .background(Color("PlayerColor"))
              .cornerRadius(5)
          }.disabled(viewModel.playlist.songs.isEmpty)

          Button(action: {
            playerViewModel.shuffleItem(
              item: viewModel.playlist,
              isFromLocal: false)
          }) {
            Text("Shuffle")
              .foregroundColor(.white)
              .customFont(.headline)
              .padding(.vertical, 10)
              .padding(.horizontal, 30)
              .background(Color("PlayerColor"))
              .cornerRadius(5)
          }.disabled(viewModel.playlist.songs.isEmpty)
        }
        .padding(.bottom, 20)

        ForEach(Array(viewModel.playlist.songs.enumerated()), id: \.element) { idx, song in
          VStack {
            HStack(alignment: .top) {
              Text(idx.description)
                .customFont(.caption1)
                .foregroundColor(.gray)
                .padding(.trailing, 5)

              VStack(alignment: .leading) {
                Text(song.title)
                  .fontWeight(.medium)

                Text(song.artist).customFont(.caption1).offset(y: 5)

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
              idx: idx, item: viewModel.playlist, isFromLocal: false)
          }
          .contextMenu {
            VStack {
              if !song.fileUrl.isEmpty {
                Button(role: .destructive) {
                  viewModel.removeDownloadSong(
                    album: viewModel.playlist, songId: song.id, isFromPlaylist: true)
                  viewModel.setActivePlaylist(playlist: viewModel.playlist)
                } label: {
                  HStack {
                    Text("Remove Download")
                    Image(systemName: "arrow.down.circle")
                  }
                }
              } else {
                Button {
                  let playlist = Album.init(from: viewModel.playlist)

                  viewModel.downloadPlaylist(viewModel.playlist, targetIdx: idx)
                  downloadViewModel.addIndividualItem(
                    album: playlist, song: viewModel.playlist.songs[idx], isFromPlaylist: true)
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
      .toolbar {
        DownloadButton(
          isDownloading: downloadViewModel.isDownloading(viewModel.playlist.name),
          isDownloaded: downloadViewModel.isDownloading(viewModel.playlist.name)
            ? downloadViewModel.isDownloaded(viewModel.playlist.name) : viewModel.isDownloaded,
          progress: downloadViewModel.getDownloadedTrackProgress(albumName: viewModel.playlist.name)
            / 100
        ) {
          if viewModel.isDownloaded {
            showDeleteAlbumAlert.toggle()
          } else {
            if downloadViewModel.isDownloading(viewModel.playlist.name) {
              downloadViewModel.cancelCurrentAlbumDownload(albumName: viewModel.playlist.name)
            } else {
              let playlist = Album.init(from: viewModel.playlist)

              viewModel.downloadPlaylist(viewModel.playlist)
              downloadViewModel.addItem(playlist, isFromPlaylist: true)
            }
          }
        }

        if downloadViewModel.hasDownloadQueue() {
          Button(action: {
            showDownloadSheet.toggle()
          }) {
            Label("", systemImage: "icloud.and.arrow.down")
          }
        }
      }
      .alert("'\(viewModel.playlist.name)' has been downloaded", isPresented: $showDeleteAlbumAlert)
      {
        let playlist = Album.init(from: viewModel.playlist)

        Button("Cancel", role: .cancel) {
          showDeleteAlbumAlert.toggle()
        }
        Button("Redownload Playlist") {
          viewModel.downloadPlaylist(viewModel.playlist)
          downloadViewModel.addItem(playlist, isFromPlaylist: true)
        }
        Button("Redownload Playlist (force)", role: .destructive) {
          viewModel.downloadPlaylist(viewModel.playlist)
          downloadViewModel.addItem(playlist, forceAll: true, isFromPlaylist: true)
        }
        Button("Remove Download", role: .destructive) {
          viewModel.removeDownloadedPlaylist(playlist: viewModel.playlist)
          downloadViewModel.clearCurrentAlbumDownload(albumName: viewModel.playlist.name)
        }
      }
      .sheet(isPresented: $showDownloadSheet) {
        DownloadQueueView().environmentObject(downloadViewModel)
          .onDisappear {
            viewModel.setActivePlaylist(playlist: viewModel.playlist)
          }
      }
      .onReceive(downloadViewModel.$downloadWatcher) { newValue in
        if newValue {
          viewModel.setActivePlaylist(playlist: viewModel.playlist)
          downloadViewModel.downloadWatcher = false  // uh anti pattern
        }
      }
      .padding(.bottom, 100)
    }
  }
}
