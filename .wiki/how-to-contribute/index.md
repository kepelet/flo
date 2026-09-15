# How to contribute

flo is a small, pragmatic SwiftUI project. We welcome code, bug reports, translations, and design feedback. This section explains how to pick up work, what "done" looks like, and where to find the tooling details.

## Quick start

1. Read the [README](/README.md) for an overview of the project and dependencies.
2. Check the [cleanup opportunities](/droid-wiki/cleanup-opportunities/index.md) for low-risk maintenance work.
3. Choose a task from the wiki, open a GitHub issue, or discuss it in GitHub Discussions.
4. Branch from `develop` using the naming convention below.
5. Open a pull request back to `develop` when the work is ready.

## Branching and pull request expectations

We use Gitflow. The branches have different purposes:

- `main` — the App Store release.
- `develop` — the public TestFlight release. This is the default branch and the target for most pull requests.
- `release/xxx` — internal TestFlight builds for a specific release.
- `features/yyy` or `bugfix/zzz` — staging branches for the current release.

For most contributions, branch from `develop` and open a PR back to `develop`. Name your branch `features/<short-description>` or `bugfix/<short-description>`. Keep changes focused on a single concern so reviews stay small.

Pull request checklist:

- The change builds in Xcode without warnings or errors.
- It has been manually tested on the intended platform (iOS, iPadOS, macOS Catalyst, Apple Watch, or CarPlay).
- The UI matches the existing style and supports dynamic type and dark mode where relevant.
- If you add a new file, make sure it is included in the correct target and that the app still launches.
- Update the changelog if the change is user-facing. We use git-cliff with `cliff.toml` for release notes.

## Definition of done

A contribution is considered complete when:

- It addresses the issue or task it was opened for.
- It builds and runs on real devices or simulators for the affected platforms.
- It does not introduce new TODO/FIXME markers unless they are documented in the code and the issue tracker.
- It follows the existing project structure and naming style.
- The PR description explains what changed and why.

For more details, see the sub-pages:

- [Development workflow](development-workflow.md)
- [Testing](testing.md)
- [Debugging](debugging.md)
- [Tooling](tooling.md)

## Support

If you are unsure about a change, open a GitHub Discussion or ask in the issue. For private matters, contact the maintainer at `oss [at] rizaldy.club`.
