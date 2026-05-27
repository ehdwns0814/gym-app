import Foundation
import SwiftData

enum ExerciseSeeder {
    @MainActor
    static func seedDefaultExercises(in context: ModelContext) async {
        for defaultExercise in DefaultExercises.all {
            if !existingSeedKeys(in: context).contains(defaultExercise.seedKey) {
                let exercise = Exercise(
                    seedKey: defaultExercise.seedKey,
                    name: defaultExercise.name,
                    type: defaultExercise.type,
                    isSystem: true
                )
                context.insert(exercise)
            }
        }

        do {
            try context.save()
        } catch {
            assertionFailure("Failed to seed default exercises: \(error)")
        }
    }

    @MainActor
    private static func existingSeedKeys(in context: ModelContext) -> Set<String> {
        let descriptor = FetchDescriptor<Exercise>()
        let exercises = (try? context.fetch(descriptor)) ?? []
        return Set(exercises.compactMap(\.seedKey))
    }
}
