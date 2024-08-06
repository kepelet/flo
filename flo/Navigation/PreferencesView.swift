//
//  PreferencesView.swift
//  flo
//
//  Created by rizaldy on 08/06/24.
//

import SwiftUI

struct PreferencesView: View {
  @ObservedObject var authViewModel: AuthViewModel
  @State private var storeCredsInKeychain = false

  @State private var accentColor = Color(.accent)
  @State private var playerColor = Color(.player)
  @State private var customFontFamily = "Plus Jakarta Sans"

  @EnvironmentObject var scanStatusViewModel: ScanStatusViewModel

  let themeColors = ["Blue", "Green", "Red", "Ohio"]

  var body: some View {
    NavigationView {
      Form {
        Section(header: Text("Local Storage")) {
          HStack {
            Text("Downloaded Albums")
            Spacer()
            Text(scanStatusViewModel.downloadedAlbums.description)
          }

          HStack {
            Text("Downloaded Songs")
            Spacer()
            Text(scanStatusViewModel.downloadedSongs.description)
          }

          HStack {
            Text("Optimize local storage")
          }.onTapGesture {
            scanStatusViewModel.optimizeLocalStorage()
          }
        }

        if authViewModel.isLoggedIn {
          Section(header: Text("Server Information")) {
            HStack {
              Text("Server URL")
              Spacer()
              Text(UserDefaultsManager.serverBaseURL)  // TODO: is this safe?
            }
            HStack {
              Text("Navidrome Version")
              Spacer()
              Text(scanStatusViewModel.scanStatus?.serverVersion ?? "undefined")
            }
            HStack {
              Text("Subsonic Version")
              Spacer()
              Text(scanStatusViewModel.scanStatus?.version ?? "undefined")
            }
            HStack {
              Text("Total Folders Scanned:")
              Spacer()
              Text(scanStatusViewModel.scanStatus?.scanStatus.folderCount.description ?? "0")
            }
            HStack {
              Text("Total Files Scanned:")
              Spacer()
              Text(scanStatusViewModel.scanStatus?.scanStatus.count.description ?? "0")
            }
          }
        }

        // TODO: finish this later
        if false {
          Section(header: Text("Make it yours")) {
            ColorPicker("Accent color", selection: $accentColor).disabled(true)
            ColorPicker("Player color", selection: $playerColor).disabled(true)

            Picker(selection: $customFontFamily, label: Text("Font Family")) {
              ForEach(
                ["Plus Jakarta Sans", "System", "JetBrains Mono", "Comic Sans MS"], id: \.self
              ) {
                Text($0)
              }
            }.disabled(true)
          }
        }

        // TODO: finish this later
        if false {
          Section(header: Text("Experimental")) {
            Toggle(isOn: $storeCredsInKeychain) {
              Text("Store username & password in iCloud Keychain")
            }.disabled(true)
            Toggle(isOn: $storeCredsInKeychain) {
              Text("Cache album covers")
            }.disabled(true)
            Toggle(isOn: $storeCredsInKeychain) {
              Text("Scrobble to Last.fm")
            }.disabled(true)
            Toggle(isOn: $storeCredsInKeychain) {
              Text("Scrobble to ListenBrainz")
            }.disabled(true)
            Toggle(isOn: $storeCredsInKeychain) {
              Text("Share my listening activity to Discord now playing status")
            }.disabled(true)
          }
        }

        // TODO: finish this later
        //        Section(header: Text("Development")) {
        //          Text("About")
        //          Text("Get in touch")
        //          Text("Source Code (GitHub)")
        //          Text("Tip me <3 (Trakteer)")
        //        }

        if authViewModel.isLoggedIn {
          Section(header: Text("Logged in as \(authViewModel.user?.username ?? "sigma")")) {
            Button(action: {
              authViewModel.logout()
            }) {
              Text("Logout")
                .foregroundColor(.red)
            }
          }
        }
      }
      .navigationBarTitle("Preferences", displayMode: .inline).padding(.bottom, 100)
    }.onAppear {
      scanStatusViewModel.getLocalStorageInformation()

      if authViewModel.isLoggedIn {
        self.scanStatusViewModel.checkScanStatus()
      }
    }
  }
}

struct PreferencesView_Previews: PreviewProvider {
  @State static var authViewModel: AuthViewModel = AuthViewModel()
  @State static var scanStatusViewModel: ScanStatusViewModel = ScanStatusViewModel()

  static var previews: some View {
    PreferencesView(authViewModel: authViewModel).environmentObject(scanStatusViewModel)
  }
}
