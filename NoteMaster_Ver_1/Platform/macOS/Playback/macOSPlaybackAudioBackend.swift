#if os(macOS)
import AVFoundation

final class macOSPlaybackAudioBackend: PlaybackAudioBackend {
    private let toneEngine = AVFoundationTonePlaybackEngine()

    func startVoice(_ voiceID: PlaybackVoiceID, note: NotePitch) {
        toneEngine.startVoice(voiceID, note: note)
    }

    func updateVoice(_ voiceID: PlaybackVoiceID, note: NotePitch) {
        toneEngine.updateVoice(voiceID, note: note)
    }

    func stopVoice(_ voiceID: PlaybackVoiceID) {
        toneEngine.stopVoice(voiceID)
    }

    func stopAllVoices() {
        toneEngine.stopAllVoices()
    }
}
#endif
