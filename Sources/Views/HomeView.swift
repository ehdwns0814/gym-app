import SwiftData
import SwiftUI

struct HomeView: View {
    @Query(sort: \Exercise.name, order: .forward) private var exercises: [Exercise]
    @Query(sort: \WorkoutSession.performedOn, order: .reverse) private var sessions: [WorkoutSession]

    private var recentEntries: [WorkoutEntry] {
        sessions
            .flatMap(\.entries)
            .sorted {
                let lhsDate = $0.session?.performedOn ?? $0.createdAt
                let rhsDate = $1.session?.performedOn ?? $1.createdAt
                if lhsDate == rhsDate {
                    return $0.createdAt > $1.createdAt
                }
                return lhsDate > rhsDate
            }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("최근 기록") {
                    if recentEntries.isEmpty {
                        ContentUnavailableView(
                            "저장된 기록 없음",
                            systemImage: "calendar.badge.clock",
                            description: Text("운동 종목을 선택해 첫 기록을 저장하세요.")
                        )
                    } else {
                        ForEach(recentEntries) { entry in
                            NavigationLink {
                                WorkoutDetailView(entry: entry)
                            } label: {
                                WorkoutEntryRow(entry: entry)
                            }
                        }
                    }
                }

                Section("운동 종목") {
                    if exercises.isEmpty {
                        ContentUnavailableView(
                            "운동 목록 준비 중",
                            systemImage: "dumbbell",
                            description: Text("기본 운동 목록을 불러오고 있습니다.")
                        )
                    } else {
                        ForEach(exercises) { exercise in
                            NavigationLink {
                                WorkoutEntryEditorView(exercise: exercise)
                            } label: {
                                ExerciseRow(exercise: exercise)
                            }
                        }
                    }
                }
            }
            .navigationTitle("운동 기록")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        ExerciseManagementView()
                    } label: {
                        Label("운동 관리", systemImage: "list.bullet.clipboard")
                    }
                }
            }
        }
    }
}

private struct WorkoutEntryRow: View {
    let entry: WorkoutEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(entry.exercise?.name ?? "운동 기록")
                    .font(.headline)
                Spacer()
                Text(DateFormatters.day.string(from: entry.session?.performedOn ?? entry.createdAt))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Text("\(entry.setCount)세트")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
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

struct ExerciseManagementView: View {
    @Query(sort: \Exercise.name, order: .forward) private var exercises: [Exercise]
    @State private var sheet: ExerciseEditSheet?

    var body: some View {
        List {
            Section("운동 종목") {
                ForEach(exercises) { exercise in
                    Button {
                        sheet = .edit(exercise)
                    } label: {
                        HStack {
                            ExerciseRow(exercise: exercise)
                            Spacer()
                            if exercise.isSystem {
                                Text("기본")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .navigationTitle("운동 관리")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    sheet = .add
                } label: {
                    Label("운동 추가", systemImage: "plus")
                }
            }
        }
        .sheet(item: $sheet) { sheet in
            switch sheet {
            case .add:
                ExerciseFormView(exercise: nil)
            case .edit(let exercise):
                ExerciseFormView(exercise: exercise)
            }
        }
    }
}

private enum ExerciseEditSheet: Identifiable {
    case add
    case edit(Exercise)

    var id: String {
        switch self {
        case .add:
            "add"
        case .edit(let exercise):
            exercise.id.uuidString
        }
    }
}

private struct ExerciseFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let exercise: Exercise?
    @State private var name: String
    @State private var type: ExerciseType
    @State private var errorMessage: String?

    init(exercise: Exercise?) {
        self.exercise = exercise
        _name = State(initialValue: exercise?.name ?? "")
        _type = State(initialValue: exercise?.type ?? .weightReps)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("운동 정보") {
                    TextField("운동 이름", text: $name)
                    Picker("운동 타입", selection: $type) {
                        ForEach(ExerciseType.allCases) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(exercise == nil ? "운동 추가" : "운동 수정")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        save()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func save() {
        do {
            if let exercise {
                try WorkoutStore.updateExercise(exercise, name: name, type: type, in: modelContext)
            } else {
                _ = try WorkoutStore.addExercise(name: name, type: type, in: modelContext)
            }
            dismiss()
        } catch {
            errorMessage = "운동 종목을 저장하지 못했습니다."
        }
    }
}

struct WorkoutEntryEditorView: View {
    @Environment(\.modelContext) private var modelContext

    let exercise: Exercise
    @State private var performedOn = Date()
    @State private var equipmentNote = ""
    @State private var sets: [WorkoutSetDraft]
    @State private var recentEntry: WorkoutEntry?
    @State private var savedEntry: WorkoutEntry?
    @State private var errorMessage: String?

    init(exercise: Exercise) {
        self.exercise = exercise
        _sets = State(initialValue: [WorkoutSetDraft(type: exercise.type)])
    }

    var body: some View {
        Form {
            Section("기록 날짜") {
                DatePicker("운동 날짜", selection: $performedOn, displayedComponents: .date)
            }

            if let recentEntry {
                Section("최근 기록") {
                    RecentRecordSummary(entry: recentEntry)
                    Button("지난 세트 복사") {
                        sets = WorkoutStore.draftSets(from: recentEntry).map { WorkoutSetDraft(input: $0, type: exercise.type) }
                    }
                }
            } else {
                Section("최근 기록") {
                    Text("이 운동의 이전 기록이 없습니다.")
                        .foregroundStyle(.secondary)
                }
            }

            Section("세트") {
                ForEach($sets) { $set in
                    WorkoutSetEditorRow(type: exercise.type, set: $set)
                }
                .onDelete { offsets in
                    sets.remove(atOffsets: offsets)
                }

                Button {
                    sets.append(WorkoutSetDraft(type: exercise.type))
                } label: {
                    Label("세트 추가", systemImage: "plus")
                }
            }

            Section("기구 세팅 메모") {
                TextEditor(text: $equipmentNote)
                    .frame(minHeight: 88)
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }

            Section {
                Button {
                    save()
                } label: {
                    Label("저장", systemImage: "checkmark.circle")
                }
                .disabled(validSetInputs.isEmpty)

                if let savedEntry {
                    NavigationLink {
                        WorkoutDetailView(entry: savedEntry)
                    } label: {
                        Label("저장된 기록 보기", systemImage: "doc.text.magnifyingglass")
                    }
                }
            }
        }
        .navigationTitle(exercise.name)
        .task {
            loadRecentEntry()
        }
    }

    private var validSetInputs: [WorkoutSetInput] {
        sets.compactMap { $0.input(for: exercise.type) }
    }

    private func loadRecentEntry() {
        recentEntry = try? WorkoutStore.recentEntry(for: exercise, in: modelContext)
    }

    private func save() {
        do {
            let entry = try WorkoutStore.saveWorkout(
                exercise: exercise,
                performedOn: performedOn,
                equipmentNote: equipmentNote,
                sets: validSetInputs,
                in: modelContext
            )
            savedEntry = entry
            errorMessage = nil
            loadRecentEntry()
        } catch {
            errorMessage = "운동 기록을 저장하지 못했습니다."
        }
    }
}

private struct WorkoutSetDraft: Identifiable {
    let id = UUID()
    var weightText: String
    var repetitionsText: String
    var durationText: String
    var isCompleted: Bool

    init(type: ExerciseType) {
        weightText = ""
        repetitionsText = ""
        durationText = ""
        isCompleted = false
    }

    init(input: WorkoutSetInput, type: ExerciseType) {
        weightText = input.weight.map { Self.numberFormatter.string(from: NSNumber(value: $0)) ?? "\($0)" } ?? ""
        repetitionsText = input.repetitions.map(String.init) ?? ""
        durationText = input.durationSeconds.map(String.init) ?? ""
        isCompleted = input.isCompleted
    }

    func input(for type: ExerciseType) -> WorkoutSetInput? {
        switch type {
        case .weightReps:
            guard let weight = Double(weightText), let repetitions = Int(repetitionsText) else { return nil }
            return WorkoutSetInput(weight: weight, repetitions: repetitions, durationSeconds: nil, isCompleted: isCompleted)
        case .duration:
            guard let durationSeconds = Int(durationText) else { return nil }
            return WorkoutSetInput(weight: nil, repetitions: nil, durationSeconds: durationSeconds, isCompleted: isCompleted)
        }
    }

    fileprivate static let numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        return formatter
    }()
}

private struct WorkoutSetEditorRow: View {
    let type: ExerciseType
    @Binding var set: WorkoutSetDraft

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            switch type {
            case .weightReps:
                HStack {
                    TextField("무게", text: $set.weightText)
                        .keyboardType(.decimalPad)
                    Text("kg")
                        .foregroundStyle(.secondary)
                    TextField("횟수", text: $set.repetitionsText)
                        .keyboardType(.numberPad)
                    Text("회")
                        .foregroundStyle(.secondary)
                }
            case .duration:
                HStack {
                    TextField("시간", text: $set.durationText)
                        .keyboardType(.numberPad)
                    Text("초")
                        .foregroundStyle(.secondary)
                }
            }

            Toggle("완료", isOn: $set.isCompleted)
        }
        .padding(.vertical, 4)
    }
}

private struct RecentRecordSummary: View {
    let entry: WorkoutEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(DateFormatters.day.string(from: entry.session?.performedOn ?? entry.createdAt))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ForEach(WorkoutStore.sortedSets(for: entry)) { set in
                Text(SetEntryFormatter.summary(for: set, type: entry.exercise?.type ?? .weightReps))
                    .font(.subheadline)
            }

            if !entry.equipmentNote.isEmpty {
                Text(entry.equipmentNote)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct WorkoutDetailView: View {
    @Environment(\.modelContext) private var modelContext

    let entry: WorkoutEntry
    @State private var previousEntry: WorkoutEntry?
    @State private var didLoadPrevious = false

    var body: some View {
        List {
            Section("기록") {
                LabeledContent("날짜", value: DateFormatters.day.string(from: entry.session?.performedOn ?? entry.createdAt))
                LabeledContent("운동", value: entry.exercise?.name ?? "운동 기록")
                LabeledContent("세트 수", value: "\(entry.setCount)")
            }

            Section("세트별 기록") {
                ForEach(WorkoutStore.sortedSets(for: entry)) { set in
                    HStack {
                        Text(SetEntryFormatter.summary(for: set, type: entry.exercise?.type ?? .weightReps))
                        Spacer()
                        Text(set.isCompleted ? "완료" : "미완료")
                            .foregroundStyle(set.isCompleted ? .green : .secondary)
                    }
                }
            }

            Section("기구 세팅 메모") {
                if entry.equipmentNote.isEmpty {
                    Text("저장된 메모가 없습니다.")
                        .foregroundStyle(.secondary)
                } else {
                    Text(entry.equipmentNote)
                }
            }

            Section("이전 기록") {
                if let previousEntry {
                    NavigationLink {
                        WorkoutDetailView(entry: previousEntry)
                    } label: {
                        WorkoutEntryRow(entry: previousEntry)
                    }
                } else if didLoadPrevious {
                    Text("이전 기록이 없습니다.")
                        .foregroundStyle(.secondary)
                } else {
                    ProgressView()
                }
            }
        }
        .navigationTitle(entry.exercise?.name ?? "기록 상세")
        .task(id: entry.id) {
            previousEntry = try? WorkoutStore.previousEntry(before: entry, in: modelContext)
            didLoadPrevious = true
        }
    }
}

private enum SetEntryFormatter {
    static func summary(for set: SetEntry, type: ExerciseType) -> String {
        switch type {
        case .weightReps:
            let weight = set.weight.map { WorkoutSetDraft.numberFormatter.string(from: NSNumber(value: $0)) ?? "\($0)" } ?? "-"
            let repetitions = set.repetitions.map(String.init) ?? "-"
            return "\(weight)kg x \(repetitions)회"
        case .duration:
            let duration = set.durationSeconds.map(String.init) ?? "-"
            return "\(duration)초"
        }
    }
}

private enum DateFormatters {
    static let day: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
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
