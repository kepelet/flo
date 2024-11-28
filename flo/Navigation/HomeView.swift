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

  @EnvironmentObject var scanStatusViewModel: ScanStatusViewModel

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

  var body: some View {
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
          Image(systemName: "person.crop.circle.fill")
            .font(.largeTitle)
        }
      }.padding(.top)
        .sheet(isPresented: shouldShowLoginSheet()) {
          Login(viewModel: viewModel, showLoginSheet: $showLoginSheet)
            .onDisappear {
              if viewModel.isLoggedIn {
                self.scanStatusViewModel.checkScanStatus()
              }
            }
        }
        .padding()

      ScrollView {
        if !viewModel.isLoggedIn {
          VStack {
            Text("Login to start streaming your music by tapping the icon above")
              .customFont(.body)
              .multilineTextAlignment(.center)
          }
          .padding()
          .overlay(
            RoundedRectangle(cornerRadius: 8).stroke(Color("PlayerColor"), lineWidth: 0.8)
          )
          .padding(.top, 10)
          .padding(.bottom)
        }

        VStack(alignment: .leading, spacing: 16) {
          Text("Listening Activity (all time)").customFont(.title2).fontWeight(.bold)
            .multilineTextAlignment(.leading)

          HStack(alignment: .top, spacing: 16) {
            StatCard(
              title: "Total Listens",
              value: scanStatusViewModel.totalPlay.description,
              icon: "headphones",
              color: .purple
            )

            StatCard(
              title: "Top Artist",
              value: scanStatusViewModel.stats?.topArtist ?? "N/A",
              icon: "music.mic",
              color: .blue,
              showArrow: true
            )
          }

          HStack(alignment: .top, spacing: 16) {
            StatCard(
              title: "Top Album",
              value: scanStatusViewModel.stats?.topAlbum ?? "N/A",
              subtitle: scanStatusViewModel.stats?.topAlbumArtist ?? "N/A",
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
        .padding(.bottom, 100)
        .padding(.horizontal)
      }
    }
    .onAppear {
      self.scanStatusViewModel.getListeningHistory()
    }
  }
}

struct HomeViewPreviews_Previews: PreviewProvider {
  @StateObject static var viewModel: AuthViewModel = AuthViewModel()
  @StateObject static var scanStatusViewModel: ScanStatusViewModel = ScanStatusViewModel()

  static var previews: some View {
    HomeView(viewModel: viewModel).environmentObject(scanStatusViewModel)
  }
}
