import SwiftUI

/// Full-screen container for the night flow (alarm → gate → settle → session → complete → takeaway
/// → step-up). **Always dark**, regardless of theme — a white screen at 9pm defeats the product.
/// Screen changes cross-fade.
struct NightFlowView: View {
    @Environment(AppServices.self) private var services

    var body: some View {
        let session = services.session
        ZStack {
            switch session.phase {
            case .ringing:  AlarmRingingView()
            case .gate:     CameraGateView()
            case .settle:   PostScanSettleView()
            case .session:  SessionView()
            case .complete: CompleteView()
            case .takeaway: TakeawayRecorderView()
            case .stepup:   StepUpView()
            case .idle:     Color.clear
            }
        }
        .animation(.easeInOut(duration: 0.5), value: session.phase)
        .nightFlow()
    }
}
