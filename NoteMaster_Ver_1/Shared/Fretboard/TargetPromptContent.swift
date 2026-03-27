//
//  TargetPromptContent.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/3/27.
//

struct TargetPromptSequenceDisplayItem: Equatable, Sendable {
    enum State: Equatable, Sendable {
        case answered
        case current
        case pending
    }

    var text: String
    var state: State
}

enum TargetPromptContent: Equatable, Sendable {
    case single(text: String)
    case sequence(tokens: [String], currentIndex: Int)

    var accessibilityLabel: String {
        switch self {
        case let .single(text):
            return "Current target note \(text)"
        case let .sequence(tokens, currentIndex):
            Self.validateSequence(tokens: tokens, currentIndex: currentIndex)
            if currentIndex < tokens.count {
                return "Target note sequence, current step \(currentIndex + 1) of \(tokens.count), target \(tokens[currentIndex])"
            } else {
                return "Target note sequence completed, \(tokens.count) notes total"
            }
        }
    }

    var sequenceDisplayItems: [TargetPromptSequenceDisplayItem] {
        switch self {
        case .single:
            return []
        case let .sequence(tokens, currentIndex):
            Self.validateSequence(tokens: tokens, currentIndex: currentIndex)
            return tokens.enumerated().map { index, token in
                let state: TargetPromptSequenceDisplayItem.State
                if index < currentIndex {
                    state = .answered
                } else if index == currentIndex && currentIndex < tokens.count {
                    state = .current
                } else {
                    state = .pending
                }
                return TargetPromptSequenceDisplayItem(
                    text: token,
                    state: state
                )
            }
        }
    }

    private static func validateSequence(
        tokens: [String],
        currentIndex: Int
    ) {
        precondition(
            !tokens.isEmpty,
            "Target prompt sequence must contain at least one token."
        )
        precondition(
            currentIndex >= 0 && currentIndex <= tokens.count,
            "Target prompt sequence current index must stay within the token range."
        )
    }
}

extension GeneratedNoteSequence {
    func targetPromptContent(
        currentIndex: Int = 0,
        spelling: PitchSpelling = .sharp
    ) -> TargetPromptContent {
        .sequence(
            tokens: displayTexts(using: spelling),
            currentIndex: currentIndex
        )
    }
}

extension FretboardNaturalNoteTrainerState.Prompt {
    var targetPromptContent: TargetPromptContent {
        .single(text: displayText)
    }
}

extension FretboardNaturalNoteTrainerState.QuarterNoteSequencePrompt {
    func targetPromptContent(
        currentIndex: Int = 0,
        spelling: PitchSpelling = .sharp
    ) -> TargetPromptContent {
        generatedSequence.targetPromptContent(
            currentIndex: currentIndex,
            spelling: spelling
        )
    }
}

extension FretboardNaturalNoteTrainerState.QuarterNoteSequenceSession {
    func targetPromptContent(
        spelling: PitchSpelling = .sharp
    ) -> TargetPromptContent {
        generatedSequence.targetPromptContent(
            currentIndex: currentIndex,
            spelling: spelling
        )
    }
}
