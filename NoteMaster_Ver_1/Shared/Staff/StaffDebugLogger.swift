//
//  StaffDebugLogger.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/3/26.
//

import Foundation
import CoreGraphics

enum StaffDebugLogger {
    private static let lock = NSLock()
    private static var emittedKeys: Set<String> = []

    static func logOnce(
        key: String,
        message: @autoclosure () -> String
    ) {
        #if DEBUG
        lock.lock()
        let shouldEmit = emittedKeys.insert(key).inserted
        lock.unlock()

        guard shouldEmit else {
            return
        }

        print(message())
        #endif
    }

    static func format(_ value: CGFloat) -> String {
        String(format: "%.2f", Double(value))
    }

    static func format(_ point: CGPoint) -> String {
        "(\(format(point.x)), \(format(point.y)))"
    }

    static func format(_ size: CGSize) -> String {
        "(\(format(size.width)) x \(format(size.height)))"
    }

    static func format(_ rect: CGRect) -> String {
        "[x=\(format(rect.minX)), y=\(format(rect.minY)), w=\(format(rect.width)), h=\(format(rect.height))]"
    }
}
