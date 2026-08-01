# Getting started

flo is a SwiftUI app built with Xcode. It uses Swift Package Manager for dependencies and fastlane for signing, build, and TestFlight workflows.

## Prerequisites

- macOS with Xcode installed (the latest stable version is recommended).
- Swift 5 toolchain (as of this writing, the project uses Swift 5).
- A Navidrome server to log into, either self-hosted or accessible for testing.
- Ruby + Bundler for fastlane (only needed for team members who deploy builds).

## Clone and open

```bash
git clone https://github.com/kepelet/flo.git
cd flo
open flo.xcodeproj
```

## Build and run

1. Select the `flo` target in Xcode.
2. Choose a simulator or a connected device.
3. Build and run (`Cmd+R`).

If you are running on a physical device, you may need to set up a provisioning profile. For Kepelet org members, fastlane match can handle this:

```bash
bundle install
bundle exec fastlane match development
```

## Run on Mac Catalyst

Mac Catalyst is supported for local builds. Note that on Catalyst the app uses a file-backed credential store instead of the iOS Keychain, because unsigned Catalyst builds fail to read or write the system Keychain. See `flo/Shared/Services/KeychainManager.swift` for the implementation.

## Testing

The project currently does not have an automated test suite. The README notes that the developer tests the app manually. If you add tests, place them in the Xcode test target and run them with `Cmd+U`.

## Deployment (team members only)

The release flow is automated through GitHub Actions (`.github/workflows/ios-deployment.yml`) and fastlane:

1. Push to `release/*` for an internal TestFlight build.
2. Push to `develop` for a public TestFlight beta.
3. The workflow uses `fastlane ios beta` to build, increment the build number, and upload to TestFlight.
4. After beta approval and testing, the App Store release is merged to `main`.

Required secrets for CI are listed in `.github/workflows/ios-deployment.yml`:
- `APPLE_ID`
- `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_CONTENT`
- `MATCH_GIT_PRIVATE_KEY`, `MATCH_PASSWORD`

## Useful commands

```bash
# Install fastlane dependencies
bundle install

# Run a local development match
bundle exec fastlane match development

# Build and push a beta locally (requires ASC secrets)
bundle exec fastlane ios beta
```

## Localizing the app

flo uses Xcode string catalogs (`flo/Resources/Localizable.xcstrings`). Localization requires Xcode; open the catalog and add translations for the existing keys. See the [Apple localization guide](https://developer.apple.com/documentation/xcode/localizing-and-varying-text-with-a-string-catalog) for the workflow.
