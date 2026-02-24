//
//  PreferencesView.swift
//  flo
//
//  Created by rizaldy on 08/06/24.
//

import SwiftUI

@MainActor
final class AppIconViewModel: ObservableObject {
  @Published var selectedIconID = "default"
  @Published var errorMessage = ""
  @Published var showError = false
  @Published var isChangingIcon = false

  func syncCurrentIcon() {
    selectedIconID = UIApplication.shared.alternateIconName ?? "default"
  }

  func changeIcon(to iconName: String?) {
    if isChangingIcon {
      return
    }

    if (UIApplication.shared.alternateIconName ?? "default") == (iconName ?? "default") {
      return
    }

    isChangingIcon = true
    applyIcon(iconName, attempt: 1)
  }

  private func applyIcon(_ iconName: String?, attempt: Int) {
    UIApplication.shared.setAlternateIconName(iconName) { error in
      DispatchQueue.main.async {
        guard let error else {
          self.isChangingIcon = false
          self.syncCurrentIcon()

          return
        }

        let nsError = error as NSError
        let isTemporaryBusyError = nsError.domain == NSPOSIXErrorDomain && nsError.code == 35

        if isTemporaryBusyError && attempt < 4 {
          let delay = 0.25 * Double(attempt)

          DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            self.applyIcon(iconName, attempt: attempt + 1)
          }

          return
        }

        self.isChangingIcon = false
        self.syncCurrentIcon()

        if nsError.domain == "UIApplicationErrorDomain", nsError.code == 4 {
          return
        }

        self.errorMessage =
          "\(error.localizedDescription)\n(\(nsError.domain) code \(nsError.code))"

        self.showError = true
      }
    }
  }
}

struct PreferencesView: View {
  struct AppIconOption: Identifiable {
    let id: String
    let displayName: String
    let previewImageName: String
    let iconName: String?
  }

  @StateObject private var appIconViewModel = AppIconViewModel()
  @ObservedObject var authViewModel: AuthViewModel
  @State private var storeCredsInKeychain = false
  @State private var optimizeLocalStorageAlert = false
  @State private var showLoginSheet = false
  @State private var showCustomLRCLIBServer = false
  @State private var showFloPlusSheet = false

  @State private var accentColor = Color(.accent)
  @State private var playerColor = Color(.player)
  @State private var customFontFamily = "Plus Jakarta Sans"

  @EnvironmentObject var floooViewModel: FloooViewModel
  @EnvironmentObject var playerViewModel: PlayerViewModel
  @EnvironmentObject var inAppPurchaseManager: InAppPurchaseManager

  let themeColors = ["Blue", "Green", "Red", "Ohio"]
  let presetExperimentalLRCLIBServer: [(label: String, url: String)] = [
    ("lrclib.net", "https://lrclib.net"),
    ("lrclib.flooo.club", "https://lrclib.flooo.club"),
  ]

  let appIconOptions: [AppIconOption] = [
    AppIconOption(
      id: "default", displayName: "flo", previewImageName: "AppIconPreviewDefault", iconName: nil),
    AppIconOption(
      id: "AppIconAlt1", displayName: "flo+", previewImageName: "AppIconPreviewAlt1",
      iconName: "AppIconAlt1"),
    AppIconOption(
      id: "AppIconAlt2", displayName: "flo+", previewImageName: "AppIconPreviewAlt2",
      iconName: "AppIconAlt2"),
    AppIconOption(
      id: "AppIconAlt3", displayName: "flo_robot", previewImageName: "AppIconPreviewAlt3",
      iconName: "AppIconAlt3"),
  ]

  @State private var experimentalMaxBitrate = UserDefaultsManager.maxBitRate
  @State private var experimentalPlayerBackground = UserDefaultsManager.playerBackground
  @State private var experimentalLRCLIBIntegration = UserDefaultsManager.LRCLIBServerURL
  @State private var customLRCLIBServer = ""

  var floPlusPriceLabel: String {
    if let price = inAppPurchaseManager.floPlusProduct?.displayPrice {
      return price
    }

    return inAppPurchaseManager.isLoadingProduct ? "Loading..." : "Unavailable"
  }

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

  var lrclibOptions: [(label: String, url: String)] {
    let current = UserDefaultsManager.LRCLIBServerURL

    let isCustom =
      !current.isEmpty && !presetExperimentalLRCLIBServer.contains(where: { $0.url == current })

    var options = presetExperimentalLRCLIBServer

    if isCustom {
      options.append(("Custom (\(current))", current))
    }

    return options
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
            Text(floooViewModel.downloadedAlbums.description)
          }

          HStack {
            Text("Downloaded Songs")
            Spacer()
            Text(floooViewModel.downloadedSongs.description)
          }

          HStack {
            Text("Total usage")
            Spacer()
            Text(floooViewModel.localDirectorySize)
          }

          Button(
            role: .destructive,
            action: {
              floooViewModel.clearListeningHistory()
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
                  floooViewModel.optimizeLocalStorage()
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
              Text(floooViewModel.scanStatus?.serverVersion ?? "undefined")
            }
            HStack {
              Text("Subsonic Version")
              Spacer()
              Text(floooViewModel.scanStatus?.version ?? "undefined")
            }
            HStack {
              Text("Total Folders Scanned")
              Spacer()
              Text(floooViewModel.scanStatus?.data?.folderCount.description ?? "0")
            }
            HStack {
              Text("Total Files Scanned")
              Spacer()
              Text(floooViewModel.scanStatus?.data?.count.description ?? "0")
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

        Section(header: Text("App Icon")) {
          if UIApplication.shared.supportsAlternateIcons {
            ScrollView(.horizontal, showsIndicators: false) {
              HStack(spacing: 12) {
                ForEach(appIconOptions) { option in
                  Button(action: {
                    appIconViewModel.changeIcon(to: option.iconName)
                  }) {
                    VStack(spacing: 8) {
                      Image(option.previewImageName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 72, height: 72)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                          RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(
                              appIconViewModel.selectedIconID == option.id
                                ? Color.accentColor : Color.secondary.opacity(0.25),
                              lineWidth: appIconViewModel.selectedIconID == option.id ? 2 : 1
                            )
                        )
                    }
                    .frame(width: 88)
                  }
                }
                .buttonStyle(.plain)
                .disabled(appIconViewModel.isChangingIcon)
              }
            }
          } else {
            Text("Alternate app icons are not supported on this device.")
              .font(.caption)
              .foregroundColor(.gray)
          }
        }

        // TODO: finish this later
        Section(header: Text("Experimental")) {
          VStack(alignment: .leading, spacing: 4) {
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
            Picker(selection: $experimentalLRCLIBIntegration, label: Text("LRCLIB")) {
              Text("Disabled").tag("")

              ForEach(lrclibOptions, id: \.url) { option in
                Text(option.label).tag(option.url)
              }

              Text("Add/Change Custom").tag("custom")
            }
            .onChange(of: experimentalLRCLIBIntegration) { value in
              if value != "custom" {
                UserDefaultsManager.LRCLIBServerURL = value
                floooViewModel.getUserDefaults()
              } else {
                showCustomLRCLIBServer.toggle()
              }
            }

            Text("LRCLIB server is required. Learn more at dub.sh/flo-lrclib").font(.caption)
              .foregroundColor(.gray)
          }

          VStack(alignment: .leading, spacing: 4) {
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

          VStack(alignment: .leading, spacing: 8) {
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
                      floooViewModel.getUserDefaults()
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
                  self.floooViewModel.checkScanStatus()
                  self.floooViewModel.checkAccountLinkStatus()
                }

                if UserDefaultsManager.enableDebug {
                  floooViewModel.getUserDefaults()
                }

                if !showLoginSheet && authViewModel.experimentalSaveLoginInfo {
                  authViewModel.experimentalSaveLoginInfo = false
                }
              }
          }

          if authViewModel.isLoggedIn {
            VStack(alignment: .leading, spacing: 6) {
              Toggle(isOn: $floooViewModel.isLastFmLinked) {
                Text("Scrobble to Last.fm")
              }.disabled(true)

              Text("To change this, please do so via the Navidrome Web UI").font(.caption)
                .foregroundColor(.gray)
            }

            VStack(alignment: .leading, spacing: 6) {
              Toggle(isOn: $floooViewModel.isListenBrainzLinked) {
                Text("Scrobble to ListenBrainz")
              }.disabled(true)

              Text("To change this, please do so via the Navidrome Web UI").font(.caption)
                .foregroundColor(.gray)
            }
          }
        }

        Section(header: Text("Development")) {

          // TODO(@fariz): uncomment this on 2.2
          //          if !UserDefaultsManager.floPlus {
          //            VStack(alignment: .leading, spacing: 6) {
          //              Button(action: {
          //                showFloPlusSheet = true
          //              }) {
          //                Text("Purchase flo+")
          //              }
          //            }
          //          } else {
          //            VStack(alignment: .leading, spacing: 6) {
          //              Text("flo+ purchased")
          //              Text("Thank you for supporting flo!").font(.caption)
          //                .foregroundColor(.gray)
          //            }
          //          }

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
                floooViewModel.getUserDefaults()
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
              ForEach(floooViewModel.userDefaultsItems.keys.sorted(), id: \.self) { key in
                VStack(alignment: .leading, spacing: 8) {
                  Text("UserDefaults.\(key)")
                    .font(.headline)
                    .foregroundColor(.primary)

                  Text(String(describing: floooViewModel.userDefaultsItems[key]))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
              }

              ForEach(floooViewModel.keychainItems.keys.sorted(), id: \.self) { key in
                VStack(alignment: .leading, spacing: 8) {
                  Text("Keychain.\(key)")
                    .font(.headline)
                    .foregroundColor(.primary)

                  Text(String(describing: floooViewModel.keychainItems[key]))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
              }
            }

            Button(action: {
              floooViewModel.getUserDefaults()
            }) {
              Text("Refetch UserDefaults & Keychains")
            }

            Button(action: {
              authViewModel.logout()
              floooViewModel.getUserDefaults()
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
      floooViewModel.getLocalStorageInformation()

      Task {
        await inAppPurchaseManager.loadFloPlusProduct()
      }

      if authViewModel.isLoggedIn {
        self.floooViewModel.checkScanStatus()
        self.floooViewModel.checkAccountLinkStatus()
      }

      if UserDefaultsManager.enableDebug {
        floooViewModel.getUserDefaults()
      }

      appIconViewModel.syncCurrentIcon()
    }
    .alert("Unable to Change App Icon", isPresented: $appIconViewModel.showError) {
      Button("OK", role: .cancel) {}
    } message: {
      Text(appIconViewModel.errorMessage)
    }
    .sheet(isPresented: $showFloPlusSheet) {
      FloPlusSheet(showSheet: $showFloPlusSheet)
        .environmentObject(inAppPurchaseManager)
    }
    .alert("Unable to Purchase flo+", isPresented: $inAppPurchaseManager.showPurchaseError) {
      Button("OK", role: .cancel) {}
    } message: {
      Text(inAppPurchaseManager.purchaseErrorMessage)
    }
    .alert("LRCLIB Server URL", isPresented: $showCustomLRCLIBServer) {
      Button("Cancel", role: .cancel) {
        self.showCustomLRCLIBServer.toggle()
        self.experimentalLRCLIBIntegration = ""
      }

      Button("Save") {
        UserDefaultsManager.LRCLIBServerURL = customLRCLIBServer
        self.experimentalLRCLIBIntegration = customLRCLIBServer
        floooViewModel.getUserDefaults()
      }

      TextField("https://lrclib.your-server.net", text: $customLRCLIBServer).keyboardType(.URL)
        .autocapitalization(.none)
        .disableAutocorrection(true)
        .textContentType(.none)
    } message: {
      Text("Learn more at https://dub.sh/flo-lrclib")
    }
  }
}

struct FloPlusSheet: View {
  @Binding var showSheet: Bool
  @EnvironmentObject var inAppPurchaseManager: InAppPurchaseManager

  private var floPlusPriceLabel: String {
    if let price = inAppPurchaseManager.floPlusProduct?.displayPrice {
      return price
    }

    return inAppPurchaseManager.isLoadingProduct ? "Loading..." : "Unavailable"
  }

  var body: some View {
    NavigationStack {
      VStack(alignment: .leading, spacing: 18) {
        Spacer()

        Image("AppIconPreviewAlt1")
          .resizable()
          .scaledToFit()
          .frame(width: 88, height: 88)
          .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
          .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
              .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
          )

        Text("Purchase flo+")
          .font(.title2)
          .fontWeight(.bold)

        Text("Help fund flo development")
          .foregroundColor(.secondary)

        VStack(alignment: .leading, spacing: 12) {
          Label("The full version of flo is always Free and OSS", systemImage: "heart")
          Label("Get a dedicated channel on flo Campfire", systemImage: "cloud")
          Label("Some other things yet to come", systemImage: "sparkles")
        }

        Spacer()

        Button(action: {
          Task {
            await inAppPurchaseManager.purchaseFloPlus()

            if UserDefaultsManager.floPlus {
              showSheet = false
            }
          }
        }) {
          HStack {
            Text("Purchase flo+ for \(floPlusPriceLabel)")
              .fontWeight(.semibold)

            if inAppPurchaseManager.isPurchasing {
              Spacer()
              ProgressView().controlSize(.small)
            }
          }
          .frame(maxWidth: .infinity)
        }
        .padding()
        .buttonStyle(.borderedProminent)
        .disabled(inAppPurchaseManager.isPurchasing)

        Button(action: {
          Task {
            await inAppPurchaseManager.restorePurchases()
          }
        }) {
          HStack {
            Text("Restore purchases")

            if inAppPurchaseManager.isRestoring {
              Spacer()
              ProgressView().controlSize(.small)
            }
          }
          .frame(maxWidth: .infinity)
        }
        .disabled(inAppPurchaseManager.isRestoring)
      }
      .padding(20)
      .navigationBarTitleDisplayMode(.inline)
    }
    .presentationDetents([.medium, .large])
    .presentationDragIndicator(.visible)
  }
}

struct PreferencesView_Previews: PreviewProvider {
  @State static var authViewModel: AuthViewModel = AuthViewModel()
  @State static var floooViewModel: FloooViewModel = FloooViewModel()
  @State static var inAppPurchaseManager: InAppPurchaseManager = InAppPurchaseManager(
    startObservingTransactions: false)

  static var previews: some View {
    PreferencesView(authViewModel: authViewModel).environmentObject(floooViewModel)
      .environmentObject(inAppPurchaseManager)
  }
}
