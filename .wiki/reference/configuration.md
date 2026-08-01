# Configuration

This page documents all user-facing and build configuration in flo.

Sources: `flo/Shared/Utils/Constants.swift`, `flo/Shared/Services/UserDefaultsManager.swift`, `fastlane/Appfile`, `fastlane/Fastfile`, `fastlane/Gymfile`, `fastlane/Matchfile`, `.github/workflows/ios-deployment.yml`, `flo/Info.plist`, and `flo/flo.entitlements`.

## App metadata

Defined in `flo/Shared/Utils/Constants.swift` under `AppMeta`:

| Key | Value | Purpose |
| --- | --- | --- |
| `name` | `flo` | Display name. |
| `identifier` | `net.faultables.flo` | Primary bundle identifier used in code. |
| `subsonicApiVersion` | `1.16.1` | Subsonic API version the app reports to servers. |

Note: the fastlane `Appfile` uses `com.penerbangwalet.flo` for the iOS/macOS app identifier and `com.penerbangwalet.flo.watchkitapp` for the watch companion. `AppMeta.identifier` is used in the Keychain service namespace.

## UserDefaults keys

`UserDefaultsKeys` in `flo/Shared/Utils/Constants.swift` lists the raw keys, and `UserDefaultsManager.swift` provides typed accessors.

| Key | Type | Default | Description |
| --- | --- | --- | --- |
| `serverURL` | `String` | `""` | Base URL of the Navidrome server. |
| `queueActiveIdx` | `Int` | `0` | Index of the currently active item in the playback queue. |
| `nowPlayingProgress` | `Double` | `0` | Last known playback progress, in seconds. |
| `playbackMode` | `String` | `defaultPlayback` | Current repeat/shuffle mode. See `PlaybackMode` values below. |
| `enableDebug` | `Bool` | `false` | Enables experimental debug features. |
| `enableMaxBitRate` | `String` | `sourceBitRate` | Selected max bitrate for transcoding. See `TranscodingSettings` below. |
| `playerBackground` | `String` | `translucent` | Player background style. Currently hardcoded to `translucent` in `UserDefaultsManager`. |
| `saveLoginInfo` | `Bool` | `false` | Whether to save login credentials locally (experimental). |
| `LRCLIBServerURL` | `String` | `""` | Custom LRCLIB lyrics server URL. |
| `floPlus` | `Bool` | `false` | Whether the user has unlocked flo Plus via in-app purchase. |
| `streamCacheMaxSize` | `Int64` | `0` | Maximum size for the transparent stream cache; `0` means off. |

### Playback modes

Defined in `flo/Shared/Utils/Constants.swift` under `PlaybackMode`:

| Value | Meaning |
| --- | --- |
| `default` | Normal queue playback. |
| `repeatAlbum` | Repeat the current album or collection. |
| `repeatOnce` | Repeat the current track once. |

### Player backgrounds

`PlayerBackground` in `flo/Shared/Utils/Constants.swift`:

| Value | Description |
| --- | --- |
| `solid` | Solid color background. |
| `translucent` | Translucent background. |

## Transcoding settings

`TranscodingSettings` in `flo/Shared/Utils/Constants.swift`:

| Setting | Value | Description |
| --- | --- | --- |
| `sourceBitRate` | `"0"` | Pass-through / original bitrate. |
| `sourceFormat` | `"raw"` | Original stream format. |
| `targetFormat` | `"mp3"` | Format used when transcoding. |
| `availableBitRate` | `["0", "32", "48", "64", "80", "96", "112", "128", "160", "192", "224", "256", "320"]` | All user-selectable bitrates in kbps. `0` means source quality. |

## Keychain keys

`KeychainKeys` in `flo/Shared/Utils/Constants.swift`:

| Key | Value | Description |
| --- | --- | --- |
| `service` | `AppMeta.identifier` on iOS, `Bundle.main.bundleIdentifier` on Mac Catalyst | Keychain service name used for credential isolation. |
| `dataKey` | `"authCreds"` | Key under which the encoded `UserAuth` object is stored. |
| `serverPassword` | `"serverPassword"` | Key for the plain-text server password when `saveLoginInfo` is enabled. |

See `flo/Shared/Services/KeychainManager.swift` for the actual read/write implementation.

## fastlane configuration

### `fastlane/Appfile`

Defines the app identifiers used by fastlane:

```ruby
app_identifier(["com.penerbangwalet.flo", "com.penerbangwalet.flo.watchkitapp"])
```

### `fastlane/Fastfile`

All lanes are defined inside `platform :ios do` with `configuration = "Release"` and the TestFlight group `groups = ["Kepelet"]`.

| Lane | Purpose |
| --- | --- |
| `load_asc_api_key` | Creates an App Store Connect API key from `ENV["ASC_KEY_ID"]`, `ENV["ASC_ISSUER_ID"]`, and `ENV["ASC_KEY_CONTENT"]`. |
| `sync_certs` | Uses `match` in read-only mode to sync the app store certificates for both Catalyst and iOS. |
| `fetch_and_increment_build_number` | Reads the latest TestFlight build number and increments it in the project. |
| `build` | Loads the API key, syncs certs, increments the build number, then runs `build_app`. |
| `beta` | Builds the app and uploads it to TestFlight. Accepts a `public` option; when `public:true`, it distributes to the external group defined in `groups`. |

### `fastlane/Gymfile`

Build options for `gym` / `build_app`:

| Option | Value |
| --- | --- |
| `scheme` | `flo` |
| `export_method` | `app-store` |
| `output_directory` | `./fastlane/builds` |
| `include_symbols` | `false` |

### `fastlane/Matchfile`

Certificate storage configuration for `match`:

| Option | Value |
| --- | --- |
| `git_url` | `git@github.com:kepelet/match.git` |
| `storage_mode` | `git` |
| `type` | `appstore` |
| `username` | `ENV["APPLE_ID"]` |

## GitHub Actions workflow

`.github/workflows/ios-deployment.yml` runs on pushes to `develop` and `release/*` branches. The job is gated to `github.actor == 'faultables'` and runs on `macos-latest`.

Environment variables passed via secrets:

| Variable | Secret | Purpose |
| --- | --- | --- |
| `APPLE_ID` | `secrets.APPLE_ID` | Apple ID used by fastlane match. |
| `ASC_KEY_ID` | `secrets.ASC_KEY_ID` | App Store Connect API key ID. |
| `ASC_ISSUER_ID` | `secrets.ASC_ISSUER_ID` | App Store Connect API issuer ID. |
| `ASC_KEY_CONTENT` | `secrets.ASC_KEY_CONTENT` | App Store Connect API key content. |
| `MATCH_GIT_PRIVATE_KEY` | `secrets.MATCH_GIT_PRIVATE_KEY` | SSH key for the match repository. |
| `MATCH_PASSWORD` | `secrets.MATCH_PASSWORD` | Passphrase for the match repository. |

Other workflow settings:

| Setting | Value |
| --- | --- |
| Xcode version | `26.3` |
| Ruby version | `3.2.1` |
| Bundler cache | enabled |
| Public beta | `bundle exec fastlane ios beta public:true` for `develop` |
| Internal beta | `bundle exec fastlane ios beta` for `release/*` branches |

The workflow uploads the resulting IPA and dSYM to an artifact named `appstore ipa & dsym`.

## Info.plist

`flo/Info.plist` contains the following relevant keys:

| Key | Value | Purpose |
| --- | --- | --- |
| `CFBundleIconFile` | `floIcon` | macOS app icon file. |
| `UIAppFonts` | `["PlusJakartaSans-VariableFont_wght.ttf"]` | Custom font bundled with the app. |
| `UIApplicationSupportsMultipleScenes` | `true` | Enables multi-window / multi-scene support. |
| `CPTemplateApplicationSceneSessionRoleApplication` | CarPlay scene configuration | Registers `CarPlaySceneDelegate` as the CarPlay scene delegate. |
| `UIBackgroundModes` | `["audio"]` | Allows audio playback to continue in the background. |

## Entitlements

`flo/flo.entitlements` is minimal and only enables the CarPlay audio entitlement:

```xml
<key>com.apple.developer.carplay-audio</key>
<true/>
```
