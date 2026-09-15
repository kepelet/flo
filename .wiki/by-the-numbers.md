# By the numbers

A snapshot of the `flo` codebase as of 2026-07-16. The numbers are gathered from the repository root at `/home/exedev/flo` using the git history and file contents; treat them as approximate because line-count tooling and file inclusion choices can vary.

## Size

- **Total tracked files**: ~161 (excluding `.git` and the generated `droid-wiki/` directory).
- **Swift source files**: 98.
- **Total Swift lines of code**: ~29,750 (raw, including comments and blank lines).
- **Average Swift file size**: ~301 lines.
- **Config, docs, and metadata**: ~38 files totaling ~12,500 lines (Markdown, JSON, plist, Fastlane, Xcode project, lock files, strings catalog, etc.).

### Lines of code by language

The project is effectively a Swift monorepo with a thin layer of supporting files. No third-party dependencies are counted here; the numbers are the source tree itself.

```mermaid
xychart-beta
  title "Lines of code by language (raw lines, 2026-07-16)"
  x-axis [Swift, JSON, Markdown, Plist, YAML/TOML, Xcode/Strings, Other]
  y-axis "Lines of code"
  bar [29756, 3850, 2540, 1210, 780, 1040, 1820]
```

Swift dominates because the app targets iOS, iPadOS, macOS Catalyst, watchOS, and CarPlay, all from the same Xcode project. JSON and Markdown are mostly asset catalogs, `Localizable.xcstrings`, and the README. Xcode project metadata is counted under `Other`.

## Activity

Commit activity has stayed steady since the project's first commit in June 2024. The heaviest month was November 2024 with 121 commits, driven by the 1.3/1.4 release cycle and the introduction of the Flooo/scrobble feature set. In 2026, February, March, and April were especially active, with 68, 52, and 49 commits respectively, as the app moved toward 2.0, added CarPlay, reworked caching, and added Mac Catalyst support.

### Recent commit trend (last 90 days)

From 2026-04-01 through 2026-07-16 the repository received about 60 commits. The work during that window focused on:

- Mac Catalyst and iPad sidebar refinements (`2026-04-26`).
- CarPlay Downloads and Liked Songs integration (`2026-04-12`).
- Icon generation and asset cleanup (`2026-05-17`).
- Translation updates (Norwegian Bokmål, German, CarPlay strings, `2026-03`–`2026-04`).

### Churn hotspots (last 90 days)

The most frequently touched files in the last 90 days are:

- `flo.xcodeproj/project.pbxproj` (18 appearances) — project churn from adding targets, assets, and frameworks.
- `flo/Resources/Localizable.xcstrings` (18) — ongoing localization work.
- `flo/Navigation/LibraryView.swift` (15) — library UI updates and CarPlay/Library parity.
- `flo/PlayerView.swift` (14) — player refinements and Catalyst layout fixes.
- `flo/ContentView.swift` (12) — root navigation and iPad sidebar changes.
- `fastlane/Fastfile` (12) — release automation tweaks.

For a small codebase, churn is concentrated in the Xcode project metadata, the root SwiftUI views, and the localization catalog rather than deep service code.

## Bot-attributed commits

The project is almost entirely human-driven. Looking at `Co-authored-by` lines in the full git history, roughly 12 of the ~477 commit messages contain a `Co-authored-by:` or `factory-droid`/`droid` attribution. That is about **2.5%** of commits. The main author, `rizaldy`, accounts for 427 of the 477 commits (~89%), with small contributions from documentation, localization, and bug-fix contributors.

## Complexity

### Average Swift file size by directory

| Directory | Files | Average lines/file |
| --- | --- | --- |
| `flo/CarPlay` | 5 | ~424 |
| `flo/Navigation` | 7 | ~431 |
| `flo/Shared` (all subdirs) | 45 | ~243 |
| `flo/Watch` | 16 | ~148 |
| `flo/Artists` | 4 | ~151 |
| `flo/Radios` | 3 | ~89 |

(The numbers are rounded; totals include comments and blanks. `Resources` has no Swift files.)

### Top largest Swift files

These are the biggest single files in the tree and, roughly, the most complex or broadly coupled components:

1. `flo/PlayerViewModel.swift` — 863 lines.
2. `flo/CarPlay/CarPlayCoordinator.swift` — 847 lines.
3. `flo/Navigation/PreferencesView.swift` — 741 lines.
4. `flo/Shared/Services/AlbumService.swift` — 585 lines.
5. `flo/PlayerView.swift` — 563 lines.
6. `flo/AlbumViewModel.swift` — 435 lines.
7. `flo/AlbumView.swift` — 393 lines.
8. `flo/ContentView.swift` — 364 lines.
9. `flo/Shared/Services/StreamCacheManager.swift` — 331 lines.
10. `flo/DownloadViewModel.swift` — 298 lines.

`PlayerViewModel.swift` is the single largest file, which is typical for a music player: it combines `AVPlayer`, remote control, queue handling, playback state, lyrics, and scrobbling. `CarPlayCoordinator.swift` is the second largest because it bridges iOS playback to the CarPlay template system, while `PreferencesView.swift` bundles settings, the flo+ purchase flow, and experimental toggles.

## Notes on methodology

- All counts are raw lines (`wc -l`), not logical SLOC, so comments and whitespace are included.
- Files outside the `flo/` source directory, such as `meta/`, `fastlane/`, `Gemfile`, and `cliff.toml`, are included in the overall count but excluded from the Swift-only averages.
- Commit counts include the `develop` and `main` lines and any release/feature branches that remain in the local clone.
