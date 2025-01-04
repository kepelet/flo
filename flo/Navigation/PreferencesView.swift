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
  @State private var showLoginSheet = false

  @State private var accentColor = Color(.accent)
  @State private var playerColor = Color(.player)
  @State private var customFontFamily = "Plus Jakarta Sans"

  @EnvironmentObject var scanStatusViewModel: ScanStatusViewModel
  @EnvironmentObject var playerViewModel: PlayerViewModel

  let themeColors = ["Blue", "Green", "Red", "Ohio"]

  @State private var experimentalMaxBitrate = UserDefaultsManager.maxBitRate
  @State private var experimentalPlayerBackground = UserDefaultsManager.playerBackground

  var shouldShowLoginSheet: Binding<Bool> {
    Binding(
      get: {
        return showLoginSheet && authViewModel.experimentalSaveLoginInfo
      },
      set: { newValue in
        showLoginSheet = newValue
      }
    )
  }

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

          HStack {
            Text("Total usage")
            Spacer()
            Text(scanStatusViewModel.localDirectorySize)
          }

          Button(
            role: .destructive,
            action: {
              scanStatusViewModel.clearListeningHistory()
            }
          ) {
            Text("Clear listening history (no alert and irreversible)")
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
          VStack(alignment: .leading) {
            Toggle(
              "Enable Debug",
              isOn: Binding(
                get: { UserDefaultsManager.enableDebug },
                set: { value in
                  UserDefaultsManager.enableDebug = value
                  APIManager.shared.reconfigureSession()
                }
              ))

            Text(
              "Enabling this option may affect the experience."
            ).font(.caption).foregroundColor(.gray)
          }

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

          Toggle(
            "Use translucent backgrounds",
            isOn: Binding(
              get: { UserDefaultsManager.playerBackground == PlayerBackground.translucent },
              set: {
                UserDefaultsManager.playerBackground =
                  $0 ? PlayerBackground.translucent : PlayerBackground.solid
              }
            ))

          VStack(alignment: .leading) {
            Toggle(
              "Save login info",
              isOn: Binding(
                get: { UserDefaultsManager.saveLoginInfo },
                set: {
                  if $0 {
                    authViewModel.experimentalSaveLoginInfo = true
                    showLoginSheet = true
                  } else {
                    authViewModel.destroySavedPassword()

                    if UserDefaultsManager.enableDebug {
                      scanStatusViewModel.getUserDefaults()
                    }
                  }
                }
              ))

            Text(
              "flo will store your server URL, username, and password in the Keychain with no biometric protection. If you enable this, flo will try to 'refresh' the auth token—by logging you in automatically—every time you open flo so you'll never log out unless you do it explicitly (it will also reset this option)"
            ).font(.caption).foregroundColor(.gray)
          }
          .sheet(isPresented: shouldShowLoginSheet) {
            Login(viewModel: authViewModel, showLoginSheet: $showLoginSheet)
              .onDisappear {
                if authViewModel.isLoggedIn {
                  self.scanStatusViewModel.checkScanStatus()
                  self.scanStatusViewModel.checkAccountLinkStatus()
                }

                if UserDefaultsManager.enableDebug {
                  scanStatusViewModel.getUserDefaults()
                }

                if !showLoginSheet && authViewModel.experimentalSaveLoginInfo {
                  authViewModel.experimentalSaveLoginInfo = false
                }
              }
          }

          if authViewModel.isLoggedIn {
            VStack(alignment: .leading) {
              Toggle(isOn: $scanStatusViewModel.isLastFmLinked) {
                Text("Scrobble to Last.fm")
              }.disabled(true)

              Text("To change this, please do so via the Navidrome Web UI").font(.caption)
                .foregroundColor(.gray)
            }

            Toggle(isOn: $scanStatusViewModel.isListenBrainzLinked) {
              Text("Scrobble to ListenBrainz")
            }.disabled(true)

            Text("To change this, please do so via the Navidrome Web UI").font(.caption)
              .foregroundColor(.gray)
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

              if UserDefaultsManager.enableDebug {
                scanStatusViewModel.getUserDefaults()
              }
            }) {
              Text("Logout")
                .foregroundColor(.red)
            }
          }
        }

        if UserDefaultsManager.enableDebug {
          Section(header: Text("Troubleshoot")) {
            List {
              ForEach(scanStatusViewModel.userDefaultsItems.keys.sorted(), id: \.self) { key in
                VStack(alignment: .leading, spacing: 8) {
                  Text("UserDefaults.\(key)")
                    .font(.headline)
                    .foregroundColor(.primary)

                  Text(String(describing: scanStatusViewModel.userDefaultsItems[key]))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
              }

              ForEach(scanStatusViewModel.keychainItems.keys.sorted(), id: \.self) { key in
                VStack(alignment: .leading, spacing: 8) {
                  Text("Keychain.\(key)")
                    .font(.headline)
                    .foregroundColor(.primary)

                  Text(String(describing: scanStatusViewModel.keychainItems[key]))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
              }
            }

            Button(action: {
              scanStatusViewModel.getUserDefaults()
            }) {
              Text("Refetch UserDefaults & Keychains")
            }

            Button(action: {
              authViewModel.logout()
              scanStatusViewModel.getUserDefaults()
            }) {
              Text("Force Logout").foregroundColor(.red)
            }
          }
        }

        if playerViewModel.hasNowPlaying() && !playerViewModel.shouldHidePlayer {
          Color.clear.frame(height: 50).listRowBackground(Color.clear)
        }
      }.navigationBarTitle("Preferences", displayMode: .inline)
    }.onAppear {
      scanStatusViewModel.getLocalStorageInformation()

      if authViewModel.isLoggedIn {
        self.scanStatusViewModel.checkScanStatus()
        self.scanStatusViewModel.checkAccountLinkStatus()
      }

      if UserDefaultsManager.enableDebug {
        scanStatusViewModel.getUserDefaults()
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
