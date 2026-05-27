import Foundation
import SwiftData

@Model
final class WorkoutEntry {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var updatedAt: Date
    var equipmentNote: String
    var exercise: Exercise?
    var session: WorkoutSession?
    @Relationship(deleteRule: .cascade, inverse: \SetEntry.workoutEntry)
    var sets: [SetEntry]

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        equipmentNote: String = "",
        exercise: Exercise? = nil,
        session: WorkoutSession? = nil,
        sets: [SetEntry] = []
    ) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.equipmentNote = equipmentNote
        self.exercise = exercise
        self.session = session
        self.sets = sets
    }

    var setCount: Int { sets.count }
}
