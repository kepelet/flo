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
                self.floooViewModel.checkScanStatus()
              }
            }
        }
        .padding()

      ScrollView {
        VStack(alignment: .leading, spacing: 16) {
          if !viewModel.isLoggedIn {
            VStack {
              Text("Login to start streaming your music by tapping the icon above")
                .customFont(.body)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
            }
            .padding()
            .overlay(
              RoundedRectangle(cornerRadius: 8).stroke(Color("PlayerColor"), lineWidth: 0.8)
            )
            .padding(.top, 10)
            .padding(.bottom)
          }

          Text("Listening Activity (all time)").customFont(.title2).fontWeight(.bold)
            .multilineTextAlignment(.leading)

          HStack(alignment: .top, spacing: 16) {
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
        .padding(.bottom, 100)
        .padding(.horizontal)
      }
    }
    .onAppear {
      self.floooViewModel.getListeningHistory()
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
