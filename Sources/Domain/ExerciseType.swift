import Foundation

enum ExerciseType: String, Codable, CaseIterable, Identifiable {
    case weightReps
    case duration

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .weightReps:
            "중량/횟수형"
        case .duration:
            "시간형"
        }
    }
}
