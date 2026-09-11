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
    case bcr1QuestionModeChanged

    var debugName: String {
        rawValue
    }
}

typealias PlaybackVoiceID = PianoVoiceID

protocol PlaybackAudioBackend: AnyObject {
    func startVoice(_ voiceID: PlaybackVoiceID, note: NotePitch)
    func updateVoice(_ voiceID: PlaybackVoiceID, note: NotePitch)
    func stopVoice(_ voiceID: PlaybackVoiceID)
    func stopAllVoices()
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
            upsertVoice(preview)
        case let .previewChanged(preview):
            upsertVoice(preview)
        case let .previewEnded(preview):
            guard activeVoices[preview.voiceID] == preview else {
                return
            }

            activeVoices.removeValue(forKey: preview.voiceID)
            backend.stopVoice(preview.voiceID)
        }
    }

    func forceStop(reason _: PlaybackStopReason) {
        activeVoices.removeAll()
        backend.stopAllVoices()
    }
}

private extension PlaybackCoordinator {
    func upsertVoice(_ preview: PianoPreviewState) {
        if let currentVoice = activeVoices[preview.voiceID] {
            guard currentVoice != preview else {
                return
            }

            activeVoices[preview.voiceID] = preview
            if currentVoice.note != preview.note {
                backend.updateVoice(preview.voiceID, note: preview.note)
            }
            return
        }

        activeVoices[preview.voiceID] = preview
        backend.startVoice(preview.voiceID, note: preview.note)
    }
}
