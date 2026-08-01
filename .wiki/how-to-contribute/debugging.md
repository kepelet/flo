# Debugging

flo includes a built-in debug mode for manual testing and a few common error patterns. This page explains how to enable debug mode, what it shows, and how to clear caches and optimize storage.

## Enable debug mode

Debug mode is controlled by a toggle in `flo/Navigation/PreferencesView.swift`. The toggle is bound to `UserDefaultsManager.enableDebug`. When the toggle is turned on:

- `APIManager.shared.reconfigureSession()` is called, which recreates the Alamofire session with a `Pulse` network logger.
- A new **Troubleshoot** section appears in Preferences.
- UserDefaults and Keychain values are listed in the Troubleshoot section.
- The Pulse console view is available from the new Debug tab in the tab bar.

To enable debug mode, open the app, go to Preferences, scroll to the Experimental section, and turn on **Enable Debug**. The change takes effect immediately for new network requests.

## Pulse network logger

flo uses [Pulse](https://github.com/kean/Pulse) for logging network requests. The relevant code is in `flo/Shared/Services/APIManager.swift`:

- `NetworkLoggerEventMonitor` conforms to Alamofire's `EventMonitor` and forwards events to `NetworkLogger.shared`.
- `APIManager.createSession()` creates a new `Alamofire.Session` with a retry policy and the event monitor.
- When `UserDefaultsManager.enableDebug` is true, the monitor is attached to the session; otherwise it is omitted.

When debug mode is enabled, the app adds a Debug tab to the main tab bar. The tab hosts `PulseUI.ConsoleView` so you can inspect requests, responses, and errors in the app.

## Troubleshoot section in Preferences

When debug mode is enabled, the Preferences screen shows a **Troubleshoot** section that lists:

- `UserDefaults` keys and values from `FloooViewModel.userDefaultsItems`.
- `Keychain` entries from `FloooViewModel.keychainItems`.
- A **Refetch UserDefaults & Keychains** button that refreshes the displayed values.
- A **Force Logout** button that logs the user out and refreshes the display.

This is useful for checking the saved server URL, bitrate, cache size, and stored credentials without leaving the app.

## Common errors and how to resolve them

### Expired session or login

Symptom: every request returns an auth error or the library does not load.

- Check `UserDefaultsManager.serverBaseURL` in the Troubleshoot section to make sure the server URL is correct.
- Try **Force Logout** and log in again.
- If you use **Save login info**, the app stores the password in the Keychain and refreshes the token on launch. If the keychain read fails, the login may silently fail. Look at the Keychain entries in the Troubleshoot section for clues.

### Network redaction

Symptom: a login failure appears but the response contains the password.

`AuthService.login` redacts the password field from the debug response before logging it to Pulse. The regex replaces `"password":"..."` with `"password":"[REDACTED]"`. This is a temporary solution and is marked with a FIXME in `flo/Shared/Services/AuthService.swift`. If you change the auth response shape, update the redaction regex so credentials stay out of logs.

### Mac Catalyst keychain failures

Symptom: login works on iOS but not on macOS Catalyst.

`KeychainKeys.service` in `flo/Shared/Utils/Constants.swift` uses a different keychain service on macOS Catalyst:

```swift
#if targetEnvironment(macCatalyst)
  static let service = Bundle.main.bundleIdentifier ?? AppMeta.identifier
#else
  static let service = AppMeta.identifier
#endif
```

This is because the keychain is namespaced by app bundle identifier on Catalyst. If you change the bundle identifier or the keychain access group, make sure the service string stays in sync.

### Stream cache reconcile issues

Symptom: a song plays but then the next track fails, or the cache size reported in Preferences does not match the actual disk usage.

- Check `FloooViewModel.streamCacheSize` in the Troubleshoot section.
- Use **Clear streaming cache** in the Local Storage section of Preferences. This deletes cached streamed songs but does not affect downloaded albums.
- If downloads are also out of sync, use **Optimize local storage**. This deletes all downloaded albums and songs, including their files, and calls `CoreDataManager.shared.clearEverything()`.

## Clearing caches and optimizing storage

The Preferences screen has several buttons for storage management:

- **Clear streaming cache** — removes cached streamed songs. Downloads are not affected.
- **Clear listening history** — removes the local listening history immediately and without confirmation.
- **Optimize local storage** — deletes all downloaded albums and songs, including their content. It also calls `PlayerViewModel.shared.destroyPlayerAndQueue()` to stop any active playback.

These actions are defined in `flo/Navigation/PreferencesView.swift` and call methods on `FloooViewModel` and `PlayerViewModel`.

## Logging and diagnostics

In addition to Pulse, the app uses `LoggerStore.shared.storeMessage` in a few places, such as `AuthService.login` and `AuthService.loginWithIAP`. These messages appear in the Pulse console when debug mode is enabled. Some services still print to standard output using `print()`, which is visible in the Xcode console.

## When to use debug mode

- A feature works on simulator but not on device.
- Login or playback fails and you need to see the exact request and response.
- You need to confirm the stored server URL, token, bitrate, or cache limit.
- You are testing a new release and want to verify that the correct network configuration is in use.

## Related pages

- [Tooling](tooling.md) for the Xcode and fastlane setup.
- [Testing](testing.md) for how to test changes and where to add automated tests.
