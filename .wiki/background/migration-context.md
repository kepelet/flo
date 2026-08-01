# Migration context

Active contributors: rizaldy, docmeth02, Piekay, Francesco, faultables, SindreKjelsrud, Ed Poe, Simon Risse.

This page lists notable changes that affect upgrading between versions or running different versions side by side. If you are changing a subsystem, check here first to avoid breaking existing users.

## `OfflineData` to `flo` rename

The app was previously named `OfflineData` and later renamed to `flo`. This affects the bundle identifier and the Core Data container name. `CoreDataManager` now loads a container named `flo`:

```swift
let container = NSPersistentContainer(name: "flo")  // FIXME: constants?
```

File: `flo/Shared/Services/CoreDataManager.swift`, line 36.

Changing the container name again would create a new empty store and orphan the existing offline library, queue, and history. Keep the name `flo` unless you add a migration plan.

## Subsonic response wrapper refactor (`Subsonic.swift`)

The project introduced a generic `SubsonicResponse<T: SubsonicResponseData>` wrapper in `flo/Shared/Models/Subsonic.swift` to handle the `subsonic-response` envelope with dynamic keys. This replaced scattered manual decoding. Models that already adopted it include `ScanStatus`, `Radio`, and `ArtistRadio`. Older models such as `AlbumInfo` and `Starred2Response` still have their own wrappers, which is why they are marked with `// FIXME: constants?` or custom coding keys. When adding new Subsonic responses, prefer the shared wrapper and migrate the older ones when touching them.

File: `flo/Shared/Models/Subsonic.swift`, `flo/Shared/Models/ScanStatus.swift`, `flo/Shared/Models/Radio.swift`, `flo/Shared/Models/ArtistRadio.swift`, `flo/Shared/Models/Album.swift`.

## Watch app addition

flo now includes an Apple Watch app under `flo/Watch/`. The Watch uses `WatchConnectivityManager` to send commands to the main app, which `PlaybackCoordinator` routes to `PlayerViewModel`. The coordinator attaches to `PlayerViewModel` weakly, so any change to the player lifecycle must also consider whether the Watch still has a valid target.

Files: `flo/Watch/WatchRootView.swift`, `flo/Watch/WatchLibraryViewModel.swift`, `flo/Shared/Services/WatchConnectivityManager.swift`, `flo/Shared/Services/PlaybackCoordinator.swift`.

## CarPlay addition

CarPlay support is implemented under `flo/CarPlay/`. The CarPlay scene delegates to `CarPlaySceneDelegate`, and playback is coordinated through `CarPlayCoordinator` and `CarPlayNowPlayingManager`. CarPlay shares the same `PlayerViewModel` singleton, so changes to the player command center or Now Playing metadata affect CarPlay immediately.

Files: `flo/CarPlay/CarPlaySceneDelegate.swift`, `flo/CarPlay/CarPlayCoordinator.swift`, `flo/CarPlay/CarPlayNowPlayingManager.swift`.

## IAP auth mode

`AuthMode` was extended from `.standard` to also support `.iap` (Identity-Aware Proxy). The auth mode is stored in the Keychain/file-backed store alongside credentials. If a user switches from standard to IAP, the password is removed and `saveLoginInfo` is disabled. Be careful with backward compatibility: older versions of the app do not know about `AuthMode.iap`, so they may treat the stored credentials as standard and fail to log in. The `KeychainManager` also stores `IAPAuthInfo` under a separate key.

Files: `flo/AuthMode.swift`, `flo/Shared/Services/AuthService.swift`, `flo/Shared/Services/KeychainManager.swift`, `flo/AuthViewModel.swift`.

## Stream cache and library cache introduction

`StreamCacheManager` and `LibraryCacheManager` were added to improve offline playback and reduce server load. The stream cache is optional and controlled by `UserDefaultsManager.streamCacheMaxSize`. When the setting is off, no stream cache records are created. The library cache stores JSON snapshots of fetched data. Because these caches live in `Caches/` and `CacheEntity`, they are not part of Core Data migrations; clearing the cache or reinstalling the app loses them. Downloads under `Documents/Media/` are preserved across app updates (unless the user deletes the app).

Files: `flo/Shared/Services/StreamCacheManager.swift`, `flo/Shared/Services/LibraryCacheManager.swift`, `flo/Shared/Services/UserDefaultsManager.swift`.

## Keychain service name compatibility

`KeychainKeys.service` uses the legacy value `net.faultables.flo` on iOS to avoid logging existing users out on upgrade. On Mac Catalyst it uses `Bundle.main.bundleIdentifier` because the Keychain is namespaced by bundle ID. Changing the iOS service name would require a migration step to read the old value and rewrite it under the new service, or existing users would lose their saved credentials.

File: `flo/Shared/Utils/Constants.swift`, lines 67-75.

## Saved auth mode and credential shape

`AuthService` decodes the stored credential JSON into `UserAuth`. `UserAuth` has an explicit `init(from decoder:)` that defaults `lastFMApiKey` to `""` if missing. Adding new required fields to `UserAuth` will break stored credentials unless the decoder handles missing values. The `authMode` key is stored separately and may be absent on older installs; the default is `.standard`.

File: `flo/Shared/Models/UserAuth.swift`, `flo/Shared/Services/AuthService.swift`, `flo/Shared/Services/KeychainManager.swift`.

## Backward-compatibility concerns summary

| Area | Concern | Mitigation in code |
| --- | --- | --- |
| Core Data container name | Renaming would drop data | Hard-coded `name: "flo"` in `CoreDataManager`. |
| Keychain service name | Changing would log users out | iOS keeps `net.faultables.flo` legacy service. |
| Mac Catalyst keychain | Sandboxing or signing changes break fallback | `FileBackedCredentialStore` is the fallback. |
| Subsonic response models | Mixed old/new wrappers | Prefer `SubsonicResponse<T>` for new models. |
| `UserAuth` shape | New required fields break stored creds | Decoder defaults `lastFMApiKey`; mimic for future fields. |
| `AuthMode` | Older versions do not understand `.iap` | Stored mode falls back to `.standard` when unknown. |
| Download paths | Moving or renaming `Media/` breaks existing files | Paths are hard-coded in `AlbumService` and `LocalFileManager`. |
| Stream cache | Enabling/disabling changes cache behavior | Default is off; existing `CacheEntity` records survive until reconciled. |
