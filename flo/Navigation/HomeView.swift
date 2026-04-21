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

  private var mainContent: some View {
    VStack {
      HStack {
        Text("Home").font(.system(size: 32)).foregroundColor(.primary).fontWeight(.bold).padding(
          .vertical)
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
      }.padding(.top)
        .padding()

      GeometryReader { geometry in
        ScrollView {
          VStack(alignment: .leading, spacing: 16) {
            Text("Listening Activity (all time)").customFont(.title2).fontWeight(.bold)
              .multilineTextAlignment(.leading)

            let statCardSpacing: CGFloat = geometry.size.width <= 390 ? 8 : 16

            HStack(alignment: .top, spacing: statCardSpacing) {
              StatCard(
                title: "Total Listens",
                value: floooViewModel.totalPlay.description,
                icon: "headphones",
                color: .purple
              )

              StatCard(
                title: "Top Artist",
                value: floooViewModel.stats?.topArtist ?? "N/A",
                icon: "music.mic",
                color: .blue,
                showArrow: true
              )
            }

            HStack(alignment: .top, spacing: 16) {
              StatCard(
                title: "Top Album",
                value: floooViewModel.stats?.topAlbum ?? "N/A",
                subtitle: floooViewModel.stats?.topAlbumArtist ?? "N/A",
                icon: "record.circle",
                color: .pink,
                isWide: true,
                showArrow: true
              )
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
          .frame(maxWidth: 700)
          .frame(maxWidth: .infinity)
          .padding(.bottom, 100)
          .padding(.horizontal)
        }
      }
    }
    .onAppear {
      self.floooViewModel.getListeningHistory()
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
    Group {
      if UIDevice.current.userInterfaceIdiom == .pad {
        AnyView(mainContent.fullScreenCover(isPresented: shouldShowLoginSheet()) {
          loginContent
        })
      } else {
        AnyView(mainContent.sheet(isPresented: shouldShowLoginSheet()) {
          loginContent
        })
      }
    }
  }
}

struct HomeViewPreviews_Previews: PreviewProvider {
  @StateObject static var viewModel: AuthViewModel = AuthViewModel()
  @StateObject static var floooViewModel: FloooViewModel = FloooViewModel()

  static var previews: some View {
    HomeView(viewModel: viewModel).environmentObject(floooViewModel)
  }
}
