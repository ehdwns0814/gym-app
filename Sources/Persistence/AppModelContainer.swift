import SwiftData

enum AppModelContainer {
    @MainActor
    static func make(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema([
            Exercise.self,
            WorkoutSession.self,
            WorkoutEntry.self,
            SetEntry.self,
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
