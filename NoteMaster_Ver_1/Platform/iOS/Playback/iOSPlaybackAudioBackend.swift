#if os(iOS)
import AVFoundation

final class iOSPlaybackAudioBackend: PlaybackAudioBackend {
    private let toneEngine = AVFoundationTonePlaybackEngine()
    private var isAudioSessionPrepared = false

    func startVoice(_ voiceID: PlaybackVoiceID, note: NotePitch) {
        prepareAudioSessionIfNeeded()
        toneEngine.startVoice(voiceID, note: note)
    }

    func updateVoice(_ voiceID: PlaybackVoiceID, note: NotePitch) {
        prepareAudioSessionIfNeeded()
        toneEngine.updateVoice(voiceID, note: note)
    }

    func stopVoice(_ voiceID: PlaybackVoiceID) {
        toneEngine.stopVoice(voiceID)
    }

    func stopAllVoices() {
        toneEngine.stopAllVoices()
    }
}

private extension iOSPlaybackAudioBackend {
    func prepareAudioSessionIfNeeded() {
        guard !isAudioSessionPrepared else {
            return
        }

        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(
                .playback,
                mode: .default,
                options: [.mixWithOthers]
            )
            try audioSession.setActive(true)
            isAudioSessionPrepared = true
        } catch {
            print("[Playback][iOSBackend] audioSessionSetupFailed error=\(error)")
        }
    }
}
#endif
