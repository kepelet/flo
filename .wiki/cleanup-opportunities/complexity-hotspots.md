# Complexity hotspots

This page lists the largest Swift files in the flo project by line count, identifies the files that carry the most responsibility, and suggests where to start refactoring.

## Top 20 Swift files by line count

| Rank | Lines | File |
| --- | --- | --- |
| 1 | 863 | `flo/PlayerViewModel.swift` |
| 2 | 847 | `flo/CarPlay/CarPlayCoordinator.swift` |
| 3 | 741 | `flo/Navigation/PreferencesView.swift` |
| 4 | 585 | `flo/Shared/Services/AlbumService.swift` |
| 5 | 563 | `flo/PlayerView.swift` |
| 6 | 435 | `flo/AlbumViewModel.swift` |
| 7 | 393 | `flo/AlbumView.swift` |
| 8 | 364 | `flo/ContentView.swift` |
| 9 | 331 | `flo/Shared/Services/StreamCacheManager.swift` |
| 10 | 298 | `flo/DownloadViewModel.swift` |
| 11 | 285 | `flo/Shared/Services/WatchConnectivityManager.swift` |
| 12 | 284 | `flo/Navigation/LibraryView.swift` |
| 13 | 264 | `flo/Shared/Services/KeychainManager.swift` |
| 14 | 252 | `flo/Shared/Utils/IAPLoginView.swift` |
| 15 | 250 | `flo/Shared/Utils/IAPWebView.swift` |
| 16 | 249 | `flo/LyricsView.swift` |
| 17 | 244 | `flo/AuthViewModel.swift` |
| 18 | 231 | `flo/LoginView.swift` |
| 19 | 229 | `flo/Shared/Services/PlaybackCoordinator.swift` |
| 20 | 213 | `flo/Shared/Services/AuthService.swift` |

These counts include comments and blank lines. The top five files account for a large share of the total project logic, so improving them has the biggest impact on readability and maintainability.

## Candidates for refactoring

### `flo/PlayerViewModel.swift` (863 lines)

This is the largest file in the project. It manages AVPlayer state, the queue, playback mode, lyrics, scrobbling, remote command center handling, and audio route updates. It is also one of the oldest files, with several TODO and FIXME markers.

Cleanup ideas:

- Extract queue management into a `PlaybackQueue` class or actor. This includes `addToQueue`, `playFromQueue`, `nextSong`, `prevSong`, `shuffleCurrentQueue`, and queue restoration.
- Extract Now Playing info and remote command center setup into a `NowPlayingController`.
- Extract lyrics handling into a `LyricsViewModel` or `LyricsController`.
- Extract the audio session and route change observations into a small `AudioSessionController`.
- Clarify the relationship between `_playFromLocal`, `isLocallySaved`, and `isPlayingFromLocal`.

### `flo/CarPlay/CarPlayCoordinator.swift` (847 lines)

This file is almost as large as the player view model and is responsible for the CarPlay interface. CarPlay templates tend to be verbose, but the file should still be split into smaller helpers if possible.

Cleanup ideas:

- Split template creation into separate functions or classes per scene (browse, queue, now playing).
- Extract data source helpers into a `CarPlayDataSource` that talks to `AlbumService`.
- Share as much logic as possible with the iOS player to avoid duplicating playback state handling.

### `flo/Navigation/PreferencesView.swift` (741 lines)

The preferences view is one large SwiftUI file with many sections, view models, and helper views. It also contains unfinished features and disabled sections.

Cleanup ideas:

- Move `AppIconViewModel` and `FloPlusSheet` to their own files in `flo/Navigation/` or `flo/Shared/ViewModels/`.
- Split the preferences form into sub-views such as `LocalStorageSection`, `ServerInformationSection`, `ExperimentalSection`, and `TroubleshootSection`.
- Remove or finish the disabled "Make it yours" and experimental theme sections.
- Move the `getAppVersion` and `getBuildNumber` helpers into a shared utility.

### `flo/Shared/Services/AlbumService.swift` (585 lines)

AlbumService mixes remote API calls, local file lookups, Core Data persistence, and cover art resolution. It also has the most TODO and FIXME markers of any service.

Cleanup ideas:

- Split the file into `AlbumService` (remote API), `DownloadService` (downloads and offline files), and `CoverArtService` (cover art resolution and caching).
- Replace the duplicated `getCreds(key: "subsonicToken")` calls with a single URL builder.
- Introduce pagination for the unbounded album, song, and artist fetches.
- Merge `download` and `downloadNew` or move the download logic into a dedicated coordinator.

### `flo/PlayerView.swift` (563 lines)

This is the main SwiftUI player screen. It is mostly UI, but it still holds a lot of presentation logic.

Cleanup ideas:

- Extract subviews such as the controls, progress bar, artwork, lyrics, and queue.
- Move gesture handling and layout constants into small helper views or modifiers.
- Keep `PlayerView` as the top-level container that wires together the smaller views.

## Other files worth watching

- `flo/AlbumViewModel.swift` (435 lines) — handles caching, album loading, and downloads. Could be split into a cache layer and a view model.
- `flo/AlbumView.swift` (393 lines) — the album detail UI. Could be split into header, song list, and action sections.
- `flo/ContentView.swift` (364 lines) — the root tab and navigation container. Keep it small by moving tab-specific logic into the child views.
- `flo/Shared/Services/StreamCacheManager.swift` (331 lines) — manages the on-disk streaming cache. Could be split into a cache manager and a cleanup policy.
- `flo/Shared/Services/PlaybackCoordinator.swift` (229 lines) — coordinates playback with the watch and system. Watch this file as it grows alongside `PlayerViewModel`.

## Where to start

If you are new to the codebase, start with the smallest high-impact cleanup:

1. `flo/Shared/Utils/Constants.swift` and `flo/Shared/Models/Album.swift` — extract the repeated `subsonic-response` string and hardcoded model names.
2. `flo/Shared/Services/APIManager.swift` — centralize the Subsonic URL builder.
3. `flo/PlayerViewModel.swift` — extract the queue navigation logic into a helper class.
4. `flo/Shared/Services/AlbumService.swift` — split the download and cover art helpers into separate services.

Each step should be paired with manual testing on a device or simulator because the project has no automated tests. See [Testing](/droid-wiki/how-to-contribute/testing.md) for guidance on where to add tests as you refactor.

## Related pages

- [TODOs and FIXMEs](todos-and-fixmes.md) — the markers inside these large files.
- [How to contribute](/droid-wiki/how-to-contribute/index.md) — how to open a cleanup pull request.
- [Testing](/droid-wiki/how-to-contribute/testing.md) — how to test changes while refactoring.
