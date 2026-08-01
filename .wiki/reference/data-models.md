# Data models

This page documents the main Swift data models and Core Data entities used by flo. It is intended as a quick reference when adding features, debugging data flow, or working with the persistence layer.

Sources: `flo/Shared/Models/*.swift` and `flo/Shared/Services/CoreDataManager.swift`, plus the Core Data model at `flo/flo.xcdatamodeld/flo.xcdatamodel/contents`.

## Swift models

### `Song`

File: `flo/Shared/Models/Song.swift`

A single playable track. Conforms to `Codable`, `Identifiable`, and `Hashable`. It also has `init(from: CacheEntity)` and `init(from: SongEntity)` helpers used on iOS to bridge Core Data objects.

| Field | Type | Description |
| --- | --- | --- |
| `id` | `String` | Navidrome song ID. |
| `title` | `String` | Track title. |
| `artist` | `String` | Track artist name. |
| `albumId` | `String` | Parent album ID. |
| `albumName` | `String` | Parent album name. |
| `trackNumber` | `Int` | Position within the album. |
| `discNumber` | `Int` | Disc number. |
| `bitRate` | `Int` | Bitrate of the file. |
| `sampleRate` | `Int` | Sample rate of the file. |
| `suffix` | `String` | File extension / codec. |
| `duration` | `Double` | Track duration in seconds. |
| `mediaFileId` | `String` | ID used for streaming via Subsonic `stream` endpoint. |
| `fileUrl` | `String` | Local file URL when downloaded. |
| `starred` | `Bool` | Whether the user has starred the track. |

### `Album`

File: `flo/Shared/Models/Album.swift`

Conforms to `Codable`, `Identifiable`, and `Playable`. It can also be initialized from a `PlaylistEntity` (used for cached library groups) or from a `Playlist` (to treat playlists as albums in the player).

| Field | Type | Description |
| --- | --- | --- |
| `id` | `String` | Album ID. |
| `name` | `String` | Album title. |
| `albumArtist` | `String` | Album artist. |
| `artist` | `String` | Display artist (fallbacks to `albumArtist` for pre-BFR compatibility). |
| `albumCover` | `String` | Cover art identifier. |
| `info` | `String` | Album notes / description. |
| `songs` | `[Song]` | Tracks on the album. |
| `genre` | `String` | Album genre. |
| `minYear` | `Int` | Earliest year of the tracks. |

### `Artist`

File: `flo/Shared/Models/Artist.swift`

Conforms to `Codable`, `Hashable`, and `Identifiable`. Equality is based on `id` only.

| Field | Type | Description |
| --- | --- | --- |
| `id` | `String` | Artist ID. |
| `name` | `String` | Artist name. |
| `orderArtistName` | `String` | Sort-friendly name. |
| `stats` | `ArtistStats` | Aggregated stats for related roles. |
| `size` | `Int` | Total size of artist tracks. |
| `albumCount` | `Int` | Number of albums. |
| `songCount` | `Int` | Number of songs. |
| `missing` | `Bool` | Whether the artist is missing metadata. |
| `createdAt` | `String` | Creation timestamp. |
| `updatedAt` | `String` | Last update timestamp. |
| `sortArtistName` | `String?` | Alternative sort name. |
| `playCount` | `Int?` | Play count. |
| `playDate` | `String?` | Last play date. |
| `mbzArtistID` | `String?` | MusicBrainz artist ID. |
| `biography` | `String?` | Artist biography. |
| `smallImageURL` | `String?` | Small image URL. |
| `mediumImageURL` | `String?` | Medium image URL. |
| `largeImageURL` | `String?` | Large image URL. |
| `externalURL` | `String?` | External link. |
| `externalInfoUpdatedAt` | `String?` | When external info was last synced. |
| `fullText` | `String?` | Full-text search content. |

### `Playlist`

File: `flo/Shared/Models/Playlist.swift`

Conforms to `Codable`, `Identifiable`, `Hashable`, and `Playable`.

| Field | Type | Description |
| --- | --- | --- |
| `id` | `String` | Playlist ID. |
| `name` | `String` | Playlist name. |
| `comment` | `String` | Playlist description. |
| `isPublic` | `Bool` | Visibility flag. |
| `ownerName` | `String` | Playlist owner. |
| `artist` | `String` | Exposed as `ownerName` for `Playable` conformance. |
| `songs` | `[Song]` | Tracks in the playlist. |

### `Radio`

File: `flo/Shared/Models/Radio.swift`

A Subsonic internet radio station. Conforms to `Codable`, `Identifiable`, and `Hashable`. Includes a `toPlayable()` helper that wraps the station in a `RadioEntity` so it can be queued like an album or playlist.

| Field | Type | Description |
| --- | --- | --- |
| `id` | `String` | Station ID. |
| `name` | `String` | Station name. |
| `streamUrl` | `String` | Stream URL. |

### `RadioEntity`

File: `flo/Shared/Models/Radio.swift`

A transient `Playable` wrapper produced by `Radio.toPlayable()` so a radio station can be inserted into the same playback pipeline as albums and playlists.

| Field | Type | Description |
| --- | --- | --- |
| `id` | `String` | Station ID. |
| `name` | `String` | Station name. |
| `songs` | `[Song]` | A single synthetic `Song` representing the stream. |
| `artist` | `String` | Stream host, used as the display artist. |

### `UserAuth`

File: `flo/Shared/Models/UserAuth.swift`

Conforms to `Codable`. Stores the authenticated user's server credentials and the Subsonic salt/token pair needed for Subsonic API calls.

| Field | Type | Description |
| --- | --- | --- |
| `id` | `String` | User ID. |
| `name` | `String` | Display name. |
| `username` | `String` | Login username. |
| `isAdmin` | `Bool` | Admin flag. |
| `lastFMApiKey` | `String` | Last.fm API key when linked. |
| `subsonicSalt` | `String` | Salt used for Subsonic token auth. |
| `subsonicToken` | `String` | Subsonic auth token. |
| `token` | `String` | Navidrome bearer token. |

### `Playable` protocol

File: `flo/Shared/Models/Playable.swift`

Anything that can be queued and played exposes a uniform interface.

| Requirement | Type | Description |
| --- | --- | --- |
| `id` | `String { get }` | Unique identifier. |
| `name` | `String { get }` | Display name. |
| `songs` | `[Song] { get set }` | Tracks to play. |
| `artist` | `String { get }` | Display artist / owner. |

Conformers include `Album`, `Playlist`, `RadioEntity`, and `SongCollection`.

### Other supporting models

| Model | File | Purpose |
| --- | --- | --- |
| `NowPlaying` | `flo/Shared/Models/NowPlaying.swift` | Lightweight snapshot of the current track for the command center / widgets. |
| `Stats` | `flo/Shared/Models/Stats.swift` | Summary stats (top artist, album, album artist). |
| `AccountLinkStatus` | `flo/Shared/Models/AccountLinkStatus.swift` | Whether ListenBrainz and LastFM accounts are linked. |
| `ScanStatus` | `flo/Shared/Models/ScanStatus.swift` | Subsonic scan status (scanning flag, count, folder count, last scan). |
| `SubsonicResponse<T>` | `flo/Shared/Models/Subsonic.swift` | Generic wrapper for Subsonic `subsonic-response` payloads. |
| `SubsonicSong` | `flo/Shared/Models/Subsonic.swift` | Intermediate struct used when decoding Subsonic song responses into `Song`. |
| `SimilarSongsList` / `TopSongsList` | `flo/Shared/Models/ArtistRadio.swift` | Decoding containers for Subsonic `getSimilarSongs2` and `getTopSongs` responses. |
| `ArtistRadio` | `flo/Shared/Models/ArtistRadio.swift` | Navidrome artist radio support. |
| `LRCLIBLyrics` | `flo/Shared/Models/LRCLIB.swift` | LRCLIB lyrics response, including plain and synced lyrics. |
| `LyricsLine` | `flo/Shared/Models/LyricsLine.swift` | A single synced lyric line with timestamp. |

## Core Data entities

The Core Data model file is `flo/flo.xcdatamodeld/flo.xcdatamodel/contents`. The persistent container is managed by `flo/Shared/Services/CoreDataManager.swift`.

### `QueueEntity`

Represents an item in the playback queue.

| Attribute | Type | Notes |
| --- | --- | --- |
| `albumCover` | `String?` | Cover art identifier. |
| `albumId` | `String?` | Parent album ID. |
| `albumName` | `String?` | Album name. |
| `artistName` | `String?` | Artist name. |
| `bitRate` | `Int16` | Bitrate. |
| `contextName` | `String?` | Queue context. |
| `duration` | `Double` | Track duration. |
| `id` | `String?` | Song ID. |
| `isFromLocal` | `Bool` | Whether the item is from local storage. |
| `isFromPlaylist` | `Bool` | Whether the item is from a playlist. |
| `sampleRate` | `Int32` | Sample rate. |
| `songName` | `String?` | Track title. |
| `suffix` | `String?` | File extension. |

### `SongEntity`

Represents a downloaded or locally available song.

| Attribute | Type | Notes |
| --- | --- | --- |
| `albumId` | `String` | Parent album ID. |
| `albumName` | `String?` | Album name. |
| `artistName` | `String?` | Artist name. |
| `bitRate` | `Int64` | Bitrate. |
| `discNumber` | `Int16` | Disc number. |
| `duration` | `Double` | Track duration. |
| `fileURL` | `String?` | Local file URL. |
| `id` | `String` | Unique song ID (uniqueness constraint). |
| `mediaFileId` | `String?` | Streaming ID. |
| `sampleRate` | `Int32` | Sample rate. |
| `status` | `String?` | Download status. |
| `suffix` | `String?` | File extension. |
| `title` | `String?` | Track title. |
| `trackNumber` | `Int16` | Track number. |

### `PlaylistEntity`

Stores cached playlist metadata. Note: this entity is also used as a cached album-like group in offline mode.

| Attribute | Type | Notes |
| --- | --- | --- |
| `albumArtist` | `String?` | Album artist. |
| `albumCover` | `String?` | Cover art identifier. |
| `albumName` | `String?` | Album name. |
| `artistName` | `String?` | Artist name. |
| `genre` | `String?` | Genre. |
| `id` | `String` | ID. |
| `minYear` | `Int64` | Earliest year. |
| `name` | `String?` | Name (uniqueness constraint). |

### `CacheEntity`

Stores stream cache metadata and file paths for transparent audio caching.

| Attribute | Type | Notes |
| --- | --- | --- |
| `albumId` | `String?` | Album ID. |
| `albumName` | `String?` | Album name. |
| `artistName` | `String?` | Artist name. |
| `bitRate` | `Int16` | Bitrate. |
| `cacheKey` | `String` | Unique cache key (uniqueness constraint). |
| `cachedAt` | `Date?` | Cache timestamp. |
| `duration` | `Double` | Duration. |
| `fileSize` | `Int64` | File size. |
| `lastAccessedAt` | `Date?` | Last access timestamp. |
| `mediaFileId` | `String?` | Streaming ID. |
| `filePath` | `String?` | Local file path. |
| `sampleRate` | `Int32` | Sample rate. |
| `state` | `String?` | Cache state. |
| `suffix` | `String?` | File extension. |
| `title` | `String?` | Track title. |

### `HistoryEntity`

Stores the playback history used for scrobbling and stats.

| Attribute | Type | Notes |
| --- | --- | --- |
| `albumId` | `String?` | Album ID. |
| `albumName` | `String?` | Album name. |
| `artistName` | `String?` | Artist name. |
| `timestamp` | `Date?` | When the track was played. |
| `trackName` | `String?` | Track title. |

### `RadioEntity`

See the Swift `RadioEntity` row above. It is a transient `Playable` wrapper, not a Core Data entity.

## Core Data manager

`CoreDataManager` in `flo/Shared/Services/CoreDataManager.swift` is a singleton (`CoreDataManager.shared`) that provides:

- `persistentContainer` / `viewContext` access.
- Generic fetch helpers: `getRecordsByEntity`, `getRecordsByEntityBatched`, `getRecordByKey`, `countRecords`.
- Mutation helpers: `saveRecord`, `deleteRecords`, `deleteRecordByKey`, `clearEverything`.
- Fallback to an in-memory store if the persistent store fails to load.

`clearEverything()` deletes all records from `QueueEntity`, `SongEntity`, `PlaylistEntity`, and `CacheEntity`, but intentionally leaves `HistoryEntity` intact (it is cleared elsewhere).
