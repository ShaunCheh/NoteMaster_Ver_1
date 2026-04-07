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

    private struct RenderState {
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
    }

    private let engine = AVAudioEngine()
    private let sourceFormat: AVAudioFormat
    private var renderState: RenderState

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
        self.renderState = RenderState(sampleRate: sampleRate)
        engine.attach(sourceNode)
        engine.connect(
            sourceNode,
            to: engine.mainMixerNode,
            format: sourceFormat
        )
        engine.prepare()
    }

    func startPreview(note: NotePitch) {
        ensureEngineRunning()
        let frequencyHz = note.playbackFrequencyHz
        renderState.targetFrequencyHz = frequencyHz
        if abs(renderState.currentAmplitude) < Self.amplitudeEpsilon {
            renderState.currentFrequencyHz = frequencyHz
        }
        renderState.targetAmplitude = Self.previewAmplitude
    }

    func replacePreview(note: NotePitch) {
        ensureEngineRunning()
        let frequencyHz = note.playbackFrequencyHz
        renderState.targetFrequencyHz = frequencyHz
        if abs(renderState.currentAmplitude) < Self.amplitudeEpsilon {
            renderState.currentFrequencyHz = frequencyHz
        }
        renderState.targetAmplitude = Self.previewAmplitude
    }

    func stopPreview() {
        renderState.targetAmplitude = 0
    }
}

private extension AVFoundationTonePlaybackEngine {
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
        let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
        for frameIndex in 0..<Int(frameCount) {
            let sample = renderState.nextSample()
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
