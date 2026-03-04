import SwiftUI
import AppKit
import CodingPlanStatusCore

@main
struct CodingPlanStatusApp: App {
    @StateObject private var appState = AppState.makeDefault()

    var body: some Scene {
        MenuBarExtra("Coding Plan", systemImage: iconName) {
            MenuBarContentView(appState: appState)
                .onAppear {
                    appState.start()
                }
        }
        .menuBarExtraStyle(.window)
    }

    private var iconName: String {
        AppTheme.menuBarSymbol(StatusAggregator.overallSeverity(from: appState.latestStatuses))
    }
}
