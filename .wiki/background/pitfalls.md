# Pitfalls

Active contributors: rizaldy, docmeth02, Piekay, Francesco, faultables, SindreKjelsrud, Ed Poe, Simon Risse.

This page collects rough areas and open questions that appear as `FIXME` or `TODO` comments in the source. They are not blockers, but they are places where a small change can have unexpected consequences.

## PlayerViewModel

### `_playFromLocal` naming confusion

`PlayerViewModel` declares `// FIXME: this make confusion with isDownloaded and/or isPlayingFromLocal` on line 45 above `_playFromLocal`. The flag is set from `audioURL.isFileURL` in `setNowPlaying` and is used in `isPlayFromSource` to decide whether to bypass transcoding. It overlaps conceptually with the queue item's `isFromLocal` and the download state. Be careful when adding new offline/local playback logic; the three concepts are not always aligned.

File: `flo/PlayerViewModel.swift`, around line 45.

### `nextSong` and `prevSong` TODOs

Line 611 contains a TODO about the experience when the album finishes, wraps to index 0, and the user hits previous: the expected behavior is unclear. Line 624 is a TODO to refactor the mode-heavy `nextSong` implementation. The current logic is a series of `if/else` branches for `defaultPlayback`, `repeatAlbum`, and `repeatOnce` that handles both single-track and multi-track queues.

File: `flo/PlayerViewModel.swift`, lines 611 and 624.

## AlbumService

### Long parameter list in `download` and `downloadNew`

Both `download` and `downloadNew` take `artistName`, `albumName`, `id`, `bitrate`, `trackNumber`, `title`, and `suffix`. The source comments this explicitly: `// FIXME: the parameters are so damn long`. The two methods are nearly identical except that `downloadNew` returns the `DownloadRequest` and reports progress, while `download` does not. Refactoring them into a shared builder would reduce duplication and the chance of inconsistent path construction.

File: `flo/Shared/Services/AlbumService.swift`, lines 440 and 468.

### Streaming from local downloads is incomplete

`getSongsByPlaylist` is annotated with `// FIXME: currently we can't stream from the local (offline) one :)`. The same limitation may apply to other callers that try to serve a downloaded playlist offline.

File: `flo/Shared/Services/AlbumService.swift`, line 179.

### "Load it all" fetches

`getAllSongs` and `getAlbum`/`getAlbumsByArtist` use `_start=0, _end=0` to fetch all items. The comments note this is a performance experiment:

- `getAllSongs`: `// FIXME: load it all!!!` (line 201)
- `getAlbum`: `// FIXME: now we fetch all albums. let's see if this will affect performance` (line 120)
- `getAlbumsByArtist`: `// TODO: now we fetch all albums. let's see if this will affect performance` (line 149)
- `getSongFromAlbum`: `// FIXME: get all songs for now` (line 97)

If the library grows large, these endpoints will need pagination or on-demand fetching.

File: `flo/Shared/Services/AlbumService.swift`, lines 97, 120, 149, 201.

## APIManager

### Repeated `getCreds(key: "subsonicToken")` refactor

`APIManager` repeats `AuthService.shared.getCreds(key: "subsonicToken")` in several Subsonic methods. The file opens with `// TODO: refactor this` and each Subsonic caller has `// FIXME: refactor getCreds(key: "subsonicToken")` or `// FIXME: refactor later`. The Subsonic query string should ideally be injected once, or at least read once per request, to make the code easier to test and less error-prone.

File: `flo/Shared/Services/APIManager.swift`, lines 12, 87, 100, 108, 136.

### `NetworkLoggerEventMonitor` TODO

The entire monitor struct is marked `// TODO: refactor this`. It currently forwards task creation, data, metrics, and errors to Pulse's shared logger. Any change to the session configuration (timeouts, retriers, event monitors) must also consider debug logging.

File: `flo/Shared/Services/APIManager.swift`, line 12.

## AuthService

### Password redaction and logging TODOs

`AuthService.login` redacts the password from `debugDescription` before logging it to Pulse, but the comment calls it a `// FIXME: temporary solution`. The logging call itself is marked `// FIXME: move to general Logger`. If a general logger is introduced, this code should be migrated so that redaction happens in one place.

File: `flo/Shared/Services/AuthService.swift`, lines 113 and 120.

## Mac Catalyst keychain limitation

`KeychainManager` switches to a file-backed store on Catalyst because the system Keychain refuses to work for non-sandboxed, ad-hoc builds. The fallback is simple and secure-by-isolation, but it is not the Keychain. Any future sandboxing or signing change must revisit this branch, and the file store's permissions (`0600`) must be preserved on migration.

File: `flo/Shared/Services/KeychainManager.swift`.

## PreferencesView

### `if false` feature blocks

The "Make it yours" section (accent color, player color, font picker) is wrapped in `if false` with a `// TODO: finish this later` comment. The "Experimental" section is also marked `// TODO: finish this later`. The flo+ purchase section is commented out with `// TODO(@fariz): uncomment this on 2.2`. These blocks are dead code today; enabling them requires finishing the backing preferences and UI behavior.

File: `flo/Navigation/PreferencesView.swift`, lines 291, 344, and 450.

### Server URL visibility

Line 266 displays `UserDefaultsManager.serverBaseURL` directly in the preferences UI with a `// TODO: is this safe?` comment. If the server URL contains sensitive tokens or paths, exposing it here may be a privacy concern.

File: `flo/Navigation/PreferencesView.swift`, line 266.

## StreamCacheManager

### `reconcile` behavior

`reconcile()` cancels active downloads, deletes `CacheEntity` records whose files are missing, removes files not tracked by any record, and removes any record still in `downloading` state. It is safe to call but does not retry interrupted downloads; it simply cleans up. If the user expects interrupted cache fills to resume, this behavior will need to change.

File: `flo/Shared/Services/StreamCacheManager.swift`, `reconcile()` method.

### Prefetching only the next track

The periodic time observer triggers cache preloading only after ten seconds of playback and only prefetches the next track in the queue. If the user skips rapidly, the cache will not help. It also skips preloading when the queue has one item or the mode is `repeatOnce`.

File: `flo/Shared/Services/StreamCacheManager.swift`, `cacheSong` and `nextQueueIdxForPreCache` callers in `PlayerViewModel`.

## Other rough areas

### `Album` pre-BFR compatibility

`Album` decoding has a fallback for the old `artist` field with a comment `// FIXME(@faultables): fix this in 2.x`. The model now prefers `albumArtist` and falls back to `artist` when only the older field is present. Removing this fallback is a breaking change for older cached data.

File: `flo/Shared/Models/Album.swift`, line 61.

### `AlbumInfo` response key constant

`AlbumInfo` hard-codes `subsonic-response` as a string in `CodingKeys`, annotated `// FIXME: constants?`. The rest of the project is moving toward `Subsonic.swift` response wrappers.

File: `flo/Shared/Models/Album.swift`, line 22.

### Subsonic API version

`AppMeta.subsonicApiVersion` is fixed at `1.16.1` with a `// FIXME: should we respect the subsonic-response?` comment. The server may report a different version; the app currently ignores it.

File: `flo/Shared/Utils/Constants.swift`, line 50.

### Fonts helper

`Fonts.swift` contains `// FIXME: this is fishy` near the custom font registration logic. If custom font support is re-enabled, this code should be reviewed.

File: `flo/Shared/Utils/Fonts.swift`, line 64.

### StatCardView arrow flag

`StatCardView` sets `showArrow` to false with a comment `// FIXME: use showArrow after implement deeplinks`. The arrow is intended to support deeplinks that are not yet implemented.

File: `flo/StatCardView.swift`, line 34.

### FloooViewModel TODOs

`FloooViewModel` has several open notes:

- Line 37: listening history and stats should perhaps live here.
- Line 40: questions whether the current stats task approach is okay.
- Lines 164-165: scrobble failure handling and offline-mode checks are not yet implemented.

File: `flo/FloooViewModel.swift`, lines 37, 40, 164-165.

### AuthViewModel TODOs

- Line 47: invalidate the authorization token somewhere on logout.
- Line 130: decide how to handle "last playing" data on logout.

File: `flo/AuthViewModel.swift`, lines 47 and 130.

### AlbumViewModel server-side config checks

`AlbumViewModel` has `//TODO: add logic to check server-side config` on lines 33 and 42. These are likely around feature gating or checking Navidrome server capabilities before enabling a UI option.

File: `flo/AlbumViewModel.swift`, lines 33 and 42.
