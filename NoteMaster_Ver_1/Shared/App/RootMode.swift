enum RootMode: String, Equatable, Hashable, Sendable {
    case exercise
    case play

    static let defaultMode: RootMode = .exercise

    var debugName: String {
        rawValue
    }
}
