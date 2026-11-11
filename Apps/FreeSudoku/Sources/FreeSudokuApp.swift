import SwiftUI

@main
struct FreeSudokuApp: App {
    @StateObject private var model = GameModel()
    @AppStorage("appearance") private var appearance = AppAppearance.system

    var body: some Scene {
        WindowGroup {
            GameView(model: model)
                .preferredColorScheme(appearance.colorScheme)
        }
    }
}
