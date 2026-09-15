# Design decisions

Active contributors: rizaldy, docmeth02, Piekay, Francesco, faultables, SindreKjelsrud, Ed Poe, Simon Risse.

## Why singletons

flo uses shared service singletons (`APIManager.shared`, `AuthService.shared`, `AlbumService.shared`, `CoreDataManager.shared`, `PlayerViewModel.shared`, and so on). The architecture is pragmatic MVVM: the UI talks to view models, and the view models talk to shared service singletons. This avoids dependency injection complexity and keeps the project small, which is important because the project deliberately limits dependencies (see "Minimal dependency policy" below). The trade-off is that singletons can make testing harder and create hidden coupling, but for a small Swift/SwiftUI project they keep the call sites simple and consistent.

Relevant: `flo/Shared/Services/APIManager.swift`, `flo/Shared/Services/AuthService.swift`, `flo/PlayerViewModel.swift`.

## Why Core Data

Core Data is used for the offline library, playback queue, and stream cache metadata. It is chosen because it is the built-in Apple persistence framework, requires no extra dependency, and provides an object graph that works well with SwiftUI. The schema is small: `QueueEntity`, `SongEntity`, `PlaylistEntity`, and `CacheEntity`. The project does not use heavy Core Data features such as migrations or complex relationships; it mostly treats it as a queryable object store.

Relevant: `flo/Shared/Services/CoreDataManager.swift`, `flo/flo.xcdatamodeld`.

## Why two API surfaces (Navidrome + Subsonic)

Navidrome exposes its own REST API for richer metadata (albums, artists, playlists, songs, shares, scrobbling), while Subsonic-compatible endpoints are used for operations that are standardized across Subsonic servers: streaming, downloading, cover art, scan status, starring, and radios. This split lets flo take advantage of Navidrome-specific features while keeping the audio path compatible with the broader Subsonic ecosystem. The cost is that every feature must decide which surface to use, and some endpoints need the same entity mapped differently.

Relevant: `flo/Shared/Utils/Constants.swift`, `flo/Shared/Services/AlbumService.swift`, `flo/Shared/Services/FloooService.swift`.

## Why the file-backed credential store on Mac Catalyst

The system Keychain on Mac Catalyst returns `errSecMissingEntitlement` (-34018) when the app is not sandboxed or signed with a real development certificate plus `keychain-access-groups`. The project avoids sandboxing because it would relocate the app's data container and drop existing downloads. It also avoids requiring a paid developer certificate for local builds. The compromise is `FileBackedCredentialStore`: each credential is stored as a file under `~/Library/Application Support/<bundle-id>/Credentials/` with `0600` permissions, so macOS file-system ownership restricts access to the current user account. This matches the practical threat model the Keychain usage already relied on.

Relevant: `flo/Shared/Services/KeychainManager.swift` (lines 11-40 and `FileBackedCredentialStore`).

## Why downloads are stored under `Media/<Artist>/<Album>/`

Downloads mirror a human-readable music folder layout: `Media/<Artist>/<Album>/<trackNumber> <title>.<suffix>`. Playlists are grouped under `Media/Various Artists/<PlaylistName>/`. This makes the downloaded content easy to browse outside the app and matches how users typically expect local music files to be organized. The same path is stored in `SongEntity.fileURL` and reused by the player and cover art lookup.

Relevant: `flo/Shared/Services/AlbumService.swift` (`saveDownload` and `downloadNew`).

## Why the stream cache is separate from downloads

Downloads are explicit user actions: they are permanent, organized, and meant to work offline. The stream cache is implicit: it holds recently streamed tracks in `Caches/StreamCache/` and evicts by least-recent access when a size limit is reached. Keeping them separate lets the app distinguish between "I want this forever" and "I might want this again soon" without complicating the download logic. The stream cache is also bitrate-keyed (`<mediaFileId>_<bitrate>`), so a user can cache different transcodings of the same source file.

Relevant: `flo/Shared/Services/StreamCacheManager.swift`, `flo/Shared/Services/LocalFileManager.swift`.

## Why MVVM over Clean Architecture

The project uses pragmatic MVVM with shared service singletons rather than Clean Architecture, VIPER, or The Composable Architecture. The goal is to keep the codebase accessible to Swift/SwiftUI developers without introducing extra layers, protocols, or indirection. The project has only four external dependencies (Alamofire, KeychainAccess, Nuke, Pulse), and the architecture is chosen to match that minimalism.

Relevant: `flo/PlayerViewModel.swift`, `flo/AuthViewModel.swift`, `flo/FloooViewModel.swift`, `flo/AlbumViewModel.swift`.

## Minimal dependency policy

Dependencies are intentionally limited to:

- Alamofire — networking
- KeychainAccess — iOS Keychain wrapper
- Nuke — image loading
- Pulse — network debug logging

This is documented in the README. The policy exists to keep the project easy to build, maintain, and review. Before adding a new dependency, the preference is to use Apple's built-in frameworks or extend an existing singleton service.

Relevant: `/home/exedev/flo/README.md` (Development section).
