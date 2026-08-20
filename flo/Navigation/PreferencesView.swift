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
  @State private var showTipJarSheet = false
  @State private var showScrobbleQueueSheet = false

  @ObservedObject private var scrobbleQueue = ScrobbleQueueManager.shared

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
  @State private var experimentalStreamCacheSize = UserDefaultsManager.streamCacheMaxSize
  @State private var clearStreamCacheAlert = false
  @State private var experimentalLRCLIBIntegration = UserDefaultsManager.LRCLIBServerURL
  @State private var customLRCLIBServer = ""

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

  private var mainContent: some View {
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

          HStack {
            Text("Streaming cache")
            Spacer()
            Text(floooViewModel.streamCacheSize)
          }

          Button(action: {
            showScrobbleQueueSheet = true
          }) {
            HStack {
              Text("Offline Scrobbles")

              Spacer()

              Text(
                scrobbleQueue.pendingCount == 0 ? "Empty" : "\(scrobbleQueue.pendingCount) waiting"
              )
              .foregroundColor(.secondary)
            }
          }

          Picker("Cache limit", selection: $experimentalStreamCacheSize) {
            Text("Off").tag(Int64(0))
            Text("500 MB").tag(Int64(524_288_000))
            Text("1 GB").tag(Int64(1_073_741_824))
            Text("2 GB").tag(Int64(2_147_483_648))
            Text("5 GB").tag(Int64(5_368_709_120))
          }
          .onChange(of: experimentalStreamCacheSize) { value in
            UserDefaultsManager.streamCacheMaxSize = value
          }

          Button(action: {
            self.clearStreamCacheAlert.toggle()
          }) {
            Text("Clear streaming cache")
          }.alert(
            "Clear Streaming Cache", isPresented: $clearStreamCacheAlert,
            actions: {
              Button(
                "Clear", role: .destructive,
                action: {
                  StreamCacheManager.shared.clearCache()
                  floooViewModel.getLocalStorageInformation()
                })
            },
            message: {
              Text("This will delete all cached streamed songs. Downloads are not affected.")
            })

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
              )
            )
            .disabled(authViewModel.authMode == .iap)

            Text(
              authViewModel.authMode == .iap
                ? "This option is not available when using OAuth."
                : "flo will store your server URL, username, and password in the Keychain with no biometric protection. If you enable this, flo will try to 'refresh' the auth token—by logging you in automatically—every time you open flo so you'll never log out unless you do it explicitly (it will also reset this option). Logging in via OAuth will reset this option."
            ).font(.caption).foregroundColor(.gray)
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

          Button(action: {
            if let url = URL(string: "https://client.flooo.club/about") {
              UIApplication.shared.open(url)
            }
          }) {
            Text("About flo")
          }

          Button(action: {
            showTipJarSheet = true
          }) {
            Text("Support flo")
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
        await inAppPurchaseManager.loadTipProducts()
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
    .sheet(isPresented: $showTipJarSheet) {
      TipJarSheet(showSheet: $showTipJarSheet)
        .environmentObject(inAppPurchaseManager)
    }
    .fullScreenCover(isPresented: $showScrobbleQueueSheet) {
      ScrobbleQueueView()
    }
    .alert("Unable to Send Tip", isPresented: $inAppPurchaseManager.showPurchaseError) {
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

  private var loginContent: some View {
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

  var body: some View {
    Group {
      if UIDevice.current.userInterfaceIdiom == .pad {
        AnyView(
          mainContent.fullScreenCover(isPresented: shouldShowLoginSheet) {
            loginContent
          })
      } else {
        AnyView(
          mainContent.sheet(isPresented: shouldShowLoginSheet) {
            loginContent
          })
      }
    }
  }
}

struct TipJarSheet: View {
  @Binding var showSheet: Bool
  @EnvironmentObject var inAppPurchaseManager: InAppPurchaseManager

  /// Default tier. Dinner (tipjar.large) sits center and is active on open.
  @State private var selectedTierID = "tipjar.large"

  /// A description bullet with an accent-colored icon and secondary text.
  private func tipBullet(_ systemImage: String, _ text: String) -> some View {
    Label {
      Text(text)
        .foregroundColor(.white.opacity(0.92))
    } icon: {
      Image(systemName: systemImage)
        .foregroundColor(.white)
    }
  }

  /// All loaded tiers, rendered as a carousel where the selected tier sits centered.
  private var carouselItems: [InAppPurchaseManager.TipTier] {
    inAppPurchaseManager.tipTiers
  }

  /// Circular slot for an item relative to the selection: -1 left, 0 center, +1 right.
  private func relIndex(for productID: String) -> Int {
    let order = ["tipjar.small", "tipjar.medium", "tipjar.large"]
    guard let selected = order.firstIndex(of: selectedTierID),
      let index = order.firstIndex(of: productID)
    else {
      return 0
    }
    let delta = index - selected
    if delta > 1 { return -1 }
    if delta < -1 { return 1 }
    return delta
  }

  /// Moves the selection to the previous/next tier following the ring order.
  private func advanceSelection(by delta: Int) {
    let order = ["tipjar.small", "tipjar.medium", "tipjar.large"]
    guard let current = order.firstIndex(of: selectedTierID) else { return }
    let nextIndex = (current + delta + order.count) % order.count
    let nextID = order[nextIndex]
    guard inAppPurchaseManager.tipTiers.contains(where: { $0.id == nextID }) else { return }
    selectedTierID = nextID
  }

  private var selectedTier: InAppPurchaseManager.TipTier? {
    inAppPurchaseManager.tipTiers.first { $0.id == selectedTierID }
  }

  /// Column background color matching its image.
  private func tierBackground(_ productID: String) -> Color {
    switch productID {
    case "tipjar.small":
      return Color(red: 253 / 255, green: 188 / 255, blue: 139 / 255)  // coffee peach
    case "tipjar.medium":
      return Color(red: 244 / 255, green: 119 / 255, blue: 88 / 255)  // lunch coral
    case "tipjar.large":
      return Color(red: 62 / 255, green: 75 / 255, blue: 50 / 255)  // dinner deep green
    default:
      return Color(.secondarySystemBackground)
    }
  }

  /// Asset image name for each tier.
  private func tierImage(_ productID: String) -> String {
    switch productID {
    case "tipjar.small":
      return "TipCoffee"
    case "tipjar.medium":
      return "TipLunch"
    case "tipjar.large":
      return "TipDinner"
    default:
      return "TipCoffee"
    }
  }

  private func tierCard(_ tier: InAppPurchaseManager.TipTier, isSelected: Bool) -> some View {
    ZStack(alignment: .bottom) {
      Image(tierImage(tier.id))
        .resizable()
        .scaledToFill()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .opacity(isSelected ? 1 : 0.45)

      if isSelected {
        LinearGradient(
          colors: [.black.opacity(0.0), .black.opacity(0.65)],
          startPoint: .top,
          endPoint: .bottom
        )
        .frame(height: 90)

        VStack(alignment: .leading, spacing: 2) {
          Text(tier.displayName)
            .fontWeight(.semibold)
            .foregroundColor(.white)
          Text(tier.priceLabel)
            .font(.subheadline)
            .foregroundColor(.white.opacity(0.95))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
      }
    }
    .frame(height: isSelected ? 210 : 165)
    .background(tierBackground(tier.id))
    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 20, style: .continuous)
        .stroke(isSelected ? Color.white : Color.clear, lineWidth: 3)
    )
    .overlay(alignment: .topTrailing) {
      let count = inAppPurchaseManager.tipCounts[tier.id] ?? 0
      if count > 0 {
        Text("\(count)")
          .font(.caption.bold())
          .foregroundColor(.white)
          .padding(.horizontal, 8)
          .padding(.vertical, 3)
          .background(Capsule().fill(Color.black.opacity(0.5)))
          .padding(8)
      }
    }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 24) {
      VStack(alignment: .leading, spacing: 4) {
        Text("Support flo")
          .font(.title2)
          .fontWeight(.bold)
          .foregroundColor(.white)

        Text("Your support helps flo get better over time.")
          .font(.subheadline)
          .foregroundColor(.white.opacity(0.85))
      }

      Rectangle()
        .stroke(Color.white.opacity(0.6), style: StrokeStyle(lineWidth: 1, dash: [5, 5]))
        .frame(height: 1)

      VStack(spacing: 24) {
        if inAppPurchaseManager.isLoadingProducts {
          ProgressView()
            .frame(maxWidth: .infinity)
            .padding()
        } else if inAppPurchaseManager.tipTiers.isEmpty {
          Text("Tip options are currently unavailable.")
            .foregroundColor(.white.opacity(0.85))
            .frame(maxWidth: .infinity)
            .padding()
        } else {
          GeometryReader { geo in
            let cardWidth: CGFloat = (geo.size.width - 24) / 3
            let gap: CGFloat = -30
            ZStack(alignment: .bottom) {
              ForEach(carouselItems) { tier in
                let rel = relIndex(for: tier.id)
                Button(action: {
                  withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    selectedTierID = tier.id
                  }
                }) {
                  tierCard(tier, isSelected: rel == 0)
                }
                .buttonStyle(.plain)
                .frame(width: cardWidth)
                .offset(x: CGFloat(rel) * (cardWidth + gap))
                .zIndex(rel == 0 ? 1 : 0)
              }
            }
            .frame(width: geo.size.width, height: 220)
            .frame(maxWidth: .infinity)
            .gesture(
              DragGesture(minimumDistance: 20)
                .onEnded { value in
                  let horizontal = value.translation.width
                  if horizontal > 40 {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                      advanceSelection(by: -1)
                    }
                  } else if horizontal < -40 {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                      advanceSelection(by: 1)
                    }
                  }
                }
            )
          }
          .frame(height: 220)

          Button(action: {
            guard let selected = selectedTier else { return }
            Task {
              await inAppPurchaseManager.purchase(selected)
            }
          }) {
            HStack {
              if let selected = selectedTier {
                Text("Tip \(selected.priceLabel)")
                  .fontWeight(.semibold)
              } else {
                Text("Select a tip")
              }

              if inAppPurchaseManager.purchasingProductID != nil {
                Spacer()
                ProgressView().controlSize(.small)
              }
            }
            .frame(maxWidth: .infinity)
          }
          .tint(.white)
          .foregroundColor(.accentColor)
          .font(.title3)
          .fontWeight(.semibold)
          .controlSize(.large)
          .padding(.vertical, 4)
          .buttonStyle(.borderedProminent)
          .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
          .disabled(selectedTier == nil || inAppPurchaseManager.isPurchasing)
        }
      }
      .padding(.top, 12)

      Rectangle()
        .stroke(Color.white.opacity(0.6), style: StrokeStyle(lineWidth: 1, dash: [5, 5]))
        .frame(height: 1)

      VStack(alignment: .leading, spacing: 10) {
        tipBullet("gift", "Tipping is optional and unlocks no features.")
        tipBullet(
          "wrench.and.screwdriver",
          "Your tip helps flo improve and grow."
        )
        tipBullet("heart", "flo stays free and open source for everyone.")
      }
      .font(.subheadline)
    }
    .padding(20)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.accentColor.ignoresSafeArea())
    .overlay(alignment: .topTrailing) {
      Button {
        showSheet = false
      } label: {
        Image(systemName: "xmark")
          .font(.body.weight(.semibold))
          .foregroundColor(.white.opacity(0.9))
          .frame(width: 36, height: 36)
          .padding(.trailing, 16)
          .padding(.top, 8)
      }
    }
    .presentationDetents([.large])
    .presentationDragIndicator(.hidden)
    .task {
      await inAppPurchaseManager.refreshTipProducts()
    }
    .overlay {
      if inAppPurchaseManager.showThankYou {
        ZStack {
          ConfettiView()

          VStack(spacing: 12) {
            Image(systemName: "heart.fill")
              .font(.system(size: 46))
              .foregroundColor(.white)
            Text("Thank you!")
              .font(.title2.bold())
              .foregroundColor(.white)
            Text("for the \(inAppPurchaseManager.thankYouTierName)")
              .font(.subheadline)
              .foregroundColor(.white.opacity(0.92))
          }
          .padding(28)
          .background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
          )
        }
        .transition(.opacity)
      }
    }
    .onChange(of: inAppPurchaseManager.showThankYou) { isShowing in
      guard isShowing else { return }

      Task {
        try? await Task.sleep(nanoseconds: 2_600_000_000)

        guard inAppPurchaseManager.showThankYou else { return }

        inAppPurchaseManager.thankYouTierName = ""
        inAppPurchaseManager.showThankYou = false
        showSheet = false
      }
    }
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
