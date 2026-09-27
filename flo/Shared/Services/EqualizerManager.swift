//
//  EqualizerManager.swift
//  flo
//
//  10-band EQ via MTAudioProcessingTap.
//  Works with the existing AVPlayer engine: each AVPlayerItem gets an
//  AVAudioMix carrying a tap that applies 10 peaking biquads in-place.
//  Preset changes apply live (no track rebuild) via a generation counter.
//

import AVFoundation
import CoreMedia
import MediaToolbox
import os

private let eqLog = Logger(subsystem: "net.faultables.flo", category: "EQ")

extension Notification.Name {
  static let eqPresetDidChange = Notification.Name("flo.eqPresetDidChange")
}

/// Throttled per-tap source-error log (audio thread; first 3 only).
private func eqLogSourceError(tap: MTAudioProcessingTap, status: OSStatus) {
  guard UserDefaultsManager.enableDebug else { return }
  let ctx = Unmanaged<EQTapContext>.fromOpaque(MTAudioProcessingTapGetStorage(tap))
    .takeUnretainedValue()
  guard ctx.sourceErrorCount < 3 else {
    ctx.sourceErrorCount += 1
    return
  }
  ctx.sourceErrorCount += 1
  eqLog.error("tap GetSourceAudio failed: status=\(status) count=\(ctx.sourceErrorCount)")
}

// MARK: - Biquad

private struct EQCoeffs {
  var b0: Float = 1
  var b1: Float = 0
  var b2: Float = 0
  var a1: Float = 0
  var a2: Float = 0
  var bypass: Bool = true
}

private struct EQState {
  var x1: Float = 0
  var x2: Float = 0
  var y1: Float = 0
  var y2: Float = 0
}

/// RBJ peaking-EQ coefficients, normalized (a0 = 1).
private func peakingCoeffs(gainDB: Float, freq: Float, q: Float, sampleRate: Float) -> EQCoeffs {
  if abs(gainDB) < 0.05 { return EQCoeffs() }
  let a = pow(10, gainDB / 40)
  let w0 = 2 * Float.pi * freq / sampleRate
  let sinW0 = sin(w0)
  let cosW0 = cos(w0)
  let alpha = sinW0 / (2 * q)
  let b0 = 1 + alpha * a
  let b1 = -2 * cosW0
  let b2 = 1 - alpha * a
  let a0 = 1 + alpha / a
  let a1 = -2 * cosW0
  let a2 = 1 - alpha / a
  return EQCoeffs(
    b0: b0 / a0, b1: b1 / a0, b2: b2 / a0,
    a1: a1 / a0, a2: a2 / a0, bypass: false)
}

// MARK: - Tap context (one per AVPlayerItem)

private final class EQTapContext {
  let lock = NSLock()
  var sampleRate: Float = 44100
  var channelCount: Int = 2
  var coeffs: [EQCoeffs] = Array(repeating: EQCoeffs(), count: 10)
  // states[channel][band]
  var states: [[EQState]] = []
  var lastGeneration: UInt64 = 0
  var sourceErrorCount = 0

  func resetChannels(_ count: Int) {
    channelCount = max(count, 1)
    states = Array(
      repeating: Array(repeating: EQState(), count: 10), count: channelCount)
  }

  func refreshIfNeeded() {
    let mgr = EqualizerManager.shared
    mgr.stateLock.lock()
    let gen = mgr.generation
    let gains = mgr.currentGains
    mgr.stateLock.unlock()
    if gen == lastGeneration { return }
    lastGeneration = gen
    lock.lock()
    defer { lock.unlock() }
    let q: Float = 1.0
    for i in 0..<10 {
      coeffs[i] = peakingCoeffs(
        gainDB: i < gains.count ? gains[i] : 0,
        freq: EqualizerPreset.frequencies[i],
        q: q, sampleRate: sampleRate)
    }
    // Clear state on preset switch to avoid zipper thumps.
    for c in states.indices {
      for b in states[c].indices { states[c][b] = EQState() }
    }
  }
}

// MARK: - Tap callbacks (C function pointers — must be global, non-capturing)

private func eqTapInit(
  _ tap: MTAudioProcessingTap, _ clientInfo: UnsafeMutableRawPointer?,
  _ tapStorageOut: UnsafeMutablePointer<UnsafeMutableRawPointer?>
) {
  // clientInfo is a retained EQTapContext (passRetained at creation).
  tapStorageOut.pointee = clientInfo
}

private func eqTapFinalize(_ tap: MTAudioProcessingTap?) {
  guard let tap else { return }
  let storage = MTAudioProcessingTapGetStorage(tap)
  // Balance the passRetained at creation.
  Unmanaged<EQTapContext>.fromOpaque(storage).release()
}

private func eqTapPrepare(
  _ tap: MTAudioProcessingTap, _ maxFrames: CMItemCount,
  _ processingFormat: UnsafePointer<AudioStreamBasicDescription>
) {
  let ctx = Unmanaged<EQTapContext>.fromOpaque(MTAudioProcessingTapGetStorage(tap))
    .takeUnretainedValue()
  let fmt = processingFormat.pointee
  ctx.lock.lock()
  ctx.sampleRate = Float(fmt.mSampleRate > 0 ? fmt.mSampleRate : 44100)
  ctx.lock.unlock()
  let channels = Int(fmt.mChannelsPerFrame > 0 ? fmt.mChannelsPerFrame : 2)
  ctx.resetChannels(channels)
  if UserDefaultsManager.enableDebug {
    eqLog.debug("tap prepare: sampleRate=\(ctx.sampleRate) channels=\(channels)")
  }
  ctx.lastGeneration = 0 // force coeff recompute on first process block
  ctx.refreshIfNeeded()
}

private func eqTapUnprepare(_ tap: MTAudioProcessingTap?) {}

private func eqTapProcess(
  _ tap: MTAudioProcessingTap, _ numberFrames: CMItemCount,
  _ flags: MTAudioProcessingTapFlags,
  _ bufferListInOut: UnsafeMutablePointer<AudioBufferList>,
  _ numberFramesOut: UnsafeMutablePointer<CMItemCount>,
  _ flagsOut: UnsafeMutablePointer<MTAudioProcessingTapFlags>
) {
  var range = CMTimeRange.invalid
  var framesOut: CMItemCount = 0
  var flagsStorage = MTAudioProcessingTapFlags(0)
  let status = MTAudioProcessingTapGetSourceAudio(
    tap, numberFrames, bufferListInOut, &flagsStorage, &range, &framesOut)
  guard status == noErr else {
    // Must still answer the pipeline — leaving outputs untouched stalls
    // the player permanently (stuck playback on track change / seek).
    numberFramesOut.pointee = 0
    flagsOut.pointee = flagsStorage
    eqLogSourceError(tap: tap, status: status)
    return
  }
  numberFramesOut.pointee = framesOut
  flagsOut.pointee = flagsStorage
  if framesOut == 0 { return }

  let ctx = Unmanaged<EQTapContext>.fromOpaque(MTAudioProcessingTapGetStorage(tap))
    .takeUnretainedValue()
  ctx.refreshIfNeeded()

  ctx.lock.lock()
  let coeffs = ctx.coeffs
  ctx.lock.unlock()

  // Fast path: all bands bypassed.
  if coeffs.allSatisfy({ $0.bypass }) { return }

  // Manual AudioBufferList walk (no UnsafeMutableAudioBufferListPointer —
  // unavailable under Mac Catalyst). Layout: mNumberBuffers followed by
  // a variable-length array of AudioBuffer structs.
  let numBuffers = Int(bufferListInOut.pointee.mNumberBuffers)
  var channelOffset = 0
  withUnsafeMutablePointer(to: &bufferListInOut.pointee.mBuffers) { first in
    let base = UnsafeMutableRawPointer(first)
    for bufIdx in 0..<numBuffers {
      let abPtr = base.advanced(by: bufIdx * MemoryLayout<AudioBuffer>.stride)
        .assumingMemoryBound(to: AudioBuffer.self)
      let mNumberChannels = abPtr.pointee.mNumberChannels
      guard let mData = abPtr.pointee.mData else {
        channelOffset += Int(mNumberChannels)
        continue
      }
      eqProcessBuffer(
        mData: mData, channelsInBuffer: Int(mNumberChannels),
        frames: Int(framesOut), dataByteSize: Int(abPtr.pointee.mDataByteSize),
        channelOffset: &channelOffset, ctx: ctx, coeffs: coeffs)
    }
  }
}

/// Applies the 10-band cascade to one AudioBuffer in place.
private func eqProcessBuffer(
  mData: UnsafeMutableRawPointer, channelsInBuffer: Int,
  frames: Int, dataByteSize: Int, channelOffset: inout Int,
  ctx: EQTapContext, coeffs: [EQCoeffs]
) {
  guard frames > 0 else {
    channelOffset += channelsInBuffer
    return
  }
  // Only touch Float32 PCM. Anything else (e.g. Int16) passes through
  // untouched rather than being misinterpreted as float.
  guard dataByteSize >= frames * max(channelsInBuffer, 1) * MemoryLayout<Float>.size else {
    channelOffset += channelsInBuffer
    return
  }
  let ptr = mData.assumingMemoryBound(to: Float.self)
  if channelsInBuffer <= 1 {
      let ch = channelOffset
      guard ch < ctx.states.count else {
        channelOffset += 1
        return
      }
      var st = ctx.states[ch]
      for i in 0..<frames {
        var s = ptr[i]
        for b in 0..<10 {
          let c = coeffs[b]
          if c.bypass { continue }
          var cur = st[b]
          let y = c.b0 * s + c.b1 * cur.x1 + c.b2 * cur.x2 - c.a1 * cur.y1 - c.a2 * cur.y2
          cur.x2 = cur.x1
          cur.x1 = s
          cur.y2 = cur.y1
          cur.y1 = y
          st[b] = cur
          s = y
        }
        ptr[i] = min(max(s, -1.0), 1.0)
      }
      ctx.states[ch] = st
      channelOffset += 1
    } else {
      // Interleaved: frames × channels.
      for f in 0..<frames {
        for c in 0..<channelsInBuffer {
          let ch = channelOffset + c
          guard ch < ctx.states.count else { continue }
          var st = ctx.states[ch]
          var s = ptr[f * channelsInBuffer + c]
          for b in 0..<10 {
            let cf = coeffs[b]
            if cf.bypass { continue }
            var cur = st[b]
            let y =
              cf.b0 * s + cf.b1 * cur.x1 + cf.b2 * cur.x2 - cf.a1 * cur.y1 - cf.a2 * cur.y2
            cur.x2 = cur.x1
            cur.x1 = s
            cur.y2 = cur.y1
            cur.y1 = y
            st[b] = cur
            s = y
          }
          ptr[f * channelsInBuffer + c] = min(max(s, -1.0), 1.0)
          ctx.states[ch] = st
        }
      }
      channelOffset += channelsInBuffer
  }
}

// MARK: - Manager

final class EqualizerManager {
  static let shared = EqualizerManager()

  fileprivate let stateLock = NSLock()
  fileprivate var currentGains: [Float] = EqualizerPreset.off.gains
  fileprivate var generation: UInt64 = 1

  var preset: EqualizerPreset {
    get { EqualizerPreset.from(rawValue: UserDefaultsManager.equalizerPreset) }
    set {
      let wasBypassed = preset.isBypass
      UserDefaultsManager.equalizerPreset = newValue.rawValue
      applyGains(newValue.gains)
      NotificationCenter.default.post(
        name: .eqPresetDidChange,
        object: nil,
        userInfo: [
          "wasBypassed": wasBypassed, "isBypassed": newValue.isBypass,
        ])
    }
  }

  private init() {
    currentGains = preset.gains
  }

  func applyGains(_ gains: [Float]) {
    stateLock.lock()
    currentGains = gains
    generation &+= 1
    stateLock.unlock()
  }

  /// Call after launch / login to pick up the persisted preset.
  func restorePersistedPreset() {
    applyGains(preset.gains)
  }

  var isBypassed: Bool { preset.isBypass }

  /// Returns nil when EQ is Off/Flat (bit-perfect, zero CPU).
  func makeAudioMix() -> AVAudioMix? {
    if isBypassed { return nil }
    let ctx = EQTapContext()
    // Retained here, released in eqTapFinalize.
    let clientInfo = Unmanaged.passRetained(ctx).toOpaque()
    var callbacks = MTAudioProcessingTapCallbacks(
      version: kMTAudioProcessingTapCallbacksVersion_0,
      clientInfo: clientInfo,
      init: eqTapInit,
      finalize: eqTapFinalize,
      prepare: eqTapPrepare,
      unprepare: eqTapUnprepare,
      process: eqTapProcess)
    var tap: MTAudioProcessingTap?
    let status = MTAudioProcessingTapCreate(
      kCFAllocatorDefault, &callbacks, kMTAudioProcessingTapCreationFlag_PreEffects, &tap)
    guard status == noErr, let tap else {
      // Creation failed — avoid leaking the retained context.
      Unmanaged<EQTapContext>.fromOpaque(clientInfo).release()
      if UserDefaultsManager.enableDebug {
        eqLog.error("tap creation failed: status=\(status)")
      }
      return nil
    }
    let params = AVMutableAudioMixInputParameters()
    params.trackID = kCMPersistentTrackID_Invalid
    params.audioTapProcessor = tap
    let mix = AVMutableAudioMix()
    mix.inputParameters = [params]
    return mix
  }
}
