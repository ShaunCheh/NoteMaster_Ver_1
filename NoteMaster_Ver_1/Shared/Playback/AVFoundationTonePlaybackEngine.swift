//
//  AVFoundationTonePlaybackEngine.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/4/7.
//

import Foundation
import AVFoundation

final class AVFoundationTonePlaybackEngine {
    private static let previewAmplitude = 0.14
    private static let smoothingFactor = 0.004
    private static let amplitudeEpsilon = 0.0001

    private struct VoiceRenderState {
        let sampleRate: Double
        var phase = 0.0
        var currentFrequencyHz = 0.0
        var targetFrequencyHz = 0.0
        var currentAmplitude = 0.0
        var targetAmplitude = 0.0

        mutating func nextSample() -> Float {
            currentFrequencyHz += (targetFrequencyHz - currentFrequencyHz)
                * AVFoundationTonePlaybackEngine.smoothingFactor
            currentAmplitude += (targetAmplitude - currentAmplitude)
                * AVFoundationTonePlaybackEngine.smoothingFactor

            if targetAmplitude == 0,
               abs(currentAmplitude) < AVFoundationTonePlaybackEngine.amplitudeEpsilon {
                currentAmplitude = 0
            }

            let sample = sin(phase) * currentAmplitude
            phase += (2 * .pi * max(currentFrequencyHz, 0)) / sampleRate
            if phase >= 2 * .pi {
                phase.formTruncatingRemainder(dividingBy: 2 * .pi)
            }

            return Float(sample)
        }

        var canBePruned: Bool {
            targetAmplitude == 0
                && abs(currentAmplitude) < AVFoundationTonePlaybackEngine.amplitudeEpsilon
        }
    }

    private let engine = AVAudioEngine()
    private let sourceFormat: AVAudioFormat
    private let renderStateLock = NSLock()
    private var voiceStates: [PlaybackVoiceID: VoiceRenderState] = [:]

    private lazy var sourceNode = AVAudioSourceNode { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
        guard let self else {
            return noErr
        }

        return self.renderAudio(
            frameCount: frameCount,
            audioBufferList: audioBufferList
        )
    }

    init(
        sampleRate: Double = 44_100
    ) {
        self.sourceFormat = AVAudioFormat(
            standardFormatWithSampleRate: sampleRate,
            channels: 1
        )!
        engine.attach(sourceNode)
        engine.connect(
            sourceNode,
            to: engine.mainMixerNode,
            format: sourceFormat
        )
        engine.prepare()
    }

    func startVoice(_ voiceID: PlaybackVoiceID, note: NotePitch) {
        ensureEngineRunning()
        updateVoiceState(
            voiceID,
            note: note
        )
    }

    func updateVoice(_ voiceID: PlaybackVoiceID, note: NotePitch) {
        ensureEngineRunning()
        updateVoiceState(
            voiceID,
            note: note
        )
    }

    func stopVoice(_ voiceID: PlaybackVoiceID) {
        renderStateLock.lock()
        defer { renderStateLock.unlock() }

        guard var voiceState = voiceStates[voiceID] else {
            return
        }
        voiceState.targetAmplitude = 0
        voiceStates[voiceID] = voiceState
    }

    func stopAllVoices() {
        renderStateLock.lock()
        voiceStates.removeAll()
        renderStateLock.unlock()
    }
}

private extension AVFoundationTonePlaybackEngine {
    func updateVoiceState(
        _ voiceID: PlaybackVoiceID,
        note: NotePitch
    ) {
        renderStateLock.lock()
        defer { renderStateLock.unlock() }

        let frequencyHz = note.playbackFrequencyHz
        var voiceState = voiceStates[voiceID]
            ?? VoiceRenderState(sampleRate: sourceFormat.sampleRate)
        voiceState.targetFrequencyHz = frequencyHz
        if abs(voiceState.currentAmplitude) < Self.amplitudeEpsilon {
            voiceState.currentFrequencyHz = frequencyHz
        }
        voiceState.targetAmplitude = Self.previewAmplitude
        voiceStates[voiceID] = voiceState
    }

    func ensureEngineRunning() {
        guard !engine.isRunning else {
            return
        }

        do {
            try engine.start()
        } catch {
            print("[Playback][AVFoundationTonePlaybackEngine] failedToStart error=\(error)")
        }
    }

    func renderAudio(
        frameCount: AVAudioFrameCount,
        audioBufferList: UnsafeMutablePointer<AudioBufferList>
    ) -> OSStatus {
        renderStateLock.lock()
        defer { renderStateLock.unlock() }

        let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
        for frameIndex in 0..<Int(frameCount) {
            let voiceIDs = Array(voiceStates.keys)
            let normalizationFactor = max(1.0, sqrt(Double(voiceIDs.count)))
            var mixedSample = 0.0

            for voiceID in voiceIDs {
                guard var voiceState = voiceStates[voiceID] else {
                    continue
                }

                mixedSample += Double(voiceState.nextSample())
                if voiceState.canBePruned {
                    voiceStates.removeValue(forKey: voiceID)
                } else {
                    voiceStates[voiceID] = voiceState
                }
            }

            let sample = Float(
                max(min(mixedSample / normalizationFactor, 1.0), -1.0)
            )
            for buffer in buffers {
                guard let mData = buffer.mData else {
                    continue
                }

                let samples = mData.assumingMemoryBound(to: Float.self)
                samples[frameIndex] = sample
            }
        }

        return noErr
    }
}
