import SwiftUI
import AVFoundation

/// The composition root: the single owner of every app-lifetime store and service, so the alarm /
/// session flow can drive the UI from outside any screen. Constructor-injected, `@Observable`.
///
/// Coordinators that arrive with later feature work — `SessionCoordinator` (night flow) and
/// `ShieldManager` (Family Controls) — attach through the seams marked below, so this container
/// stays buildable at every step.
@MainActor @Observable
final class AppServices {

    // Stores (source of truth)
    let books: BookStore
    let store: AlarmStore
    let scheduler: AlarmScheduler
    let progress: ProgressStore
    let journal: JournalStore
    let takeaways: TakeawayStore
    let settings: ReadingSettings
    let subscription: SubscriptionStore
    let shield: ShieldManager
    let session: SessionCoordinator

    /// Live camera authorization, mirrored so views don't each poll AVFoundation.
    private(set) var cameraStatus: AVAuthorizationStatus = CameraAccess.status

    /// Set once resolved, so the paywall can decide without waiting on a product fetch.
    var subscriptionResolved: Bool { subscription.hasResolved }
    var isSubscribed: Bool { subscription.isSubscribed }

    // MARK: Seams for later coordinators

    /// Called on each alarm-update tick with the alerting ids. The `SessionCoordinator` (task #5)
    /// installs the real handler; until then alerts are simply ignored.
    var onAlarmAlerting: ([UUID]) -> Void = { _ in }

    init() {
        let loadedAlarms = SchedulePersistence.load()
        books = BookStore.load()
        store = AlarmStore(alarms: loadedAlarms)
        progress = ProgressStore.load()
        journal = JournalStore.load()
        takeaways = TakeawayStore.load()
        settings = ReadingSettings.load()
        scheduler = AlarmScheduler()
        subscription = SubscriptionStore()
        shield = ShieldManager()   // no-ops (shield OFF) until the family-controls entitlement lands

        let bookStore = books
        let alarmStore = store
        session = SessionCoordinator(
            scheduleForID: { [weak alarmStore] in alarmStore?.schedule(for: $0) },
            progress: progress, journal: journal, books: bookStore,
            settings: settings, scheduler: scheduler, shield: shield)
        let sess = session

        // Persist alarm edits — set AFTER load so hydration doesn't echo a save.
        store.onChange = { [weak alarmStore] in
            guard let alarmStore else { return }
            SchedulePersistence.save(alarmStore.alarms)
        }

        // The alarm alert shows the current book's title; provide it without a book dependency
        // living inside the scheduler.
        AlarmScheduler.bookTitleProvider = { [weak bookStore] in bookStore?.currentReading?.title ?? "" }

        // Route AlarmKit alerting ticks into the session coordinator (no retain cycle: `sess` does
        // not reference `self`).
        onAlarmAlerting = { [weak sess] ids in sess?.handleAlarmUpdate(alertingIDs: ids) }
        scheduler.onUpdate = { [weak self] ids in self?.onAlarmAlerting(ids) }

        #if DEBUG
        seedForScreenshotsIfRequested()
        #endif
    }

    // MARK: Lifecycle

    /// Called once from `RootView.task`. Refreshes authorization, bootstraps StoreKit, reconciles
    /// alarms with AlarmKit, then consumes the update stream for the app's lifetime.
    func onLaunch() async {
        refreshCameraStatus()
        scheduler.refreshAuthorization()
        async let boot: Void = subscription.bootstrap()
        await scheduler.reconcile(store.alarms)
        await boot
        session.consumePendingGate()       // route straight into the reading gate if tapped
        await scheduler.observeUpdates()   // never returns
    }

    /// Called on every foreground. Deliberately does NOT reconcile alarms on a plain foreground
    /// (that was an alarm-leak source in Thrise); it only refreshes authorization + subscription
    /// and, once wired, consumes a pending gate.
    func onForeground() async {
        refreshCameraStatus()
        scheduler.refreshAuthorization()
        await subscription.refresh()
        session.consumePendingGate()
    }

    /// Re-schedule after an edit to the alarm time / active nights.
    func resync() async {
        await scheduler.reconcile(store.alarms)
    }

    func refreshCameraStatus() { cameraStatus = CameraAccess.status }

    // MARK: Debug seeding

    #if DEBUG
    private func seedForScreenshotsIfRequested() {
        let env = ProcessInfo.processInfo.environment
        if env["BOOKGATE_SKIP_ONBOARDING"] == "1" {
            UserDefaults.standard.set(true, forKey: "bookgate.onboarding.v1.done")
        }
        if env["BOOKGATE_SEED_PROGRESS"] == "1" { progress.debugSeed() }
        if env["BOOKGATE_SEED_LIBRARY"] == "1", books.books.isEmpty {
            books.add(title: "The Long Field", author: "Katharine Reeve", status: .reading)
            books.add(title: "Winter Grammar", author: "P. A. Voss", status: .next)
            books.add(title: "The Salt Ledger", author: "M. Okonkwo", status: .next)
            books.add(title: "Northline", author: "R. Bellamy", status: .finished)
        }
        if let jump = env["BOOKGATE_JUMP"] {
            let phase: SessionCoordinator.Phase? = switch jump {
            case "ringing":  .ringing(alarmID: nil)
            case "gate":     .gate
            case "settle":   .settle
            case "session":  .session
            case "complete": .complete
            case "takeaway": .takeaway
            case "stepup":   .stepup
            default: nil
            }
            if let phase { session.debugJump(to: phase) }
        }
    }
    #endif
}
