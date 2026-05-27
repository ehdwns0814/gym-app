import Foundation
import SwiftData

@Model
final class SetEntry {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var updatedAt: Date
    var weight: Double?
    var repetitions: Int?
    var durationSeconds: Int?
    var isCompleted: Bool
    var workoutEntry: WorkoutEntry?

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        weight: Double? = nil,
        repetitions: Int? = nil,
        durationSeconds: Int? = nil,
        isCompleted: Bool = false,
        workoutEntry: WorkoutEntry? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.weight = weight
        self.repetitions = repetitions
        self.durationSeconds = durationSeconds
        self.isCompleted = isCompleted
        self.workoutEntry = workoutEntry
    }
}
