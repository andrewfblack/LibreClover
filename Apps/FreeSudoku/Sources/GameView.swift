import Combine
import FreeSudokuCore
import SwiftUI

struct GameView: View {
    @ObservedObject var model: GameModel
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @AppStorage("hasSeenWelcome") private var hasSeenWelcome = false
    @AppStorage("showMistakes") private var showMistakes = false
    @State private var showHelp = false
    @State private var showSettings = false
    @State private var pendingDifficulty: Difficulty?
    @State private var confirmNewGame = false
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ScrollView {
                    VStack(spacing: 20) {
                        if model.isLoading {
                            ProgressView("Preparing your puzzle…")
                                .padding(60)
                        } else if let game = model.game {
                            status(game)
                            if model.paused && !game.isComplete {
                                ContentUnavailableView {
                                    Label("Take your time", systemImage: "pause.circle")
                                } description: {
                                    Text("Your puzzle is saved on this device.")
                                } actions: {
                                    Button("Resume puzzle") { model.paused = false }
                                        .buttonStyle(.borderedProminent)
                                        .foregroundStyle(Color(uiColor: .systemBackground))
                                }
                            } else {
                                playArea(game, wide: geometry.size.width >= 800 && !dynamicTypeSize.isAccessibilitySize)
                                if game.isComplete {
                                    Label("Puzzle complete!", systemImage: "checkmark.seal.fill")
                                        .font(.title2.bold()).foregroundStyle(.green)
                                    Text("\(game.hintsUsed) hints used. Choose New puzzle to play again.")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        } else {
                            ContentUnavailableView(
                                "A little focus. A fresh puzzle.", systemImage: "square.grid.3x3",
                                description: Text("Choose New puzzle below to begin. Everything stays on this device."))
                            if model.recoveryNeeded {
                                Button("Retry loading saved game") { Task { await model.retryRestore() } }
                            }
                        }
                        newGameMenu
                        Text("No ads. No accounts. Just Sudoku.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: geometry.size.width >= 800 && !dynamicTypeSize.isAccessibilitySize ? 1060 : 620)
                    .frame(maxWidth: .infinity)
                }
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("FreeSudoku")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("How to play", systemImage: "questionmark.circle") {
                        showHelp = true
                        model.pause()
                    }
                    .labelStyle(.iconOnly)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Settings and statistics", systemImage: "gearshape") {
                        showSettings = true
                        model.pause()
                    }
                    .labelStyle(.iconOnly)
                }
            }
            .sheet(isPresented: $showHelp, onDismiss: { hasSeenWelcome = true }) { help }
            .sheet(isPresented: $showSettings) { settings }
            .confirmationDialog("Replace your saved puzzle?", isPresented: $confirmNewGame, titleVisibility: .visible) {
                Button("Replace with new puzzle", role: .destructive) {
                    if let difficulty = pendingDifficulty { Task { await model.start(difficulty) } }
                }
            } message: {
                Text("This replaces the current puzzle, including any saved game that could not be loaded.")
            }
            .alert(
                "Save notice",
                isPresented: Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })
            ) {
                Button("OK", role: .cancel) { model.errorMessage = nil }
                if model.game != nil { Button("Retry saving") { model.persist() } }
            } message: {
                Text(model.errorMessage ?? "")
            }
            .onAppear { if !hasSeenWelcome { showHelp = true } }
            .onReceive(timer) { _ in
                if scenePhase == .active && !showHelp && !showSettings { model.tick() }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase != .active { model.pause() }
            }
        }
    }

    private func status(_ game: Game) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack {
                difficultyLabel(game)
                Spacer()
                timerControls(game)
            }.fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 12) {
                difficultyLabel(game)
                timerControls(game)
            }
        }
    }

    private func difficultyLabel(_ game: Game) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(game.puzzle.difficulty.title).font(.title2.bold())
            Text("\(game.puzzle.clues.filter { $0 != 0 }.count) starting clues")
                .font(.caption).foregroundStyle(.secondary)
        }.fixedSize(horizontal: false, vertical: true)
    }

    private func timerControls(_ game: Game) -> some View {
        HStack(spacing: 16) {
            Text(time(game.elapsedSeconds)).monospacedDigit()
                .accessibilityLabel(
                    "Elapsed time, \(game.elapsedSeconds / 60) minutes, \(game.elapsedSeconds % 60) seconds")
            if !game.isComplete {
                Button {
                    if model.paused { model.paused = false } else { model.pause() }
                } label: {
                    Label(model.paused ? "Resume" : "Pause", systemImage: model.paused ? "play.fill" : "pause.fill")
                        .labelStyle(.iconOnly).frame(minWidth: 44, minHeight: 44)
                }
            }
        }.fixedSize(horizontal: true, vertical: true)
    }

    @ViewBuilder private func playArea(_ game: Game, wide: Bool) -> some View {
        if wide {
            HStack(alignment: .top, spacing: 24) {
                SudokuBoard(game: game, selected: $model.selected, showMistakes: showMistakes)
                    .frame(maxWidth: 600)
                if !game.isComplete { playControls(game).frame(width: 280) }
            }
        } else {
            VStack(spacing: 16) {
                SudokuBoard(game: game, selected: $model.selected, showMistakes: showMistakes)
                if !game.isComplete { playControls(game) }
            }
        }
    }

    private func playControls(_ game: Game) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            if let selected = model.selected {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Row \(selected / 9 + 1) · Column \(selected % 9 + 1)").font(.headline)
                    if game.puzzle.clues[selected] != 0 {
                        Text("Starting clue: \(game.board.values[selected])")
                    } else if game.board.values[selected] != 0 {
                        Text("Your digit: \(game.board.values[selected])")
                    } else {
                        let notes = game.board.notes[selected].sorted().map(String.init).joined(separator: ", ")
                        Text(notes.isEmpty ? "Empty cell" : "Notes: \(notes)")
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("selectedCellDetails")
            } else {
                Text("Select an empty cell to begin.").foregroundStyle(.secondary)
            }
            controls
        }
    }

    private var controls: some View {
        VStack(spacing: 14) {
            LazyVGrid(
                columns: Array(
                    repeating: GridItem(.flexible(), spacing: 6), count: dynamicTypeSize.isAccessibilitySize ? 3 : 5),
                spacing: 8
            ) {
                ForEach(1...9, id: \.self) { value in
                    Button {
                        model.enter(value)
                    } label: {
                        Text("\(value)").font(.title2.bold())
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.bordered).accessibilityLabel("Enter \(value)")
                    .disabled(
                        !model.playable || model.selected == nil
                            || model.game?.puzzle.clues[model.selected ?? 0] != 0)
                }
                Button {
                    model.erase()
                } label: {
                    Label("Erase", systemImage: "eraser").labelStyle(.iconOnly)
                        .frame(maxWidth: .infinity, minHeight: 44).contentShape(Rectangle())
                }.buttonStyle(.bordered)
            }
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: dynamicTypeSize.isAccessibilitySize ? 180 : 110), spacing: 8)],
                spacing: 8
            ) {
                editingTools
            }
        }.disabled(!model.playable)
    }

    @ViewBuilder private var editingTools: some View {
        Toggle(isOn: $model.notesMode) {
            Text("Notes").frame(maxWidth: .infinity, minHeight: 44)
        }.toggleStyle(.button)
            .accessibilityIdentifier("notesMode")
            .accessibilityHint("When enabled, number buttons toggle pencil notes in empty cells")
        Button {
            model.undo()
        } label: {
            Label("Undo", systemImage: "arrow.uturn.backward").frame(maxWidth: .infinity, minHeight: 44)
                .contentShape(Rectangle())
        }
        .disabled(model.game?.canUndo != true)
        Button {
            model.redo()
        } label: {
            Label("Redo", systemImage: "arrow.uturn.forward").frame(maxWidth: .infinity, minHeight: 44)
                .contentShape(Rectangle())
        }
        .disabled(model.game?.canRedo != true)
        Button {
            model.hint()
        } label: {
            Label("Hint", systemImage: "lightbulb").frame(maxWidth: .infinity, minHeight: 44)
                .contentShape(Rectangle())
        }
    }

    private var newGameMenu: some View {
        Menu {
            ForEach(Difficulty.allCases, id: \.self) { difficulty in
                Button(difficulty.title) {
                    pendingDifficulty = difficulty
                    if model.game != nil || model.recoveryNeeded {
                        confirmNewGame = true
                    } else {
                        Task { await model.start(difficulty) }
                    }
                }
            }
        } label: {
            Label("New puzzle", systemImage: "plus.circle.fill")
                .frame(maxWidth: .infinity, minHeight: 44)
                .foregroundStyle(Color(uiColor: .systemBackground))
        }
        .buttonStyle(.borderedProminent).disabled(model.isLoading)
        .accessibilityIdentifier("newPuzzle")
    }

    private var help: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("A quiet space to solve.").font(.largeTitle.bold())
                    Text("Fill every row, column and 3×3 box with the digits 1 through 9, without repeats.")
                    Text(
                        "Tap a cell, then a number. Starting clues cannot be changed. Turn on Notes to keep possible digits in an empty cell. Undo and Redo let you revisit moves."
                    )
                    Text(
                        "Hints reveal one correct digit. Mistake highlighting is optional in Settings. There are no penalties or time limits."
                    )
                    Text(
                        "The four difficulty presets use starting-clue counts, not human-solving technique ratings. Every puzzle has exactly one solution."
                    )
                    Text(
                        "Your game and statistics stay on this device. Progress saves after moves and when you pause or leave the app; the timer also saves every ten seconds."
                    )
                }.padding()
            }
            .navigationTitle("Welcome")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Let’s play") {
                        showHelp = false
                        hasSeenWelcome = true
                    }
                }
            }
        }
    }

    private var settings: some View {
        NavigationStack {
            Form {
                Section("Play your way") { Toggle("Highlight incorrect digits", isOn: $showMistakes) }
                Section("On this device") {
                    LabeledContent("Puzzles completed", value: "\(model.statistics.completed)")
                    LabeledContent(
                        "Best time (all presets, hints allowed)",
                        value: model.statistics.bestSeconds.map(time) ?? "No completed puzzles")
                }
                Section("Privacy") {
                    Text(
                        "No accounts, ads, tracking or data collection. No permissions required. Games are saved locally; deleting the app removes its data."
                    )
                }
                Section("About") {
                    Text("FreeSudoku · FreeKit\nOpen-source software under GPLv3.")
                    Text("Difficulty is based on clue density, not a technique-based rating.")
                }
            }
            .navigationTitle("Settings")
            .toolbar { Button("Done") { showSettings = false } }
        }
    }

    private func time(_ seconds: Int) -> String {
        String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}

private struct SudokuBoard: View {
    let game: Game
    @Binding var selected: Int?
    let showMistakes: Bool
    @ScaledMetric(relativeTo: .body) private var digitSize = 24

    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<9) { row in
                HStack(spacing: 0) {
                    ForEach(0..<9) { column in
                        cell(row * 9 + column)
                        if column == 2 || column == 5 { Rectangle().fill(.primary).frame(width: 2) }
                    }
                }
                if row == 2 || row == 5 { Rectangle().fill(.primary).frame(height: 2) }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .overlay(Rectangle().stroke(.primary, lineWidth: 2))
        .accessibilityIdentifier("sudokuBoard")
    }

    private func cell(_ index: Int) -> some View {
        let value = game.board.values[index]
        let fixed = game.puzzle.clues[index] != 0
        let wrong = showMistakes && value != 0 && value != game.puzzle.solution[index]
        let notes = game.board.notes[index].sorted().map(String.init).joined(separator: ", ")
        return Button {
            if !game.isComplete { selected = index }
        } label: {
            ZStack {
                Rectangle().fill(background(index))
                if value != 0 {
                    Text("\(value)")
                        .font(.system(size: min(digitSize, 36), weight: fixed ? .bold : .regular, design: .rounded))
                        .foregroundStyle(wrong ? Color.red : fixed ? Color.primary : Color.accentColor)
                        .minimumScaleFactor(0.5)
                    if wrong {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.system(size: 8)).foregroundStyle(.red)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    }
                } else {
                    VStack(spacing: 0) {
                        ForEach(0..<3) { row in
                            HStack(spacing: 0) {
                                ForEach(1...3, id: \.self) { column in
                                    let digit = row * 3 + column
                                    Text(game.board.notes[index].contains(digit) ? "\(digit)" : " ")
                                        .font(.system(size: 9)).frame(maxWidth: .infinity)
                                }
                            }
                        }
                    }.padding(2).foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .overlay(Rectangle().stroke(Color.primary.opacity(0.2), lineWidth: 0.5))
            .overlay(Rectangle().stroke(selected == index ? Color.accentColor : .clear, lineWidth: 3))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Row \(index / 9 + 1), column \(index % 9 + 1)")
        .accessibilityValue(
            value == 0
                ? "Empty\(notes.isEmpty ? "" : ", notes \(notes)")"
                : "\(value)\(fixed ? ", starting clue" : "")\(wrong ? ", incorrect" : "")"
        )
        .accessibilityAddTraits(selected == index ? [.isSelected] : [])
        .accessibilityHint(fixed ? "Starting clue, cannot be changed" : "Select, then use the number buttons")
        .accessibilityIdentifier("cell-\(index)")
    }

    private func background(_ index: Int) -> Color {
        if selected == index { return Color.accentColor.opacity(0.2) }
        if let selected, Sudoku.peers(of: selected).contains(index) { return Color.accentColor.opacity(0.07) }
        return Color(uiColor: .secondarySystemGroupedBackground)
    }
}
