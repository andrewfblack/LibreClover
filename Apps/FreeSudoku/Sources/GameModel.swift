import Foundation
import FreeSudokuCore

@MainActor
final class GameModel: ObservableObject {
    @Published private(set) var game: Game?
    @Published private(set) var statistics = Statistics()
    @Published private(set) var isLoading = true
    @Published var selected: Int?
    @Published var notesMode = false
    @Published var paused = false
    @Published var errorMessage: String?
    @Published private(set) var recoveryNeeded = false
    private let store: SessionStore

    init() {
        let saveURL = URL.applicationSupportDirectory
            .appendingPathComponent("FreeSudoku", isDirectory: true)
            .appendingPathComponent("session.json")
        store = SessionStore(url: saveURL)
        Task { await restore() }
    }

    private func restore() async {
        let store = self.store
        do {
            let saved = try await Task.detached(priority: .userInitiated) { () -> SavedSession? in
                try store.load()
            }.value
            game = saved?.game
            statistics = saved?.statistics ?? Statistics()
            // Resume deliberately, rather than starting the timer behind first-run help.
            paused = game != nil && game?.isComplete == false
        } catch {
            recoveryNeeded = true
            errorMessage =
                "Your saved game could not be opened. It has not been overwritten. You can retry loading it or explicitly replace it with a new game."
        }
        isLoading = false
    }

    func retryRestore() async {
        errorMessage = nil
        isLoading = true
        recoveryNeeded = false
        await restore()
    }

    func start(_ difficulty: Difficulty) async {
        guard !isLoading else { return }
        isLoading = true
        let puzzle = await Task.detached(priority: .userInitiated) {
            Puzzle.generate(difficulty: difficulty)
        }.value
        game = Game(puzzle: puzzle)
        selected = puzzle.clues.firstIndex(of: 0)
        notesMode = false
        paused = false
        recoveryNeeded = false
        isLoading = false
        persist()
    }

    func enter(_ value: Int) {
        guard playable, let selected else { return }
        game?.enter(value, at: selected, asNote: notesMode)
        changed()
    }

    func erase() {
        guard playable, let selected else { return }
        game?.erase(at: selected)
        changed()
    }

    func undo() {
        guard playable else { return }
        game?.undo()
        changed()
    }

    func redo() {
        guard playable else { return }
        game?.redo()
        changed()
    }

    func hint() {
        guard playable else { return }
        selected = game?.hint(at: selected)
        changed()
    }

    var playable: Bool { game != nil && game?.isComplete == false && !paused && !isLoading }

    func tick() {
        guard playable else { return }
        game?.tick()
        // Changes and lifecycle events save immediately; the timer checkpoints every 10 seconds.
        if let seconds = game?.elapsedSeconds, seconds % 10 == 0 { persist() }
    }

    func pause() {
        paused = true
        persist()
    }

    private func changed() {
        if let game, game.isComplete { statistics.record(game) }
        persist()
    }

    func persist() {
        guard !recoveryNeeded, let game else { return }
        do {
            try store.save(SavedSession(game: game, statistics: statistics))
        } catch {
            errorMessage = "Your latest progress could not be saved. Keep the app open and try saving again."
        }
    }
}
