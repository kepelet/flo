//
//  PlayerViewModel.swift
//  flo
//
//  Created by rizaldy on 05/06/24.
//

import AVFoundation
import MediaPlayer
import SwiftUI

class PlayerViewModel: ObservableObject {
  private var player: AVPlayer?
  private var playerItem: AVPlayerItem?
  private var timeObserverToken: Any?

  @Published var queue: [Song] = []
  @Published var nowPlaying: NowPlaying = NowPlaying()
  @Published var playbackMode = PlaybackMode.defaultPlayback

  private var tempAlbumName: String = ""
  private var tempAlbumCover: String = ""
  private var tempOriginQueue: [Song] = []

  @Published var activeQueueIdx: Int = 0

  @Published var isShuffling: Bool = false
  @Published var isPlaying: Bool = false
  @Published var isSeeking: Bool = false
  @Published var isLyricsMode: Bool = false

  @Published var progress: Double = 0.0

  @Published var currentTimeString: String = "00:00"
  @Published var totalTimeString: String = "00:00"

  private var isFinished: Bool = false
  private var totalDuration: Double = 0.0

  init() {
    // FIXME: pikirin nanti (ini si NowPlaying udah bukan lagi source of truth harusbya)
    //    if let lastPlayData = UserDefaultsManager.nowPlaying,
    //      let lastPlay = try? JSONDecoder().decode(NowPlaying.self, from: lastPlayData)
    //    {
    //      self.setNowPlaying(data: lastPlay, playAudio: false)
    //
    //    }
    //
    //    self.progress = UserDefaultsManager.nowPlayingProgress
  }

  func hasNowPlaying() -> Bool {
    return self.nowPlaying.streamUrl != ""
  }

  func addToQueue(idx: Int, item: Album, songs: [Song]) {
    // FIXME: of course
    self.tempAlbumName = item.name
    self.tempAlbumCover = AlbumService.shared.getCoverArt(id: item.id)
    self.tempOriginQueue = songs

    self.activeQueueIdx = idx
    self.queue = songs
    self.setNowPlaying()
  }

  func setNowPlaying(playAudio: Bool = true) {
    let activeSong = self.queue[activeQueueIdx]
    let selectedSong = NowPlaying(
      artistName: activeSong.artist,
      songName: activeSong.title,
      albumName: self.tempAlbumName,
      albumCover: self.tempAlbumCover,
      streamUrl: AlbumService.shared.getStreamUrl(id: activeSong.id),
      bitRate: activeSong.bitRate,
      suffix: activeSong.suffix
    )

    let audioURL = URL(string: selectedSong.streamUrl)

    self.nowPlaying = selectedSong

    self.player = AVPlayer()

    self.playerItem = AVPlayerItem(url: audioURL!)
    self.player?.replaceCurrentItem(with: self.playerItem)

    //  FIXME: pikirin nanti (ini si NowPlaying udah bukan lagi source of truth harusbya)
    //    if let jsonData = try? JSONEncoder().encode(selectedSong) {
    //      UserDefaultsManager.nowPlaying = jsonData
    //    } else {
    //      print("error storing in UserDefaults")
    //    }

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

    addPeriodicTimeObserver()

    if playAudio {
      self.play()
      self.updateNowPlayingInfo(
        title: self.nowPlaying.songName,
        artist: self.nowPlaying.artistName,
        playbackDuration: self.totalDuration,
        playbackRate: self.player?.rate)
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

    nowPlayingInfo[MPMediaItemPropertyTitle] = title
    nowPlayingInfo[MPMediaItemPropertyArtist] = artist
    nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = playbackDuration

    if let rate = playbackRate {
      nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = rate
    } else {
      nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = 1.0
    }

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

  // TODO: Make this persistent
  func setPlaybackMode() {
    if self.playbackMode == PlaybackMode.defaultPlayback {
      self.playbackMode = PlaybackMode.repeatAlbum
    } else if self.playbackMode == PlaybackMode.repeatAlbum {
      self.playbackMode = PlaybackMode.repeatOnce
    } else {
      self.playbackMode = PlaybackMode.defaultPlayback
    }
  }

  func playByAlbum(item: Album, songs: [Song]) {
    self.addToQueue(idx: 0, item: item, songs: songs)
  }

  func shuffleByAlbum(item: Album, songs: [Song]) {
    // FIXME: gw penasaran kenapa pake songs instead of Album.songs
    let shuffledSongs = songs.shuffled()
    self.addToQueue(idx: 0, item: item, songs: shuffledSongs)
  }

  func shuffleCurrentQueue() {
    self.isShuffling.toggle()

    if self.isShuffling {
      self.queue = self.queue.shuffled()
    } else {
      self.queue = self.tempOriginQueue
    }
  }

  func playFromQueue(idx: Int) {
    self.activeQueueIdx = idx
    self.setNowPlaying()
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
  }

  deinit {
    if let timeObserverToken = timeObserverToken {
      player?.removeTimeObserver(timeObserverToken)
      player?.pause()
    }
  }
}
