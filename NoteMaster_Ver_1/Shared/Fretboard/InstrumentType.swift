//
//  InstrumentType.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/3/19.
//

enum InstrumentType: CaseIterable, Sendable {
    case guitar6
    case bass4
    case bass5

    var stringCount: Int {
        switch self {
        case .guitar6:
            return 6
        case .bass4:
            return 4
        case .bass5:
            return 5
        }
    }
}
