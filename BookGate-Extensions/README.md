# BookGate — Family Controls extensions (scaffold, not yet in the build)

These files are **ready but intentionally NOT part of the Xcode project yet**, because the
`com.apple.developer.family-controls` (Distribution) entitlement is being requested separately.
The main app already ships a `ShieldManager` (`BookGate/Shield/ShieldManager.swift`) that imperatively
raises/lowers the shield at session start/complete and **no-ops cleanly without the entitlement**
(shield OFF). These two app extensions add the pieces that need the entitlement to exist as targets:

1. **`ReadingShieldMonitor/`** — a `DeviceActivityMonitor` extension. It applies the shield at the
   *reading-window start* (the alarm time) even if the app isn't open, and lifts it when the window
   ends. This is what makes "apps are locked from the reading-window start" true when BookGate is closed.
2. **`ReadingShieldUI/`** — a custom `ShieldConfigurationDataSource` (the barrier UI, screen 1g:
   "Reading time is active.", **Return to BookGate**, **Emergency access** always present) plus a
   `ShieldActionDelegate` handling those two buttons.

## Wiring it up when the entitlement lands

1. Add the entitlement to the app target: set `CODE_SIGN_ENTITLEMENTS = BookGate/BookGate.entitlements`
   (see `BookGate.entitlements` here) — it declares `com.apple.developer.family-controls = true`.
2. Add an **App Group** (e.g. `group.app.bookgate.shared`) to the app and both extensions, and change
   `ShieldManager` + the extensions to persist the `FamilyActivitySelection` in
   `UserDefaults(suiteName: "group.app.bookgate.shared")` instead of `.standard`, so the extensions
   can read the user's selection. (Search `selectionKey` in both.)
3. Create two **App Extension** targets in `BookGate.xcodeproj`:
   - *Device Activity Monitor Extension* → point it at `ReadingShieldMonitor/` (principal class
     `ReadingShieldMonitor`), give it the family-controls entitlement + the App Group.
   - *Shield Configuration Extension* → point it at `ReadingShieldUI/ShieldConfigurationExtension.swift`;
     and a *Shield Action Extension* → `ReadingShieldUI/ShieldActionExtension.swift`. Both get the
     family-controls entitlement + App Group.
4. In `ShieldManager`, schedule the reading window with `DeviceActivityCenter().startMonitoring(...)`
   using the alarm time as the interval start and the session's min duration as the guaranteed lock
   (the app still lifts the shield early on completion). A `// TODO(entitlement)` marks the spot.

Until steps 1–4 are done the app builds and runs; the shield is simply off. Nothing here is compiled
into the app target (this folder is outside the `BookGate/` synchronized group).
