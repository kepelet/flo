# Testing

flo currently has no automated tests. All testing is manual. This page documents the current state and suggests where to add tests as the project grows.

## Current state

- There is no unit test target, no UI test target, and no test runner in the project.
- The `PlayerViewModel`, `AlbumService`, `APIManager`, and other services are singletons that are exercised by running the app on a device or simulator.
- The README notes that the project does not run tests yet, so the developer tests the app directly.
- When you are ready to verify a change, run the app in Xcode with the intended scheme and device destination.

## How to run tests in Xcode

Once a test target exists:

1. Open `flo.xcodeproj` in Xcode.
2. Select the scheme you want to test, for example `flo` or the watch app.
3. Press `Cmd+U` to run the full test suite, or use the Test Navigator to run individual tests.

Until tests are added, the project will build the test bundle but there will be nothing to execute. You can still use `Cmd+U` to verify that the test target compiles and links correctly.

## Where to add tests first

The codebase is small, but several components are good candidates for early test coverage. Add tests in small, focused files that match the structure of the code under test.

### Unit tests

- `flo/Shared/Utils/LRCParser.swift` — the `parse` method takes a string and returns an array of `LyricsLine`. Test cases are easy to write and run quickly. Add tests for empty strings, standard LRC tags, malformed tags, and millisecond rounding.
- `flo/Shared/Services/PlaybackService.swift` — `addToQueue`, `clearQueue`, and `shuffleQueue` operate on Core Data entities. Add an in-memory Core Data stack, create `QueueEntity` objects, and assert the resulting queue order and metadata.
- `flo/Shared/Services/LibraryCacheManager.swift` — `save`, `load`, and `clearCache` read and write JSON files in a cache directory. Use a temporary directory, encode sample models, and assert that the round trip works and that `clearCache` removes the files.
- `flo/Shared/Services/AuthService.swift` — `getCreds`, `setCreds`, and the JWT parsing helpers can be tested with fake keychain data and well-known JWT strings. Keep the keychain interactions behind a protocol so tests can inject a mock store.
- `flo/Shared/Models/Album.swift` — the custom `init(from decoder:)` handles backward compatibility for the `artist` field. Test decoding with and without that field to prevent regressions.
- `flo/Shared/Utils/Constants.swift` — the constants are static, but the `TranscodingSettings` and `UserDefaultsKeys` enums are worth sanity-checking so they match the rest of the app.

### UI tests

- `flo/LoginView.swift` — the login flow is the first interaction a user has with the app. Add UI tests that enter a server URL, username, and password, tap the login button, and assert that the library appears or an error message is shown. Use a mock `APIManager` session so tests do not depend on a real Navidrome server.
- `flo/Navigation/PreferencesView.swift` — the preferences screen contains many toggles and pickers. Add UI tests that switch the LRCLIB server, toggle debug mode, and clear the stream cache, asserting the resulting state.
- `flo/PlayerView.swift` — the player controls are complex. Add UI tests that play a song, pause, skip, and toggle shuffle, asserting the Now Playing state where possible.

### Network tests

- `flo/Shared/Services/APIManager.swift` — the `NDEndpointRequest`, `SubsonicEndpointRequest`, and login methods all use the shared `Session`. Refactor `APIManager` to accept an injected session or configuration so tests can pass a stub. Write tests for successful responses, HTTP errors, and timeout behavior. The Pulse `NetworkLoggerEventMonitor` should be excluded from test builds to keep network logs predictable.
- `flo/Shared/Services/AlbumService.swift` — most methods delegate to `APIManager` or `CoreDataManager`. Use the same injected session approach and assert the correct parameters are sent to the Navidrome endpoints.

## Testing strategy

- Start with the parser and cache manager because they have no UI or external dependencies.
- Add Core Data-backed tests next, using the `inMemoryContainer()` helper in `flo/Shared/Services/CoreDataManager.swift` as a model for a test stack.
- Add network tests after `APIManager` supports injection.
- Add UI tests last, once the core logic is covered and the main flows are stable.

## Manual testing checklist

Until automated tests exist, use this checklist before opening a pull request:

- [ ] The app builds for the intended scheme and destination.
- [ ] Login succeeds with a valid Navidrome server.
- [ ] The library lists albums, artists, and playlists.
- [ ] A song plays, pauses, skips, and resumes.
- [ ] Downloads and offline playback work on a device.
- [ ] CarPlay and Apple Watch do not crash on launch where applicable.
- [ ] macOS Catalyst builds and basic playback works.
- [ ] The debug toggle and Pulse console still work when enabled.

## Related pages

- [Tooling](tooling.md) for Xcode and SwiftPM setup.
- [Debugging](debugging.md) for the tools that help during manual testing.
- [Development workflow](development-workflow.md) for how and when to open a pull request.
