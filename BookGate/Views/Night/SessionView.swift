import SwiftUI

/// The session (screen 4a).
///
/// One idea, carried the whole way: **a lamp above a reader, burning down.** The glow is the only
/// progress indicator — no ring, no bar, no edge track — and everything you actually need to read
/// (the book, the time left) sits *inside* that pool of light, so the light is lighting something
/// rather than decorating an empty screen. As the session burns down the pool contracts and the
/// room around it deepens, until at the goal there is just an ember and the words go quiet.
///
/// Composition, top to bottom: a whispered shield line at the top edge; the lit block centred (book
/// · time · "left of N minutes" · the one aside); the actions resting at the bottom. Nothing floats
/// in the middle distance.
struct SessionView: View {
    @Environment(AppServices.self) private var services
    @Environment(\.bgPalette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var session: SessionCoordinator { services.session }
    private var book: Book? { services.books.currentReading }

    /// Lamp radius: full at the start, an ember at the goal. Never quite zero — the reader is still
    /// there.
    private var glowScale: CGFloat {
        session.inOvertime ? 0.16 : 0.16 + 0.84 * CGFloat(session.remainingFraction)
    }

    /// How far the room has darkened, 0 (start) → 1 (goal).
    private var settled: Double {
        session.inOvertime ? 1 : 1 - session.remainingFraction
    }

    /// The lit block sits a little above centre — where a lamp's pool naturally falls, and clear of
    /// the actions.
    private let lightCentre: CGFloat = 0.44

    private var shieldLabel: String {
        let n = services.shield.shieldedCount
        return n > 0 ? String(localized: "\(n) apps shielded").uppercased()
                     : String(localized: "Quiet session").uppercased()
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                palette.base.ignoresSafeArea()
                lamp(in: geo.size)
                vignette(in: geo.size)
                content
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .ignoresSafeArea()
        .animation(reduceMotion ? nil : .easeInOut(duration: 1.2), value: glowScale)
    }

    // MARK: The lamp — the progress indicator

    private func lamp(in size: CGSize) -> some View {
        // Sized off the diagonal so the pool is generous on every device, and centred exactly on
        // the lit block below.
        let base = max(size.width, size.height) * 1.15
        return Circle()
            .fill(RadialGradient(
                stops: [
                    .init(color: Color(hex: 0xFFD9A6, opacity: 0.30), location: 0.00),
                    .init(color: Color(hex: 0xF0C68F, opacity: 0.20), location: 0.22),
                    .init(color: Color(hex: 0xD79A56, opacity: 0.085), location: 0.48),
                    .init(color: .clear, location: 0.76),
                ],
                center: .center, startRadius: 0, endRadius: base * 0.5))
            .frame(width: base, height: base)
            .scaleEffect(glowScale)
            .blur(radius: 34)
            .position(x: size.width / 2, y: size.height * lightCentre)
            .accessibilityHidden(true)
    }

    /// The room settling in around the reader. Deepens as the light contracts, so the end of a
    /// session *feels* later than the start of one.
    private func vignette(in size: CGSize) -> some View {
        RadialGradient(
            stops: [
                .init(color: .clear, location: 0.0),
                .init(color: Color(hex: 0x0A0705, opacity: 0.30 + 0.42 * settled), location: 1.0),
            ],
            center: UnitPoint(x: 0.5, y: lightCentre),
            startRadius: size.width * 0.20,
            endRadius: size.width * 1.05)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    // MARK: Content

    private var content: some View {
        VStack(spacing: 0) {
            Text(shieldLabel)
                .font(BGFont.ui(10.5, .medium)).tracking(1.6)
                .foregroundStyle(palette.ink(.caption))
            Spacer(minLength: 20)
            litBlock
            Spacer(minLength: 20)
            actions
        }
        .padding(.horizontal, 30)
        .padding(.top, 74)
        .padding(.bottom, 54)
    }

    /// Everything the light is actually lighting. One group, one rhythm — the book it belongs to,
    /// the time that remains, and the single line of reassurance.
    private var litBlock: some View {
        VStack(spacing: 0) {
            Text(book?.title ?? String(localized: "Your book"))
                .font(BGFont.serif(21, .regular))
                .foregroundStyle(Color(hex: 0xF7EFE4, opacity: 0.62))
                .multilineTextAlignment(.center)
                .lineLimit(2)

            Spacer().frame(height: 18)

            Text(session.inOvertime ? "+\(timeString(session.overtimeSecs))"
                                    : timeString(session.secondsLeft))
                .font(BGFont.serif(76, .light))
                .monospacedDigit()
                .foregroundStyle(Color(hex: 0xFBF3E7, opacity: session.inOvertime ? 0.80 : 0.94))
                .contentTransition(.numericText(countsDown: !session.inOvertime))
                .animation(reduceMotion ? nil : .easeOut(duration: 0.28), value: session.secondsLeft)
                .accessibilityLabel(timeAccessibilityLabel)

            Spacer().frame(height: 10)

            Text(session.inOvertime
                 ? String(localized: "Past your \(session.sessionLengthMinutes) minutes").uppercased()
                 : String(localized: "Left of \(session.sessionLengthMinutes) minutes").uppercased())
                .font(BGFont.ui(10.5, .medium)).tracking(1.5)
                .foregroundStyle(Color(hex: 0xF7EFE4, opacity: 0.42))

            Spacer().frame(height: 30)

            Rectangle()
                .fill(Color(hex: 0xF2D6AB, opacity: 0.22))
                .frame(width: 30, height: 1)

            Spacer().frame(height: 22)

            Text(asideCopy)
                .font(BGFont.aside(15))
                .foregroundStyle(Color(hex: 0xF7EFE4, opacity: 0.52))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var asideCopy: String {
        if session.inOvertime { return String(localized: "Stop whenever the chapter lets you.") }
        if session.goalReached { return String(localized: "That's your night. The light is out.") }
        return String(localized: "The light goes out when you're done.")
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
            VStack(spacing: 10) {
                Button("Finish Session") { session.finishSession() }
                    .buttonStyle(PrimaryActionButtonStyle(minHeight: 56))
                Text("Shield stays on until you finish")
                    .font(BGFont.caption).foregroundStyle(palette.ink(.caption))
            }
        } else {
            // Mid-session the screen should ask nothing of you: both ways out are quiet text.
            VStack(spacing: 14) {
                Button("Finish Session") { session.finishSession() }
                    .buttonStyle(TextButtonStyle(ink: .body))
                Button("End Early") { session.endEarly() }
                    .buttonStyle(TextButtonStyle(ink: .caption))
            }
        }
    }

    // MARK: Labels

    private func timeString(_ seconds: Int) -> String {
        let m = seconds / 60, s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }

    private var timeAccessibilityLabel: String {
        let secs = session.inOvertime ? session.overtimeSecs : session.secondsLeft
        let m = secs / 60, s = secs % 60
        return session.inOvertime
            ? String(localized: "\(m) minutes \(s) seconds past your goal")
            : String(localized: "\(m) minutes \(s) seconds left")
    }
}
