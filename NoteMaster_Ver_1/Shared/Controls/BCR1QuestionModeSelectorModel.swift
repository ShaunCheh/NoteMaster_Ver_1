//
//  BCR1QuestionModeSelectorModel.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/9/11.
//

struct BCR1QuestionModeSelectorChoice: Equatable, Sendable {
    var mode: TrainerBCR1QuestionMode
    var title: String
    var isSelected: Bool
}

struct BCR1QuestionModeSelectorModel: Equatable, Sendable {
    var accessibilityLabel: String
    var choices: [BCR1QuestionModeSelectorChoice]

    static func make(from state: TrainerDisplayState) -> Self {
        let selectedMode = state.bcr1QuestionConfiguration.mode
        return Self(
            accessibilityLabel: "选择 BCR-1 音符位置模式",
            choices: [
                BCR1QuestionModeSelectorChoice(
                    mode: .line,
                    title: "线上",
                    isSelected: selectedMode == .line
                ),
                BCR1QuestionModeSelectorChoice(
                    mode: .space,
                    title: "间上",
                    isSelected: selectedMode == .space
                ),
                BCR1QuestionModeSelectorChoice(
                    mode: .mixed,
                    title: "混合",
                    isSelected: selectedMode == .mixed
                )
            ]
        )
    }
}

enum BCR1QuestionModeSelectorEvent: Equatable, Sendable {
    case select(TrainerBCR1QuestionMode)
}
