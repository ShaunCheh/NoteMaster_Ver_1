//
//  PlaybackCoordinator.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/4/7.
//

enum PlaybackStopReason: String, Sendable {
    case rootModeChanged
    case panelStateChanged
    case sharedSettingsChanged
    case viewWillDisappear
    case interactionDisabled

    var debugName: String {
        rawValue
    }
}

typealias PlaybackVoiceID = PianoVoiceID

protocol PlaybackAudioBackend: AnyObject {
    func startPreview(note: NotePitch)
    func replacePreview(note: NotePitch)
    func stopPreview()
}

final class PlaybackCoordinator {
    private let backend: PlaybackAudioBackend

    private(set) var activeVoices: [PlaybackVoiceID: PianoPreviewState] = [:]

    var currentPreview: PianoPreviewState? {
        activeVoices.values.min { lhs, rhs in
            lhs.previewID.rawValue < rhs.previewID.rawValue
        }
    }

    init(backend: PlaybackAudioBackend) {
        self.backend = backend
    }

    func handle(_ semanticEvent: PianoSemanticEvent) {
        switch semanticEvent {
        case .rowsChanged:
            return
        case let .previewStarted(preview):
            transitionToPreview(preview)
        case let .previewChanged(preview):
            transitionToPreview(preview)
        case let .previewEnded(preview):
            guard activeVoices[preview.voiceID] == preview else {
                return
            }

            activeVoices.removeValue(forKey: preview.voiceID)
            backend.stopPreview()
        }
    }

    func forceStop(reason _: PlaybackStopReason) {
        activeVoices.removeAll()
        backend.stopPreview()
    }
}

private extension PlaybackCoordinator {
    func transitionToPreview(_ preview: PianoPreviewState) {
        if let currentPreview {
            guard currentPreview != preview else {
                return
            }

            if currentPreview.note != preview.note {
                backend.replacePreview(note: preview.note)
            }

            // Phase 1 only freezes the shared identity contract. Until the
            // backend becomes polyphonic in phase 5, keep the legacy runtime
            // behavior of collapsing playback to the latest active voice.
            activeVoices = [preview.voiceID: preview]
            return
        }

        activeVoices = [preview.voiceID: preview]
        backend.startPreview(note: preview.note)
    }
}
