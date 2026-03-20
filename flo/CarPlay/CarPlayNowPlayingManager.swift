//
//  CarPlayNowPlayingManager.swift
//  flo
//

import CarPlay
import Combine

class CarPlayNowPlayingManager: NSObject {
  private let playerVM: PlayerViewModel
  private var cancellables = Set<AnyCancellable>()
  private weak var interfaceController: CPInterfaceController?

  init(playerVM: PlayerViewModel, interfaceController: CPInterfaceController) {
    self.playerVM = playerVM
    self.interfaceController = interfaceController
    super.init()
  }

  func configure() {
    let nowPlaying = CPNowPlayingTemplate.shared
    nowPlaying.add(self)

    nowPlaying.isUpNextButtonEnabled = true
    nowPlaying.upNextTitle = String(localized: "Up Next")

    updateButtons(on: nowPlaying)

    playerVM.$isShuffling
      .receive(on: DispatchQueue.main)
      .sink { [weak self] _ in
        self?.updateButtons(on: nowPlaying)
      }
      .store(in: &cancellables)

    playerVM.$playbackMode
      .receive(on: DispatchQueue.main)
      .sink { [weak self] _ in
        self?.updateButtons(on: nowPlaying)
      }
      .store(in: &cancellables)
  }

  func teardown() {
    cancellables.removeAll()
    CPNowPlayingTemplate.shared.remove(self)
  }

  private func updateButtons(on template: CPNowPlayingTemplate) {
    let shuffleButton = CPNowPlayingShuffleButton { [weak self] _ in
      self?.playerVM.shuffleCurrentQueue()
    }

    let repeatButton = CPNowPlayingRepeatButton { [weak self] _ in
      self?.playerVM.setPlaybackMode()
    }

    template.updateNowPlayingButtons([shuffleButton, repeatButton])
  }
}

// MARK: - CPNowPlayingTemplateObserver

extension CarPlayNowPlayingManager: CPNowPlayingTemplateObserver {
  func nowPlayingTemplateUpNextButtonTapped(_ nowPlayingTemplate: CPNowPlayingTemplate) {
    guard let interfaceController = interfaceController else { return }

    let queue = playerVM.queue
    let activeIdx = playerVM.activeQueueIdx

    let upcomingItems = queue.enumerated().compactMap { (idx, entity) -> CPListItem? in
      guard idx > activeIdx else { return nil }

      let item = CPListItem(
        text: entity.songName ?? String(localized: "Unknown"),
        detailText: entity.artistName ?? ""
      )
      item.handler = { [weak self] _, completion in
        self?.playerVM.playFromQueue(idx: idx)
        completion()
      }
      return item
    }

    if upcomingItems.isEmpty {
      let emptyItem = CPListItem(text: String(localized: "No upcoming tracks"), detailText: nil)
      let template = CPListTemplate(
        title: String(localized: "Up Next"),
        sections: [CPListSection(items: [emptyItem])]
      )
      interfaceController.pushTemplate(template, animated: true, completion: nil)
    } else {
      let template = CPListTemplate(
        title: String(localized: "Up Next"),
        sections: [CPListSection(items: upcomingItems)]
      )
      interfaceController.pushTemplate(template, animated: true, completion: nil)
    }
  }

  func nowPlayingTemplateAlbumArtistButtonTapped(_ nowPlayingTemplate: CPNowPlayingTemplate) {
    // Not used
  }
}
