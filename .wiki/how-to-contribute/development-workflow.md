# Development workflow

flo uses a Gitflow-style branching model. The workflow is described in the [README](/README.md) and implemented in the deployment pipeline. This page explains how the branches, releases, and continuous deployment fit together.

## Branch purposes

| Branch | Purpose |
| --- | --- |
| `main` | App Store release. Only merged after a release is approved and live. |
| `develop` | Public TestFlight beta. The default branch and the target for most PRs. |
| `release/xxx` | Internal TestFlight build for a specific release. |
| `features/yyy` | Short-lived staging branch for a new feature. |
| `bugfix/zzz` | Short-lived staging branch for a bug fix. |

## Day-to-day flow

1. Create a branch from `develop` for the feature or bug fix.
2. Open a pull request back to `develop` when the work is complete.
3. After the PR is merged, the change is included in the next public TestFlight build once it is deployed from `develop`.
4. When a release is ready for wider internal testing, create or use a `release/xxx` branch. This triggers the internal TestFlight deployment.
5. After internal testing, merge the release into `develop` and push it to public TestFlight.
6. When a release is approved for the App Store, merge it into `main`.

This matches the cycle in the README: draft a release branch, merge to `develop` and submit to the external TestFlight group, test the beta, then submit to the App Store and finally merge to `main`.

## Cutting and merging release branches

To cut a release branch:

1. Make sure `develop` is in a releasable state.
2. Create a branch named `release/<version>` from `develop`, for example `release/2.3`.
3. Push the branch. The GitHub Actions workflow in `.github/workflows/ios-deployment.yml` will build and upload an internal TestFlight beta.
4. Test the internal build.
5. When the release is ready for the public beta, merge the release branch into `develop`.
6. Pushing `develop` triggers the public TestFlight deployment because the workflow passes `public:true` to the fastlane beta lane.

## fastlane version bumping

fastlane handles build numbers and signing. The fastlane files live in `/fastlane/`:

- `fastlane/Fastfile` defines the lanes: `load_asc_api_key`, `sync_certs`, `fetch_and_increment_build_number`, `build`, and `beta`.
- `fastlane/Appfile` lists the app identifiers: `com.penerbangwalet.flo` and `com.penerbangwalet.flo.watchkitapp`.
- `fastlane/Gymfile` sets the scheme, export method, and output directory.
- `fastlane/Matchfile` stores the match git repository and certificate type.

Build numbers are bumped automatically. The `fetch_and_increment_build_number` lane fetches the latest TestFlight build number for the current version from App Store Connect and increments it by one. The `build` lane then calls `build_app` with the `Release` configuration. The version number itself is read from Xcode by `get_version_number`.

## GitHub Actions workflow

The deployment workflow is `.github/workflows/ios-deployment.yml`. It runs on pushes to `develop` and any `release/*` branch. It only runs when the actor is `faultables`, which is the release manager account.

The workflow does the following:

1. Checks out the repository.
2. Sets up Xcode 26.3.
3. Sets up Ruby 3.2.1 and uses bundler-cache.
4. Runs the fastlane beta lane:
   - For `develop`, it passes `public:true` to distribute to the external TestFlight group.
   - For `release/*`, it distributes internally.
5. Uploads the resulting IPA and dSYM to GitHub artifacts.

The required secrets are passed as environment variables:

- `APPLE_ID`
- `ASC_KEY_ID`
- `ASC_ISSUER_ID`
- `ASC_KEY_CONTENT`
- `MATCH_GIT_PRIVATE_KEY`
- `MATCH_PASSWORD`

The App Store Connect API key is loaded in the `load_asc_api_key` lane using `ENV["ASC_KEY_ID"]`, `ENV["ASC_ISSUER_ID"]`, and `ENV["ASC_KEY_CONTENT"]`.

## Changelog

Release notes are generated with git-cliff using the configuration in `/cliff.toml`. The changelog uses conventional commit groups: Features, Bug Fixes, Documentation, Performance, Refactoring, Style, Revert, Tests, Miscellaneous Chores, and Security. When you make a commit, use a conventional commit prefix such as `feat:`, `fix:`, or `refactor:` so the changelog can group your change correctly.

## When to merge to `develop`

Merge to `develop` when:

- The feature or bug fix is complete and manually tested.
- There are no critical errors in the current release branch.
- You are ready for the change to be included in the next public TestFlight build.

Do not merge directly to `main` unless you are cutting a final App Store release.

## Useful commands

- `bundle exec fastlane ios beta` — build and upload an internal TestFlight beta locally.
- `bundle exec fastlane ios beta public:true` — build and upload a public TestFlight beta.
- `bundle exec fastlane ios build` — build the app without uploading.
- `git cliff` — preview the generated changelog.
