# TODOs and FIXMEs

This page lists all TODO, FIXME, HACK, and XXX markers found in the flo Swift source. They are grouped by file and include the comment text and line number. The oldest markers can be identified by the file creation dates in the header comments.

## `flo/Shared/Services/APIManager.swift`

- Line 12: `// TODO: refactor this` — on the `NetworkLoggerEventMonitor` struct that wraps Pulse logging.
- Line 87: `// FIXME: refactor getCreds(key: "subsonicToken")` — inside `SubsonicEndpointRequest`.
- Line 100: `// FIXME: refactor later` — above the `SubsonicEndpointDownloadNew` method.
- Line 108: `// FIXME: refactor getCreds(key: "subsonicToken")` — inside `SubsonicEndpointDownloadNew`.
- Line 136: `// FIXME: refactor getCreds(key: "subsonicToken")` — inside `SubsonicEndpointDownload`.

These markers suggest the Subsonic credential handling is duplicated across several methods. A good cleanup would be to centralize the URL construction in one helper method and remove the repeated calls to `AuthService.shared.getCreds(key: "subsonicToken")`.

## `flo/Shared/Services/AuthService.swift`

- Line 113: `// FIXME: temporary solution` — password redaction regex in `login`.
- Line 120: `// FIXME: move to general Logger` — the Pulse logging call after redaction.

The password redaction should be replaced with a more robust log sanitizer or moved to a dedicated logging utility. A general `Logger` would also let the `IAP` login path share the same logging behavior.

## `flo/Shared/Services/AlbumService.swift`

- Line 97: `// FIXME: get all songs for now` — in `getSongFromAlbum`.
- Line 120: `// FIXME: now we fetch all albums. let's see if this will affect performance` — in `getAlbum`.
- Line 149: `// TODO: now we fetch all albums. let's see if this will affect performance` — in `getAlbumsByArtist`.
- Line 179: `// FIXME: currently we can't stream from the local (offline) one :)` — in `getSongsByPlaylist`.
- Line 201: `// FIXME: load it all!!!` — in `getAllSongs`.
- Line 440: `// FIXME: refactor later` — above `downloadNew`.
- Line 468: `// FIXME: the parameters are so damn long` — above the `download` method.

Several of these are about fetching unbounded data. The cleanup could introduce pagination, move the limit logic into the callers, or add a `MediaLibraryService` that separates local and remote data. The `download` and `downloadNew` methods should be merged or split into a download coordinator with a small parameter object.

## `flo/PlayerViewModel.swift`

- Line 45: `// FIXME: this make confusion with `isDownloaded` and/or `isPlayingFromLocal`` — on `_playFromLocal`.
- Line 611: `// TODO: handle experience saat album abis -> balik ke index 0 -> prevSong() -> expect nya i guess ke index .count?` — in `prevSong`.
- Line 624: `// TODO: refactor later ngantuk bosss` — in `nextSong`.

The playback state flags (`_playFromLocal`, `isLocallySaved`, `isPlayingFromLocal`) need clarification. The `nextSong` and `prevSong` logic is verbose and could be replaced with a small queue navigation helper.

## `flo/Navigation/PreferencesView.swift`

- Line 266: `// TODO: is this safe?` — on the server URL display in the Server Information section.
- Line 291: `// TODO: finish this later` — on the disabled "Make it yours" theme section.
- Line 344: `// TODO: finish this later` — on the disabled Experimental theme section.
- Line 450: `// TODO(@fariz): uncomment this on 2.2` — on the commented-out `Purchase flo+` button.

The server URL display should be reviewed from a privacy standpoint. The unfinished theme and flo+ purchase sections should either be completed or removed to keep the file focused.

## `flo/Shared/Services/CoreDataManager.swift`

- Line 36: `//FIXME: constants?` — on the `NSPersistentContainer(name: "flo")` call.

This is the model name. It could be moved to a `CoreDataConstants` or `AppMeta` constant to avoid hardcoding the string.

## `flo/Shared/Models/Album.swift`

- Line 22: `// FIXME: constants?` — on the `subsonic-response` coding key.
- Line 61: `// FIXME(@faultables): fix this in 2.x` — on the backward-compatible `artist` decoding.

The `subsonic-response` key is shared with other Subsonic response models. A `SubsonicResponseCodingKeys` enum or extension would remove duplication. The backward-compatible `artist` decoding should be revisited for the next major release.

## `flo/Shared/Utils/Constants.swift`

- Line 50: `// FIXME: should we respect the subsonic-response?` — on the `subsonicApiVersion` value.

The app hardcodes Subsonic API version 1.16.1. The fix is to read the version from the server response after login or from a configuration endpoint.

## `flo/Shared/Utils/Fonts.swift`

- Line 64: `// FIXME: this is fishy` — on the `customFont` view modifier that applies a foreground color.

The modifier applies `.foregroundColor(.accent)` to every text style, which may not be intended. Review whether the color should be part of the font modifier or left to the call site.

## `flo/StatCardView.swift`

- Line 34: `// FIXME: use `showArrow` after implement deeplinks` — in the `StatCard` initializer.

The `showArrow` parameter is ignored and set to `false`. This should be wired up once deeplinks are implemented, or the parameter should be removed until it is needed.

## `flo/FloooViewModel.swift`

- Line 37: `// FIXME: i think everything that is related to listening history and stats should live in FloooViewModel` — a structural note.
- Line 40: `// TODO: is this ok?` — on the `getListeningHistory` implementation.
- Line 164: `// TODO: handle when this fail` — on `sendScrobble` failure handling.
- Line 165: `// TODO: also, add "check offline mode" later` — on scrobble failure handling.

The listening history and stats logic is partially in `FloooViewModel` and partially in `FloooService`. Consolidating the logic and adding offline handling would improve consistency.

## `flo/AuthViewModel.swift`

- Line 47: `// TODO: invalidate authz token somewhere here` — in the `init` that restores the saved login.
- Line 130: `// TODO: how to deal with "last playing" data?` — in `logout`.

The authorization token validation and last-playing data cleanup need explicit handling during restore and logout.

## `flo/AlbumViewModel.swift`

- Line 33: `//TODO: add logic to check server-side config` — on `refreshAlbums`.
- Line 42: `//TODO: add logic to check server-side config` — on `refreshArtists`.
- Line 422: `// TODO: is this expensive?` — on the downloaded album filtering in `fetchDownloadedAlbums`.

The server-side config checks would let the app respect Navidrome settings. The downloaded album filtering could be replaced with a Core Data fetch that joins `PlaylistEntity` and `SongEntity`.

## Oldest markers

Based on the file creation dates in the header comments, the oldest markers are in:

- `flo/PlayerViewModel.swift` (created 05/06/24) — line 45, line 611, line 624.
- `flo/Shared/Utils/Constants.swift` (created 06/06/24) — line 50.
- `flo/Shared/Models/Album.swift` (created 07/06/24) — line 22, line 61.
- `flo/Shared/Services/APIManager.swift` (created 08/06/24) — line 12, line 87, line 100, line 108, line 136.
- `flo/Shared/Services/AuthService.swift` (created 08/06/24) — line 113, line 120.

These files were created in June 2024 and have carried their markers since then. They are the best starting point for cleanup work that stabilizes the core networking and playback logic.

## Related pages

- [Complexity hotspots](complexity-hotspots.md) — the largest files, many of which also contain the markers above.
- [How to contribute](/droid-wiki/how-to-contribute/index.md) — workflow and pull request expectations.
