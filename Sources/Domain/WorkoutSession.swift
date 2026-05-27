import Foundation
import SwiftData

@Model
final class WorkoutSession {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var updatedAt: Date
    var performedOn: Date
    @Relationship(deleteRule: .cascade, inverse: \WorkoutEntry.session)
    var entries: [WorkoutEntry]

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        performedOn: Date = Date(),
        entries: [WorkoutEntry] = []
    ) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.performedOn = performedOn
        self.entries = entries
    }
}
