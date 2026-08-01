# flo overview

flo is an open-source Navidrome client written in Swift and SwiftUI. It targets iOS, iPadOS, macOS Catalyst, Apple Watch, and CarPlay, giving users a native Apple ecosystem experience for streaming and downloading music from a self-hosted Navidrome server.

The app is built around a few high-level ideas: stream first, download for offline, keep the UI simple, and let the user choose their server. It supports album and playlist browsing, artist discovery, background playback, CarPlay control, an Apple Watch companion, and optional Last.fm/ListenBrainz scrobbling through Navidrome's built-in endpoints. The codebase is deliberately small, with a minimal dependency set and a pragmatic MVVM-ish architecture.

flo is under active development, so the codebase carries many `TODO` and `FIXME` markers, feature flags, and experimental settings. The default branch is `develop` (TestFlight public), while `main` tracks the App Store release. Releases are cut through a Gitflow-style workflow with fastlane and GitHub Actions.

## Quick links

- Repository: `https://github.com/kepelet/flo`
- Landing page: `https://client.flooo.club`
- Tech stack: Swift 5, SwiftUI, UIKit, Core Data, AVFoundation, Alamofire, Nuke, Pulse, KeychainAccess, StoreKit
- Build system: Xcode project + Swift Package Manager
- Deployment: fastlane + GitHub Actions (`release/*` and `develop` branches)
- License: MIT
