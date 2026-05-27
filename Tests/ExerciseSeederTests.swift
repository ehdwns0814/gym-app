import SwiftData
import XCTest
@testable import GymApp

@MainActor
final class ExerciseSeederTests: XCTestCase {
    func testSeedDefaultExercisesCreatesExpectedExercises() async throws {
        let container = try AppModelContainer.make(inMemory: true)

        await ExerciseSeeder.seedDefaultExercises(in: container.mainContext)

        let exercises = try fetchExercises(from: container.mainContext)
        XCTAssertEqual(Set(exercises.map(\.name)), Set(DefaultExercises.all.map(\.name)))
        XCTAssertEqual(exercises.count, 7)
        XCTAssertTrue(exercises.allSatisfy(\.isSystem))
        XCTAssertEqual(exercises.first { $0.name == "플랭크" }?.type, .duration)
        XCTAssertEqual(exercises.first { $0.name == "벤치프레스" }?.type, .weightReps)
    }

    func testSeedDefaultExercisesDoesNotCreateDuplicates() async throws {
        let container = try AppModelContainer.make(inMemory: true)

        await ExerciseSeeder.seedDefaultExercises(in: container.mainContext)
        await ExerciseSeeder.seedDefaultExercises(in: container.mainContext)

        let exercises = try fetchExercises(from: container.mainContext)
        XCTAssertEqual(exercises.count, DefaultExercises.all.count)
        XCTAssertEqual(Set(exercises.compactMap(\.seedKey)).count, DefaultExercises.all.count)
    }

    func testCoreModelsIncludeSyncMetadata() throws {
        let exercise = Exercise(name: "테스트", type: .weightReps, isSystem: false)
        let session = WorkoutSession()
        let entry = WorkoutEntry(exercise: exercise, session: session)
        let setEntry = SetEntry(weight: 20, repetitions: 10, workoutEntry: entry)

        XCTAssertNotNil(exercise.id)
        XCTAssertNotNil(session.id)
        XCTAssertNotNil(entry.id)
        XCTAssertNotNil(setEntry.id)
        XCTAssertLessThanOrEqual(exercise.createdAt, exercise.updatedAt)
        XCTAssertLessThanOrEqual(session.createdAt, session.updatedAt)
        XCTAssertLessThanOrEqual(entry.createdAt, entry.updatedAt)
        XCTAssertLessThanOrEqual(setEntry.createdAt, setEntry.updatedAt)
    }

    private func fetchExercises(from context: ModelContext) throws -> [Exercise] {
        try context.fetch(FetchDescriptor<Exercise>())
    }
}
