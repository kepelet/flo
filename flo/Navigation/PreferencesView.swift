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
  @State private var optimizeLocalStorageAlert = false

  @State private var accentColor = Color(.accent)
  @State private var playerColor = Color(.player)
  @State private var customFontFamily = "Plus Jakarta Sans"

  @EnvironmentObject var scanStatusViewModel: ScanStatusViewModel
  @EnvironmentObject var playerViewModel: PlayerViewModel

  let themeColors = ["Blue", "Green", "Red", "Ohio"]

  @State private var experimentalMaxBitrate = UserDefaultsManager.maxBitRate

  func getAppVersion() -> String {
    if let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
      return appVersion
    }

    return "dev"
  }

  func getBuildNumber() -> String {
    if let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
      return buildNumber
    }

    return "000000"
  }

  var body: some View {
    NavigationStack {
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

          Button(action: {
            self.optimizeLocalStorageAlert.toggle()
          }) {
            Text("Optimize local storage")
          }.alert(
            "Optimize Local Storage", isPresented: $optimizeLocalStorageAlert,
            actions: {
              Button(
                "Continue", role: .destructive,
                action: {
                  scanStatusViewModel.optimizeLocalStorage()
                  playerViewModel.destroyPlayerAndQueue()
                })
            },
            message: {
              Text(
                "For now this action means 'Delete all downloaded albums and songs' including its content. Continue?"
              )
            })
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
              Text("Total Folders Scanned")
              Spacer()
              Text(scanStatusViewModel.scanStatus?.scanStatus.folderCount.description ?? "0")
            }
            HStack {
              Text("Total Files Scanned")
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
        Section(header: Text("Experimental")) {
          Toggle(
            "Enable Request Log",
            isOn: Binding(
              get: { UserDefaultsManager.enableDebug },
              set: { value in
                UserDefaultsManager.enableDebug = value
                APIManager.shared.reconfigureSession()
              }
            ))

          VStack(alignment: .leading) {
            Picker(selection: $experimentalMaxBitrate, label: Text("Max Bitrate")) {
              ForEach(TranscodingSettings.availableBitRate, id: \.self) { bitrate in
                Text(bitrate == "0" ? "Source" : bitrate).tag(bitrate)
              }
            }
            .onChange(of: experimentalMaxBitrate) { value in
              UserDefaultsManager.maxBitRate = value
            }

            Text(
              "Currently the output format is MP3 due to compatibility issues; however, MP3 is less efficient in streaming at lower bitrates compared to modern codecs like Opus."
            ).font(.caption).foregroundColor(.gray)
          }

          if false {
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

        Section(header: Text("Development")) {
          Button(action: {
            if let url = URL(string: "https://client.flooo.club/about") {
              UIApplication.shared.open(url)
            }
          }) {
            Text("About flo")
          }

          Button(action: {
            if let url = URL(string: "https://github.com/kepelet/flo") {
              UIApplication.shared.open(url)
            }
          }) {
            Text("Source Code")
          }

          HStack {
            Text("App Version")
            Spacer()
            Text("\(self.getAppVersion()) (\(self.getBuildNumber()))")
          }
        }

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
      }.navigationBarTitle("Preferences", displayMode: .inline)
    }.padding(
      .bottom, playerViewModel.hasNowPlaying() && !playerViewModel.shouldHidePlayer ? 100 : 0
    ).onAppear {
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
