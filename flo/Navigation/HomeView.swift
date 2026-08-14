//
//  HomeView.swift
//  flo
//
//  Created by rizaldy on 08/06/24.
//

import SwiftUI

struct HomeView: View {
  @ObservedObject var viewModel: AuthViewModel
  @State private var showLoginSheet: Bool = false

  @EnvironmentObject var floooViewModel: FloooViewModel
  @EnvironmentObject var albumViewModel: AlbumViewModel
  @EnvironmentObject var playerViewModel: PlayerViewModel
  @EnvironmentObject var downloadViewModel: DownloadViewModel

  private enum ConnectionState {
    case online
    case expired
    case freshInstall
  }

  private var connectionState: ConnectionState {
    if viewModel.isLoggedIn {
      return .online
    } else if hasConfiguredServer() {
      return .expired
    } else {
      return .freshInstall
    }
  }

  private var statusColor: Color {
    switch connectionState {
    case .online:
      return .green
    case .expired:
      return .orange
    case .freshInstall:
      return .red
    }
  }

  private func hasConfiguredServer() -> Bool {
    UserDefaults.standard.string(forKey: "serverURL") != nil
  }

  private func shouldShowLoginSheet() -> Binding<Bool> {
    Binding(
      get: {
        showLoginSheet && !viewModel.isLoggedIn
      },
      set: { newValue in
        showLoginSheet = newValue
      }
    )
  }

  private func homeContentWidth(for availableWidth: CGFloat) -> CGFloat {
    let horizontalPadding: CGFloat = 32
    let baseWidth = max(availableWidth - horizontalPadding, 0)

    if UIDevice.current.userInterfaceIdiom == .pad {
      return min(baseWidth, 700)
    }

    return baseWidth
  }

  private var mainContent: some View {
    GeometryReader { rootGeometry in
      let contentWidth = homeContentWidth(for: rootGeometry.size.width)
      let horizontalInset = max((rootGeometry.size.width - contentWidth) / 2, 16)

      VStack(spacing: 0) {
        ScrollView {
          VStack(alignment: .leading, spacing: 16) {
            HStack {
              Text("")
                .font(.system(size: 32))
                .foregroundColor(.primary)
                .fontWeight(.bold)
                .padding(.vertical)
              Spacer()
              Menu {
                Button(action: {
                  showLoginSheet = true
                }) {
                  if !viewModel.isLoggedIn {
                    Text("Login")
                  } else {
                    Text("Logged in as \(viewModel.user?.name ?? "")")
                  }
                }.disabled(viewModel.isLoggedIn)
                if viewModel.isLoggedIn {
                  Button(action: {
                    viewModel.logout()
                  }) {
                    Text("Logout")
                  }
                }
              } label: {
                ZStack {
                  Image(systemName: "person.crop.circle.fill")
                    .font(.largeTitle)
                    .foregroundColor(.accentColor)

                  Circle()
                    .fill(statusColor)
                    .frame(width: 10, height: 10)
                    .offset(x: 12, y: -12)
                }
              }
            }

            Text("Listening Activity (all time)").customFont(.title2).fontWeight(.bold)
              .multilineTextAlignment(.leading)

            let statCardSpacing: CGFloat = rootGeometry.size.width <= 390 ? 8 : 16

            HStack(alignment: .top, spacing: statCardSpacing) {
              StatCard(
                title: "Total Listens",
                value: floooViewModel.totalPlay.description,
                icon: "headphones",
                color: .purple
              )

              topArtistCard
            }

            HStack(alignment: .top, spacing: 16) {
              topAlbumCard
            }

            HStack(spacing: 16) {
              StatCard(
                title: "Experimental",
                value: "More data is cooking soon",
                icon: "chart.pie",
                color: .indigo,
                isWide: false,
                showArrow: false
              )
            }
            Text(
              "This stat is generated on-device (once every session) and no data is stored or shared with a third party — #selfhosting, baby!"
            )
            .frame(maxWidth: .infinity)
            .multilineTextAlignment(.center)
            .customFont(.caption1)
            .lineSpacing(2)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.horizontal, horizontalInset)
          .padding(.bottom, 100)
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
    .onAppear {
      self.floooViewModel.getListeningHistory()
      if viewModel.isLoggedIn {
        self.albumViewModel.getArtists()
        self.albumViewModel.fetchAlbums()
      }
    }
  }

  @ViewBuilder
  private var topArtistCard: some View {
    let artistName = floooViewModel.stats?.topArtist ?? "N/A"
    let canNavigate = viewModel.isLoggedIn && floooViewModel.stats?.hasNavigableTopArtist == true
    let artist =
      canNavigate
      ? albumViewModel.artistForNavigation(name: artistName)
      : nil

    if let artist {
      NavigationLink {
        ArtistDetailView(artist: artist)
          .environmentObject(albumViewModel)
          .environmentObject(playerViewModel)
          .environmentObject(downloadViewModel)
      } label: {
        StatCard(
          title: "Top Artist",
          value: artistName,
          icon: "music.mic",
          color: .blue,
          showArrow: true
        )
      }
      .buttonStyle(.plain)
    } else {
      StatCard(
        title: "Top Artist",
        value: artistName,
        icon: "music.mic",
        color: .blue
      )
    }
  }

  @ViewBuilder
  private var topAlbumCard: some View {
    let albumName = floooViewModel.stats?.topAlbum ?? "N/A"
    let albumArtist = floooViewModel.stats?.topAlbumArtist ?? "N/A"
    let canNavigate = viewModel.isLoggedIn && floooViewModel.stats?.hasNavigableTopAlbum == true
    let album =
      canNavigate
      ? albumViewModel.albumForNavigation(
        id: floooViewModel.stats?.topAlbumId ?? "",
        name: albumName,
        artist: albumArtist
      )
      : nil

    if let album {
      NavigationLink {
        AlbumView(viewModel: albumViewModel)
          .environmentObject(playerViewModel)
          .environmentObject(downloadViewModel)
          .onAppear {
            albumViewModel.setActiveAlbum(album: album)
          }
      } label: {
        StatCard(
          title: "Top Album",
          value: albumName,
          subtitle: albumArtist,
          icon: "record.circle",
          color: .pink,
          isWide: true,
          showArrow: true
        )
      }
      .buttonStyle(.plain)
    } else {
      StatCard(
        title: "Top Album",
        value: albumName,
        subtitle: albumArtist,
        icon: "record.circle",
        color: .pink,
        isWide: true
      )
    }
  }

  private var loginContent: some View {
    Login(viewModel: viewModel, showLoginSheet: $showLoginSheet)
      .onDisappear {
        if viewModel.isLoggedIn {
          self.floooViewModel.checkScanStatus()
        }
      }
  }

  var body: some View {
    NavigationStack {
      Group {
        if UIDevice.current.userInterfaceIdiom == .pad {
          AnyView(
            mainContent.fullScreenCover(isPresented: shouldShowLoginSheet()) {
              loginContent
            })
        } else {
          AnyView(
            mainContent.sheet(isPresented: shouldShowLoginSheet()) {
              loginContent
            })
        }
      }
    }
  }
}

struct HomeViewPreviews_Previews: PreviewProvider {
  @StateObject static var viewModel: AuthViewModel = AuthViewModel()
  @StateObject static var floooViewModel: FloooViewModel = FloooViewModel()
  @StateObject static var albumViewModel: AlbumViewModel = AlbumViewModel()
  @StateObject static var playerViewModel: PlayerViewModel = PlayerViewModel()
  @StateObject static var downloadViewModel: DownloadViewModel = DownloadViewModel()

  static var previews: some View {
    HomeView(viewModel: viewModel)
      .environmentObject(floooViewModel)
      .environmentObject(albumViewModel)
      .environmentObject(playerViewModel)
      .environmentObject(downloadViewModel)
  }
}
