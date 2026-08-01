# Glossary

Terms used throughout the flo codebase and this wiki.

| Term | Meaning |
| ---- | ------- |
| **Navidrome** | The self-hosted music server flo connects to. Supports both its own REST API and Subsonic-compatible endpoints. |
| **Subsonic API** | The legacy protocol Navidrome implements for streaming, cover art, scrobbling, and more. flo uses Subsonic endpoints under `/rest/`. |
| **ND endpoint** | A Navidrome native REST endpoint under `/api/`. Used for login, library metadata, shares, and account links. |
| **flo+** | The optional in-app subscription product (`flo.plus`). Intended to support development; currently gated/commented in some places. |
| **IAP auth** | Identity-Aware Proxy authentication mode. Logs in through OAuth2-Proxy or a similar proxy, extracting a JWT token from headers or cookies. |
| **Auth mode** | Either `standard` (username/password) or `iap` (OAuth2-Proxy / IAP). Stored in `AuthMode` and `KeychainManager`. |
| **Stream cache** | Optional disk cache for streamed audio, managed by `StreamCacheManager`. Separate from offline downloads. |
| **Downloaded album** | An album or playlist saved to the local file system and Core Data, playable offline. Stored under `Media/<Artist>/<Album>/`. |
| **Playlist album** | A downloaded playlist represented as a fake "Various Artists" album for local browsing. |
| **Playable** | A protocol implemented by `Album`, `Playlist`, `RadioEntity`, and `SongCollection`. Anything `Playable` can be turned into a playback queue. |
| **Queue entity** | A Core Data record representing one item in the current playback queue, stored by `PlaybackService`. |
| **Scrobbling** | Reporting played tracks to Last.fm or ListenBrainz via Navidrome's built-in Subsonic scrobble endpoint. |
| **LRCLIB** | Optional external service for fetching synced lyrics, configured in Preferences. |
| **CarPlay scene** | A separate `UIScene` for CarPlay that uses `CarPlayCoordinator` to build list templates. |
| **WatchConnectivity** | The framework that lets the Apple Watch app request library data and send playback commands to the phone. |
| **Source bitrate** | Transcoding setting `0` (or `raw`), meaning the server streams the original file without transcoding. |
