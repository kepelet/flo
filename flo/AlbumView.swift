//
//  AlbumView.swift
//  flo
//
//  Created by rizaldy on 08/06/24.
//

import SwiftUI

struct AlbumView: View {
  @EnvironmentObject var playerViewModel: PlayerViewModel
  @ObservedObject var viewModel: AlbumViewModel

  @State private var showAlbumInfo: Bool = false

  @State private var shareDescription: String = ""
  @State private var generatedShareURL: String = ""
  @State private var showShareAlert: Bool = false
  @State private var showShareURLAlert: Bool = false

  var isDownloadScreen: Bool = false

  var body: some View {
    ScrollView {
      AsyncImage(url: URL(string: viewModel.album.albumCover)) { phase in
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
          Color("PlayerColor").frame(width: 200, height: 200)
            .cornerRadius(5)

        @unknown default:
          EmptyView().frame(width: 200, height: 200)
        }
      }.padding(.bottom, 10)

      VStack {
        Text(viewModel.album.name)
          .customFont(.title)
          .fontWeight(.bold)
          .multilineTextAlignment(.center)
          .padding(.bottom, 5)

        Text(viewModel.album.artist)
          .customFont(.title3)
          .multilineTextAlignment(.center)
          .padding(.bottom, 10)

        Text(
          "\(viewModel.album.genre.isEmpty ? "Unknown genre" : viewModel.album.genre) • \(viewModel.album.minYear == 0 ? "Unknown release year" : viewModel.album.minYear.description)"
        )
        .customFont(.subheadline)
        .fontWeight(.medium)

        HStack(spacing: 20) {
          Button(action: {
            playerViewModel.playByAlbum(
              item: viewModel.album)
          }) {
            Text("Play")
              .foregroundColor(.white)
              .customFont(.headline)
              .padding(.vertical, 10)
              .padding(.horizontal, 30)
              .background(Color("PlayerColor"))
              .cornerRadius(5)
          }
          Button(action: {
            playerViewModel.shuffleByAlbum(
              item: viewModel.album)
          }) {
            Text("Shuffle")
              .foregroundColor(.white)
              .customFont(.headline)
              .padding(.vertical, 10)
              .padding(.horizontal, 30)
              .background(Color("PlayerColor"))
              .cornerRadius(5)
          }
        }.padding(10)
      }.padding(10)

      HStack(spacing: 40) {
        Button(action: {
          self.showAlbumInfo.toggle()
          viewModel.getAlbumInfo()
        }) {
          VStack(spacing: 8) {
            Image(systemName: "info.circle")
              .font(.system(size: 24))
            Text("Album Info")
              .font(.caption)
          }
        }.sheet(isPresented: $showAlbumInfo) {
          VStack {
            ScrollView {
              Spacer()

              AsyncImage(url: URL(string: viewModel.album.albumCover)) { phase in
                switch phase {
                case .empty:
                  ProgressView().frame(width: 300, height: 300)
                case .success(let image):
                  image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 300, height: 300)
                    .clipShape(
                      RoundedRectangle(cornerRadius: 10, style: .continuous)
                    )

                case .failure:
                  Color("PlayerColor").frame(width: 300, height: 300)
                    .cornerRadius(5)

                @unknown default:
                  EmptyView().frame(width: 300, height: 300)
                }
              }.padding()

              VStack {

                Text(viewModel.album.name)
                  .customFont(.title2)
                  .fontWeight(.bold)
                  .multilineTextAlignment(.center)
                  .padding(.bottom, 5)

                Text(viewModel.album.artist)
                  .customFont(.title3)
                  .multilineTextAlignment(.center)
                  .padding(.bottom, 10)

                Text(
                  "\(viewModel.album.genre.isEmpty ? "Unknown genre" : viewModel.album.genre) • \(viewModel.album.minYear == 0 ? "Unknown release year" : viewModel.album.minYear.description)"
                )
                .customFont(.subheadline)
                .fontWeight(.medium)
              }.padding(.bottom, 20)

              Spacer()

              Text(viewModel.album.info)
                .customFont(.subheadline)
                .multilineTextAlignment(.center)
                .lineSpacing(5)

              Spacer()
            }.padding()
            Spacer()
          }
        }

        Button(action: {
          viewModel.downloadAlbum()
        }) {
          VStack(spacing: 8) {
            Image(systemName: "arrow.down.circle")
              .font(.system(size: 24))
            Text("Download")
              .font(.caption)
          }
        }.disabled(viewModel.ifNotDownloadable(isDownloadScreen: isDownloadScreen))

        Button(action: {
          self.showShareAlert = true
        }) {
          VStack(spacing: 8) {
            Image(systemName: "square.and.arrow.up")
              .font(.system(size: 24))
            Text("Share")
              .font(.caption)
          }.alert(
            "Share album '\(viewModel.album.name)'",
            isPresented: $showShareAlert
          ) {
            Button("Cancel", role: .cancel) {
              self.shareDescription = ""
            }
            Button("Share") {
              self.viewModel.shareAlbum(description: self.shareDescription) { result in
                UIPasteboard.general.string = result

                self.generatedShareURL = result
                self.showShareAlert = false
                self.showShareURLAlert = true
              }
            }
            TextField("Description (i.e: for my wife)", text: $shareDescription)
          } message: {
            Text(
              "Share features with Download option is disabled, please update directly in Navidrome UI if needed"
            )
          }.alert(
            "Link copied to clipboard! (\(self.generatedShareURL))", isPresented: $showShareURLAlert
          ) {
            Button("OK", role: .cancel) {
              self.shareDescription = ""
              self.generatedShareURL = ""

              self.showShareURLAlert = false
            }
          }
        }.disabled(viewModel.ifNotSharable(isDownloadScreen: isDownloadScreen))
      }

      if viewModel.isLoading {
        ProgressView()
      }

      SongView(
        viewModel: viewModel, playerViewModel: playerViewModel)

    }.padding(.bottom, 100)
  }
}

struct AlbumViewPreview_Previews: PreviewProvider {
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

  @StateObject static var viewModel: AlbumViewModel = AlbumViewModel(album: album)

  static var previews: some View {
    AlbumView(viewModel: viewModel).environmentObject(
      PlayerViewModel())
  }
}
