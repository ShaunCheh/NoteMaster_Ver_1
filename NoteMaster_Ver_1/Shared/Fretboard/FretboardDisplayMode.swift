//
//  FretboardDisplayMode.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/3/25.
//

enum FretboardDisplayMode: Equatable, Sendable {
    // 品位沿 x 轴向右递增；弦按低音到高音沿 y 轴向下排列。
    case horizontal
    // 品位沿 y 轴向下递增；弦按低音到高音沿 x 轴向右排列；音名文字保持正立。
    case vertical
}
