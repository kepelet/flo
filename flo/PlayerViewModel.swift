//
//  PlayerViewModel.swift
//  flo
//
//  Created by rizaldy on 05/06/24.
//

import AVFoundation
import Combine
import CoreData
import MediaPlayer
import SwiftUI

class PlayerViewModel: ObservableObject {
  static let shared = PlayerViewModel()

  private var player: AVQueuePlayer?
  private var playerItem: AVPlayerItem?
  private var timeObserverToken: Any?

  // MARK: - Gapless queue state
  /// AVPlayerItem identity → index into `queue`. Resolves which track the
  /// AVQueuePlayer is playing after a gapless auto-advance.
  private var itemIndexByIdentity: [ObjectIdentifier: Int] = [:]
  /// Item preloaded behind the current one. AVQueuePlayer plays it with no
  /// gap as long as it is buffered in time; nil falls back to a full swap.
  private var queuedNextItem: AVPlayerItem?
  private var queuedNextIdx: Int?
  /// Set right before a manual `setNowPlaying` swap so the `currentItem` KVO
  /// observer knows that call owns the state update.
  private var manuallyActivatedItem: AVPlayerItem?
  private var currentItemObservation: AnyCancellable?
  private var statusObservedItem: AVPlayerItem?
  private var observersAttachedToItem: AVPlayerItem?
  /// How many seconds before the end of the current track a remote next item
  /// is enqueued when it was not already served from disk.
  private let gaplessRemoteLeadTime: Double = 10

  // MARK: - Failure supervision
  /// A failed item must not strand playback. This dedupes the two failure
  /// signals (status KVO and FailedToPlayToEndTime) per item.
  private var didHandleFailureForItem: AVPlayerItem?
  private var failedSkipCount: Int = 0
  private let maxFailedSkips = 3
  /// The preload that just failed, so it is not re-armed on every tick until
  /// the track or queue changes.
  private var failedPreloadIdx: Int?
  private var failedPreloadMediaFileId: String?
  private var advanceWatchdogWorkItem: DispatchWorkItem?
  private let advanceWatchdogDelay: TimeInterval = 1.5
  private var queuedNextStatusObservation: AnyCancellable?
  private var queuedNextStatusObservedItem: AVPlayerItem?

  @Published var queue: [QueueEntity] = []
  @Published var playbackMode = PlaybackMode.defaultPlayback

  @Published var activeQueueIdx: Int = 0

  @Published var isMediaFailed: Bool = false
  @Published var isMediaLoading: Bool = false
  @Published var isShuffling: Bool = false
  @Published var isPlaying: Bool = false
  @Published var isSeeking: Bool = false
  @Published var isLyricsMode: Bool = false

  @Published var lyrics: [LyricsLine] = []
  @Published var currentLyricsLineIndex: Int = 0
  @Published var isLoadingLyrics: Bool = false
  @Published var lyricsError: String?

  @Published var progress: Double = 0.0

  @Published var currentTimeString: String = "00:00"
  @Published var totalTimeString: String = "00:00"
  @Published var shouldHidePlayer: Bool = false
  @Published var externalOutputName: String?
  @Published var isStarred: Bool = false
  @Published var playbackVolume: Float = UserDefaultsManager.playbackVolume {
    didSet {
      let clamped = min(max(playbackVolume, 0), 1)
      if clamped != playbackVolume {
        playbackVolume = clamped
        return
      }
      UserDefaultsManager.playbackVolume = clamped
      player?.volume = clamped
    }
  }
  private var volumeBeforeMute: Float = UserDefaultsManager.playbackVolume

  // FIXME: this make confusion with `isDownloaded` and/or `isPlayingFromLocal`
  @Published var _playFromLocal: Bool = false

  private var isLocallySaved: Bool = false
  private var isFinished: Bool = false
  private var totalDuration: Double = 0.0
  private var lastProgressPersistAt: Date?
  private var playerItemObservation: AnyCancellable?
  private var interruptionObservation = Set<AnyCancellable>()
  private var routeChangeObservation = Set<AnyCancellable>()
  private var eqPresetObservation = Set<AnyCancellable>()

  // FLO-5/FLO-3 hardening: stall and end-of-track state machine
  private var bufferEmptyCancellable: AnyCancellable?
  private var bufferKeepUpCancellable: AnyCancellable?
  private var stallNotificationToken: NSObjectProtocol?
  private var failedToEndToken: NSObjectProtocol?
  private var didPlayToEndToken: NSObjectProtocol?
  private var lastNextSongFire: Date?
  private var stallRetryCount: Int = 0
  private var isRecoveringFromStall: Bool = false
  private let stallMaxRetries = 2
  private let endTolerance: Double = 0.5
  private let nextSongDebounce: TimeInterval = 0.8

  private var scrobbleThreshold = 0.5
  private var hasTriggeredCache: Bool = false

  /// Never-trapping now-playing accessor. Views (and cover-art / CarPlay /
  /// Watch readers) evaluate this during the teardown window after the queue
  /// empties but before the presence gates flip — returning a blank sentinel
  /// instead of subscript-trapping keeps that window crash-free.
  var nowPlaying: QueueEntity {
    if queue.indices.contains(activeQueueIdx) {
      return queue[activeQueueIdx]
    }
    return Self.emptyQueueSentinel
  }

  /// Blank stand-in for `nowPlaying` when there is nothing to play. Lives in
  /// a store-less scratch context (never saved, never merged, never deleted
  /// by `clearQueue`), so it is always safe to read: every attribute is
  /// nil/zero, matching what the hidden player UI would show anyway.
  private static let emptyQueueSentinel: QueueEntity = {
    let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
    context.persistentStoreCoordinator =
      CoreDataManager.shared.persistentContainer.persistentStoreCoordinator
    return QueueEntity(context: context)
  }()

  var isPlayFromSource: Bool {
    return self._playFromLocal
      || UserDefaultsManager.maxBitRate == TranscodingSettings.sourceBitRate
  }

  var isLRCLIBEnabled: Bool {
    return UserDefaultsManager.LRCLIBServerURL != ""
  }

  var lyricsSourceName: String? {
    LRCLIBSource.displayName(for: UserDefaultsManager.LRCLIBServerURL)
  }

  var isLiveRadio: Bool {
    guard hasNowPlaying() else { return false }

    return nowPlaying.duration.isInfinite || nowPlaying.duration.isNaN
  }

  init() {
    self.player = AVQueuePlayer()
    self.player?.volume = UserDefaultsManager.playbackVolume
    self.currentItemObservation = self.player?.publisher(for: \.currentItem)
      .receive(on: DispatchQueue.main)
      .sink { [weak self] item in
        self?.handleCurrentItemChanged(item)
      }
    self.volumeBeforeMute = UserDefaultsManager.playbackVolume > 0 ? UserDefaultsManager.playbackVolume : 1.0
    self.observeInterruptionNotifications()
    self.observeRouteChangeNotifications()
    self.observeEqualizerPresetChanges()
    self.updateAudioRoute()

    let lastPlayData = PlaybackService.shared.getQueue()
    let queueActiveIdx = UserDefaultsManager.queueActiveIdx

    if !lastPlayData.isEmpty && queueActiveIdx < lastPlayData.count {
      self.progress = UserDefaultsManager.nowPlayingProgress
      self.playbackMode = UserDefaultsManager.playbackMode
      self.addToQueue(
        idx: UserDefaultsManager.queueActiveIdx, item: lastPlayData, playAudio: false)

      // if users played more than half of the song then it's considered as saved
      if self.progress > scrobbleThreshold {
        self.isLocallySaved = true
      }
    } else {
      UserDefaultsManager.removeObject(key: UserDefaultsKeys.queueActiveIdx)
      UserDefaultsManager.removeObject(key: UserDefaultsKeys.nowPlayingProgress)
      PlaybackService.shared.clearQueue()
    }

    self.setupRemoteCommandCenter()
  }

  func observeInterruptionNotifications() {
    NotificationCenter.default
      .publisher(for: AVAudioSession.interruptionNotification)
      .sink { [weak self] notification in
        guard let self else { return }
        self.handleInterruptionNotification(notification)
      }
      .store(in: &interruptionObservation)
  }

  func observeRouteChangeNotifications() {
    NotificationCenter.default
      .publisher(for: AVAudioSession.routeChangeNotification)
      .sink { [weak self] _ in
        guard let self else { return }
        self.updateAudioRoute()
      }
      .store(in: &routeChangeObservation)
  }

  func observeEqualizerPresetChanges() {
    NotificationCenter.default
      .publisher(for: .eqPresetDidChange)
      .receive(on: DispatchQueue.main)
      .sink { [weak self] notification in
        guard let self, let item = self.playerItem, self.hasNowPlaying() else { return }
        let wasBypassed = (notification.userInfo?["wasBypassed"] as? Bool) ?? true
        let isBypassed = (notification.userInfo?["isBypassed"] as? Bool) ?? true
        // Preset-to-preset updates flow through the tap's live gains.
        // Only (de)attach the mix when bypass state flips — e.g. Off->Rock
        // on the playing item, which otherwise would stay unequalized
        // until the next track.
        guard wasBypassed != isBypassed else { return }
        item.audioMix = EqualizerManager.shared.makeAudioMix()
      }
      .store(in: &eqPresetObservation)
  }

  func updateAudioRoute() {
    let outputs = AVAudioSession.sharedInstance().currentRoute.outputs

    if let externalOutput = outputs.first(where: { !Self.isInternalAudioOutput($0) }) {
      self.externalOutputName = externalOutput.portName
    } else {
      self.externalOutputName = nil
    }
  }

  private static func isInternalAudioOutput(_ output: AVAudioSessionPortDescription) -> Bool {
    switch output.portType {
    case .builtInReceiver, .builtInSpeaker, .builtInMic:
      return true
    default:
      return false
    }
  }

  // MARK: - FLO-5 / FLO-3: Stall + end-of-track helpers

  private func removePlayerItemObservers() {
    observersAttachedToItem = nil
    bufferEmptyCancellable?.cancel()
    bufferKeepUpCancellable?.cancel()
    bufferEmptyCancellable = nil
    bufferKeepUpCancellable = nil

    if let token = stallNotificationToken {
      NotificationCenter.default.removeObserver(token)
      stallNotificationToken = nil
    }
    if let token = failedToEndToken {
      NotificationCenter.default.removeObserver(token)
      failedToEndToken = nil
    }
    if let token = didPlayToEndToken {
      NotificationCenter.default.removeObserver(token)
      didPlayToEndToken = nil
    }
    // Keep playerItemObservation for status; caller cancels separately if needed
  }

  private func setupPlayerItemObservers(for item: AVPlayerItem) {
    guard observersAttachedToItem !== item else { return }

    removePlayerItemObservers()
    observersAttachedToItem = item
    stallRetryCount = 0
    isRecoveringFromStall = false

    // KVO: playbackBufferEmpty — true means we drained the forward buffer.
    bufferEmptyCancellable = item.publisher(for: \.isPlaybackBufferEmpty)
      .receive(on: DispatchQueue.main)
      .sink { [weak self] isEmpty in
        guard let self else { return }
        if isEmpty, self.isPlaying, !self.isRecoveringFromStall {
          // Will enter waitingToPlayAtSpecifiedRate; let KeepUp observer drive recovery.
          self.isMediaLoading = true
        }
      }

    // KVO: playbackLikelyToKeepUp — false/true transition drives auto-resume.
    bufferKeepUpCancellable = item.publisher(for: \.isPlaybackLikelyToKeepUp)
      .receive(on: DispatchQueue.main)
      .sink { [weak self] likely in
        guard let self else { return }
        if likely, self.isPlaying, self.player?.timeControlStatus == .waitingToPlayAtSpecifiedRate {
          // Buffer refilled — resume if we were stalled.
          if self.isRecoveringFromStall {
            self.isRecoveringFromStall = false
            self.isMediaLoading = false
          }
          self.player?.play()
          self.updateNowPlayingInfo(progress: self.progress, rate: 1.0)
        } else if !likely, self.isPlaying {
          // Keep waiting; stall handler may nudge later.
        }
        if likely {
          self.isMediaLoading = false
        }
      }

    stallNotificationToken = NotificationCenter.default.addObserver(
      forName: .AVPlayerItemPlaybackStalled, object: item, queue: .main
    ) { [weak self] _ in
      self?.handlePlaybackStall()
    }

    failedToEndToken = NotificationCenter.default.addObserver(
      forName: .AVPlayerItemFailedToPlayToEndTime, object: item, queue: .main
    ) { [weak self] note in
      self?.handleFailedToPlayToEnd(note)
    }

    didPlayToEndToken = NotificationCenter.default.addObserver(
      forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main
    ) { [weak self] note in
      self?.handleDidPlayToEndTime(note)
    }
  }

  private func handlePlaybackStall() {
    guard isPlaying, !isLiveRadio else { return }
    // FLO-5: transcoded mp3 gap at ~71s triggers playbackStalled / bufferEmpty with
    // timeControlStatus == .waitingToPlayAtSpecifiedRate. Previously no observer existed,
    // so isPlaying stayed true while player was frozen and play() was a no-op.
    if let last = lastNextSongFire, Date().timeIntervalSince(last) < nextSongDebounce {
      return
    }
    if isRecoveringFromStall { return }
    isRecoveringFromStall = true
    isMediaLoading = true

    // First retry: ask AVPlayer to resume (covers transient buffer gap).
    if stallRetryCount < stallMaxRetries {
      stallRetryCount += 1
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
        guard let self else { return }
        if self.isPlaying
          && (self.player?.timeControlStatus == .waitingToPlayAtSpecifiedRate
            || self.player?.rate == 0)
        {
          self.player?.play()
          self.updateNowPlayingInfo(progress: self.progress, rate: 1.0)
        }
      }
      // Second-phase nudge: tiny seek forward to force refill if still stalled after 1.5s.
      DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { [weak self] in
        guard let self else { return }
        let status = self.player?.timeControlStatus
        let empty = self.playerItem?.isPlaybackBufferEmpty ?? false
        if (status == .waitingToPlayAtSpecifiedRate || empty), self.isPlaying {
          let current = CMTimeGetSeconds(self.player?.currentTime() ?? .zero)
          if current.isFinite {
            let nudge = min(max(current + 0.5, 0), max(self.totalDuration - 0.4, 0))
            let target = CMTime(seconds: nudge, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
            self.player?.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
              self?.player?.play()
              self?.updateNowPlayingInfo(progress: self?.progress ?? 0, rate: 1.0)
              self?.isRecoveringFromStall = false
              self?.isMediaLoading = false
            }
            return
          }
        }
        self.isRecoveringFromStall = false
        self.isMediaLoading = false
      }
    } else {
      // Exhausted retries — clear flag and surface loading; user skip still works.
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
        self?.isRecoveringFromStall = false
        self?.isMediaLoading = false
      }
    }
  }

  private func handleFailedToPlayToEnd(_ note: Notification) {
    handleCurrentItemFailure()
  }

  /// Terminal item failure: surface the failed state, then try the next
  /// distinct track. After `maxFailedSkips` consecutive failures we stop and
  /// leave the error visible instead of skipping through the whole queue.
  private func handleCurrentItemFailure() {
    guard let item = playerItem, didHandleFailureForItem !== item else { return }
    didHandleFailureForItem = item

    isMediaLoading = false
    isMediaFailed = true
    isRecoveringFromStall = false
    updateNowPlayingInfo(progress: progress, rate: 0.0)
    MPNowPlayingInfoCenter.default().playbackState = .paused

    // Live radio is a single endless item: nothing to skip to.
    guard !isLiveRadio else {
      player?.pause()
      return
    }

    failedSkipCount += 1
    guard failedSkipCount <= maxFailedSkips, let target = nextDistinctIdxAfterFailure() else {
      player?.pause()
      return
    }

    // Short delay so a failed item does not flicker; the identity guard below
    // drops the skip if the user (or a late transition) moved on already.
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
      guard let self, self.playerItem === item, self.hasNowPlaying() else { return }
      self.advanceToTrack(at: target)
    }
  }

  /// Next track to try after a failure. Unlike `nextQueueIdxForGapless` this
  /// never returns the failed track itself (repeat-once would otherwise loop
  /// on it), but still wraps when a repeat mode is on.
  func nextDistinctIdxAfterFailure() -> Int? {
    guard queue.count > 1, queue.indices.contains(activeQueueIdx) else { return nil }

    let nextIdx = activeQueueIdx + 1
    if nextIdx < queue.count { return nextIdx }

    return playbackMode == PlaybackMode.defaultPlayback ? nil : 0
  }

  private func handleDidPlayToEndTime(_ note: Notification) {
    // FLO-3: authoritative end-of-track signal; replaces sole reliance on rounding.
    guard !isLiveRadio else { return }

    // Gapless: the item already advanced, or a preloaded next item is waiting.
    if let ended = note.object as? AVPlayerItem, ended !== playerItem { return }
    if queuedNextItem != nil {
      scheduleAdvanceWatchdog(for: note.object as? AVPlayerItem)
      return
    }

    if let last = lastNextSongFire, Date().timeIntervalSince(last) < nextSongDebounce {
      return
    }
    // Ignore spurious end while stalled mid-track (buffer empty but not near end).
    if let item = playerItem, item.isPlaybackBufferEmpty,
       player?.timeControlStatus == .waitingToPlayAtSpecifiedRate {
      let current = CMTimeGetSeconds(player?.currentTime() ?? .zero)
      if current.isFinite, totalDuration.isFinite, totalDuration > 0,
         current + endTolerance < totalDuration - 1.0 {
        return
      }
    }
    nextSong()
    UserDefaultsManager.removeObject(key: UserDefaultsKeys.nowPlayingProgress)
  }

  private func shouldAdvanceToNextTrack(currentTime: Double) -> Bool {
    guard !isLiveRadio,
          totalDuration.isFinite, totalDuration > 0,
          currentTime.isFinite else { return false }
    // FLO-3: tolerance instead of round/floor; prevents early skip when duration estimate short.
    let remaining = totalDuration - currentTime
    guard remaining <= endTolerance else { return false }
    // Do not advance if we are stalled mid-track (transcoded gap, not end).
    if player?.timeControlStatus == .waitingToPlayAtSpecifiedRate,
       playerItem?.isPlaybackBufferEmpty == true,
       remaining > 1.0 {
      return false
    }
    if let last = lastNextSongFire, Date().timeIntervalSince(last) < nextSongDebounce {
      return false
    }
    // Ensure we were actually playing forward, not seeking or paused.
    if player?.rate == 0, player?.timeControlStatus != .waitingToPlayAtSpecifiedRate {
      return false
    }
    return true
  }

  func handleInterruptionNotification(_ notification: Notification) {
    guard let userInfo = notification.userInfo,
      let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? Int,
      let type = AVAudioSession.InterruptionType(rawValue: UInt(typeValue))
    else {
      return
    }

    switch type {
    case .began:
      // CarPlay / phone call / Siri: pause but keep isPlaying intent for .shouldResume gate
      self.pause()

    case .ended:
      // FLO-3: guard against double-play race (unconditional play + conditional play).
      // Only resume when the system explicitly signals .shouldResume.
      if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? Int {
        let options = AVAudioSession.InterruptionOptions(rawValue: UInt(optionsValue))

        if options.contains(.shouldResume) {
          // Debounce: if we already fired nextSong within 0.8s, do not resume stray playback
          if let last = lastNextSongFire, Date().timeIntervalSince(last) < nextSongDebounce {
            break
          }
          self.play()
        }
      }
      // No .shouldResume -> remain paused; NowPlayingManager will stay in .paused.

    @unknown default:
      break
    }
  }

  func addToQueue(idx: Int, item: [QueueEntity], playAudio: Bool = true) {
    self.activeQueueIdx = idx
    self.queue = item
    self.setNowPlaying(playAudio: playAudio)
  }

  func getAlbumCoverArt() -> String {
    guard hasNowPlaying() else { return "" }
    return AlbumService.shared.getAlbumCover(
      artistName: self.nowPlaying.artistName ?? "",
      albumName: self.nowPlaying.albumName ?? "",
      albumId: self.nowPlaying.albumId ?? "",
      trackId: self.nowPlaying.id ?? "",
      contextName: self.nowPlaying.contextName,
      albumCover: self.nowPlaying.albumCover ?? ""
    )
  }

  func hasNowPlaying() -> Bool {
    return !self.queue.isEmpty
  }

  func setNowPlaying(playAudio: Bool = true) {
    guard self.queue.indices.contains(self.activeQueueIdx) else {
      self.isMediaLoading = false
      self.isMediaFailed = true

      return
    }

    self.shouldHidePlayer = false
    self.isMediaFailed = false
    self.hasTriggeredCache = false

    StreamCacheManager.shared.cancelAllInFlight()

    try? AVAudioSession.sharedInstance().setActive(true)

    // Tear down the prior item's stall/end observers before swapping items (FLO-5/FLO-3)
    self.removePlayerItemObservers()

    guard let newItem = makePlayerItem(forQueueIndex: self.activeQueueIdx, allowRemote: true) else {
      self.isMediaLoading = false
      self.isMediaFailed = true

      return
    }

    removeUpcomingItems()

    self.manuallyActivatedItem = newItem
    self.player?.automaticallyWaitsToMinimizeStalling = false
    self.player?.volume = playbackVolume
    self.player?.removeAllItems()
    self.player?.insert(newItem, after: nil)
    self.bindCurrentItem(newItem)
    self.pruneItemIndexMap()

    applyCommonTrackState(for: newItem)

    if playAudio {
      self.seek(to: 0.0)
      self.play()
    } else {
      self.seek(to: self.progress)
    }

    primeGaplessNext()
  }

  // MARK: - Gapless queue

  /// Index of the track that should play after the current one, honoring the
  /// repeat mode. `nil` means playback stops at the end of the queue.
  /// Internal (not private) so the unit tests can pin the boundary cases.
  func nextQueueIdxForGapless() -> Int? {
    guard !queue.isEmpty, queue.indices.contains(activeQueueIdx) else { return nil }

    if playbackMode == PlaybackMode.repeatOnce {
      return activeQueueIdx
    }

    if playbackMode == PlaybackMode.repeatAlbum {
      return activeQueueIdx + 1 >= queue.count ? 0 : activeQueueIdx + 1
    }

    let nextIdx = activeQueueIdx + 1
    return nextIdx < queue.count ? nextIdx : nil
  }

  /// Builds a player item for a queue index. `allowRemote: false` returns nil
  /// unless the track already exists on disk (download or stream cache), which
  /// is what makes a transition gapless without racing the network.
  private func makePlayerItem(forQueueIndex idx: Int, allowRemote: Bool) -> AVPlayerItem? {
    guard queue.indices.contains(idx) else { return nil }

    let songId = queue[idx].id ?? ""
    guard !songId.isEmpty else { return nil }

    let streamUrl = AlbumService.shared.getStreamUrl(id: songId)
    guard !streamUrl.isEmpty, let audioURL = URL(string: streamUrl) else { return nil }
    guard allowRemote || audioURL.isFileURL else { return nil }

    let item: AVPlayerItem

    if !audioURL.isFileURL, AuthService.shared.getAuthMode() == .iap {
      let cookies = HTTPCookieStorage.shared.cookies(for: audioURL) ?? []
      let asset = AVURLAsset(url: audioURL, options: [AVURLAssetHTTPCookiesKey: cookies])
      item = AVPlayerItem(asset: asset)
    } else {
      item = AVPlayerItem(url: audioURL)
    }

    // EQ: per-item tap (nil when Off/Flat = bit-perfect bypass).
    item.audioMix = EqualizerManager.shared.makeAudioMix()
    // Prefer smaller forward buffer for transcoded streams so gaps surface faster and recover.
    item.preferredForwardBufferDuration = 3
    itemIndexByIdentity[ObjectIdentifier(item)] = idx

    return item
  }

  /// Points the view model at a new current item: EQ state, status + stall
  /// observers. The EQ mix is refreshed here because a pre-queued item may
  /// have been built while a different preset was active.
  private func bindCurrentItem(_ item: AVPlayerItem) {
    guard playerItem !== item else { return }

    playerItem = item
    item.audioMix = EqualizerManager.shared.makeAudioMix()
    observeCurrentItemStatus(item)
    setupPlayerItemObservers(for: item)
  }

  private func observeCurrentItemStatus(_ item: AVPlayerItem) {
    guard statusObservedItem !== item else { return }

    playerItemObservation?.cancel()
    playerItemObservation = nil
    statusObservedItem = item

    playerItemObservation = item.publisher(for: \.status)
      .receive(on: DispatchQueue.main)
      .sink { [weak self] status in
        guard let self = self else { return }
        switch status {
        case .readyToPlay:
          self.failedSkipCount = 0
          self.didHandleFailureForItem = nil
          DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.isMediaLoading = false
            self.isMediaFailed = false
          }
        case .failed:
          self.handleCurrentItemFailure()
        case .unknown:
          self.isMediaLoading = false
        @unknown default:
          self.isMediaLoading = true
        }
      }
  }

  /// KVO entry point for `AVQueuePlayer.currentItem`. Fires for manual swaps
  /// (owned by `setNowPlaying`) and for gapless auto-advance (owned here).
  private func handleCurrentItemChanged(_ item: AVPlayerItem?) {
    guard let item else { return }

    advanceWatchdogWorkItem?.cancel()

    let isSameItem = playerItem === item
    bindCurrentItem(item)

    if manuallyActivatedItem === item {
      manuallyActivatedItem = nil
      return
    }

    guard !isSameItem else { return }
    guard let idx = itemIndexByIdentity[ObjectIdentifier(item)] else { return }

    // The preloaded item is now the current one; stop tracking it as "next".
    clearQueuedNextTracking()

    activeQueueIdx = idx
    pruneItemIndexMap()
    advanceTrackState()
  }

  /// State sync for an automatic (gapless) transition. The audio never
  /// stopped, so no seek/play is issued — only metadata and bookkeeping.
  private func advanceTrackState() {
    guard hasNowPlaying(), let item = playerItem else { return }

    progress = 0.0
    currentTimeString = "00:00"
    isMediaLoading = false
    isMediaFailed = false

    applyCommonTrackState(for: item)
    updateNowPlayingInfo(progress: 0, rate: isPlaying ? 1.0 : 0.0)
    UserDefaultsManager.removeObject(key: UserDefaultsKeys.nowPlayingProgress)

    // Resume after a failure-recovery advance; a natural gapless advance is
    // already playing, where this is a harmless no-op.
    if isPlaying {
      player?.play()
    }

    primeGaplessNext()
  }

  /// Everything that must change when the now-playing track changes, except
  /// item swapping and transport (seek/play).
  private func applyCommonTrackState(for item: AVPlayerItem) {
    self.shouldHidePlayer = false
    self.isLocallySaved = false
    self.hasTriggeredCache = false
    self.clearFailedPreloadGuard()

    self.resetLyrics()
    self.checkStarredStatus()
    StreamCacheManager.shared.setCurrentlyPlaying(mediaFileId: self.nowPlaying.id ?? "")

    if let asset = item.asset as? AVURLAsset {
      self._playFromLocal = asset.url.isFileURL
    }

    let duration = CMTime(
      seconds: self.nowPlaying.duration, preferredTimescale: self.nowPlaying.sampleRate)
    let playbackDuration = CMTimeGetSeconds(duration)

    self.totalDuration = playbackDuration
    self.totalTimeString = timeString(for: playbackDuration)
    self.currentTimeString = timeString(for: self.progress * playbackDuration)

    self.addPeriodicTimeObserver()
    self.initNowPlayingInfo(
      title: self.nowPlaying.songName ?? "",
      artist: self.nowPlaying.artistName ?? "",
      playbackDuration: playbackDuration)

    FloooViewModel.shared.setNowPlayingToScrobbleServer(nowPlaying: self.nowPlaying)

    if isLRCLIBEnabled && !isLiveRadio {
      self.fetchLyrics()
    }

    UserDefaultsManager.queueActiveIdx = self.activeQueueIdx
  }

  /// Enqueues the next track behind the current one when it is already on
  /// disk. Remote tracks wait for the deadline check so two server transcodes
  /// do not compete mid-track.
  private func primeGaplessNext() {
    guard !isLiveRadio, hasNowPlaying(), queuedNextItem == nil,
      let nextIdx = nextQueueIdxForGapless(),
      !isFailedPreloadCandidate(nextIdx),
      let currentItem = player?.currentItem
    else { return }

    guard let nextItem = makePlayerItem(forQueueIndex: nextIdx, allowRemote: false) else { return }

    insertQueuedNext(nextItem, at: nextIdx, after: currentItem)
  }

  private func insertQueuedNext(_ item: AVPlayerItem, at idx: Int, after currentItem: AVPlayerItem) {
    guard queuedNextItem == nil, item !== currentItem,
      player?.canInsert(item, after: currentItem) == true
    else {
      itemIndexByIdentity.removeValue(forKey: ObjectIdentifier(item))
      return
    }

    player?.insert(item, after: currentItem)
    queuedNextItem = item
    queuedNextIdx = idx
    observeQueuedNextStatus(item, idx: idx)
    StreamCacheManager.shared.setWillPlayNext(
      mediaFileId: queue.indices.contains(idx) ? queue[idx].id : nil)
  }

  /// Once per tick: enqueue the next item when the current track is about to
  /// end and nothing is queued yet (stream-cache miss fallback).
  private func maybeQueueNextItemBeforeDeadline(currentTime: Double) {
    guard !isLiveRadio, isPlaying, queuedNextItem == nil,
      totalDuration.isFinite, totalDuration > 0,
      let nextIdx = nextQueueIdxForGapless(),
      !isFailedPreloadCandidate(nextIdx),
      let currentItem = player?.currentItem
    else { return }

    let remaining = totalDuration - currentTime
    guard remaining > 0, remaining <= gaplessRemoteLeadTime else { return }
    guard let nextItem = makePlayerItem(forQueueIndex: nextIdx, allowRemote: true) else { return }

    insertQueuedNext(nextItem, at: nextIdx, after: currentItem)
  }

  /// Drops every enqueued item behind the current one (queue edit, repeat
  /// mode change, manual swap). The playing item keeps playing.
  private func removeUpcomingItems() {
    guard let player else {
      clearQueuedNextTracking()
      itemIndexByIdentity.removeAll()
      return
    }

    let current = player.currentItem
    for item in player.items() where item !== current {
      player.remove(item)
    }

    clearQueuedNextTracking()
    pruneItemIndexMap()
  }

  private func pruneItemIndexMap() {
    guard let player else {
      itemIndexByIdentity.removeAll()
      return
    }

    let live = Set(player.items().map(ObjectIdentifier.init))
    itemIndexByIdentity = itemIndexByIdentity.filter { live.contains($0.key) }
  }

  /// Re-arms the gapless queue after the queue contents or order changed.
  private func resyncGaplessQueue() {
    guard player?.currentItem != nil else { return }

    clearFailedPreloadGuard()
    removeUpcomingItems()
    pruneItemIndexMap()
    primeGaplessNext()
  }

  // MARK: - Gapless queue failure supervision

  /// Applies the failed-preload guard: the same queue index/media id is not
  /// re-armed until the current track or the queue changes.
  private func isFailedPreloadCandidate(_ idx: Int) -> Bool {
    guard failedPreloadIdx == idx else { return false }
    let candidateId = queue.indices.contains(idx) ? queue[idx].id : nil
    return candidateId == failedPreloadMediaFileId
  }

  private func clearFailedPreloadGuard() {
    failedPreloadIdx = nil
    failedPreloadMediaFileId = nil
  }

  /// Stops tracking the preloaded item (status observation, cache eviction
  /// protection, queued state).
  private func clearQueuedNextTracking() {
    queuedNextStatusObservation?.cancel()
    queuedNextStatusObservation = nil
    queuedNextStatusObservedItem = nil
    queuedNextItem = nil
    queuedNextIdx = nil
    StreamCacheManager.shared.setWillPlayNext(mediaFileId: nil)
  }

  private func discardQueuedNextItem() {
    if let item = queuedNextItem {
      player?.remove(item)
      itemIndexByIdentity.removeValue(forKey: ObjectIdentifier(item))
    }
    clearQueuedNextTracking()
  }

  private func observeQueuedNextStatus(_ item: AVPlayerItem, idx: Int) {
    queuedNextStatusObservation?.cancel()
    queuedNextStatusObservedItem = item
    queuedNextStatusObservation = item.publisher(for: \.status)
      .receive(on: DispatchQueue.main)
      .sink { [weak self] status in
        guard status == .failed, let self, self.queuedNextItem === item else { return }
        self.handleQueuedNextItemFailure(item, idx: idx)
      }
  }

  /// The preloaded item is dead. Drop it and remember not to retry that exact
  /// track this round; the fallback path at track end handles the retry.
  private func handleQueuedNextItemFailure(_ item: AVPlayerItem, idx: Int) {
    failedPreloadIdx = idx
    failedPreloadMediaFileId = queue.indices.contains(idx) ? queue[idx].id : nil
    discardQueuedNextItem()
  }

  /// If AVQueuePlayer fails to advance on its own while a next item is queued,
  /// drop the preload and take the replaceCurrentItem-era path so playback
  /// cannot dead-end at the last second of a track.
  private func scheduleAdvanceWatchdog(for endedItem: AVPlayerItem?) {
    advanceWatchdogWorkItem?.cancel()
    guard let endedItem else { return }

    let work = DispatchWorkItem { [weak self] in
      guard let self, self.playerItem === endedItem, self.queuedNextItem != nil else { return }
      self.discardQueuedNextItem()
      self.nextSong()
      UserDefaultsManager.removeObject(key: UserDefaultsKeys.nowPlayingProgress)
    }
    advanceWatchdogWorkItem = work
    DispatchQueue.main.asyncAfter(deadline: .now() + advanceWatchdogDelay, execute: work)
  }

  /// Persisting playback progress on every 1s tick writes UserDefaults once per
  /// second, which invalidates `@AppStorage` state across the app — including
  /// ContentView's tab hierarchy, which then re-diffs (and UIKit rebuilds its
  /// tab bar items) every second during playback. The stored value only has to
  /// be good enough to restore the position on relaunch, so persist on a
  /// throttle and flush it whenever playback pauses or is seeked.
  private func persistProgressThrottled(force: Bool = false) {
    let now = Date()
    if !force, let last = lastProgressPersistAt, now.timeIntervalSince(last) < 5 {
      return
    }
    lastProgressPersistAt = now
    UserDefaultsManager.nowPlayingProgress = self.progress
  }

  private func addPeriodicTimeObserver() {
    guard timeObserverToken == nil, let player = self.player else { return }

    let interval = CMTime(seconds: 1, preferredTimescale: CMTimeScale(NSEC_PER_SEC))

    timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) {
      [weak self] time in
      guard let self else { return }
      let currentTime = CMTimeGetSeconds(time)

      if self.totalDuration.isFinite, self.totalDuration > 0 {
        self.progress = currentTime / self.totalDuration
      } else {
        self.progress = 0.0
      }

      self.currentTimeString = timeString(for: currentTime)

      self.persistProgressThrottled()

      if self.isLRCLIBEnabled {
        self.updateCurrentLyricsLine(currentTime: currentTime)
      }

      if !self.isLocallySaved && self.progress >= 0.5 {
        self.isLocallySaved = true
        // Capture identity now: a very short track may already have advanced
        // by the time the task runs, which would scrobble the next song.
        let scrobbledTrack = self.nowPlaying

        Task { @MainActor in
          FloooViewModel.shared.scrobble(submission: true, nowPlaying: scrobbledTrack)
        }
      }

      if !self.hasTriggeredCache && currentTime >= 10.0 && !self.isLiveRadio {
        self.hasTriggeredCache = true
        if let nextIdx = self.nextQueueIdxForPreCache(),
          let nextId = self.queue[nextIdx].id, !nextId.isEmpty
        {
          let nextItem = self.queue[nextIdx]
          StreamCacheManager.shared.cacheSong(
            mediaFileId: nextId, originalSuffix: nextItem.suffix, from: nextItem
          ) { [weak self] ready in
            // The next track just landed on disk — enqueue it now for a
            // seamless transition instead of letting the deadline race it.
            guard ready, let self else { return }
            self.primeGaplessNext()
          }
        }
      }

      // Gapless: when the current track is about to end and no next item is
      // queued yet (cache miss), fall back to enqueueing the remote stream.
      self.maybeQueueNextItemBeforeDeadline(currentTime: currentTime)

      // FLO-3/FLO-5: tolerance + stall + debounce guard (replaces round/floor).
      // When a next item is already enqueued, AVQueuePlayer owns the
      // transition — advancing here would cut the tail and rebuild the item.
      if self.queuedNextItem == nil, self.shouldAdvanceToNextTrack(currentTime: currentTime) {
        self.nextSong()
        UserDefaultsManager.removeObject(key: UserDefaultsKeys.nowPlayingProgress)
      }
    }
  }

  private func initNowPlayingInfo(
    title: String, artist: String, playbackDuration: Double
  ) {
    DispatchQueue.global().async {
      let artwork = self.makeNowPlayingArtwork()

      DispatchQueue.main.async {
        var nowPlayingInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [String: Any]()

        nowPlayingInfo[MPMediaItemPropertyTitle] = title
        nowPlayingInfo[MPMediaItemPropertyArtist] = artist
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = playbackDuration
        nowPlayingInfo[MPMediaItemPropertyIsExplicit] =
          ExplicitStatus(from: self.nowPlaying.explicitStatus).isExplicit

        if let artwork = artwork {
          nowPlayingInfo[MPMediaItemPropertyArtwork] = artwork
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
      }
    }
  }

  private func makeNowPlayingArtwork() -> MPMediaItemArtwork? {
    if isLiveRadio {
      if let image = UIImage(named: "placeholder") {
        return MPMediaItemArtwork(boundsSize: image.size) { _ in
          return image
        }
      }

      return nil
    }

    let albumCoverArt = self.getAlbumCoverArt()

    let image: UIImage?

    if albumCoverArt.hasPrefix("/") {
      image = UIImage(contentsOfFile: albumCoverArt)
    } else if let remoteURL = URL(string: albumCoverArt),
      let data = try? Data(contentsOf: remoteURL)
    {
      image = UIImage(data: data)
    } else {
      image = nil
    }

    guard let resolvedImage = image else {
      return nil
    }

    return MPMediaItemArtwork(boundsSize: resolvedImage.size) { _ in
      return resolvedImage
    }
  }

  func updateNowPlayingInfo(progress: TimeInterval, rate: Float) {
    var nowPlayingInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [String: Any]()

    nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = progress * self.totalDuration
    nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = self.totalDuration
    nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = rate

    MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
  }

  private func setupRemoteCommandCenter() {
    let commandCenter = MPRemoteCommandCenter.shared()

    commandCenter.playCommand.isEnabled = true
    commandCenter.playCommand.addTarget { [weak self] _ in
      guard let self else { return .commandFailed }
      self.play()
      return .success
    }

    commandCenter.pauseCommand.isEnabled = true
    commandCenter.pauseCommand.addTarget { [weak self] _ in
      guard let self else { return .commandFailed }
      self.pause()
      return .success
    }

    // FLO-6: Wired EarPods single-press sends togglePlayPauseCommand (iOS 26),
    // not discrete play/pause. Without this target the click is dropped as
    // .commandFailed while volume/skip still work.
    commandCenter.togglePlayPauseCommand.isEnabled = true
    commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
      guard let self else { return .commandFailed }
      if self.isPlaying {
        self.pause()
      } else {
        self.play()
      }
      return .success
    }

    commandCenter.nextTrackCommand.isEnabled = true
    commandCenter.nextTrackCommand.addTarget { event in
      self.nextSong()

      return .success
    }

    commandCenter.previousTrackCommand.isEnabled = true
    commandCenter.previousTrackCommand.addTarget { event in
      self.prevSong()

      return .success
    }

    commandCenter.changePlaybackPositionCommand.isEnabled = true
    commandCenter.changePlaybackPositionCommand.addTarget { event in
      if self.isLiveRadio {
        return .commandFailed
      }

      if let event = event as? MPChangePlaybackPositionCommandEvent {
        let progress = event.positionTime / self.totalDuration

        self.seek(to: progress)

        return .success
      }

      return .commandFailed
    }
  }

  func play() {
    if self.isFinished {
      self.stop()
      self.updateNowPlayingInfo(progress: self.progress, rate: 0.0)
    }

    player?.volume = playbackVolume
    player?.play()

    self.isFinished = false
    self.isPlaying = true
    // If user explicitly hits play after a stall, clear stall gating so next stall can recover again.
    if isRecoveringFromStall, player?.timeControlStatus != .waitingToPlayAtSpecifiedRate {
      isRecoveringFromStall = false
      stallRetryCount = 0
    }
    self.isMediaLoading = false
    self.updateNowPlayingInfo(progress: self.progress, rate: 1.0)
    MPNowPlayingInfoCenter.default().playbackState = .playing
  }

  func pause() {
    player?.pause()

    self.isPlaying = false
    self.isRecoveringFromStall = false
    self.persistProgressThrottled(force: true)
    self.updateNowPlayingInfo(progress: self.progress, rate: 0.0)
    MPNowPlayingInfoCenter.default().playbackState = .paused
  }

  func stop() {
    player?.pause()
    player?.seek(to: CMTime.zero)

    self.isFinished = true
    self.isPlaying = false
  }

  func seek(to progress: Double) {
    if isLiveRadio {
      return
    }

    self.progress = progress
    self.persistProgressThrottled(force: true)

    let newTime = CMTime(
      seconds: progress * totalDuration, preferredTimescale: CMTimeScale(NSEC_PER_SEC))

    player?.seek(to: newTime)

    self.updateNowPlayingInfo(progress: progress, rate: 1.0)

    if isLRCLIBEnabled {
      self.updateCurrentLyricsLine(currentTime: progress * totalDuration)
    }
  }

  func setPlaybackMode() {
    if self.playbackMode == PlaybackMode.defaultPlayback {
      self.playbackMode = PlaybackMode.repeatAlbum
    } else if self.playbackMode == PlaybackMode.repeatAlbum {
      self.playbackMode = PlaybackMode.repeatOnce
    } else {
      self.playbackMode = PlaybackMode.defaultPlayback
    }

    UserDefaultsManager.playbackMode = self.playbackMode
    resyncGaplessQueue()
  }

  func playBySong<T: Playable>(idx: Int, item: T, isFromLocal: Bool) {
    let queue = PlaybackService.shared.addToQueue(item: item, isFromLocal: isFromLocal)

    self.addToQueue(idx: idx, item: queue)
  }

  func playItem<T: Playable>(item: T, isFromLocal: Bool) {
    let queue = PlaybackService.shared.addToQueue(item: item, isFromLocal: isFromLocal)

    self.addToQueue(idx: 0, item: queue)
  }

  func playRadioItem(radio: Radio) {
    guard let radioUrl = Self.normalizedRadioURL(from: radio.streamUrl) else {
      return
    }

    let item = radio.toPlayable()
    let queue = PlaybackService.shared.addToQueue(item: item, isFromLocal: false)

    self.activeQueueIdx = 0
    self.queue = queue
    self.shouldHidePlayer = false
    self.isLocallySaved = false
    self._playFromLocal = false

    self.resetLyrics()

    self.removePlayerItemObservers()

    let radioItem = AVPlayerItem(url: radioUrl)
    radioItem.audioMix = EqualizerManager.shared.makeAudioMix()
    // Radio: still benefit from stall recovery but DidPlayToEndTime is ignored via isLiveRadio guard.
    radioItem.preferredForwardBufferDuration = 3
    itemIndexByIdentity[ObjectIdentifier(radioItem)] = 0

    removeUpcomingItems()

    self.manuallyActivatedItem = radioItem
    self.player?.automaticallyWaitsToMinimizeStalling = false
    self.player?.volume = playbackVolume
    self.player?.removeAllItems()
    self.player?.insert(radioItem, after: nil)
    self.bindCurrentItem(radioItem)
    self.pruneItemIndexMap()

    self.isMediaLoading = true
    self.isMediaFailed = false
    self.totalDuration = self.nowPlaying.duration
    self.progress = 0.0
    self.currentTimeString = "00:00"
    self.totalTimeString = "00:00"

    self.addPeriodicTimeObserver()
    self.play()

    self.initNowPlayingInfo(
      title: item.name,
      artist: item.artist,
      playbackDuration: 0)
    PlaybackService.shared.clearQueue()
    UserDefaultsManager.removeObject(key: UserDefaultsKeys.nowPlayingProgress)
  }

  func shuffleItem<T: Playable>(item: T, isFromLocal: Bool) {
    var shuffledItem = item
    shuffledItem.songs.shuffle()

    let queue = PlaybackService.shared.addToQueue(item: shuffledItem, isFromLocal: isFromLocal)
    self.addToQueue(idx: 0, item: queue)
  }

  func shuffleCurrentQueue() {
    self.isShuffling.toggle()

    if self.isShuffling {
      self.queue = PlaybackService.shared.shuffleQueue(currentIdx: self.activeQueueIdx)
    } else {
      self.queue = PlaybackService.shared.getQueue()
    }

    resyncGaplessQueue()
  }

  func playFromQueue(idx: Int) {
    if let queued = queuedNextItem, queuedNextIdx == idx {
      advanceToTrack(at: idx)
      return
    }

    self.activeQueueIdx = idx
    self.setNowPlaying()

    UserDefaultsManager.queueActiveIdx = self.activeQueueIdx
  }

  // MARK: - Queue management (reorder / insert / remove)

  /// Where newly queued songs should land relative to the current queue.
  enum QueueInsertPosition {
    /// Directly after the currently playing song.
    case next
    /// After the last consecutive song sharing the now-playing context
    /// (keeps the current album/playlist block together).
    case afterContext
    /// At the very end of the queue.
    case end
  }

  /// Rewrites the persisted queue so it matches the in-memory order
  /// (positions are normalized to the array order).
  private func persistQueueOrdering() {
    let objects = PlaybackService.shared.snapshotObjects(from: queue)
    queue = PlaybackService.shared.replaceQueue(objects: objects)
    UserDefaultsManager.queueActiveIdx = activeQueueIdx
    resyncGaplessQueue()
  }

  private func insertSongs(
    _ songs: [Song], at position: QueueInsertPosition, contextName: String? = nil,
    isFromLocal: Bool = false, isFromPlaylist: Bool = false
  ) {
    guard !songs.isEmpty else { return }

    let context: String = {
      if let contextName, !contextName.isEmpty { return contextName }
      return songs.first?.albumName ?? ""
    }()

    let makeObjects: () -> [[String: Any]] = {
      songs.map { song in
        var object = PlaybackService.shared.queueObject(
          from: song, contextName: context,
          isFromLocal: isFromLocal || !song.fileUrl.isEmpty, position: 0)
        object["isFromPlaylist"] = isFromPlaylist
        return object
      }
    }

    // Empty queue: the inserted songs become the queue and start playing.
    if queue.isEmpty {
      var objects = makeObjects()
      for idx in objects.indices { objects[idx]["position"] = idx }
      queue = PlaybackService.shared.replaceQueue(objects: objects)
      activeQueueIdx = 0
      setNowPlaying()
      UserDefaultsManager.queueActiveIdx = activeQueueIdx
      return
    }

    let insertIdx: Int
    switch position {
    case .next:
      insertIdx = min(activeQueueIdx + 1, queue.count)
    case .end:
      insertIdx = queue.count
    case .afterContext:
      let current = queue[activeQueueIdx].contextName ?? ""
      var idx = activeQueueIdx
      while idx + 1 < queue.count, (queue[idx + 1].contextName ?? "") == current {
        idx += 1
      }
      insertIdx = idx + 1
    }

    // Insertions always land after the now-playing index, so it is unchanged.
    var snapshot = PlaybackService.shared.snapshotObjects(from: queue)
    snapshot.insert(contentsOf: makeObjects(), at: insertIdx)
    for idx in snapshot.indices { snapshot[idx]["position"] = idx }
    queue = PlaybackService.shared.replaceQueue(objects: snapshot)
    UserDefaultsManager.queueActiveIdx = activeQueueIdx
    resyncGaplessQueue()
  }

  /// "Play Next": inserts songs directly after the now-playing song.
  func playNext(
    songs: [Song], contextName: String? = nil, isFromLocal: Bool = false,
    isFromPlaylist: Bool = false
  ) {
    insertSongs(
      songs, at: .next, contextName: contextName, isFromLocal: isFromLocal,
      isFromPlaylist: isFromPlaylist)
  }

  func playNext(
    song: Song, contextName: String? = nil, isFromLocal: Bool = false,
    isFromPlaylist: Bool = false
  ) {
    playNext(
      songs: [song], contextName: contextName, isFromLocal: isFromLocal,
      isFromPlaylist: isFromPlaylist)
  }

  /// "Play After": inserts songs after the current album/playlist block,
  /// keeping the now-playing context together.
  func playAfter(
    songs: [Song], contextName: String? = nil, isFromLocal: Bool = false,
    isFromPlaylist: Bool = false
  ) {
    insertSongs(
      songs, at: .afterContext, contextName: contextName, isFromLocal: isFromLocal,
      isFromPlaylist: isFromPlaylist)
  }

  func playAfter(
    song: Song, contextName: String? = nil, isFromLocal: Bool = false,
    isFromPlaylist: Bool = false
  ) {
    playAfter(
      songs: [song], contextName: contextName, isFromLocal: isFromLocal,
      isFromPlaylist: isFromPlaylist)
  }

  /// "Add to Queue": appends songs to the end of the queue.
  func appendToQueue(
    songs: [Song], contextName: String? = nil, isFromLocal: Bool = false,
    isFromPlaylist: Bool = false
  ) {
    insertSongs(
      songs, at: .end, contextName: contextName, isFromLocal: isFromLocal,
      isFromPlaylist: isFromPlaylist)
  }

  func appendToQueue(
    song: Song, contextName: String? = nil, isFromLocal: Bool = false,
    isFromPlaylist: Bool = false
  ) {
    appendToQueue(
      songs: [song], contextName: contextName, isFromLocal: isFromLocal,
      isFromPlaylist: isFromPlaylist)
  }

  /// In-memory reorder without persisting. Used during drag-hover on
  /// Catalyst (persisting mid-drag would recreate the entities and break
  /// the drag session); call `saveQueueOrder()` on drop.
  func moveQueueInMemory(from source: IndexSet, to destination: Int) {
    guard !queue.isEmpty, queue.indices.contains(activeQueueIdx) else { return }
    let activeObject = queue[activeQueueIdx]
    queue.move(fromOffsets: source, toOffset: destination)
    if let newIdx = queue.firstIndex(where: { $0 === activeObject }) {
      activeQueueIdx = newIdx
    }
  }

  /// Album-level variants for grid context menus. Downloaded albums
  /// resolve locally (offline-capable); otherwise songs are fetched first.
  func playNext(album: Album) {
    queueAlbum(album, at: .next)
  }

  func playAfter(album: Album) {
    queueAlbum(album, at: .afterContext)
  }

  func appendToQueue(album: Album) {
    queueAlbum(album, at: .end)
  }

  private func queueAlbum(_ album: Album, at position: QueueInsertPosition) {
    if AlbumService.shared.checkIfAlbumDownloaded(albumID: album.id) {
      let local = AlbumService.shared.getSongsByAlbumId(albumId: album.id)
      if !local.isEmpty {
        insertSongs(
          local, at: position, contextName: album.name, isFromLocal: true)
        return
      }
    }
    AlbumService.shared.getSongFromAlbum(id: album.id) { [weak self] result in
      guard case .success(let songs) = result, !songs.isEmpty else { return }
      DispatchQueue.main.async {
        self?.insertSongs(songs, at: position, contextName: album.name, isFromLocal: false)
      }
    }
  }

  /// Playlist-level variants for grid context menus.
  func playNext(playlist: Playlist) {
    queuePlaylist(playlist, at: .next)
  }

  func playAfter(playlist: Playlist) {
    queuePlaylist(playlist, at: .afterContext)
  }

  func appendToQueue(playlist: Playlist) {
    queuePlaylist(playlist, at: .end)
  }

  private func queuePlaylist(_ playlist: Playlist, at position: QueueInsertPosition) {
    let local = AlbumService.shared.getPlaylistSongs(playlistId: playlist.id)
    if !local.isEmpty {
      insertSongs(
        local, at: position, contextName: playlist.name, isFromLocal: false,
        isFromPlaylist: true)
      return
    }
    AlbumService.shared.getSongsByPlaylist(id: playlist.id) { [weak self] result in
      guard case .success(let songs) = result, !songs.isEmpty else { return }
      DispatchQueue.main.async {
        self?.insertSongs(
          songs, at: position, contextName: playlist.name, isFromLocal: false,
          isFromPlaylist: true)
      }
    }
  }

  /// Drag-to-reorder handler for `List.onMove`. Tracks the now-playing
  /// item by identity so playback follows it to its new position.
  func moveQueue(from source: IndexSet, to destination: Int) {
    moveQueueInMemory(from: source, to: destination)
    persistQueueOrdering()
  }

  /// Persists the current in-memory order (call after drag-and-drop).
  func saveQueueOrder() {
    guard !queue.isEmpty else { return }
    persistQueueOrdering()
  }

  /// Moves a queue item to the very top, keeping now-playing in sync.
  func moveToTop(idx: Int) {
    guard queue.indices.contains(idx), idx != 0 else { return }
    guard queue.indices.contains(activeQueueIdx) else { return }
    let activeObject = queue[activeQueueIdx]
    let item = queue.remove(at: idx)
    queue.insert(item, at: 0)
    activeQueueIdx = queue.firstIndex(where: { $0 === activeObject }) ?? activeQueueIdx
    persistQueueOrdering()
  }

  /// Removes a single item. Removing the now-playing song advances
  /// playback to the item sliding into its place.
  func removeFromQueue(at idx: Int) {
    guard queue.indices.contains(idx) else { return }
    removeFromQueue(atOffsets: IndexSet(integer: idx))
  }

  /// Swipe-to-delete handler for `List.onDelete`.
  func removeFromQueue(atOffsets offsets: IndexSet) {
    guard !queue.isEmpty else { return }
    let sorted = offsets.sorted().filter { queue.indices.contains($0) }
    guard !sorted.isEmpty else { return }

    if queue.count - sorted.count <= 0 {
      clearQueue()
      return
    }

    let activeRemoved = sorted.contains(activeQueueIdx)
    let activeObject: QueueEntity? =
      activeRemoved ? nil : (queue.indices.contains(activeQueueIdx) ? queue[activeQueueIdx] : nil)

    var arr = queue
    for idx in sorted.reversed() {
      arr.remove(at: idx)
    }
    queue = arr

    if let activeObject,
      let newIdx = queue.firstIndex(where: { $0 === activeObject })
    {
      activeQueueIdx = newIdx
      persistQueueOrdering()
    } else {
      activeQueueIdx = min(sorted.first ?? 0, queue.count - 1)
      persistQueueOrdering()
      setNowPlaying()
    }
    UserDefaultsManager.queueActiveIdx = activeQueueIdx
  }

  /// "Clear Queue": stops playback and empties the queue.
  func clearQueue() {
    destroyPlayerAndQueue()
    queue = []
    activeQueueIdx = 0
    progress = 0.0
    currentTimeString = "00:00"
    UserDefaultsManager.removeObject(key: UserDefaultsKeys.queueActiveIdx)
  }

  func prevSong() {
    // TODO: handle experience saat album abis -> balik ke index 0 -> prevSong() -> expect nya i guess ke index .count?
    if self.activeQueueIdx != 0 {
      if self.playbackMode != PlaybackMode.repeatOnce {
        self.activeQueueIdx = self.activeQueueIdx - 1
      }
    } else {
      self.activeQueueIdx = 0
    }

    self.setNowPlaying()
  }

  func nextSong() {
    // FLO-3: debounce — DidPlayToEndTime + periodic observer race + CarPlay double-tap.
    // All end-of-track paths funnel here; drop duplicate fires within 0.8s.
    if let last = lastNextSongFire, Date().timeIntervalSince(last) < nextSongDebounce {
      return
    }
    lastNextSongFire = Date()
    stallRetryCount = 0
    isRecoveringFromStall = false
    isMediaLoading = false

    if self.queue.count == 1 {
      if self.playbackMode == PlaybackMode.defaultPlayback {
        self.stop()
      } else {
        self.setNowPlaying()
      }
    } else if self.playbackMode == PlaybackMode.repeatOnce {
      self.setNowPlaying()
    } else if self.playbackMode == PlaybackMode.repeatAlbum {
      let target = self.activeQueueIdx + 1 > self.queue.count - 1 ? 0 : self.activeQueueIdx + 1
      self.advanceToTrack(at: target)
    } else {
      if self.activeQueueIdx + 1 > self.queue.count - 1 {
        self.stop()
      } else {
        self.advanceToTrack(at: self.activeQueueIdx + 1)
      }
    }

    UserDefaultsManager.queueActiveIdx = self.activeQueueIdx
  }

  /// Advances to `idx` using the preloaded queue item when possible (instant,
  /// no rebuild), otherwise falls back to a fresh swap. State sync for the
  /// preloaded path is completed by `handleCurrentItemChanged`.
  private func advanceToTrack(at idx: Int) {
    guard queue.indices.contains(idx) else {
      setNowPlaying()
      return
    }

    if let queued = queuedNextItem, queuedNextIdx == idx, player?.currentItem !== queued {
      activeQueueIdx = idx
      player?.advanceToNextItem()
      UserDefaultsManager.queueActiveIdx = idx
    } else {
      activeQueueIdx = idx
      setNowPlaying()
    }
  }

  private func nextQueueIdxForPreCache() -> Int? {
    if queue.count <= 1 { return nil }

    if playbackMode == PlaybackMode.repeatOnce {
      return nil
    }

    if playbackMode == PlaybackMode.repeatAlbum {
      return activeQueueIdx + 1 >= queue.count ? 0 : activeQueueIdx + 1
    }

    let nextIdx = activeQueueIdx + 1
    guard nextIdx < queue.count else { return nil }
    return nextIdx
  }

  func destroyPlayerAndQueue() {
    self.removePlayerItemObservers()
    self.playerItemObservation?.cancel()
    self.playerItemObservation = nil
    self.statusObservedItem = nil
    if let token = timeObserverToken {
      player?.removeTimeObserver(token)
      timeObserverToken = nil
    }
    self.stop()

    self.player?.removeAllItems()
    self.playerItem = nil
    self.advanceWatchdogWorkItem?.cancel()
    self.advanceWatchdogWorkItem = nil
    self.clearQueuedNextTracking()
    self.clearFailedPreloadGuard()
    self.failedSkipCount = 0
    self.didHandleFailureForItem = nil
    self.manuallyActivatedItem = nil
    self.itemIndexByIdentity.removeAll()

    self.progress = 0.0

    self.resetLyrics()

    self.isLocallySaved = false
    self.shouldHidePlayer = true
    self.stallRetryCount = 0
    self.isRecoveringFromStall = false
    self.isMediaLoading = false

    PlaybackService.shared.clearQueue()
    UserDefaultsManager.removeObject(key: UserDefaultsKeys.nowPlayingProgress)

    MPNowPlayingInfoCenter.default().nowPlayingInfo = nil

    try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
  }

  func resetLyrics() {
    self.lyrics = []
    self.currentLyricsLineIndex = -1
    self.lyricsError = nil
    self.isLyricsMode = false
  }

  func fetchLyrics() {
    // just in case
    guard !(self.nowPlaying.songName?.isEmpty ?? true),
      !(self.nowPlaying.artistName?.isEmpty ?? true)
    else {
      self.lyricsError = "Missing track information"

      return
    }

    self.isLoadingLyrics = true
    self.lyricsError = nil

    let albumName = self.nowPlaying.albumName?.trimmingCharacters(in: .whitespacesAndNewlines)
    let contextName = self.nowPlaying.contextName?.trimmingCharacters(in: .whitespacesAndNewlines)
    let isFromPlaylist = self.nowPlaying.isFromPlaylist

    let albumNameForLyrics: String?

    if isFromPlaylist {
      if let albumName, !albumName.isEmpty, albumName != contextName {
        albumNameForLyrics = albumName
      } else {
        albumNameForLyrics = nil
      }
    } else {
      albumNameForLyrics = (albumName?.isEmpty == false) ? albumName : nil
    }

    LRCLIBService.shared.fetchLyrics(
      trackName: self.nowPlaying.songName ?? "",
      artistName: self.nowPlaying.artistName ?? "",
      albumName: albumNameForLyrics,
      duration: self.nowPlaying.duration
    ) { [weak self] result in
      DispatchQueue.main.async {
        self?.isLoadingLyrics = false

        switch result {
        case .success(let response):
          if let syncedLyrics = response.syncedLyrics, !syncedLyrics.isEmpty {
            self?.lyrics = LRCParser.parse(syncedLyrics)
          } else if let plainLyrics = response.plainLyrics, !plainLyrics.isEmpty {
            self?.lyrics = [LyricsLine(timestamp: 1, text: plainLyrics)]
          } else {
            self?.lyricsError = "No lyrics available"
          }

        case .failure:
          self?.lyricsError = "Failed to load lyrics"
        }
      }
    }
  }

  func updateCurrentLyricsLine(currentTime: TimeInterval) {
    guard !lyrics.isEmpty else { return }

    let lookahead: TimeInterval = 0.5
    let adjustedTime = currentTime + lookahead

    var newIndex = -1

    for (index, line) in lyrics.enumerated() {
      if adjustedTime >= line.timestamp {
        newIndex = index
      } else {
        break
      }
    }

    if newIndex != currentLyricsLineIndex {
      currentLyricsLineIndex = newIndex
    }
  }

  func toggleLyricsMode() {
    if isLiveRadio {
      return
    }

    withAnimation(.spring(duration: 0.3)) {
      isLyricsMode.toggle()
    }
  }

  private static func normalizedRadioURL(from streamUrl: String) -> URL? {
    let trimmedUrl = streamUrl.trimmingCharacters(in: .whitespacesAndNewlines)

    guard !trimmedUrl.isEmpty else { return nil }

    if let url = URL(string: trimmedUrl), url.scheme != nil {
      return url
    }

    if let encoded = trimmedUrl.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed),
      let url = URL(string: encoded),
      url.scheme != nil
    {
      return url
    }

    let withScheme = "https://\(trimmedUrl)"

    if let url = URL(string: withScheme), url.host != nil {
      return url
    }

    if let encoded = withScheme.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed),
      let url = URL(string: encoded),
      url.host != nil
    {
      return url
    }

    return nil
  }

  private func checkStarredStatus() {
    self.isStarred = false
    if let songId = self.nowPlaying.id, !songId.isEmpty {
      AlbumService.shared.isStarred(songId: songId) { [weak self] starred in
        DispatchQueue.main.async {
          guard self?.nowPlaying.id == songId else { return }
          self?.isStarred = starred
        }
      }
    }
  }

  func toggleMute() {
    if playbackVolume > 0.01 {
      volumeBeforeMute = playbackVolume
      playbackVolume = 0
    } else {
      let restore = volumeBeforeMute > 0.01 ? volumeBeforeMute : 1.0
      playbackVolume = restore
    }
  }

  func setPlaybackVolume(_ volume: Float) {
    let clamped = min(max(volume, 0), 1)
    if clamped > 0.01 {
      volumeBeforeMute = clamped
    }
    playbackVolume = clamped
  }

  func toggleStar() {
    guard let songId = self.nowPlaying.id, !songId.isEmpty else { return }

    let shouldStar = !self.isStarred
    self.isStarred = shouldStar

    let action = shouldStar ? AlbumService.shared.starSong : AlbumService.shared.unstarSong
    action(songId) { [weak self] success in
      if !success {
        DispatchQueue.main.async {
          guard self?.nowPlaying.id == songId else { return }
          self?.isStarred = !shouldStar
        }
      }
    }
  }

  deinit {
    removePlayerItemObservers()
    playerItemObservation?.cancel()
    currentItemObservation?.cancel()
    if let timeObserverToken = timeObserverToken {
      player?.removeTimeObserver(timeObserverToken)
      player?.pause()
    }
  }
}
