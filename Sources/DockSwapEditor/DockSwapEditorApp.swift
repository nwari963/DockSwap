import SwiftUI

@main
struct DockSwapEditorApp: App {
    var body: some Scene {
        WindowGroup {
            PresetListView()
        }
        .windowResizability(.contentSize)
    }
}
