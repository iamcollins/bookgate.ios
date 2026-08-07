import Observation
import SwiftUI

/// The list of reading alarms — the source of truth Settings reads and edits. BookGate normally
/// holds exactly one, but the engine stays list-shaped for reuse from Thrise's scheduler. Field
/// edits on a `Schedule` persist automatically (each element's `onChange` funnels here); structural
/// changes persist here and expect the caller to `resync()` so AlarmKit reflects the new set.
@MainActor @Observable
final class AlarmStore {

    private(set) var alarms: [Schedule]

    /// Persist-all hook, injected by `AppServices` (`SchedulePersistence.save`). Set *after*
    /// construction so hydration never echoes a save.
    @ObservationIgnored var onChange: () -> Void = {}

    init(alarms: [Schedule]) {
        self.alarms = alarms
        rewire()
    }

    /// The single reading alarm (BookGate's common case): the first enabled, else the first, else
    /// a freshly-created default so callers always have one to edit.
    var primary: Schedule {
        if let a = alarms.first(where: { $0.isOn }) ?? alarms.first { return a }
        return add()
    }

    // MARK: Lookup

    /// Resolve an alarm by id. A `nil` id (watchdog re-fire / debug jump) falls back to the first
    /// enabled alarm, else the first.
    func schedule(for id: UUID?) -> Schedule? {
        if let id { return alarms.first { $0.id == id } }
        return alarms.first { $0.isOn } ?? alarms.first
    }

    // MARK: Structural mutations (persist here; caller resyncs)

    @discardableResult
    func add() -> Schedule {
        let alarm = Schedule()
        alarms.append(alarm)
        rewire()
        onChange()
        return alarm
    }

    func delete(_ alarm: Schedule) {
        alarms.removeAll { $0.id == alarm.id }
        onChange()
    }

    /// Flip an alarm on/off. Persists via the element's `didSet`; the caller must `resync()`.
    func setEnabled(_ alarm: Schedule, _ on: Bool) {
        alarm.isOn = on
    }

    // MARK: Internals

    private func rewire() {
        for alarm in alarms {
            alarm.onChange = { [weak self] in self?.onChange() }
        }
    }
}
