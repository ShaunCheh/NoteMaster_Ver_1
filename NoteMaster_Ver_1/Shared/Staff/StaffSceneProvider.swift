//
//  StaffSceneProvider.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/3/24.
//

// 阶段 1 先固定“状态 -> 场景入口”的共享边界；
// 真正基于 geometry 产出 scene 的逻辑留到阶段 2 再补齐。
struct StaffSceneProvider: Equatable, Sendable {
    var clef: StaffClef

    init(clef: StaffClef = .treble) {
        self.clef = clef
    }
}
