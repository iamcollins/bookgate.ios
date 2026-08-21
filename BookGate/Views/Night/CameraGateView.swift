import SwiftUI
import AVFoundation

/// The nightly gate (camera). A viewfinder with a brass-cornered frame, a sweeping scan line, and
/// live hints for face / hand / book. A **manual fallback is always visible**. On detection: a
/// brass check pops, the cover name shows, then it auto-advances (capturing the journal photo).
struct CameraGateView: View {
    @Environment(AppServices.self) private var services
    @Environment(\.bgPalette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var detector = NightGateDetector()
    @State private var sweep = false
    @State private var showSuccess = false
    @State private var captured: Data?
    @State private var authDenied = false
    @State private var noCamera = false

    private var cameraUsable: Bool { !authDenied && !noCamera }

    private var session: SessionCoordinator { services.session }
    private var bookTitle: String { services.books.currentReading?.title ?? "your book" }

    var body: some View {
        ZStack {
            BGAmbientBackground(center: UnitPoint(x: 0.5, y: 0.3), showGlow: false)
            VStack(spacing: 22) {
                header
                viewfinder
                if cameraUsable { hints }
                Spacer(minLength: 0)
                manualFallback
            }
            .padding(.horizontal, 26)
            .padding(.top, 64)
            .padding(.bottom, 40)

            if showSuccess { successOverlay }
        }
        .task {
            let status = await CameraAccess.request()
            authDenied = (status == .denied || status == .restricted)
            noCamera = !CameraAccess.hasCamera(position: .front)
            detector.onCapture = { data in handleCapture(data) }
            // Don't spin a capture session that can never produce a frame.
            if cameraUsable { detector.start() }
        }
        .onDisappear { detector.stop() }
        .onAppear { sweep = true }
    }

    private var header: some View {
        VStack(spacing: 6) {
            Text("Show your book")
                .font(BGFont.serif(24, .medium))
                .foregroundStyle(palette.ink(.hero))
            Text(bookTitle)
                .font(BGFont.aside(15))
                .foregroundStyle(palette.ink(.body))
                .multilineTextAlignment(.center)
        }
    }

    private var viewfinder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Color.black.opacity(0.6))
            if !cameraUsable {
                CameraUnavailableView(message: authDenied
                    ? String(localized: "BookGate can't see. Start without the camera below, or allow the camera in Settings.")
                    : String(localized: "This device has no camera. Start without it below — tonight still counts."),
                    showSettingsLink: authDenied)
                    .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            } else {
                CameraPreview(session: detector.captureSession)
                    .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            }
            // Sweeping scan line — only over a live picture.
            if cameraUsable {
            GeometryReader { geo in
                Rectangle()
                    .fill(LinearGradient(colors: [.clear, palette.brassLabel.opacity(0.7), .clear],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(height: 2)
                    .offset(y: reduceMotion ? geo.size.height * 0.5 : (sweep ? geo.size.height - 4 : 4))
                    .animation(reduceMotion ? nil : .easeInOut(duration: 2.6).repeatForever(autoreverses: true), value: sweep)
            }
            }
            CornerBrackets(inset: 10, length: 26)
                .stroke(palette.brassLabel, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .opacity(reduceMotion ? 0.9 : (sweep ? 1 : 0.55))
                .animation(reduceMotion ? nil : .easeInOut(duration: 2.2).repeatForever(autoreverses: true), value: sweep)
        }
        .aspectRatio(3.0/4.0, contentMode: .fit)
    }

    private var hints: some View {
        HStack(spacing: 14) {
            hintChip("Face", detector.faceSeen, "face.smiling")
            hintChip("Hand", detector.handSeen, "hand.raised")
            hintChip("Book", detector.bookSeen, "book")
        }
    }

    private func hintChip(_ label: String, _ on: Bool, _ symbol: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: on ? "checkmark.circle.fill" : symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(on ? palette.brassLabel : palette.ink(.caption))
            Text(label)
                .font(BGFont.ui(12.5, .medium))
                .foregroundStyle(on ? palette.ink(.strong) : palette.ink(.caption))
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .glass(.quiet, cornerRadius: 13)
    }

    /// Always present, by design: nobody is locked out of their own reading night by a camera.
    /// It becomes the primary action when there is no picture to take.
    @ViewBuilder private var manualFallback: some View {
        if cameraUsable {
            Button("Start without the camera") { detector.requestManualCapture() }
                .buttonStyle(GlassButtonStyle(minHeight: 50))
        } else {
            Button("I'm holding my book") { detector.requestManualCapture() }
                .buttonStyle(PrimaryActionButtonStyle(minHeight: 56))
        }
    }

    private var successOverlay: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea()
            VStack(spacing: 14) {
                ZStack {
                    Circle().fill(palette.brassObject).frame(width: 72, height: 72)
                    Image(systemName: "checkmark")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(palette.actionText)
                }
                .scaleEffect(showSuccess ? 1 : 0.4)
                .animation(.spring(response: 0.34, dampingFraction: 0.6), value: showSuccess)
                Text("Got it.")
                    .font(BGFont.serif(22, .medium)).foregroundStyle(palette.ink(.hero))
                Text(bookTitle)
                    .font(BGFont.aside(15)).foregroundStyle(palette.ink(.body))
            }
        }
    }

    private func handleCapture(_ data: Data?) {
        captured = data
        Haptics.gateOpened()
        withAnimation { showSuccess = true }
        detector.stop()
        Task {
            try? await Task.sleep(for: .seconds(1.1))
            session.gateSucceeded(photo: captured)
        }
    }
}

/// Four L-shaped corner brackets inset into the frame — the camera viewfinder corners.
struct CornerBrackets: Shape {
    var inset: CGFloat = 10
    var length: CGFloat = 26
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let r = rect.insetBy(dx: inset, dy: inset)
        // top-left
        p.move(to: CGPoint(x: r.minX, y: r.minY + length)); p.addLine(to: CGPoint(x: r.minX, y: r.minY)); p.addLine(to: CGPoint(x: r.minX + length, y: r.minY))
        // top-right
        p.move(to: CGPoint(x: r.maxX - length, y: r.minY)); p.addLine(to: CGPoint(x: r.maxX, y: r.minY)); p.addLine(to: CGPoint(x: r.maxX, y: r.minY + length))
        // bottom-right
        p.move(to: CGPoint(x: r.maxX, y: r.maxY - length)); p.addLine(to: CGPoint(x: r.maxX, y: r.maxY)); p.addLine(to: CGPoint(x: r.maxX - length, y: r.maxY))
        // bottom-left
        p.move(to: CGPoint(x: r.minX + length, y: r.maxY)); p.addLine(to: CGPoint(x: r.minX, y: r.maxY)); p.addLine(to: CGPoint(x: r.minX, y: r.maxY - length))
        return p
    }
}
