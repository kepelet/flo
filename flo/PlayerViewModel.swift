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

  @Published var progress: Double = 0.0

  @Published var currentTimeString: String = "00:00"
  @Published var totalTimeString: String = "00:00"

  private var isFinished: Bool = false
  private var totalDuration: Double = 0.0
  private var playerItemObservation: AnyCancellable?

  var nowPlaying: QueueEntity {
    return self.queue[self.activeQueueIdx]
  }

  init() {
    let lastPlayData = PlaybackService.shared.getQueue()
    let queueActiveIdx = UserDefaultsManager.queueActiveIdx

    if !lastPlayData.isEmpty && queueActiveIdx < lastPlayData.count {
      self.addToNewQueue(
        idx: UserDefaultsManager.queueActiveIdx, item: lastPlayData, playAudio: false)
      self.progress = UserDefaultsManager.nowPlayingProgress
      self.playbackMode = UserDefaultsManager.playbackMode
    } else {
      UserDefaultsManager.removeObject(key: UserDefaultsKeys.queueActiveIdx)
      UserDefaultsManager.removeObject(key: UserDefaultsKeys.nowPlayingProgress)
      PlaybackService.shared.clearQueue()
    }
  }

  func addToNewQueue(idx: Int, item: [QueueEntity], playAudio: Bool = true) {
    self.activeQueueIdx = idx
    self.queue = item
    self.setNowPlaying(playAudio: playAudio)
  }

  func getAlbumCoverArt() -> String {
    return AlbumService.shared.getAlbumCover(
      artistName: self.nowPlaying.artistName ?? "", albumName: self.nowPlaying.albumName ?? "",
      albumId: self.nowPlaying.albumId ?? "")
  }

  func hasNowPlaying() -> Bool {
    return !self.queue.isEmpty
  }

  func setNowPlaying(playAudio: Bool = true) {
    if let timeObserverToken = timeObserverToken {
      player?.removeTimeObserver(timeObserverToken)
    }

    let audioURL = URL(
      string: AlbumService.shared.getStreamUrl(id: self.queue[activeQueueIdx].id ?? ""))

    self.player = AVPlayer()

    self.playerItem = AVPlayerItem(url: audioURL!)
    self.player?.replaceCurrentItem(with: self.playerItem)

    Task {
      do {
        let duration = try await self.player?.currentItem?.asset.load(.duration)

        DispatchQueue.main.async {
          let playbackDuration = CMTimeGetSeconds(duration!)

          self.totalDuration = playbackDuration
          self.totalTimeString = timeString(for: playbackDuration)

          let newTimeString = self.progress * playbackDuration

          self.currentTimeString = timeString(for: newTimeString)

          if playAudio {
            self.seek(to: 0.0)
          } else {
            self.seek(to: self.progress)
          }

          self.setupRemoteCommandCenter()
        }
      }
    }

    playerItemObservation = playerItem?.publisher(for: \.status)
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

    addPeriodicTimeObserver()

    self.updateNowPlayingInfo(
      title: self.nowPlaying.songName ?? "",
      artist: self.nowPlaying.artistName ?? "",
      playbackDuration: self.totalDuration,
      playbackRate: self.player?.rate)

    if playAudio {
      self.play()
    }
  }

  private func addPeriodicTimeObserver() {
    guard let player = self.player else { return }

    let interval = CMTime(seconds: 1, preferredTimescale: CMTimeScale(NSEC_PER_SEC))

    timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) {
      [weak self] time in
      guard let self = self else { return }

      let currentTime = CMTimeGetSeconds(time)

      self.progress = currentTime / self.totalDuration
      self.currentTimeString = timeString(for: currentTime)

      UserDefaultsManager.nowPlayingProgress = progress

      if currentTime >= self.totalDuration {
        self.nextSong()

        UserDefaultsManager.removeObject(key: UserDefaultsKeys.nowPlayingProgress)
      }
    }
  }

  private func updateNowPlayingInfo(
    title: String, artist: String, playbackDuration: Double, playbackRate: Float?
  ) {
    var nowPlayingInfo = [String: Any]()

    DispatchQueue.global().async {
      let url: URL
      let albumCoverArt = self.getAlbumCoverArt()

      if albumCoverArt.hasPrefix("/") {
        url = URL(fileURLWithPath: albumCoverArt)
      } else {
        guard let remoteURL = URL(string: albumCoverArt) else {
          return
        }

        url = remoteURL
      }

      if let data = try? Data(contentsOf: url),
        let image = UIImage(data: data)
      {
        let artwork = MPMediaItemArtwork(boundsSize: image.size) { size in
          return image
        }

        nowPlayingInfo[MPMediaItemPropertyArtwork] = artwork
      }

      DispatchQueue.main.async {
        nowPlayingInfo[MPMediaItemPropertyTitle] = title
        nowPlayingInfo[MPMediaItemPropertyArtist] = artist
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = playbackDuration

        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
      }
    }
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
  }

  func play() {
    if self.isFinished {
      self.stop()
    }

    player?.play()

    self.isFinished = false
    self.isPlaying = true
  }

  func pause() {
    player?.pause()

    self.isPlaying = false
  }

  func stop() {
    player?.pause()
    player?.seek(to: CMTime.zero)

    self.isFinished = true
    self.isPlaying = false
  }

  func seek(to progress: Double) {
    let newTime = CMTime(
      seconds: progress * totalDuration, preferredTimescale: CMTimeScale(NSEC_PER_SEC))

    player?.seek(to: newTime)
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

  func playBySong(idx: Int, item: Album, isFromLocal: Bool) {
    let queue = PlaybackService.shared.addToQueue(item: item, isFromLocal: isFromLocal)

    self.addToNewQueue(idx: idx, item: queue)
  }

  func playByAlbum(item: Album, isFromLocal: Bool) {
    let queue = PlaybackService.shared.addToQueue(item: item, isFromLocal: isFromLocal)

    self.addToNewQueue(idx: 0, item: queue)
  }

  func shuffleByAlbum(item: Album, isFromLocal: Bool) {
    var shuffledItem = item
    shuffledItem.songs.shuffle()

    let queue = PlaybackService.shared.addToQueue(item: shuffledItem, isFromLocal: isFromLocal)
    self.addToNewQueue(idx: 0, item: queue)
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

  deinit {
    if let timeObserverToken = timeObserverToken {
      player?.removeTimeObserver(timeObserverToken)
      player?.pause()
    }
  }
}
