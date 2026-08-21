# StoreKit Test does not work on this machine

`BookGateTests/SubscriptionFlowTests.swift` holds 10 cases covering purchase, restore, expiry,
refund and trial eligibility. All 10 skip.

**The fault is located, and it is not in this project.** StoreKit Test does not apply a
`.storekit` configuration at all here — not for BookGate, not for Thrise, not in Xcode's Run
action, not under `xcodebuild`. This was proven with a control, which is what every previous
investigation lacked.

## Environment

| | |
|---|---|
| Xcode | **26.6** (17F113) |
| Simulator runtimes installed | **iOS 26.5 only** (23F77) |
| Test device | iPhone 17 Pro Max, iOS 26.5 |

## How it was proven

The method is a **sentinel price** — a value App Store Connect cannot return. If the app shows it,
the local config is in play; if it shows the real price, it is not.

| Experiment | Fixture said | App showed | Verdict |
|---|---|---|---|
| BookGate, `xcodebuild test` | `$77.77` | `$4.99` | config not applied |
| BookGate, **Xcode ⌘R** | `$77.77` | `$4.99` | config not applied |
| **Thrise, Xcode ⌘R** (control) | `$88.88` | `$4.99` | **config not applied** |

The third row is the one that settles it. Thrise is a separate project with its own `.storekit`
and its own scheme, and it fails identically. **Nothing about BookGate is responsible.**

Under `xcodebuild`, every `SKTestSession` operation fails the same way:

```
[SKTestSession] Error saving configuration file:  SKInternalErrorDomain Code=3
[SKTestSession] Error clearing overrides:         SKInternalErrorDomain Code=3
[SKTestSession] Error deleting all transactions:  SKInternalErrorDomain Code=3
[SKTestSession] Error setting storefront to USA:  SKInternalErrorDomain Code=3
```

The session constructs, names the right bundle (`app.bookgate.BookGate`), and then every write to
`storekitd` fails. That is a session↔daemon fault, not a missing or malformed file.

## What was ruled out, and how

| Hypothesis | Result |
|---|---|
| Invalid UUIDs in `BookGate.storekit` | **Was genuinely broken** — all six identifiers were placeholders (`…-BOOKGATESTORE`; `G`,`K`,`O`,`R`,`S`,`T` are not hex), `appPolicies` missing, no group localization. **Fixed.** Changed nothing. Thrise's fixture has the *same* defect and is the working-by-assumption control, which is what exposed it as a red herring |
| Scheme path `../BookGate.storekit` | Correct as written. Resolution is from the `.xcodeproj` bundle; Thrise is written identically |
| Missing test plan | Added `BookGate.xctestplan` with `storeKitConfigurationFileReference`, ran via `-testPlan`. No change. Kept — it is the documented mechanism and costs nothing |
| `CODE_SIGN_ENTITLEMENTS` (BookGate has Family Controls, Thrise has none) | **Falsified** — ran with `CODE_SIGN_ENTITLEMENTS=""`; sentinel still `$4.99`, 50 `Code=3` errors |
| Build config / bundle id / deployment target | Identical to the control (Debug, `26.0`) |
| iOS 18.x runtime regression | **Untested** — no 18.x runtime installed, and none downloaded without asking. This is the one remaining check |

## The claim that misled three investigations

> *"StoreKit Test demonstrably works on this machine — Thrise/PillSeal run against their
> `.storekit` files."*

**Neither project contains a single line of `SKTestSession` or `StoreKitTest`.** Thrise has no
test target at all. They had never exercised StoreKit Test in any form, so they were never
evidence of anything — and when Thrise was finally used as a real control, it failed too.

Every prior conclusion rested on this. Treat it as retired.

## Errors in the record elsewhere

`FINDINGS.md` in the SubscriptionKit checkout (`build-shots/SourcePackages/`, do not edit) is
wrong in two ways:

- Its **"catalogue comes back empty"** is stale. Both products resolve, at real App Store prices.
  That change is what makes the sentinel method work at all.
- Its **"OPEN BLOCKER"** framing pointed at the environment without ever isolating it, and its
  four ruled-out hypotheses never validated BookGate's own fixture.

Also retired: any suggestion to run these "on a sandbox-signed simulator". **The Simulator cannot
sign into a Sandbox Apple Account** — Apple DTS: sandbox testing happens on a real device. That
clause has been cut from the skip messages.

## What this means

These flows are **verified on a real device, or not at all**:

purchase · restore · expiry · refund · trial offered-then-withdrawn · storefront pricing ·
offline-with-live-subscriber

The skip stays. Without it these cases run against the real App Store, where `restore()` reaches
`AppStore.sync()`, raises a "Sign in to Apple Account" sheet, and stalls the run until timeout —
once costing a full red 15-minute suite. The skip probe now measures directly (buy a product
through the session, check the transaction landed) instead of inferring from storefront prices,
and its message carries the verbatim error and catalogue count.

## If you want to try again

Two things worth doing, in order:

1. **Install an iOS 18.x simulator runtime and run the suite against it.** There is documented
   precedent for this exact symptom being runtime-specific on iOS 26. It is the only untried
   hypothesis, and it is one download.
2. **Re-run the sentinel** after any Xcode update — one run, and it answers the question outright.

```bash
# plant, run, read, revert
python3 - <<'EOF'
import json, pathlib
p = pathlib.Path("BookGate.storekit"); d = json.loads(p.read_text())
for g in d["subscriptionGroups"]:
    for s in g["subscriptions"]:
        if s["productID"].endswith(".monthly"): s["displayPrice"] = "77.77"
p.write_text(json.dumps(d, indent=2, sort_keys=True) + "\n")
EOF
Scripts/test.sh 2>&1 | grep -oE "products resolved: .*\]"
# $77.77 -> fixed.  $4.99 -> still broken.  Then set it back to 4.99.
```

Expect one `SubscriptionConfigTests` failure while the sentinel is planted — that is the
fixture-drift guardrail doing its job, not a regression.
