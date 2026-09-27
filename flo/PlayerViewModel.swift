//
//  PlayerViewModel.swift
//  flo
//
//  Created by rizaldy on 05/06/24.
//

import AVFoundation
import Combine
import MediaPlayer
import SwiftUI

class PlayerViewModel: ObservableObject {
  static let shared = PlayerViewModel()

  private var player: AVPlayer?
  private var playerItem: AVPlayerItem?
  private var timeObserverToken: Any?

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

  var nowPlaying: QueueEntity {
    return self.queue[self.activeQueueIdx]
  }

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
    self.player = AVPlayer()
    self.player?.volume = UserDefaultsManager.playbackVolume
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
    removePlayerItemObservers()
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
    ) { [weak self] _ in
      self?.handleDidPlayToEndTime()
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
    isMediaFailed = true
    isMediaLoading = false
    isRecoveringFromStall = false
    // Keep NowPlaying paused so CarPlay does not flick to next.
    updateNowPlayingInfo(progress: progress, rate: 0.0)
    MPNowPlayingInfoCenter.default().playbackState = .paused
  }

  private func handleDidPlayToEndTime() {
    // FLO-3: authoritative end-of-track signal; replaces sole reliance on rounding.
    guard !isLiveRadio else { return }
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
    self.isLocallySaved = false
    self.hasTriggeredCache = false

    StreamCacheManager.shared.cancelAllInFlight()

    try? AVAudioSession.sharedInstance().setActive(true)

    self.resetLyrics()
    self.checkStarredStatus()

    if let timeObserverToken = timeObserverToken {
      player?.removeTimeObserver(timeObserverToken)
      self.timeObserverToken = nil
    }

    let songId = self.nowPlaying.id ?? ""
    StreamCacheManager.shared.setCurrentlyPlaying(mediaFileId: songId)

    let streamUrl = AlbumService.shared.getStreamUrl(id: songId)

    guard let audioURL = URL(string: streamUrl), !streamUrl.isEmpty else {
      self.isMediaLoading = false
      self.isMediaFailed = true

      return
    }

    self._playFromLocal = audioURL.isFileURL

    // Tear down prior item's stall/end observers before swapping items (FLO-5/FLO-3)
    self.removePlayerItemObservers()
    self.playerItemObservation?.cancel()
    self.playerItemObservation = nil

    if !audioURL.isFileURL, AuthService.shared.getAuthMode() == .iap {
      let cookies = HTTPCookieStorage.shared.cookies(for: audioURL) ?? []
      let asset = AVURLAsset(url: audioURL, options: [AVURLAssetHTTPCookiesKey: cookies])
      self.playerItem = AVPlayerItem(asset: asset)
    } else {
      self.playerItem = AVPlayerItem(url: audioURL)
    }
    // EQ: per-item tap (nil when Off/Flat = bit-perfect bypass).
    self.playerItem?.audioMix = EqualizerManager.shared.makeAudioMix()
    if let item = self.playerItem {
      // Prefer smaller forward buffer for transcoded streams so gaps surface faster and recover.
      item.preferredForwardBufferDuration = 3
      self.setupPlayerItemObservers(for: item)
    }
    self.player?.automaticallyWaitsToMinimizeStalling = false
    self.player?.volume = playbackVolume
    self.player?.replaceCurrentItem(with: self.playerItem)

    let duration = CMTime(
      seconds: self.nowPlaying.duration, preferredTimescale: self.nowPlaying.sampleRate)
    let playbackDuration = CMTimeGetSeconds(duration)

    self.totalDuration = playbackDuration
    self.totalTimeString = timeString(for: playbackDuration)

    let newTimeString = self.progress * playbackDuration

    self.currentTimeString = timeString(for: newTimeString)

    self.playerItemObservation = self.playerItem?.publisher(for: \.status)
      .sink { [weak self] status in
        guard let self = self else { return }
        switch status {
        case .readyToPlay:
          DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.isMediaLoading = false
            self.isMediaFailed = false
          }
        case .failed:
          self.isMediaLoading = false
          self.isMediaFailed = true
        case .unknown:
          self.isMediaLoading = false
        @unknown default:
          self.isMediaLoading = true
        }
      }

    if playAudio {
      self.seek(to: 0.0)
      self.play()
    } else {
      self.seek(to: self.progress)
    }

    self.addPeriodicTimeObserver()
    self.initNowPlayingInfo(
      title: self.nowPlaying.songName ?? "",
      artist: self.nowPlaying.artistName ?? "",
      playbackDuration: self.totalDuration)

    FloooViewModel.shared.setNowPlayingToScrobbleServer(nowPlaying: self.nowPlaying)

    if isLRCLIBEnabled && !isLiveRadio {
      self.fetchLyrics()
    }
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
    guard let player = self.player else { return }

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

        Task { @MainActor in
          FloooViewModel.shared.scrobble(submission: true, nowPlaying: self.nowPlaying)
        }
      }

      if !self.hasTriggeredCache && currentTime >= 10.0 && !self.isLiveRadio {
        self.hasTriggeredCache = true
        if let nextIdx = self.nextQueueIdxForPreCache(),
          let nextId = self.queue[nextIdx].id, !nextId.isEmpty
        {
          StreamCacheManager.shared.cacheSong(
            mediaFileId: nextId, originalSuffix: self.queue[nextIdx].suffix,
            from: self.queue[nextIdx])
        }
      }

      // FLO-3/FLO-5: tolerance + stall + debounce guard (replaces round/floor)
      if self.shouldAdvanceToNextTrack(currentTime: currentTime) {
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

    if let timeObserverToken = timeObserverToken {
      player?.removeTimeObserver(timeObserverToken)

      self.timeObserverToken = nil
    }

    self.removePlayerItemObservers()
    self.playerItemObservation?.cancel()
    self.playerItemObservation = nil

    self.playerItem = AVPlayerItem(url: radioUrl)
    self.playerItem?.audioMix = EqualizerManager.shared.makeAudioMix()
    if let item = self.playerItem {
      item.preferredForwardBufferDuration = 3
      // Radio: still benefit from stall recovery but DidPlayToEndTime is ignored via isLiveRadio guard.
      self.setupPlayerItemObservers(for: item)
    }
    self.player?.automaticallyWaitsToMinimizeStalling = false
    self.player?.volume = playbackVolume
    self.player?.replaceCurrentItem(with: self.playerItem)

    self.playerItemObservation = self.playerItem?.publisher(for: \.status)
      .sink { [weak self] status in
        guard let self = self else { return }
        switch status {
        case .readyToPlay:
          DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.isMediaLoading = false
            self.isMediaFailed = false
          }
        case .failed:
          self.isMediaLoading = false
          self.isMediaFailed = true
        case .unknown:
          self.isMediaLoading = false
        @unknown default:
          self.isMediaLoading = true
        }
      }

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
  }

  func playFromQueue(idx: Int) {
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
    let activeObject: QueueEntity? = activeRemoved ? nil : queue[activeQueueIdx]

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
    // TODO: refactor later ngantuk bosss
    // singles
    if self.queue.count == 1 {
      // klo kaga repeat, stop
      if self.playbackMode == PlaybackMode.defaultPlayback {
        self.stop()
      } else {
        // klo repeat, ulang
        self.setNowPlaying()
      }
    } else {
      // albums
      if self.playbackMode == PlaybackMode.repeatOnce {
        // klo repeat sekali, ulang
        self.setNowPlaying()
      } else if self.playbackMode == PlaybackMode.repeatAlbum {
        // klo repeat album
        // ni udah di lagu terakhir blm?
        // harusnya bisa pakai >= gasi?
        if self.activeQueueIdx + 1 > self.queue.count - 1 {
          // klo iya, balik ke lagu pertama
          self.activeQueueIdx = 0
          self.setNowPlaying()
        } else {
          // klo bukan, lanjut
          self.activeQueueIdx = self.activeQueueIdx + 1
          self.setNowPlaying()
        }
      } else {
        // klo bukan repeat
        // ni udah di lagu terakhir blm?
        // harusnya bisa pakai >= gasi?
        if self.activeQueueIdx + 1 > self.queue.count - 1 {
          // klo iya, stop
          self.stop()
        } else {
          // klo bukan, lanjut
          self.activeQueueIdx = self.activeQueueIdx + 1
          self.setNowPlaying()
        }
      }
    }

    UserDefaultsManager.queueActiveIdx = self.activeQueueIdx
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
    if let token = timeObserverToken {
      player?.removeTimeObserver(token)
      timeObserverToken = nil
    }
    self.stop()
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
    if let timeObserverToken = timeObserverToken {
      player?.removeTimeObserver(timeObserverToken)
      player?.pause()
    }
  }
}
