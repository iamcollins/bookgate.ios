import Foundation

/// Lightweight UserDefaults persistence for the reading alarm list.
///
/// Each `Schedule` stays an `@Observable` class; this mirrors its stored values to/from flat DTOs
/// under one key. A fresh install has no alarm until onboarding creates one.
enum SchedulePersistence {

    private static let key = "bookgate.schedule.v1"

    private struct Snapshot: Codable {
        var id: String
        var isOn: Bool
        var readingMin: Int
        var days: [Bool]
    }

    /// Load the saved alarm list. Collapses any duplicate ids defensively.
    static func load() -> [Schedule] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let snaps = try? JSONDecoder().decode([Snapshot].self, from: data)
        else { return [] }
        var seen = Set<String>()
        return snaps.filter { seen.insert($0.id).inserted }.map(hydrate)
    }

    static func save(_ alarms: [Schedule]) {
        let snaps = alarms.map {
            Snapshot(id: $0.id.uuidString, isOn: $0.isOn, readingMin: $0.readingMin, days: $0.days)
        }
        if let data = try? JSONEncoder().encode(snaps) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private static func hydrate(_ snap: Snapshot) -> Schedule {
        let id = UUID(uuidString: snap.id) ?? UUID()
        let schedule = Schedule(id: id)
        schedule.apply {
            $0.isOn = snap.isOn
            $0.readingMin = snap.readingMin
            if snap.days.count == 7 { $0.days = snap.days }
        }
        return schedule
    }
}

extension Schedule {
    /// Mutate the schedule without firing `onChange` for each write — used when hydrating from disk
    /// so loading never triggers a save loop.
    func apply(_ body: (Schedule) -> Void) {
        let saved = onChange
        onChange = nil
        body(self)
        onChange = saved
    }
}
