#if os(macOS)
import AVFoundation

final class macOSPlaybackAudioBackend: PlaybackAudioBackend {
    private let toneEngine = AVFoundationTonePlaybackEngine()

    func startPreview(note: NotePitch) {
        toneEngine.startPreview(note: note)
    }

    func replacePreview(note: NotePitch) {
        toneEngine.replacePreview(note: note)
    }

    func stopPreview() {
        toneEngine.stopPreview()
    }
}
#endif
