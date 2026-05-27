import SwiftData
import SwiftUI

@main
struct GymApp: App {
    private let modelContainer: ModelContainer

    init() {
        do {
            modelContainer = try AppModelContainer.make()
        } catch {
            fatalError("Failed to create model container: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            HomeView()
                .task {
                    await ExerciseSeeder.seedDefaultExercises(in: modelContainer.mainContext)
                }
        }
        .modelContainer(modelContainer)
    }
}
