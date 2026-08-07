import SwiftUI

/// The session (screen 4a). The top is empty on purpose. A lamp glow sits high and **its radius is
/// the progress indicator — it shrinks as the session burns down** (100%→~12%). No ring, no bar, no
/// edge track. Lower third: remaining time (ink .52) + "LEFT OF N MINUTES" (ink .44). Actions are
/// quiet text. At goal, the user may Keep Reading into overtime.
struct SessionView: View {
    @Environment(AppServices.self) private var services
    @Environment(\.bgPalette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var session: SessionCoordinator { services.session }
    private var book: Book? { services.books.currentReading }

    /// Lamp radius scale: full at start, ~12% at goal.
    private var glowScale: CGFloat {
        0.12 + 0.88 * CGFloat(session.remainingFraction)
    }

    private var shieldLabel: String {
        let n = services.shield.shieldedCount
        return n > 0 ? String(localized: "\(n) apps shielded").uppercased() : String(localized: "Quiet session").uppercased()
    }

    var body: some View {
        ZStack {
            palette.base.ignoresSafeArea()
            lamp
            content
        }
    }

    // MARK: Lamp glow (the progress indicator)

    private var lamp: some View {
        GeometryReader { geo in
            let base = min(geo.size.width, geo.size.height) * 1.05
            Circle()
                .fill(RadialGradient(
                    stops: [
                        .init(color: Color(hex: 0xF0C68F, opacity: 0.42), location: 0),
                        .init(color: Color(hex: 0xD79A56, opacity: 0.14), location: 0.46),
                        .init(color: .clear, location: 0.68),
                    ],
                    center: .center, startRadius: 0, endRadius: base * 0.5))
                .frame(width: base, height: base)
                .scaleEffect(session.inOvertime ? 0.12 : glowScale)
                .blur(radius: 26)
                .position(x: geo.size.width / 2, y: 150)
                .animation(reduceMotion ? nil : .linear(duration: 1), value: glowScale)
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    // MARK: Content

    private var content: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 96)   // top empty on purpose
            insideLight
            Spacer()
            lowerThird
            actions
        }
        .padding(.horizontal, 26)
        .padding(.bottom, 44)
    }

    private var insideLight: some View {
        VStack(spacing: 12) {
            Text(book?.title ?? "Your book")
                .font(BGFont.serif(27, .medium))
                .foregroundStyle(palette.ink(.hero))
                .multilineTextAlignment(.center)
            Text(shieldLabel)
                .font(BGFont.ui(12, .medium)).tracking(1.4)
                .foregroundStyle(palette.ink(.secondary))
            Rectangle().fill(palette.ink(.caption)).frame(width: 34, height: 1)
            Text("The light goes out when you're done.")
                .font(BGFont.aside(15))
                .foregroundStyle(palette.ink(.body))
                .multilineTextAlignment(.center)
        }
    }

    private var lowerThird: some View {
        VStack(spacing: 6) {
            if session.inOvertime {
                Text("+\(timeString(session.overtimeSecs))")
                    .font(BGFont.serif(30, .regular)).monospacedDigit()
                    .foregroundStyle(Color(hex: 0xF2D6AB, opacity: 0.85))
                Text("Overtime").sectionLabel(color: palette.ink(.caption))
            } else {
                Text(timeString(session.secondsLeft))
                    .font(BGFont.serif(30, .regular)).monospacedDigit()
                    .foregroundStyle(Color(hex: 0xF7EFE4, opacity: 0.52))
                Text("Left of \(session.sessionLengthMinutes) minutes")
                    .font(BGFont.ui(10.5, .medium)).tracking(1.2).textCase(.uppercase)
                    .foregroundStyle(Color(hex: 0xF7EFE4, opacity: 0.44))
            }
        }
        .padding(.bottom, 22)
    }

    @ViewBuilder private var actions: some View {
        if session.goalReached && !session.inOvertime {
            VStack(spacing: 12) {
                Button("Finish Session") { session.finishSession() }
                    .buttonStyle(PrimaryActionButtonStyle(minHeight: 56))
                Button("Keep Reading") { session.keepReading() }
                    .buttonStyle(TextButtonStyle(ink: .body))
            }
        } else if session.inOvertime {
            Button("Finish Session") { session.finishSession() }
                .buttonStyle(PrimaryActionButtonStyle(minHeight: 56))
        } else {
            VStack(spacing: 10) {
                Button("Finish Session") { session.finishSession() }
                    .buttonStyle(TextButtonStyle(ink: .body))
                Button("End Early") { session.endEarly() }
                    .buttonStyle(TextButtonStyle(ink: .caption))
            }
        }
    }

    private func timeString(_ seconds: Int) -> String {
        let m = seconds / 60, s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }
}
