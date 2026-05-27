import Foundation

struct DefaultExercise: Identifiable, Equatable {
    let seedKey: String
    let name: String
    let type: ExerciseType

    var id: String { seedKey }
}

enum DefaultExercises {
    static let all: [DefaultExercise] = [
        DefaultExercise(seedKey: "bench_press", name: "벤치프레스", type: .weightReps),
        DefaultExercise(seedKey: "squat", name: "스쿼트", type: .weightReps),
        DefaultExercise(seedKey: "deadlift", name: "데드리프트", type: .weightReps),
        DefaultExercise(seedKey: "lat_pulldown", name: "랫풀다운", type: .weightReps),
        DefaultExercise(seedKey: "leg_press", name: "레그프레스", type: .weightReps),
        DefaultExercise(seedKey: "shoulder_press", name: "숄더프레스", type: .weightReps),
        DefaultExercise(seedKey: "plank", name: "플랭크", type: .duration),
    ]
}
