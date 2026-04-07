//
//  PianoValidationHelpers.swift
//  NoteMaster_Ver_1
//
//  Shared helpers for piano validation fixtures (split from PianoValidation.swift).
//

import Foundation

extension PianoValidationRunner {
    static func issue(
        _ fixtureName: String,
        _ message: String
    ) -> PianoValidationIssue {
        PianoValidationIssue(fixtureName: fixtureName, message: message)
    }
}
