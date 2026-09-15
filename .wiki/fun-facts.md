# Fun facts

A handful of small, interesting things about the `flo` codebase that do not fit neatly into a statistics page or a historical timeline.

## 1. The oldest surviving code is in the player and the services

`flo/PlayerViewModel.swift` and `flo/Shared/Services/AlbumService.swift` both date to the first week of June 2024. The file header on `PlayerViewModel.swift` says `Created by rizaldy on 05/06/24`, and `AlbumService.swift` says `08/06/24`. The earliest meaningful commit for `AlbumService` is `feat: add AlbumService singleton` on `2024-06-26`. The `PlayerViewModel` still holds the same root responsibilities it had then: managing an `AVPlayer`, observing interruptions, and exposing the current queue.

The longest-lasting logic is probably the Subsonic stream URL construction in `flo/Shared/Services/AlbumService.swift`:

```swift
"\(UserDefaultsManager.serverBaseURL)\(API.SubsonicEndpoint.stream)\(AuthService.shared.getCreds(key: "subsonicToken"))&id=\(id)&maxBitRate=\(maxBitrate)&format=\(format)"
```

That line has survived the `OfflineData -> flo` rename, offline downloads, stream caching, and CarPlay, which is about as close to "foundational code" as the repo gets.

## 2. Naming: flo, flo+, and Flooo

- **flo**: the app name is hard-coded as `AppMeta.name = "flo"` in `flo/Shared/Utils/Constants.swift`. The bundle identifier is `net.faultables.flo`, and the project is associated with the `kepelet` GitHub organization. The README refers to the project simply as "flo" and links to a landing page at `client.flooo.club`.
- **flo+**: this is the in-app purchase product. `UserDefaultsKeys.floPlus` stores the purchase state, `InAppPurchaseManager` uses `floPlusProductID = "flo.plus"`, and `PreferencesView.swift` has several blocks that display the price label, purchase button, and "Unable to Purchase flo+" alert. The plus appears to be a tip/premium tier rather than a separate app.
- **Flooo**: the origin is less clear. `FloooViewModel` was originally `ScanStatusViewModel` before the rename on `2025-01-11`. The `FloooService` was introduced on `2024-11-28`. The triple-o spelling appears to be a playful brand variant, used for the server-status / scrobble / listening-history feature and the landing domain (`flooo.club`). It does not show up in the App Store-facing app name; it is an internal project nickname.

## 3. TODO and FIXME are concentrated but not overwhelming

A grep across the Swift source finds 36 `TODO` or `FIXME` markers. The densest files are:

- `flo/Shared/Services/AlbumService.swift` — 7 markers.
- `flo/Shared/Services/APIManager.swift` — 5 markers.
- `flo/Navigation/PreferencesView.swift` — 4 markers.
- `flo/FloooViewModel.swift` — 4 markers.
- `flo/PlayerViewModel.swift` — 3 markers.
- `flo/AlbumViewModel.swift` — 3 markers.

Some of the oldest and most specific markers:

- `flo/Shared/Services/APIManager.swift:12` — `// TODO: refactor this`.
- `flo/Shared/Models/Album.swift:22` — `// FIXME: constants?`.
- `flo/AlbumViewModel.swift:33` — `// TODO: add logic to check server-side config`.
- `flo/PlayerViewModel.swift:45` — `// FIXME: this make confusion with `isDownloaded` and/or `isPlayingFromLocal``.
- `flo/StatCardView.swift:34` — `// FIXME: use `showArrow` after implement deeplinks`.

The TODO/FIXME count is low enough that the project does not feel abandoned, but it is high enough that a newcomer has a clear map of where the maintainers already know the code is incomplete.

## 4. The longest single file is the player view model

The longest Swift file is `flo/PlayerViewModel.swift` at 863 lines. It is followed by `flo/CarPlay/CarPlayCoordinator.swift` at 847 lines and `flo/Navigation/PreferencesView.swift` at 741 lines. The CarPlay file being nearly as large as the player view model is a good measure of how much CarPlay integration added to the codebase in a short period.

## 5. The app identifier lives in the keychain past its name

`flo/Shared/Utils/Constants.swift` contains a deliberate comment about backward compatibility for keychain service names:

```swift
// On iOS the app has historically shipped with this fixed service name; keep it
// to avoid logging existing users out on upgrade. On Mac Catalyst the keychain
// is namespaced by app bundle id, so use that to ensure writes succeed.
```

This is a small but real example of the project carrying its early history forward: the original `net.faultables.flo` keychain service name is preserved on iOS even after the Mac Catalyst target was added.

## 6. There is a `SubsonicApiVersion` constant that questions itself

In `flo/Shared/Utils/Constants.swift`:

```swift
static let subsonicApiVersion = "1.16.1"  // FIXME: should we respect the subsonic-response?
```

It is a single-line joke/comment that also captures the project's attitude: pragmatic, Navidrome-first, but aware that the Subsonic API has its own versioning conventions.

## 7. Gitflow is described as aspirational

The README explains the intended branching model (`main`, `develop`, `release/xxx`, `features/yyy`, `bugfix/zzz`), then immediately admits that "realistically, sometimes feature branches are unnecessary, as the project doesn't run tests (yet) and the developer tests the app anyway." That parenthetical "(yet)" is a small window into the project's priorities: the tooling is still lighter than the documentation suggests.
