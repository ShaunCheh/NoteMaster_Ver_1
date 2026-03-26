//
//  TopContentDisplayState.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/3/26.
//

enum TopContentMode: Equatable, Hashable, Sendable {
    case staff
    case targetPrompt
}

struct TopContentDisplayState: Equatable, Sendable {
    // 顶部内容模式属于页面编排状态，不进入五线谱或指板内部 display state。
    var mode: TopContentMode

    static let `default` = TopContentDisplayState(mode: .staff)

    init(mode: TopContentMode = .staff) {
        self.mode = mode
    }

    mutating func setMode(_ mode: TopContentMode) {
        self.mode = mode
    }
}
