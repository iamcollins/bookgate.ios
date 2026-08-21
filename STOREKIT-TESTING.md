# Why the 10 StoreKit tests skip

`BookGateTests/SubscriptionFlowTests.swift` holds 10 cases covering purchase, restore, expiry,
refund and trial eligibility. They skip under `Scripts/test.sh`. This is the record of what was
checked, so nobody re-runs the investigation from scratch.

**Short version:** the StoreKit configuration does not reach an `xcodebuild test` process on this
machine, by any route tried. Products resolve from the **real App Store**, and `SKTestSession` is
inert. Those flows are device-verified only.

## The decisive experiment

Everything before this was inference from indirect probes, which is how the previous conclusion
came to read as more settled than its evidence supported. This one is direct:

1. Set `BookGate.storekit` monthly to a price App Store Connect cannot return — `$77.77`.
2. Run the suite and print what `Product.products(for:)` actually returns.

```
fixture:   monthly = $77.77
resolved:  2 [com.bookgate.premium.yearly=$29.99, com.bookgate.premium.monthly=$4.99]
```

**$4.99, not $77.77.** The catalogue is not being read from the file. It comes from the real App
Store, which holds $4.99. That settles it: the configuration never reaches the process, so
`SKTestSession` has nothing to intercept.

Re-run this any time the situation looks like it has changed — it takes one run and answers the
question outright. Remember to restore the price.

## What was checked, and what it showed

| Check | Result |
|---|---|
| **`.storekit` identifiers are valid UUIDs** | ❌ **Was broken** — all six were placeholders (`…-BOOKGATESTORE`); `G`,`K`,`O`,`R`,`S`,`T` are not hex. `appPolicies` was missing and the group had no localization. **Fixed** — but it did *not* change the skips |
| **Scheme path `../BookGate.storekit` resolves** | ✅ Correct as written. Resolution is relative to the `.xcodeproj` bundle, not the scheme's own directory. Thrise — same layout, `.storekit` beside the `.xcodeproj` — is written the same way |
| **A test plan carries the config** | ❌ Tried. `BookGate.xctestplan` with `defaultOptions.storeKitConfigurationFileReference`, run via `-testPlan BookGate`. Same skips, same error |

## The probe

`skipUnlessStoreKitIsLocal()` no longer infers anything. It used to set
`session.storefront = "JPN"` and check whether prices came back in yen — a proxy with two
false-negative modes (`Product.products(for:)` caches per process; storefront changes are not
synchronous), so it could report "not intercepting" about a session that was working.

It now asks directly: buy a product through the session and check the transaction landed. If the
session is inert this throws at once — no dialog, no hang. The skip message carries the verbatim
diagnostic:

```
buyProduct threw: notEntitled; products resolved: 2 [monthly=$4.99, yearly=$29.99]
```

**Keep the skip.** Without it these cases run against the real App Store, where `restore()`
reaches `AppStore.sync()`, raises a "Sign in to Apple Account" sheet, and stalls the run until its
timeout. That cost a full red 15-minute suite once already.

## Corrections to the record

- SubscriptionKit's `FINDINGS.md` lists this as an **OPEN BLOCKER** with four ruled-out
  hypotheses, none of which validated *BookGate's own* fixture — hypothesis 1 rebuilt
  SubscriptionKit's, a different file in a different repo. The fixture was in fact invalid. That
  was a real defect and is now fixed. It was **not** the cause of the skips.
- The scheme-path theory (that `../` should have been `../../../`) is **wrong**. `../` is what
  Xcode itself writes for a file beside the `.xcodeproj`.

## What this means

These 10 flows are **verified on device, or not at all**:

purchase · restore · expiry · refund · trial offered-then-withdrawn · storefront pricing ·
offline-with-live-subscriber

The kept test plan is harmless and is the documented mechanism, so if a future Xcode honours it
under `xcodebuild test`, the cases light up on their own. `Scripts/test.sh` runs the same 44
tests with or without `-testPlan`.
