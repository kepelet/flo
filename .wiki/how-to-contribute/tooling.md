# Tooling

flo uses a small, standard Apple toolchain plus fastlane for deployment. This page lists the tools, the files that configure them, and how they are used day to day.

## Xcode

Xcode is the primary IDE. The project is defined in `flo.xcodeproj` at the repository root. The latest stable version is recommended; the GitHub Actions workflow pins a specific version with `maxim-lobanov/setup-xcode@v1` and currently uses Xcode 26.3. The project is written in Swift 5 and uses SwiftUI for the UI.

Key targets in the project include the iOS app, the Apple Watch app, and the CarPlay scene. When you open the project, make sure the correct scheme and destination are selected before building or running.

## Swift Package Manager

Dependencies are managed with integrated SwiftPM. The project uses four packages listed in the README:

- `Alamofire` — HTTP networking.
- `KeychainAccess` — keychain wrapper.
- `Nuke` — image loading.
- `Pulse` — network logger and console UI.

Dependencies are declared in the Xcode project under the Swift Packages section. There is no separate `Package.swift` at the repository root for the app itself.

## fastlane

fastlane handles certificates, build numbers, signing, and TestFlight uploads. The lanes are defined in `fastlane/Fastfile`:

- `load_asc_api_key` — loads the App Store Connect API key from environment variables.
- `sync_certs` — fetches the app store and catalyst signing certificates with `match`.
- `fetch_and_increment_build_number` — reads the latest TestFlight build number and increments it.
- `build` — runs the previous lanes and then builds the app using the configuration in `fastlane/Gymfile`.
- `beta` — builds the app and uploads it to TestFlight, with an optional `public:true` flag for external distribution.

Configuration files:

- `fastlane/Appfile` — app identifiers for the iOS and watch apps.
- `fastlane/Gymfile` — scheme `flo`, app store export method, and output directory `./fastlane/builds`.
- `fastlane/Matchfile` — the match git repository and certificate type.

## Ruby and Bundler

fastlane is a Ruby tool. The project pins Ruby and gem versions with:

- `Gemfile` at the repository root.
- `Gemfile.lock` at the repository root.

The GitHub Actions workflow uses `ruby/setup-ruby@v1` with Ruby 3.2.1 and `bundler-cache: true`. To run fastlane locally, install Bundler and run `bundle exec fastlane <lane>`.

## git-cliff

The project uses git-cliff for changelog generation. The configuration is in `/cliff.toml`. The changelog groups commits by conventional commit type, maps scopes, and links commits to the GitHub repository.

When you commit, use conventional commit prefixes so the changelog can group your changes correctly. For example:

- `feat: add shuffle to CarPlay`
- `fix: resolve login error on macOS Catalyst`
- `refactor: split AlbumService into smaller methods`

## GitHub Actions

The deployment workflow is `.github/workflows/ios-deployment.yml`. It runs on pushes to `develop` and `release/*` and is gated to the actor `faultables`. It:

1. Checks out the repository.
2. Sets up Xcode and Ruby.
3. Runs the appropriate fastlane beta lane.
4. Uploads the IPA and dSYM to GitHub artifacts.

The required environment secrets are:

- `APPLE_ID`
- `ASC_KEY_ID`
- `ASC_ISSUER_ID`
- `ASC_KEY_CONTENT`
- `MATCH_GIT_PRIVATE_KEY`
- `MATCH_PASSWORD`

These are configured as repository secrets and are passed to the fastlane lanes as environment variables.

## App Store Connect API key

The App Store Connect API key is loaded by the `load_asc_api_key` lane in `fastlane/Fastfile`. It uses three environment variables:

- `ASC_KEY_ID` — the key identifier.
- `ASC_ISSUER_ID` — the issuer identifier.
- `ASC_KEY_CONTENT` — the key content, not base64 encoded.

These values are set as GitHub Actions secrets. Do not commit them or log them. The repository includes password redaction in `AuthService.login`, but the App Store Connect key has the same sensitivity.

## Localization

flo uses Xcode string catalogs for localization. The project does not use a third-party localization service, so translators need Xcode to add or update strings. The process is documented by Apple at [Localizing and varying text with a string catalog](https://developer.apple.com/documentation/xcode/localizing-and-varying-text-with-a-string-catalog).

Strings are defined in the project's `.xcstrings` catalog files. When you add a new user-facing string, add it to the catalog and provide at least the base language. Other languages can be added later by translators.

## Related pages

- [Development workflow](development-workflow.md) for how the branches and deployment pipeline work together.
- [Debugging](debugging.md) for the tools that help during development.
- [Testing](testing.md) for how to run and add tests.
