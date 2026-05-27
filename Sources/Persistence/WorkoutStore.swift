import Foundation
import SwiftData

struct WorkoutSetInput: Equatable {
    var weight: Double?
    var repetitions: Int?
    var durationSeconds: Int?
    var isCompleted: Bool
}

@MainActor
enum WorkoutStore {
    static func addExercise(name: String, type: ExerciseType, in context: ModelContext) throws -> Exercise {
        let exercise = Exercise(name: name.trimmingCharacters(in: .whitespacesAndNewlines), type: type, isSystem: false)
        context.insert(exercise)
        try context.save()
        return exercise
    }

    static func updateExercise(_ exercise: Exercise, name: String, type: ExerciseType, in context: ModelContext) throws {
        exercise.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        exercise.type = type
        exercise.updatedAt = Date()
        try context.save()
    }

    static func saveWorkout(
        exercise: Exercise,
        performedOn: Date = Date(),
        equipmentNote: String,
        sets: [WorkoutSetInput],
        in context: ModelContext
    ) throws -> WorkoutEntry {
        let session = try session(on: performedOn, in: context)
        let entry = WorkoutEntry(equipmentNote: equipmentNote, exercise: exercise)
        context.insert(entry)
        session.entries.append(entry)

        for (index, input) in sets.enumerated() {
            let setEntry = SetEntry(
                weight: input.weight,
                repetitions: input.repetitions,
                durationSeconds: input.durationSeconds,
                isCompleted: input.isCompleted,
                position: index
            )
            context.insert(setEntry)
            entry.sets.append(setEntry)
        }

        session.performedOn = performedOn
        session.updatedAt = Date()
        entry.updatedAt = Date()
        try context.save()
        return entry
    }

    static func session(on date: Date, in context: ModelContext) throws -> WorkoutSession {
        let sessions = try context.fetch(FetchDescriptor<WorkoutSession>())
        if let existing = sessions.first(where: { Calendar.current.isDate($0.performedOn, inSameDayAs: date) }) {
            return existing
        }

        let session = WorkoutSession(performedOn: date)
        context.insert(session)
        return session
    }

    static func entries(in context: ModelContext) throws -> [WorkoutEntry] {
        let entries = try context.fetch(FetchDescriptor<WorkoutEntry>())
        return sortNewestFirst(entries)
    }

    static func entries(on date: Date, in context: ModelContext) throws -> [WorkoutEntry] {
        try entries(in: context).filter { entry in
            guard let performedOn = entry.session?.performedOn else { return false }
            return Calendar.current.isDate(performedOn, inSameDayAs: date)
        }
    }

    static func recentEntry(for exercise: Exercise, in context: ModelContext) throws -> WorkoutEntry? {
        try entries(in: context).first { $0.exercise?.id == exercise.id }
    }

    static func previousEntry(before entry: WorkoutEntry, in context: ModelContext) throws -> WorkoutEntry? {
        guard let exerciseID = entry.exercise?.id else { return nil }
        let sorted = try entries(in: context).filter { $0.exercise?.id == exerciseID }
        guard let index = sorted.firstIndex(where: { $0.id == entry.id }) else { return nil }
        let nextIndex = sorted.index(after: index)
        return nextIndex < sorted.endIndex ? sorted[nextIndex] : nil
    }

    static func draftSets(from entry: WorkoutEntry) -> [WorkoutSetInput] {
        sortedSets(for: entry).map {
            WorkoutSetInput(
                weight: $0.weight,
                repetitions: $0.repetitions,
                durationSeconds: $0.durationSeconds,
                isCompleted: false
            )
        }
    }

    static func sortedSets(for entry: WorkoutEntry) -> [SetEntry] {
        entry.sets.sorted {
            if $0.position == $1.position {
                return $0.createdAt < $1.createdAt
            }
            return $0.position < $1.position
        }
    }

    private static func sortNewestFirst(_ entries: [WorkoutEntry]) -> [WorkoutEntry] {
        entries.sorted {
            let lhsDate = $0.session?.performedOn ?? $0.createdAt
            let rhsDate = $1.session?.performedOn ?? $1.createdAt
            if lhsDate == rhsDate {
                return $0.createdAt > $1.createdAt
            }
            return lhsDate > rhsDate
        }
    }
}
