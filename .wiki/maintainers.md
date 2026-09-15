# Maintainers

flo does not have a `CODEOWNERS` file, so ownership is derived from recent git history. The table below maps subsystems to the people who have most frequently touched related files. It is approximate and intended only to help contributors find the right reviewer or point of contact.

This table is updated from the `develop` branch as of the latest activity in 2026. It excludes bot accounts and focuses on recent contributors.

| Subsystem | Recent contributors | Last activity |
| --- | --- | --- |
| Audio playback | rizaldy, docmeth02 | active (2026-04) |
| Library browsing | rizaldy, docmeth02 | active (2026-04) |
| Offline downloads | rizaldy, docmeth02 | active (2026-03) |
| Watch companion | rizaldy, Piekay | active (2026-02) |
| CarPlay | rizaldy, docmeth02 | active (2026-04) |
| Scrobbling and stats | rizaldy, docmeth02 | active (2026-03) |
| Networking and auth | rizaldy, docmeth02 | active (2026-04) |
| Persistence | rizaldy, docmeth02 | active (2026-03) |
| UI and system | rizaldy, docmeth02 | active (2026-04) |
| Build and release | rizaldy | active (2026-04) |

## Notes

- rizaldy is the primary maintainer across almost every subsystem and has authored the bulk of the recent commits.
- docmeth02 has contributed across playback, caching, CarPlay, UI, and core data areas.
- Piekay has been involved in the watch companion work.
- Francesco, faultables, SindreKjelsrud, Ed Poe, and Simon Risse have also contributed, but with broader or smaller scopes in recent history.
- If you are unsure who to ask, start with rizaldy.

## How this table was generated

Ownership was inferred by analyzing `git log` for each subsystem's files, ranking contributors by the number of recent commits, and selecting the top two to three contributors. The "last activity" column is an approximate estimate based on the most recent commit date touching files in that subsystem.
