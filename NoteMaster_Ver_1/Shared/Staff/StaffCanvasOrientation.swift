//
//  StaffCanvasOrientation.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/3/24.
//

struct StaffCanvasOrientation: Equatable, Sendable {
    enum Origin: Equatable, Sendable {
        case topLeft
    }

    enum VerticalAxisDirection: Equatable, Sendable {
        case down
    }

    var origin: Origin
    var verticalAxisDirection: VerticalAxisDirection

    static let standard = Self(
        origin: .topLeft,
        verticalAxisDirection: .down
    )
}
