import SwiftUI
#if DEBUG
import ShotKit
#endif

@main
struct BookGateApp: App {
    @State private var services = AppServices()

    var body: some Scene {
        WindowGroup {
            #if DEBUG
            // Screenshot mode (ShotKit): the harness replaces the app's root, so nothing live
            // starts — no alarms scheduled, no permissions asked, no shield raised. Release
            // builds have none of this.
            if ShotMode.active {
                if ShotMode.storeFrames {
                    storeFrames
                } else {
                    ShotRunner { screen in ShotHost(screen: screen) }
                }
            } else {
                RootView(services: services)
            }
            #else
            RootView(services: services)
            #endif
        }
    }

    #if DEBUG
    @ViewBuilder
    private var storeFrames: some View {
        if let config = try? StoreFrameConfig.load(from: ShotSource.captionsURL) {
            StoreFrameRunner(config: config, style: .bookGate) { source in
                ShotSource.image(named: source)
            }
        } else {
            // A missing or malformed caption file must not render an empty set that looks fine in
            // a folder — leave the screen blank so ShotKit's blank check fails the run.
            Color.black
        }
    }
    #endif
}
