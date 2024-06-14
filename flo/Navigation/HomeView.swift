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
        Text("Home").customFont(.title1).fontWeight(.bold)
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

      }
      .sheet(isPresented: shouldShowLoginSheet()) {
        Login(viewModel: viewModel, showLoginSheet: $showLoginSheet)
      }
      .padding()

      VStack(alignment: .leading) {
        Image("Home").resizable().aspectRatio(contentMode: .fit).frame(width: 300).padding()

        Group {
          Text("Have a nice day, \(viewModel.user?.name ?? "sigma")!")
            .customFont(.title1)
            .fontWeight(.bold)
            .multilineTextAlignment(.leading)
          if viewModel.isLoggedIn {
            Text(
              "Navidrome Music Server \(scanStatusViewModel.scanStatus?.serverVersion ?? "undefined")"
            )
            .customFont(.subheadline)
          } else {
            Text("You're not logged in by the way. Tap the user icon above, I guess?")
          }

        }.padding(5)
      }.foregroundColor(.accent).padding()

      Spacer()

    }.onAppear {
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
