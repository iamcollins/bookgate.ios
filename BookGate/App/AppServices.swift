import SwiftUI
import AVFoundation
import SubscriptionKit

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

    /// Set once entitlement has resolved, so nothing decides while the answer is still
    /// `.unknown`. Prefer `subscription.entitlement` at a decision point: a Bool collapses
    /// "still checking" into "not entitled" and walls a paying subscriber on a slow launch.
    var subscriptionResolved: Bool { subscription.hasResolvedEntitlement }
    var isSubscribed: Bool { subscription.isEntitled }

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
        subscription = SubscriptionStore(config: AppSubscription.config)
        let subStore = subscription
        shield = ShieldManager()   // no-ops (shield OFF) until the family-controls entitlement lands

        let bookStore = books
        let alarmStore = store
        session = SessionCoordinator(
            scheduleForID: { [weak alarmStore] in alarmStore?.schedule(for: $0) },
            progress: progress, journal: journal, books: bookStore,
            settings: settings, scheduler: scheduler, shield: shield,
            isEntitled: { [weak subStore] in subStore?.isEntitled ?? false })
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

        // The night flow is what the subscription buys. Until now nothing under `Alarm/`,
        // `Shield/` or `Model/` consulted entitlement at all, so a lapsed reader still got
        // the alarm, the gate, the shield and the whole session every night — and only met
        // the paywall if they happened to open the app in daylight.
        subscription.onEntitlementChange = { [weak self] _, now in
            Task { @MainActor in await self?.applyEntitlementToScheduling(now) }
        }

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
        shield.refreshAuthorization()
        // Entitlement first: reconciling before it resolves would arm a lapsed reader's
        // alarms for the evening and only disarm them once StoreKit answered.
        await subscription.activate()
        await applyEntitlementToScheduling(subscription.entitlement)
        session.consumePendingGate()       // route straight into the reading gate if tapped
        await scheduler.observeUpdates()   // never returns
    }

    /// Called on every foreground. Deliberately does NOT reconcile alarms on a plain foreground
    /// (that was an alarm-leak source in Thrise); it only refreshes authorization + subscription
    /// and, once wired, consumes a pending gate.
    func onForeground() async {
        refreshCameraStatus()
        scheduler.refreshAuthorization()
        shield.refreshAuthorization()
        _ = await subscription.refreshEntitlement()
        // A session keeps running on the wall clock while the app is suspended; catch the published
        // numbers up before anything is drawn.
        session.syncClock()
        session.consumePendingGate()
    }

    /// Re-schedule after an edit to the alarm time / active nights. A lapsed reader's edits
    /// are still saved — they simply do not arm anything until the subscription is back.
    func resync() async {
        guard subscription.entitlement != .notEntitled else { return }
        await scheduler.reconcile(store.alarms)
    }

    /// Arm or disarm the nightly alarms to match entitlement.
    ///
    /// Deliberately keyed on a **confirmed** `.notEntitled`: `.unknown` must never cancel a
    /// paying reader's alarms just because StoreKit has not answered yet, which is the same
    /// rule the paywall itself follows. Nothing here touches a session already running — a
    /// lapse mid-session lets tonight finish, and an alarm that is ringing can always be
    /// silenced.
    private func applyEntitlementToScheduling(_ state: SubscriptionStore.EntitlementState) async {
        switch state {
        case .notEntitled:
            await scheduler.cancelAll()
        case .entitled:
            await scheduler.reconcile(store.alarms)
        case .unknown:
            break
        }
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
