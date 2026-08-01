# Patterns and conventions

This page describes the recurring patterns in the flo codebase. If you are modifying the app, try to match these patterns so the code stays consistent.

## MVVM with singleton services

Most SwiftUI views depend on an `ObservableObject` view model, and view models call shared service singletons. For example, `AlbumView` uses `AlbumViewModel`, which in turn calls `AlbumService.shared`. The player is a special case: `PlayerViewModel` is itself a singleton (`PlayerViewModel.shared`) because the audio session, remote command center, and now-playing center must be global.

## Callbacks and Combine

The codebase uses completion-handler `Result` types rather than async/await for most service methods. Many service calls look like:

```swift
AlbumService.shared.getAlbum { result in
  DispatchQueue.main.async {
    switch result {
    case .success(let albums): self.albums = albums
    case .failure(let error): self.error = error
    }
  }
}
```

`PlayerViewModel` uses `Combine` publishers for `AVPlayerItem` status and `NotificationCenter` publishers for audio interruptions and route changes.

## Core Data usage

Core Data is used through `CoreDataManager.shared`, which exposes the main `viewContext` and generic helper methods:

- `getRecordsByEntity(_:sortDescriptors:)`
- `getRecordByKey(_:key:value:limit:sortDescriptors:)`
- `deleteRecords(_:)` and `deleteRecordByKey(_:key:value:)`
- `saveRecord()`

The queue is persisted with `NSBatchInsertRequest` in `PlaybackService`, and stats calculation is done in a `Task.detached` after extracting values from the managed objects.

## Network requests

All HTTP traffic goes through `APIManager.shared`. There are four main request paths:

- `NDEndpointRequest` — Navidrome native API with a Bearer token.
- `SubsonicEndpointRequest` — Subsonic endpoint with the pre-built token query string.
- `SubsonicEndpointDownload` / `SubsonicEndpointDownloadNew` — file downloads, the latter with progress callbacks.
- `login` / `loginWithIAP` — authentication endpoints.

The session is recreated when debug logging is toggled so the `Pulse` event monitor can be added or removed.

## Constants and UserDefaults

Endpoints and keys are centralized in `flo/Shared/Utils/Constants.swift`. Preferences are read and written through `UserDefaultsManager` so that default values and key names stay consistent.

## Platform-specific compilation

The code uses `targetEnvironment(macCatalyst)` and `os(iOS)` / `os(watchOS)` directives to branch behavior. The most important differences are:

- Keychain on Catalyst falls back to a file-backed store.
- `WatchConnectivityManager` is only compiled on iOS and watchOS.
- CarPlay code is gated with `canImport(CarPlay)`.

## Error handling

`ErrorHandler` maps `AFError` to `AuthError.server(message:)` or `AuthError.unknown`. View models usually store the last error in a published property and let the UI show an alert. Network passwords are redacted from debug logs before being stored by `Pulse`.

## Feature flags and experiments

Many features are behind `UserDefaultsManager` toggles, hardcoded `if false` blocks, or `experimental` settings in Preferences. Examples include the stream cache, LRCLIB integration, save-login info, and flo+ purchase UI. Before shipping, check these flags and remove or promote them.

## Styling

The app uses a custom font (`Plus Jakarta Sans`) applied through the `customFont(_:)` view modifier. It also uses `Color("PlayerColor")` and the accent color for branding. Most UI is built with standard SwiftUI components plus NukeUI for remote images.

## Naming conventions

- Files and types use Swift naming (`PascalCase` for types, `camelCase` for members).
- View models for screens end with `ViewModel` (`AlbumViewModel`, `AuthViewModel`).
- Service singletons end with `Service` or `Manager` and expose `static let shared`.
- `FIXME` and `TODO` comments are common; see [Cleanup opportunities](../cleanup-opportunities/todos-and-fixmes.md) for a full list.
