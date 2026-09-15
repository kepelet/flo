# Cleanup opportunities

The flo codebase is small but has accumulated TODO, FIXME, and other markers. Some files have grown large and are good candidates for refactoring. This section collects maintenance work that is safe for new contributors and does not require deep product knowledge.

## Overview

- The project has no automated tests, so any cleanup should be followed by manual testing on the affected platforms.
- Many TODO and FIXME comments are small, isolated tasks such as extracting constants or adding error handling.
- A few files are large enough that splitting them could improve readability and testability.

## Sub-pages

- [TODOs and FIXMEs](todos-and-fixmes.md) — a full list of TODO, FIXME, HACK, and XXX comments, grouped by file.
- [Complexity hotspots](complexity-hotspots.md) — the largest Swift files and which ones are worth refactoring first.

## Skipped pages

- **Dead ends** — no clearly dead code was found. The small codebase keeps most code reachable, and dependencies are minimal. If you find real dead code, you can add a `dead-ends.md` page.
- **Dependency freshness** — the project has only four direct dependencies (Alamofire, KeychainAccess, Nuke, Pulse) and they are pinned by SwiftPM. There is no meaningful freshness report to add at this time.

## How to contribute a cleanup

1. Pick a marker from the [TODOs and FIXMEs](todos-and-fixmes.md) list or a file from the [Complexity hotspots](complexity-hotspots.md) page.
2. Open a GitHub issue describing the cleanup so others know it is being worked on.
3. Branch from `develop` with `features/<cleanup-description>` or `bugfix/<cleanup-description>`.
4. Make the change in small commits and test it manually on the affected platform.
5. Open a pull request to `develop` and reference the issue.

For the full workflow, see [How to contribute](/droid-wiki/how-to-contribute/index.md).
