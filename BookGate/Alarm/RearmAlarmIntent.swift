import AppIntents
import AlarmKit
import Foundation

/// The reading alarm's **Snooze** button. Attached as `stopIntent`, iOS runs this in the
/// **background** (app closed, phone locked) the moment Snooze is pressed — the mechanism that lets
/// a dismissed alarm come back instead of ending.
///
/// `owner` is the `Schedule.id` this ring belongs to, so the re-ring stays attributed to the
/// correct alarm. `count` is which re-ring this Snooze should schedule; each press advances it by
/// one, and when it passes `AlarmChain.maxReRings` the chain stops. Both travel inside the intent,
/// so there's no shared state to reset — each night's first alarm starts its chain at `count == 1`.
struct RearmAlarmIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Snooze BookGate alarm"
    static let supportedModes: IntentModes = .background   // never opens the app

    @Parameter(title: "owner")
    var owner: String

    @Parameter(title: "count")
    var count: Int

    init() { self.owner = ""; self.count = 1 }
    init(owner: UUID, count: Int) { self.owner = owner.uuidString; self.count = count }

    func perform() async throws -> some IntentResult {
        guard count <= AlarmChain.maxReRings, let ownerID = UUID(uuidString: owner) else { return .result() }
        // Only continue the chain for an alarm that still exists and is enabled — a deleted or
        // toggled-off alarm must never keep re-ringing. The list is persisted in UserDefaults,
        // which this in-process background intent can read.
        guard SchedulePersistence.load().contains(where: { $0.id == ownerID && $0.isOn }) else { return .result() }
        // Reading is any-time, so `isWithinReRingWindow` is always true; the chain self-limits via
        // `maxReRings` and the enabled check above.
        guard AlarmChain.isWithinReRingWindow() else { return .result() }
        let countdown = Alarm.CountdownDuration(preAlert: AlarmChain.reRingSpacing, postAlert: nil)
        _ = await AlarmChain.scheduleRing(owner: ownerID,
                                          countdown: countdown,
                                          nextCount: count + 1,
                                          display: AlarmChain.cachedDisplay(ownerID))
        return .result()
    }
}
