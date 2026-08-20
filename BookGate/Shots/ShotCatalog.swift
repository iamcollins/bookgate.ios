#if DEBUG
import SwiftUI
import ShotKit

/// The screens the capture pipeline walks, in order — App Store frames, the marketing site, and
/// the localization contact sheets all come out of this one list.
///
/// The whole file is DEBUG-only, like ShotKit itself: none of it exists in a Release build.
/// Filenames are `NN_<rawValue>.png`, and `NN` is this order — `Scripts/store_captions.json`
/// refers to them by that name, so renaming a case renames a source.
enum Shot: String, ShotScreenCatalog, CaseIterable {
    case welcome        // onboarding 8a — the opening promise
    case sundial        // onboarding 8c — set your reading time
    case today          // 4b — tonight's plan
    case library        // 7a
    case bookDetails    // 7b — the takeaway timeline
    case takeaways      // 7c
    case progress       // 10a — the month heatmap
    case gate           // 1g/8e — the nightly camera gate
    case session        // 4a — the lamp burning down
    case complete       // 9 — the night's close
    case paywall        // 8f — required by App Store Connect for subscription review

    /// Screens that animate on entry need longer than the default settle: the sundial plays a
    /// ~2s auto-rise, the session's lamp eases in, and the paywall must wait for StoreKit to
    /// resolve real prices before it will show any (it shows placeholders until then, by design).
    var extraSettle: Duration {
        switch self {
        case .sundial:            return .seconds(2)
        case .paywall:            return .milliseconds(1200)
        case .session, .complete: return .milliseconds(600)
        default:                  return .zero
        }
    }
}

/// Mounts one screen exactly as the app does — same services, same environment, same theme root —
/// so a capture is the real screen and not a lookalike. Only the *data* is staged.
struct ShotHost: View {
    let screen: Shot

    private var services: AppServices { ShotFixtures.services }

    var body: some View {
        Group {
            switch screen {
            case .welcome:     OnboardingView(initialStep: .welcome, onComplete: {})
            case .sundial:     OnboardingView(initialStep: .alarm, onComplete: {})
            case .today:       MainTabView(initialTab: .today).themedRoot(.dark)
            case .library:     MainTabView(initialTab: .library).themedRoot(.dark)
            case .takeaways:   MainTabView(initialTab: .takeaways).themedRoot(.dark)
            case .progress:    MainTabView(initialTab: .progress).themedRoot(.dark)
            case .bookDetails: bookDetails
            case .gate, .session, .complete: night
            case .paywall:     PaywallView(onSubscribed: {}).nightFlow()
            }
        }
        .environment(services)
        .task { ShotFixtures.stage(screen) }
    }

    @ViewBuilder
    private var bookDetails: some View {
        if let book = services.books.currentReading {
            BookDetailsView(bookID: book.id).themedRoot(.dark)
        }
    }

    /// The night flow renders whichever phase `ShotFixtures.stage` put the coordinator in.
    private var night: some View {
        NightFlowView()
    }
}

/// The demo data every shot is taken against.
///
/// One `AppServices` for the whole run — the same object graph the app uses, with its stores
/// seeded and **nothing live started**: `onLaunch()` is never called, so no alarms are scheduled,
/// no permissions are asked for, and no shield is raised.
@MainActor
enum ShotFixtures {

    static let services: AppServices = {
        let services = AppServices()
        seed(into: services)
        return services
    }()

    /// Per-screen state that can't be expressed as stored data — which night-flow phase is
    /// running. Called from the host's `.task`, so it lands before the capture settles.
    static func stage(_ screen: Shot) {
        switch screen {
        case .gate:     services.session.debugJump(to: .gate)
        case .session:  services.session.debugJump(to: .session)
        case .complete: services.session.debugJump(to: .complete)
        default:        services.session.debugJump(to: .idle)
        }
    }

    /// Deterministic on every run: the stores are cleared before they are filled, so a second
    /// capture never shows six books because the simulator kept the first run's container.
    private static func seed(into services: AppServices) {
        // Reading alarm: one, 9:00 PM nightly (the Schedule default), 20-minute sessions.
        for alarm in services.store.alarms { services.store.delete(alarm) }
        let alarm = services.store.add()
        alarm.readingMin = 21 * 60
        alarm.isOn = true
        services.settings.defaultLength = 20
        services.settings.clearTonightOverride()

        // Library: one book being read, two waiting, one finished.
        for book in services.books.books { services.books.delete(book) }
        services.books.add(title: "The Long Field", author: "Katharine Reeve", status: .reading)
        services.books.add(title: "Winter Grammar", author: "P. A. Voss", status: .next)
        services.books.add(title: "The Salt Ledger", author: "M. Okonkwo", status: .next)
        services.books.add(title: "Northline", author: "R. Bellamy", status: .finished)
        if let current = services.books.currentReading {
            var book = current
            book.sessionsRead = 23
            book.minutesRead = 460
            book.startedDate = Calendar.current.date(byAdding: .day, value: -24, to: .now)
            services.books.update(book)
            applyStagedCover(to: current, in: services.books)
        }

        // Nights read: a 17-night streak that ends *yesterday*, so tonight is still unread and
        // Today shows its primary action rather than the already-read variant.
        services.progress.debugSeed(includeToday: false)

        // Spoken takeaways, newest first. No audio files — nothing plays during a capture, and a
        // recording of a real voice has no business in a screenshot.
        for takeaway in services.takeaways.takeaways { services.takeaways.delete(takeaway) }
        let bookID = services.books.currentReading?.idString
        let script: [(Int, Double)] = [(1, 34), (2, 41), (4, 28), (5, 52), (7, 37)]
        for (daysAgo, seconds) in script.reversed() {
            services.takeaways.add(
                bookId: bookID,
                date: Calendar.current.date(byAdding: .day, value: -daysAgo, to: .now) ?? .now,
                durationSec: seconds,
                file: "shot-\(daysAgo).m4a",
                waveform: waveform(seed: daysAgo)
            )
        }
    }

    /// Today gives its top half to the current book's cover photo, and a book added without one
    /// shows the empty cloth gradient — honest, but not a screenshot. The driver stages a real
    /// cover photo (`CONTAINER_ASSETS`); drop one at `Scripts/shot-assets/cover.jpg` and the shot
    /// gets its hero image. Absent, the capture simply shows what a user without a photo sees.
    private static func applyStagedCover(to book: Book, in books: BookStore) {
        let staged = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("shot-cover.jpg")
        guard let data = try? Data(contentsOf: staged) else { return }
        _ = books.setCover(data, for: book)
    }

    /// A plausible speech envelope, so the playback waveform reads as a voice rather than noise.
    /// Deterministic: the same seed gives the same shape in every locale and every run.
    private static func waveform(seed: Int) -> [Float] {
        (0..<64).map { i in
            let t = Double(i) / 64
            let envelope = sin(t * .pi)                                  // fades in and out
            let syllables = 0.55 + 0.45 * sin(t * .pi * Double(6 + seed))
            return Float(max(0.06, min(1, envelope * syllables)))
        }
    }
}
#endif
