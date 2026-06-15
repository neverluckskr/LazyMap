import SwiftUI

@main
struct LazyMapApp: App {
    @StateObject private var theme = ThemeManager()
    @StateObject private var location = LocationManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(theme)
                .environmentObject(location)
                .preferredColorScheme(theme.preference.colorScheme)
        }
    }
}
