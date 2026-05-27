import Foundation
import SwiftData

@Model
final class Exercise {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var updatedAt: Date
    @Attribute(.unique) var seedKey: String?
    var name: String
    var typeRawValue: String
    var isSystem: Bool

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        seedKey: String? = nil,
        name: String,
        type: ExerciseType,
        isSystem: Bool
    ) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.seedKey = seedKey
        self.name = name
        self.typeRawValue = type.rawValue
        self.isSystem = isSystem
    }

    var type: ExerciseType {
        get { ExerciseType(rawValue: typeRawValue) ?? .weightReps }
        set {
            typeRawValue = newValue.rawValue
            updatedAt = Date()
        }
    }
}
