# Lore

This is a narrative history of the `flo` codebase, reconstructed from the git log and tags. Dates are approximate; where git records only a time-stamp, I have translated it into a month or week. Phases and interpretations are my own and should be read as "best-effort reconstruction" rather than an official project timeline.

## Project overview

`flo` is an open-source Navidrome client written in Swift and SwiftUI. It began as a small SwiftUI project in June 2024, grew through the 1.x release series on the App Store, and expanded into a multi-platform Apple app in the 2.x series. The default branch is `develop`, which has been the main working branch since the beginning.

## Era 1: Prototype (June 2024)

- **2024-06-14**: Repository created with the first commits, README, and MIT license.
- **2024-06-24**: The first playback plumbing arrives: `AVAudioSession`, simple playback modes, and a `NowPlaying` model moved into the `Models` group.
- **2024-06-26**: The three core singletons of the app appear: `AlbumService` (`flo/Shared/Services/AlbumService.swift`), the first queue, and persistence for the queue and playback mode via `UserDefaults`.
- **2024-06-27**: The code pivots to singletons across the app, a pattern that remains in place today.

This era is the closest thing to a clean-sheet prototype. The `PlayerViewModel` root, the `AlbumService` stream URL builder, and the shared-service singletons all trace back to the last week of June 2024.

## Era 2: First feature set (July–August 2024)

- **2024-07-31**: Share-album support, icons, and general quality-of-life changes.
- **2024-08-01**: Downloads begin with `SubsonicEndpointDownload` and the first download logic.
- **2024-08-28**: A major rename: `OfflineData` becomes `flo`. This is the most visible early refactor and the point at which the project name settled on the current repository identity.
- **2024-08-28–2024-09-06**: Offline playback optimization, including adjustments to stream handling and the first iteration of local file management.

The app is still iOS-only at this stage, and the core architecture is a flat list of SwiftUI views plus a handful of shared services.

## Era 3: App Store launches and the 1.x release cycle (September 2024–January 2025)

- **2024-09-08**: Tag `1.0.0+1000` — the first public release.
- **2024-09-14**: Tag `1.1.0`.
- **2024-09-27**: Tag `1.2.0` with a Fastlane tooling update.
- **2024-11-13**: Navigation migration from `NavigationView` to `NavigationStack`, and the introduction of an experimental debug toggle.
- **2024-11-17**: `Playlist` and `Artist` entities are added, along with `PlaylistView` and individual song downloads.
- **2024-11-18**: Tag `1.3.0`.
- **2024-11-28**: Tag `1.4.0` and the introduction of an alternative app icon and a "flo" alt icon. The `FloooService` and `Stats` model also appear this week, seeding the later scrobble/listening-history features.
- **2024-12-31**: Tag `1.5.0`.
- **2025-01-11**: `ScanStatusViewModel` is renamed to `FloooViewModel`, the name that survives today in `flo/FloooViewModel.swift`.
- **2025-01-19**: Tag `1.6.0`.
- **2025-03-16**: Tag `1.6.1` with a compatibility fix for Navidrome BFR versions.

This is the commercialization phase. The repository moves from a personal prototype to a release-managed App Store project with a fastlane pipeline, version tags, and the first touches of analytics/social features via `FloooService`.

## Era 4: The 1.7 interlude and deeper playback features (mid-2025)

- **2025-07-15**: Version bump and `Subsonic` response parsing tweaks.
- **2025-07-23**: Track sorting is refined to use disc number and track number, and playlist playback is no longer forced into track-number order.
- **2025-09-08**: Tag `1.7`.
- **2025-09-13**: Queue performance improvements: batch Core Data inserts and `LazyVStack` for the music queue.

Between 1.6 and 2.0 the pace slows and the work focuses on playback correctness, queue performance, and laying groundwork for the next major release. `1.7` appears to be a stability release before the larger architectural changes of 2.0.

## Era 5: The 2.0 expansion (February 2026)

- **2026-02-02**: Lyrics integration via LRCLIB, `LyricsView`, and the first experimental feature flag for lyrics.
- **2026-02-04**: Web radios are added, including a `RadiosView` and radio-specific player controls.
- **2026-02-08**: Mac Catalyst support begins, alongside a major redesign of the floating player and a new `FloatingPlayerView` style.
- **2026-02-13**: Core Data fallback to an in-memory container, stream URL resolution hardening, and crash fixes around stream loading.
- **2026-02-16**: Tag `2.0`.
- **2026-02-17**: The Apple Watch companion app is initialized (`flo/Watch` target).
- **2026-02-18**: WatchKit app bundle and first watch UI.
- **2026-02-21**: Navidrome artist radio and top songs support.
- **2026-02-22**: Initial Apple CarPlay support, and the artist-detail refactor to use a view model.
- **2026-02-24**: In-app purchase preparation begins, and an alternative app icon is added.
- **2026-02-26**: Tag `2.1` with artist radio/top songs in CarPlay.

2.0 is the largest expansion of the project: CarPlay, watchOS, web radios, lyrics, and Mac Catalyst all land within a few weeks. It is also when the code starts to show platform-specific strain, with a commit on `2026-03-06` titled "fix: restore Watch target accidentally removed in CarPlay PR".

## Era 6: Platform parity and the caching overhaul (March–April 2026)

- **2026-03-02**: Spurious IAP error alert is suppressed on the preferences screen.
- **2026-03-06**: CarPlay PR review fixes; the Watch target is restored.
- **2026-03-08**: In-app purchase support is added.
- **2026-03-14**: Save-login-info is disabled for IAP users.
- **2026-03-15**: The app migrates to a UIKit `AppDelegate`/`SceneDelegate` lifecycle, required for CarPlay integration.
- **2026-03-17**: Tag `2.2` with loading indicators on download tabs.
- **2026-03-24**: A major caching rework lands, caching stream audio, library metadata, and cover art. This is the single biggest change in the 2.x series and enables offline-first behavior for CarPlay and the main app.
- **2026-03-24**: ListenBrainz and Last.fm account status checks are fixed.
- **2026-04-12**: Cached songs and Liked Songs are added to the CarPlay Downloads and Library tabs.
- **2026-04-21**: Tag `2.3`.
- **2026-04-26**: Mac Catalyst support is revisited with a batch of fixes, including iPad sidebar Library submenus, floating-player layout on iPadOS 18+, and full-screen slide-off behavior on iOS after the Catalyst change.

This era is best understood as "make the new platforms work as well as iOS." The caching rework is the technical centerpiece; the CarPlay and Catalyst work are the platform-centering effort.

## Era 7: Current stabilization (May 2026–present)

- **2026-05-17**: A flurry of icon work — "create icons from Icon Composer" and related icon fixes — suggesting the project is preparing for a store-facing release or refreshed marketing assets.

No further tags appear after 2.3, but the branch remains active on `develop`.

## Longest-standing features still in use

- **Singleton services**: the shared service pattern (`AlbumService`, `AuthService`, `APIManager`) dates to June 2024 and is still the backbone of the app.
- **Queue + playback mode persistence**: `UserDefaults` persistence for the queue and playback mode was added in June 2024 and remains unchanged at the storage level.
- **Subsonic stream URL construction**: `AlbumService.buildRemoteStreamUrl` still builds the same Subsonic stream URL with the token, id, max bit rate, and format parameters that were established in early 2024.
- **`PlayerViewModel`**: the root playback class is one of the oldest surviving files, with its file header dated June 2024.
- **`FloooViewModel`**: the name has stuck since January 2025 and is used for scrobbling, listening history, and server stats.

## Deprecated or removed features

Nothing is explicitly deprecated or removed in a way that the git log captures. The `FloatingPlayerGlassView` was removed in favor of `FloatingPlayerView` in February 2026, but that is better described as a UI redesign than a deprecation. There is no "CHANGELOG-removed" section or clear feature deletion. If the project has a formal deprecation policy, it is not visible in the source history.

## Major rewrites or migrations

- **`OfflineData -> flo` rename** (August 2024): the project identity moved from a generic offline-data concept to the named `flo` product.
- **Singletonization** (June 2024): the first architectural decision, moving from ad-hoc instances to shared singletons, still defines the codebase.
- **`NavigationView` -> `NavigationStack`** (November 2024): a SwiftUI navigation modernization.
- **Watch and CarPlay additions** (February 2026): the app went from a single iOS target to a multi-target Xcode project with watchOS and CarPlay extensions.
- **IAP auth** (March 2026): introduced the `AuthService`/`APIManager` IAP login path (`API.NDEndpoint.loginIAP`) and the `floPlus` purchase flag.
- **Stream cache rework** (March 2026): replaced the earlier download-only approach with a unified cache for audio, metadata, and cover art, implemented in `flo/Shared/Services/StreamCacheManager.swift`.
- **UIKit lifecycle migration** (March 2026): required for CarPlay, switching from a pure SwiftUI app lifecycle to `AppDelegate`/`SceneDelegate`.
- **Mac Catalyst support** (February–April 2026): a multi-pass effort to make the iPad UI work on the Mac runtime.

## Growth trajectory

- **Files**: the repository started with a handful of Swift files in June 2024 and now contains 98 `.swift` files plus supporting configuration and resources.
- **Targets**: the original iOS app has been joined by a watchOS app (`flo/Watch`), a CarPlay coordinator (`flo/CarPlay`), and Mac Catalyst support within the same Xcode project.
- **Services**: the initial `AlbumService` + ad-hoc networking has grown into a service layer that includes `AuthService`, `APIManager`, `StreamCacheManager`, `InAppPurchaseManager`, `KeychainManager`, `WatchConnectivityManager`, `PlaybackCoordinator`, and `CoreDataManager`.
- **Models**: `Album` and `Song` were joined by `Artist`, `Playlist`, `Radio`, `ArtistRadio`, `NowPlaying`, `Subsonic`, `UserAuth`, `Stats`, `ScanStatus`, and `AccountLinkStatus`.
- **UI depth**: what began as a flat `ContentView`/`PlayerView` hierarchy now has dedicated `Navigation` views, `Artists`, `Radios`, watch screens, and CarPlay templates.

The overall trajectory is a pragmatic expansion: the core remains the June 2024 playback and service model, while each release cycle added a new platform, a new feature class, or a polish pass.
