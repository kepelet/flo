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
      }.padding(.vertical)
        .sheet(isPresented: shouldShowLoginSheet()) {
          ScrollView {
            Login(viewModel: viewModel, showLoginSheet: $showLoginSheet)
          }.background(Color(red: 43 / 255, green: 42 / 255, blue: 94 / 255))
        }
        .padding()

      VStack(alignment: .leading) {
        Image("Home").resizable().aspectRatio(contentMode: .fit).frame(
          maxWidth: .infinity, maxHeight: 300
        ).padding()

        Group {
          if viewModel.isLoggedIn {
            Text("Have a nice day, \(viewModel.user?.name ?? "undefined")!")
              .customFont(.title1)
              .fontWeight(.bold)
              .multilineTextAlignment(.leading)

            Text(
              "Navidrome Music Server \(scanStatusViewModel.scanStatus?.serverVersion ?? "undefined")"
            )
            .customFont(.subheadline)
          } else {
            Text("You're not logged in")
              .customFont(.title1)
              .fontWeight(.bold)
              .multilineTextAlignment(.leading)

            Text("Login to start streaming your music by tapping the icon above")
          }

        }.padding(5)
      }.foregroundColor(.accent).padding()

      Spacer()

    }.onAppear {
      if viewModel.isLoggedIn {
        self.scanStatusViewModel.checkScanStatus()
      }
    }.onDisappear {
      if viewModel.isLoggedIn {
        self.scanStatusViewModel.checkScanStatus()
      }
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
