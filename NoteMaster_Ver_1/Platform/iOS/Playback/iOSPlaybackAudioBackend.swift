#if os(iOS)
import AVFoundation

final class iOSPlaybackAudioBackend: PlaybackAudioBackend {
    private let toneEngine = AVFoundationTonePlaybackEngine()

    func startPreview(note: NotePitch) {
        prepareAudioSession()
        toneEngine.startPreview(note: note)
    }

    func replacePreview(note: NotePitch) {
        prepareAudioSession()
        toneEngine.replacePreview(note: note)
    }

    func stopPreview() {
        toneEngine.stopPreview()
    }
}

private extension iOSPlaybackAudioBackend {
    func prepareAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(
                .playback,
                mode: .default,
                options: [.mixWithOthers]
            )
            try audioSession.setActive(true)
        } catch {
            print("[Playback][iOSBackend] audioSessionSetupFailed error=\(error)")
        }
    }
}
#endif
