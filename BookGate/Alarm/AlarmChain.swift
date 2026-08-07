import AlarmKit
import AppIntents
import SwiftUI
import Foundation

/// Actor-agnostic builder + scheduler shared by the app (`AlarmScheduler`) and the background
/// Snooze handler (`RearmAlarmIntent`), so every ring is built identically and every scheduled id
/// is tracked the same way.
///
/// **One re-ring chain per alarm.** Each alarm (a `Schedule.id` — the *owner*) has its own chain:
/// pressing **Snooze** runs `RearmAlarmIntent` in the background, which schedules exactly one fresh
/// ring `reRingSpacing`s later (up to `maxReRings`) for that owner. "Show My Book" opens the app
/// into that owner's reading gate and the app tears the owner's chain down. Ids are tracked per
/// owner so one alarm's teardown never touches another's.
enum AlarmChain {

    /// Seconds between re-rings after a Snooze.
    static let reRingSpacing: TimeInterval = 60
    /// Cap on re-rings (≈30 min at 60s) before the chain gives up for the night.
    static let maxReRings = 30

    private static let tint = Color(hex: 0xE9B872)   // brass-label

    // MARK: Re-ring time window

    /// Reading is **evening/any-time**, so — unlike Thrise's morning-only alarm — there is no
    /// wall-clock band gating the re-ring chain. The chain is bounded instead by `maxReRings`
    /// (≈30 min) and by the owner still existing and being enabled (checked in `RearmAlarmIntent`).
    ///
    /// The DEBUG toggle is retained for parity but the guard is effectively always-on.
    #if DEBUG
    static let reRingAnytimeDebugKey = "bookgate.debug.reRingAnytime"
    #endif

    static func isWithinReRingWindow(_ date: Date = Date()) -> Bool {
        true
    }

    // MARK: Per-owner id tracking (shared across processes via UserDefaults)

    private static let ownersKey = "bookgate.alarm.owners"
    private static func ownerKey(_ owner: UUID) -> String { "bookgate.alarm.ids.v1.\(owner.uuidString)" }
    private static func displayKey(_ owner: UUID) -> String { "bookgate.alarm.display.\(owner.uuidString)" }

    // MARK: Display info carried into the alert / metadata

    /// The bits needed to render the alert. Cached per owner so a background re-ring can rebuild an
    /// equivalent ring without app state. Display-only — never authoritative for gate resolution.
    struct RingDisplay: Codable, Hashable, Sendable {
        /// The current book's title, shown under the alert. May be empty (no book yet).
        var bookTitle: String

        static let fallback = RingDisplay(bookTitle: "")
    }

    // MARK: Alert presentation

    /// The full alert: a **Snooze** button (re-rings this owner via `stopIntent`) plus a
    /// **Show My Book** secondary button that opens the app into the owner's reading gate.
    static func makeAttributes(owner: UUID, display: RingDisplay) -> AlarmAttributes<BookGateAlarmMetadata> {
        let alert = AlarmPresentation.Alert(
            title: "Time to read",
            stopButton: AlarmButton(text: "Snooze",
                                    textColor: .white,
                                    systemImageName: "moon.zzz"),
            secondaryButton: AlarmButton(text: "Show My Book",
                                         textColor: .white,
                                         systemImageName: "book"),
            secondaryButtonBehavior: .custom)
        return AlarmAttributes(presentation: AlarmPresentation(alert: alert),
                               metadata: BookGateAlarmMetadata(owner: owner, display: display),
                               tintColor: tint)
    }

    /// Minimal fallback (dismiss only, no intents) used if the full config ever fails to schedule
    /// — so the alarm still *rings* rather than silently not scheduling.
    static func makePlainAttributes(owner: UUID, display: RingDisplay) -> AlarmAttributes<BookGateAlarmMetadata> {
        let alert = AlarmPresentation.Alert(
            title: "Time to read",
            stopButton: AlarmButton(text: "Show My Book",
                                    textColor: .white,
                                    systemImageName: "book"))
        return AlarmAttributes(presentation: AlarmPresentation(alert: alert),
                               metadata: BookGateAlarmMetadata(owner: owner, display: display),
                               tintColor: tint)
    }

    // MARK: Scheduling one ring

    /// Schedule a single alarm for `owner` — either a repeating `schedule` (the nightly alarm) or
    /// a `countdown` (a re-ring) — whose **Snooze** button re-arms via `RearmAlarmIntent` and whose
    /// secondary button opens the owner's gate (`OpenGateIntent`). Tries the full config, falls
    /// back to a plain ringing alarm, records the id under the owner immediately, caches the
    /// display, and returns the id (nil if both configs fail).
    @discardableResult
    static func scheduleRing(owner: UUID,
                             schedule: Alarm.Schedule? = nil,
                             countdown: Alarm.CountdownDuration? = nil,
                             nextCount: Int,
                             display: RingDisplay) async -> UUID? {
        cacheDisplay(owner, display)
        let id = UUID()
        // Uses AlarmKit's built-in .default alarm tone; iOS exposes no third-party ringtone API.
        let full = AlarmManager.AlarmConfiguration(
            countdownDuration: countdown,
            schedule: schedule,
            attributes: makeAttributes(owner: owner, display: display),
            stopIntent: RearmAlarmIntent(owner: owner, count: nextCount),
            secondaryIntent: OpenGateIntent(alarmID: owner.uuidString))
        if (try? await AlarmManager.shared.schedule(id: id, configuration: full)) != nil {
            appendGroup(owner, [id])
            return id
        }
        #if DEBUG
        print("[AlarmChain] full config failed — plain ringing fallback")
        #endif
        let plain = AlarmManager.AlarmConfiguration(
            countdownDuration: countdown,
            schedule: schedule,
            attributes: makePlainAttributes(owner: owner, display: display))
        if (try? await AlarmManager.shared.schedule(id: id, configuration: plain)) != nil {
            appendGroup(owner, [id])
            return id
        }
        return nil
    }

    // MARK: Scheduled-id bookkeeping (shared across processes)

    static func owners() -> [UUID] {
        (UserDefaults.standard.array(forKey: ownersKey) as? [String])?
            .compactMap { UUID(uuidString: $0) } ?? []
    }

    static func groupIDs(_ owner: UUID) -> [UUID] {
        (UserDefaults.standard.array(forKey: ownerKey(owner)) as? [String])?
            .compactMap { UUID(uuidString: $0) } ?? []
    }

    static func setGroup(_ owner: UUID, _ ids: [UUID]) {
        UserDefaults.standard.set(ids.map(\.uuidString), forKey: ownerKey(owner))
        addOwner(owner)
    }

    static func appendGroup(_ owner: UUID, _ ids: [UUID]) {
        setGroup(owner, groupIDs(owner) + ids)
    }

    static func clearGroup(_ owner: UUID) {
        UserDefaults.standard.removeObject(forKey: ownerKey(owner))
        UserDefaults.standard.removeObject(forKey: displayKey(owner))
        removeOwner(owner)
    }

    /// Every tracked id across all owners — for the scheduler's orphan sweep.
    static func allTrackedIDs() -> [UUID] {
        owners().flatMap { groupIDs($0) }
    }

    // MARK: Owner-index maintenance

    private static func addOwner(_ owner: UUID) {
        var set = owners()
        guard !set.contains(owner) else { return }
        set.append(owner)
        UserDefaults.standard.set(set.map(\.uuidString), forKey: ownersKey)
    }

    private static func removeOwner(_ owner: UUID) {
        let set = owners().filter { $0 != owner }
        UserDefaults.standard.set(set.map(\.uuidString), forKey: ownersKey)
    }

    // MARK: Display cache

    static func cacheDisplay(_ owner: UUID, _ display: RingDisplay) {
        if let data = try? JSONEncoder().encode(display) {
            UserDefaults.standard.set(data, forKey: displayKey(owner))
        }
    }

    static func cachedDisplay(_ owner: UUID) -> RingDisplay {
        guard let data = UserDefaults.standard.data(forKey: displayKey(owner)),
              let display = try? JSONDecoder().decode(RingDisplay.self, from: data)
        else { return .fallback }
        return display
    }
}
