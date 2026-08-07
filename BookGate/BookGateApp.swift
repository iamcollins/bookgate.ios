import SwiftUI

@main
struct BookGateApp: App {
    @State private var services = AppServices()

    var body: some Scene {
        WindowGroup {
            RootView(services: services)
        }
    }
}
