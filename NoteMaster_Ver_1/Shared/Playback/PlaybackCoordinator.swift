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

protocol PlaybackAudioBackend: AnyObject {
    func startPreview(note: NotePitch)
    func replacePreview(note: NotePitch)
    func stopPreview()
}

final class PlaybackCoordinator {
    private let backend: PlaybackAudioBackend

    private(set) var currentPreview: PianoPreviewState?

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
            guard currentPreview == preview else {
                return
            }

            currentPreview = nil
            backend.stopPreview()
        }
    }

    func forceStop(reason _: PlaybackStopReason) {
        currentPreview = nil
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

            self.currentPreview = preview
            return
        }

        currentPreview = preview
        backend.startPreview(note: preview.note)
    }
}
