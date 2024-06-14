//
//  PlayerViewModel.swift
//  flo
//
//  Created by rizaldy on 05/06/24.
//

import AVFoundation
import MediaPlayer
import SwiftUI

struct NowPlaying: Encodable, Decodable {
  var artistName: String = "Unknown Artist"
  var songName: String = "Untitled"
  var albumCover: String = ""
  var streamUrl: String = ""
  var bitRate: Int = 0
  var suffix: String = ""
}

class PlayerViewModel: ObservableObject {
  private var player: AVPlayer?
  private var playerItem: AVPlayerItem?
  private var timeObserverToken: Any?

  @Published var nowPlaying: NowPlaying = NowPlaying()

  @Published var isPlaying: Bool = false
  @Published var isSeeking: Bool = false
  @Published var isLyricsMode: Bool = false

  @Published var progress: Double = 0.0

  @Published var currentTimeString: String = "00:00"
  @Published var totalTimeString: String = "00:00"

  private var isFinished: Bool = false
  private var totalDuration: Double = 0.0

  init() {
    if let lastPlayData = UserDefaultsManager.nowPlaying,
      let lastPlay = try? JSONDecoder().decode(NowPlaying.self, from: lastPlayData)
    {
      self.setNowPlaying(data: lastPlay, playAudio: false)

    }

    self.progress = UserDefaultsManager.nowPlayingProgress
  }

  func hasNowPlaying() -> Bool {
    return self.nowPlaying.streamUrl != ""
  }

  func setNowPlaying(data: NowPlaying, playAudio: Bool = true) {
    let audioURL = URL(string: data.streamUrl)

    self.nowPlaying = data

    self.player = AVPlayer()

    self.playerItem = AVPlayerItem(url: audioURL!)
    self.player?.replaceCurrentItem(with: self.playerItem)

    setupRemoteCommandCenter()

    if let jsonData = try? JSONEncoder().encode(data) {
      UserDefaultsManager.nowPlaying = jsonData
    } else {
      print("error storing in UserDefaults")
    }

    Task {
      let duration = try await self.player?.currentItem?.asset.load(.duration)

      self.totalDuration = CMTimeGetSeconds(duration!)
      self.totalTimeString = timeString(for: totalDuration)

      let newTimeString = self.progress * self.totalDuration

      self.currentTimeString = timeString(for: newTimeString)

      if playAudio {
        self.seek(to: 0.0)
      } else {
        self.seek(to: self.progress)
      }

      self.updateNowPlayingInfo()
    }

    addPeriodicTimeObserver()

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
        self.isFinished = true
        self.isPlaying = false

        self.player?.pause()

        UserDefaultsManager.removeObject(key: UserDefaultsKeys.nowPlayingProgress)
      }
    }
  }

  private func updateNowPlayingInfo() {
    var nowPlayingInfo = [String: Any]()

    nowPlayingInfo[MPMediaItemPropertyTitle] = self.nowPlaying.songName
    nowPlayingInfo[MPMediaItemPropertyArtist] = self.nowPlaying.artistName
    nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = self.totalDuration
    nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = self.player?.rate

    MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
  }

  private func setupRemoteCommandCenter() {
    let commandCenter = MPRemoteCommandCenter.shared()

    commandCenter.playCommand.addTarget { [unowned self] event in
      self.play()
      self.updateNowPlayingInfo()
      return .success
    }

    commandCenter.pauseCommand.addTarget { [unowned self] event in
      self.pause()
      self.updateNowPlayingInfo()
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
  }

  func seek(to progress: Double) {
    let newTime = CMTime(
      seconds: progress * totalDuration, preferredTimescale: CMTimeScale(NSEC_PER_SEC))

    player?.seek(to: newTime)
  }

  // TODO: implement play list later
  func playByAlbum() {
  }

  // TODO: implement play list later
  func shuffleByAlbum() {
  }

  // TODO: implement play list later
  func prevSong() {
    player?.seek(to: CMTime.zero)
  }

  // TODO: implement play list later
  func nextSong() {
    let newTime = CMTime(
      seconds: totalDuration, preferredTimescale: CMTimeScale(NSEC_PER_SEC))

    player?.seek(to: newTime)
  }

  deinit {
    if let timeObserverToken = timeObserverToken {
      player?.removeTimeObserver(timeObserverToken)
      player?.pause()
    }
  }
}
