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

    func testUserExerciseCanBeAddedAndUpdated() throws {
        let container = try AppModelContainer.make(inMemory: true)

        let exercise = try WorkoutStore.addExercise(name: "케이블 로우", type: .weightReps, in: container.mainContext)
        try WorkoutStore.updateExercise(exercise, name: "시티드 케이블 로우", type: .duration, in: container.mainContext)

        let exercises = try fetchExercises(from: container.mainContext)
        XCTAssertEqual(exercises.count, 1)
        XCTAssertEqual(exercises.first?.name, "시티드 케이블 로우")
        XCTAssertEqual(exercises.first?.type, .duration)
        XCTAssertEqual(exercises.first?.isSystem, false)
    }

    func testWeightRepsWorkoutSavesSetsAndAppearsNewestFirst() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let exercise = Exercise(name: "벤치프레스", type: .weightReps, isSystem: true)
        container.mainContext.insert(exercise)

        let entry = try WorkoutStore.saveWorkout(
            exercise: exercise,
            performedOn: date(year: 2026, month: 5, day: 27),
            equipmentNote: "",
            sets: [
                WorkoutSetInput(weight: 60, repetitions: 10, durationSeconds: nil, isCompleted: true),
                WorkoutSetInput(weight: 65, repetitions: 8, durationSeconds: nil, isCompleted: false),
            ],
            in: container.mainContext
        )

        let entries = try WorkoutStore.entries(in: container.mainContext)
        XCTAssertEqual(entries.first?.id, entry.id)
        XCTAssertEqual(entry.setCount, 2)
        XCTAssertEqual(WorkoutStore.sortedSets(for: entry).map(\.weight), [60, 65])
        XCTAssertEqual(WorkoutStore.sortedSets(for: entry).map(\.repetitions), [10, 8])
    }

    func testDurationWorkoutSavesTimeSets() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let exercise = Exercise(name: "플랭크", type: .duration, isSystem: true)
        container.mainContext.insert(exercise)

        let entry = try WorkoutStore.saveWorkout(
            exercise: exercise,
            equipmentNote: "",
            sets: [
                WorkoutSetInput(weight: nil, repetitions: nil, durationSeconds: 45, isCompleted: true),
                WorkoutSetInput(weight: nil, repetitions: nil, durationSeconds: 60, isCompleted: true),
            ],
            in: container.mainContext
        )

        XCTAssertEqual(entry.setCount, 2)
        XCTAssertEqual(WorkoutStore.sortedSets(for: entry).map(\.durationSeconds), [45, 60])
        XCTAssertTrue(WorkoutStore.sortedSets(for: entry).allSatisfy(\.isCompleted))
    }

    func testEquipmentNoteAndDetailDataPersistThroughFetch() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let exercise = Exercise(name: "레그프레스", type: .weightReps, isSystem: true)
        container.mainContext.insert(exercise)

        let saved = try WorkoutStore.saveWorkout(
            exercise: exercise,
            equipmentNote: "의자 4, 발판 중간",
            sets: [WorkoutSetInput(weight: 120, repetitions: 12, durationSeconds: nil, isCompleted: true)],
            in: container.mainContext
        )

        let fetched = try WorkoutStore.entries(in: container.mainContext).first
        XCTAssertEqual(fetched?.id, saved.id)
        XCTAssertEqual(fetched?.equipmentNote, "의자 4, 발판 중간")
        XCTAssertEqual(fetched?.exercise?.name, "레그프레스")
        XCTAssertEqual(WorkoutStore.sortedSets(for: try XCTUnwrap(fetched)).first?.weight, 120)
    }

    func testRecentEntryUsesSameExerciseOnlyAndCanCopySetDrafts() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let bench = Exercise(name: "벤치프레스", type: .weightReps, isSystem: true)
        let squat = Exercise(name: "스쿼트", type: .weightReps, isSystem: true)
        container.mainContext.insert(bench)
        container.mainContext.insert(squat)

        _ = try WorkoutStore.saveWorkout(
            exercise: bench,
            performedOn: date(year: 2026, month: 5, day: 1),
            equipmentNote: "old",
            sets: [WorkoutSetInput(weight: 50, repetitions: 10, durationSeconds: nil, isCompleted: true)],
            in: container.mainContext
        )
        let latestBench = try WorkoutStore.saveWorkout(
            exercise: bench,
            performedOn: date(year: 2026, month: 5, day: 3),
            equipmentNote: "rack 2",
            sets: [WorkoutSetInput(weight: 70, repetitions: 5, durationSeconds: nil, isCompleted: true)],
            in: container.mainContext
        )
        _ = try WorkoutStore.saveWorkout(
            exercise: squat,
            performedOn: date(year: 2026, month: 5, day: 4),
            equipmentNote: "other",
            sets: [WorkoutSetInput(weight: 100, repetitions: 5, durationSeconds: nil, isCompleted: true)],
            in: container.mainContext
        )

        let recent = try WorkoutStore.recentEntry(for: bench, in: container.mainContext)
        XCTAssertEqual(recent?.id, latestBench.id)
        XCTAssertEqual(recent?.equipmentNote, "rack 2")
        XCTAssertEqual(WorkoutStore.draftSets(from: try XCTUnwrap(recent)), [
            WorkoutSetInput(weight: 70, repetitions: 5, durationSeconds: nil, isCompleted: false),
        ])
    }

    func testDateCanBeChangedAndMultipleEntriesShareDateSession() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let bench = Exercise(name: "벤치프레스", type: .weightReps, isSystem: true)
        let plank = Exercise(name: "플랭크", type: .duration, isSystem: true)
        container.mainContext.insert(bench)
        container.mainContext.insert(plank)
        let pastDate = date(year: 2026, month: 4, day: 20)

        _ = try WorkoutStore.saveWorkout(
            exercise: bench,
            performedOn: pastDate,
            equipmentNote: "",
            sets: [WorkoutSetInput(weight: 60, repetitions: 10, durationSeconds: nil, isCompleted: true)],
            in: container.mainContext
        )
        _ = try WorkoutStore.saveWorkout(
            exercise: plank,
            performedOn: pastDate,
            equipmentNote: "",
            sets: [WorkoutSetInput(weight: nil, repetitions: nil, durationSeconds: 60, isCompleted: true)],
            in: container.mainContext
        )

        let entries = try WorkoutStore.entries(on: pastDate, in: container.mainContext)
        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(Set(entries.compactMap { $0.exercise?.name }), ["벤치프레스", "플랭크"])
        XCTAssertTrue(entries.allSatisfy { Calendar.current.isDate($0.session?.performedOn ?? Date.distantPast, inSameDayAs: pastDate) })
    }

    func testPreviousEntryNavigationUsesSameExerciseInDateOrder() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let bench = Exercise(name: "벤치프레스", type: .weightReps, isSystem: true)
        let squat = Exercise(name: "스쿼트", type: .weightReps, isSystem: true)
        container.mainContext.insert(bench)
        container.mainContext.insert(squat)

        let oldest = try saveSingleSet(exercise: bench, day: 1, in: container.mainContext)
        let middle = try saveSingleSet(exercise: bench, day: 2, in: container.mainContext)
        let newest = try saveSingleSet(exercise: bench, day: 3, in: container.mainContext)
        _ = try saveSingleSet(exercise: squat, day: 4, in: container.mainContext)

        XCTAssertEqual(try WorkoutStore.previousEntry(before: newest, in: container.mainContext)?.id, middle.id)
        XCTAssertEqual(try WorkoutStore.previousEntry(before: middle, in: container.mainContext)?.id, oldest.id)
        XCTAssertNil(try WorkoutStore.previousEntry(before: oldest, in: container.mainContext))
    }

    private func saveSingleSet(exercise: Exercise, day: Int, in context: ModelContext) throws -> WorkoutEntry {
        try WorkoutStore.saveWorkout(
            exercise: exercise,
            performedOn: date(year: 2026, month: 5, day: day),
            equipmentNote: "day \(day)",
            sets: [WorkoutSetInput(weight: Double(day * 10), repetitions: day, durationSeconds: nil, isCompleted: true)],
            in: context
        )
    }

    private func fetchExercises(from context: ModelContext) throws -> [Exercise] {
        try context.fetch(FetchDescriptor<Exercise>())
    }

    private func date(year: Int, month: Int, day: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: day)) ?? Date()
    }
}
