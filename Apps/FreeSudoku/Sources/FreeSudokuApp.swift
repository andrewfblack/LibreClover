import SwiftUI

@main
struct FreeSudokuApp: App {
    @StateObject private var model = GameModel()

    var body: some Scene {
        WindowGroup {
            GameView(model: model)
        }
    }
}
