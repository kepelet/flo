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

  // FIXME: this make confusion with `isDownloaded` and/or `isPlayingFromLocal`
  @Published var _playFromLocal: Bool = false

  private var isLocallySaved: Bool = false
  private var isFinished: Bool = false
  private var totalDuration: Double = 0.0
  private var playerItemObservation: AnyCancellable?
  private var interruptionObservation = Set<AnyCancellable>()
  private var routeChangeObservation = Set<AnyCancellable>()

  private var scrobbleThreshold = 0.5

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

  var isLiveRadio: Bool {
    guard hasNowPlaying() else { return false }

    return nowPlaying.duration.isInfinite || nowPlaying.duration.isNaN
  }

  init() {
    self.player = AVPlayer()
    self.observeInterruptionNotifications()
    self.observeRouteChangeNotifications()
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
      .sink { notification in
        self.handleInterruptionNotification(notification)
      }
      .store(in: &interruptionObservation)
  }

  func observeRouteChangeNotifications() {
    NotificationCenter.default
      .publisher(for: AVAudioSession.routeChangeNotification)
      .sink { _ in
        self.updateAudioRoute()
      }
      .store(in: &routeChangeObservation)
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

  func handleInterruptionNotification(_ notification: Notification) {
    guard let userInfo = notification.userInfo,
      let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? Int,
      let type = AVAudioSession.InterruptionType(rawValue: UInt(typeValue))
    else {
      return
    }

    switch type {
    case .began:
      self.pause()

    case .ended:
      self.play()

      if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? Int {
        let options = AVAudioSession.InterruptionOptions(rawValue: UInt(optionsValue))

        if options.contains(.shouldResume) {
          self.play()
        }
      }

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

    try? AVAudioSession.sharedInstance().setActive(true)

    self.resetLyrics()

    if let timeObserverToken = timeObserverToken {
      player?.removeTimeObserver(timeObserverToken)
    }

    let streamUrl = AlbumService.shared.getStreamUrl(id: self.nowPlaying.id ?? "")

    guard let audioURL = URL(string: streamUrl), !streamUrl.isEmpty else {
      self.isMediaLoading = false
      self.isMediaFailed = true

      return
    }

    self._playFromLocal = audioURL.isFileURL

    self.playerItem = AVPlayerItem(url: audioURL)
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

  private func addPeriodicTimeObserver() {
    guard let player = self.player else { return }

    let interval = CMTime(seconds: 1, preferredTimescale: CMTimeScale(NSEC_PER_SEC))

    timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) {
      time in
      let currentTime = CMTimeGetSeconds(time)
      let roundedTotalDuration = floor(self.totalDuration)

      if self.totalDuration.isFinite, self.totalDuration > 0 {
        self.progress = currentTime / self.totalDuration
      } else {
        self.progress = 0.0
      }

      self.currentTimeString = timeString(for: currentTime)

      UserDefaultsManager.nowPlayingProgress = self.progress

      if self.isLRCLIBEnabled {
        self.updateCurrentLyricsLine(currentTime: currentTime)
      }

      if !self.isLocallySaved && self.progress >= 0.5 {
        Task {
          FloooViewModel.shared.scrobble(submission: true, nowPlaying: self.nowPlaying)

          self.isLocallySaved = true
        }
      }

      if self.totalDuration.isFinite,
        self.totalDuration > 0,
        round(currentTime) >= roundedTotalDuration
      {
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

    commandCenter.playCommand.addTarget { [unowned self] event in
      self.play()

      return .success
    }

    commandCenter.pauseCommand.addTarget { [unowned self] event in
      self.pause()

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

    player?.play()

    self.isFinished = false
    self.isPlaying = true
    self.updateNowPlayingInfo(progress: self.progress, rate: 1.0)
    MPNowPlayingInfoCenter.default().playbackState = .playing
  }

  func pause() {
    player?.pause()

    self.isPlaying = false
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

    self.playerItem = AVPlayerItem(url: radioUrl)
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

  func destroyPlayerAndQueue() {
    self.stop()
    self.progress = 0.0

    self.resetLyrics()

    self.isLocallySaved = false
    self.shouldHidePlayer = true

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

  deinit {
    if let timeObserverToken = timeObserverToken {
      player?.removeTimeObserver(timeObserverToken)
      player?.pause()
    }
  }
}
