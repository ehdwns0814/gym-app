import SwiftData
import SwiftUI

struct HomeView: View {
    @Query(sort: \Exercise.name, order: .forward) private var exercises: [Exercise]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if exercises.isEmpty {
                        ContentUnavailableView(
                            "운동 목록 준비 중",
                            systemImage: "dumbbell",
                            description: Text("기본 운동 목록을 불러오고 있습니다.")
                        )
                    } else {
                        ForEach(exercises) { exercise in
                            ExerciseRow(exercise: exercise)
                        }
                    }
                } header: {
                    Text("기본 운동")
                }
            }
            .navigationTitle("운동 기록")
        }
    }
}

private struct ExerciseRow: View {
    let exercise: Exercise

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: exercise.type == .duration ? "timer" : "dumbbell")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(exercise.name)
                    .font(.headline)
                Text(exercise.type.displayName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    let container = try! AppModelContainer.make(inMemory: true)
    ExerciseSeederPreview.seed(in: container.mainContext)
    return HomeView()
        .modelContainer(container)
}

@MainActor
private enum ExerciseSeederPreview {
    static func seed(in context: ModelContext) {
        for defaultExercise in DefaultExercises.all {
            context.insert(
                Exercise(
                    seedKey: defaultExercise.seedKey,
                    name: defaultExercise.name,
                    type: defaultExercise.type,
                    isSystem: true
                )
            )
        }
    }
}
