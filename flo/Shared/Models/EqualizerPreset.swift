//
//  EqualizerPreset.swift
//  flo
//
//  EQ presets. 10-band graphic EQ:
//  32, 64, 125, 250, 500, 1k, 2k, 4k, 8k, 16k Hz.
//  Gains in dB, range -12...+12.
//

import Foundation

enum EqualizerPreset: String, CaseIterable, Identifiable {
  case off
  case acoustic
  case bassBooster
  case bassReducer
  case classical
  case dance
  case deep
  case electronic
  case flat
  case hipHop
  case jazz
  case lateNight
  case latin
  case loudness
  case lounge
  case piano
  case pop
  case rb
  case rock
  case smallSpeakers
  case spokenWord
  case trebleBooster
  case trebleReducer
  case vocalBooster

  var id: String { rawValue }

  var displayName: String {
    switch self {
    case .off: return "Off"
    case .acoustic: return "Acoustic"
    case .bassBooster: return "Bass Booster"
    case .bassReducer: return "Bass Reducer"
    case .classical: return "Classical"
    case .dance: return "Dance"
    case .deep: return "Deep"
    case .electronic: return "Electronic"
    case .flat: return "Flat"
    case .hipHop: return "Hip-Hop"
    case .jazz: return "Jazz"
    case .lateNight: return "Late Night"
    case .latin: return "Latin"
    case .loudness: return "Loudness"
    case .lounge: return "Lounge"
    case .piano: return "Piano"
    case .pop: return "Pop"
    case .rb: return "R&B"
    case .rock: return "Rock"
    case .smallSpeakers: return "Small Speakers"
    case .spokenWord: return "Spoken Word"
    case .trebleBooster: return "Treble Booster"
    case .trebleReducer: return "Treble Reducer"
    case .vocalBooster: return "Vocal Booster"
    }
  }

  /// 10 gains in dB, bands: 32/64/125/250/500/1k/2k/4k/8k/16k.
  var gains: [Float] {
    switch self {
    case .off, .flat:
      return [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    case .acoustic:
      return [5, 4, 3, 2, 1, 1, 2, 3, 4, 5]
    case .bassBooster:
      return [6, 5, 4, 3, 1, 0, 0, 0, 0, 0]
    case .bassReducer:
      return [-6, -5, -4, -3, -1, 0, 0, 0, 0, 0]
    case .classical:
      return [5, 4, 3, 2, -1, -1, 0, 2, 3, 4]
    case .dance:
      return [6, 5, 2, 0, 0, -2, 0, 2, 5, 6]
    case .deep:
      return [5, 4, 3, 1, 2, 3, 2, 1, 0, -1]
    case .electronic:
      return [5, 4, 2, 0, -2, 2, 0, 2, 5, 6]
    case .hipHop:
      return [5, 4, 2, 3, -1, -1, 1, 2, 4, 5]
    case .jazz:
      return [4, 3, 2, 2, -1, -1, 1, 3, 4, 5]
    case .lateNight:
      return [4, 3, 2, 1, 0, 0, 1, 2, 3, 4]
    case .latin:
      return [4, 3, 2, 1, 0, 0, 1, 3, 4, 5]
    case .loudness:
      return [6, 4, 2, 0, 0, 0, 0, 1, 4, 6]
    case .lounge:
      return [-2, -1, 0, 1, 3, 2, 0, -1, 2, 3]
    case .piano:
      return [3, 2, 1, 2, 3, 2, 1, 3, 4, 4]
    case .pop:
      return [-1, 2, 4, 4, 2, 0, -1, -1, 1, 2]
    case .rb:
      return [4, 5, 3, 1, -1, 1, 2, 3, 4, 5]
    case .rock:
      return [5, 4, 3, 2, -1, -1, 1, 2, 4, 5]
    case .smallSpeakers:
      return [4, 3, 2, 1, 0, -2, -3, -3, 2, 4]
    case .spokenWord:
      return [-3, -2, -1, 0, 2, 4, 4, 3, 1, 0]
    case .trebleBooster:
      return [0, 0, 0, 0, 0, 0, 2, 4, 6, 7]
    case .trebleReducer:
      return [0, 0, 0, 0, 0, 0, -2, -4, -6, -7]
    case .vocalBooster:
      return [-2, -2, -1, 0, 3, 4, 3, 1, 0, -1]
    }
  }

  /// Frequencies for the 10 bands.
  static let frequencies: [Float] = [32, 64, 125, 250, 500, 1000, 2000, 4000, 8000, 16000]

  var isBypass: Bool {
    self == .off || self == .flat
  }

  static func from(rawValue: String) -> EqualizerPreset {
    EqualizerPreset(rawValue: rawValue) ?? .off
  }
}
