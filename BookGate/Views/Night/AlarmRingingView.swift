import SwiftUI

/// The alarm (screen 1a). Full-bleed, ambient centred high; a breathing "READING ALARM" pill, the
/// time at 74px, the book floating, and three **stacked full-width** actions (never side-by-side —
/// German "10 Minuten später erinnern" only fits stacked).
struct AlarmRingingView: View {
    @Environment(AppServices.self) private var services
    @Environment(\.bgPalette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var breathe = false
    @State private var float = false

    private var session: SessionCoordinator { services.session }
    private var book: Book? { services.books.currentReading }
    private var time: (time: String, marker: String) {
        let label = services.store.schedule(for: nil)?.readingMin ?? 1260
        return Schedule.hourMinute(label)
    }

    var body: some View {
        ZStack {
            BGAmbientBackground(center: UnitPoint(x: 0.5, y: 0.22))
            VStack(spacing: 0) {
                Spacer().frame(height: 8)
                alarmPill
                Spacer(minLength: 18)
                timeHero
                Spacer(minLength: 24)
                floatingBook
                Spacer(minLength: 22)
                copy
                Spacer(minLength: 30)
                actions
            }
            .padding(.horizontal, 26)
            .padding(.top, 60)
            .padding(.bottom, 40)
        }
        .onAppear { breathe = true; float = true }
    }

    private var alarmPill: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(palette.brassLabel)
                .frame(width: 7, height: 7)
                .opacity(reduceMotion ? 0.9 : (breathe ? 0.95 : 0.5))
                .scaleEffect(reduceMotion ? 1 : (breathe ? 1.05 : 1))
                .animation(reduceMotion ? nil : .easeInOut(duration: 2.4).repeatForever(autoreverses: true), value: breathe)
            Text("READING ALARM").sectionLabel()
        }
        .padding(.horizontal, 12).padding(.vertical, 7)
        .glass(.quiet, cornerRadius: 14)
    }

    private var timeHero: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(time.time).font(BGFont.serif(74, .medium)).foregroundStyle(palette.ink(.hero))
            if !time.marker.isEmpty {
                Text(time.marker).font(BGFont.serif(20, .medium)).foregroundStyle(palette.ink(.body))
            }
        }
    }

    private var floatingBook: some View {
        Group {
            if let book {
                BookCoverView(book: book, image: services.books.coverImage(for: book),
                              width: 132, height: 196)
            } else {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(LinearGradient(colors: [Color(hex: 0x6D5340), Color(hex: 0x5D4635)],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(width: 132, height: 196)
            }
        }
        .rotationEffect(.degrees(reduceMotion ? 0 : (float ? -1.5 : 0.5)))
        .offset(y: reduceMotion ? 0 : (float ? -8 : 0))
        .animation(reduceMotion ? nil : .easeInOut(duration: 6).repeatForever(autoreverses: true), value: float)
    }

    private var copy: some View {
        VStack(spacing: 6) {
            Text("It's time to read.")
                .font(BGFont.serif(24, .medium)).foregroundStyle(palette.ink(.hero))
            Text("Your book is waiting.")
                .font(BGFont.aside(15)).foregroundStyle(palette.ink(.body))
        }
    }

    private var actions: some View {
        VStack(spacing: 12) {
            Button("Show My Book") { session.showMyBook() }
                .buttonStyle(PrimaryActionButtonStyle(minHeight: 58))
            Button("Snooze 10 minutes") { session.snooze(minutes: 10) }
                .buttonStyle(GlassButtonStyle(minHeight: 52))
            Button("Skip Today") { session.skipTonight() }
                .buttonStyle(TextButtonStyle(ink: .secondary))
        }
    }
}
