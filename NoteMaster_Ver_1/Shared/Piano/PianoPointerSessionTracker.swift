//
//  PianoPointerSessionTracker.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/4/8.
//

import CoreGraphics
import Foundation

struct PianoPointerSession {
    var pointerID: PianoPointerID
    var lastLocationInView: CGPoint
}

struct PianoPointerSessionTracker<Source: Hashable> {
    private(set) var sessionsBySource: [Source: PianoPointerSession] = [:]
    private var nextPointerRawValue: UInt64 = PianoPointerID.legacyPrimary.rawValue + 1

    var hasActiveSessions: Bool {
        !sessionsBySource.isEmpty
    }

    var activePointerIDs: Set<PianoPointerID> {
        Set(sessionsBySource.values.map(\.pointerID))
    }

    func session(for source: Source) -> PianoPointerSession? {
        sessionsBySource[source]
    }

    mutating func begin(
        source: Source,
        locationInView: CGPoint
    ) -> PianoRawEvent? {
        guard sessionsBySource[source] == nil else {
            return nil
        }

        let pointerID = allocatePointerID()
        sessionsBySource[source] = PianoPointerSession(
            pointerID: pointerID,
            lastLocationInView: locationInView
        )
        return PianoRawEvent(
            pointerID: pointerID,
            phase: .began,
            locationInView: locationInView
        )
    }

    mutating func move(
        source: Source,
        locationInView: CGPoint
    ) -> PianoRawEvent? {
        update(
            source: source,
            phase: .moved,
            locationInView: locationInView,
            removeAfterDispatch: false
        )
    }

    mutating func end(
        source: Source,
        locationInView: CGPoint? = nil
    ) -> PianoRawEvent? {
        update(
            source: source,
            phase: .ended,
            locationInView: locationInView,
            removeAfterDispatch: true
        )
    }

    mutating func cancel(
        source: Source,
        locationInView: CGPoint? = nil
    ) -> PianoRawEvent? {
        update(
            source: source,
            phase: .cancelled,
            locationInView: locationInView,
            removeAfterDispatch: true
        )
    }

    mutating func retainSessions(
        withPointerIDs pointerIDs: Set<PianoPointerID>
    ) {
        sessionsBySource = sessionsBySource.filter { entry in
            pointerIDs.contains(entry.value.pointerID)
        }
    }

    mutating func removeAllSessions() {
        sessionsBySource.removeAll()
    }
}

private extension PianoPointerSessionTracker {
    mutating func allocatePointerID() -> PianoPointerID {
        let pointerID = PianoPointerID(rawValue: nextPointerRawValue)
        nextPointerRawValue += 1
        return pointerID
    }

    mutating func update(
        source: Source,
        phase: PianoEventPhase,
        locationInView: CGPoint?,
        removeAfterDispatch: Bool
    ) -> PianoRawEvent? {
        guard var session = sessionsBySource[source] else {
            return nil
        }

        let resolvedLocation = locationInView ?? session.lastLocationInView
        session.lastLocationInView = resolvedLocation
        if removeAfterDispatch {
            sessionsBySource.removeValue(forKey: source)
        } else {
            sessionsBySource[source] = session
        }

        return PianoRawEvent(
            pointerID: session.pointerID,
            phase: phase,
            locationInView: resolvedLocation
        )
    }
}
