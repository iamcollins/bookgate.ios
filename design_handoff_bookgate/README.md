# Handoff: BookGate — reading-alarm app (iOS, phone)

## Overview

BookGate is an alarm for your book. At a set time each night the app rings, asks the user to
show the book to the camera, shields the apps that usually win that hour, and runs a quiet timed
reading session. Afterwards the user records a ~30-second spoken "takeaway". There is no free
tier: a 3-day trial, then a subscription.

This bundle covers the full app as designed: first-open onboarding (7 steps), the nightly flow
(alarm → camera gate → session → shield → complete → takeaway), Library / Book details /
Takeaways / Progress, and Settings → Reading. Both **dark (default)** and **light** themes, plus
German and Japanese samples of the four tightest screens.

> **Naming:** the product was renamed from *ReadBefore* to **BookGate** late in design. The
> wordmark, the shield's return button and the step-up copy carry the new name. If any stale
> string surfaces, BookGate is correct.

## About the design files

The files in this bundle are **design references created in HTML** — prototypes showing intended
look and behaviour. They are **not production code to copy**. The task is to recreate these
designs in the target codebase's environment (SwiftUI / React Native / whatever exists) using its
established patterns; if no codebase exists yet, pick the most appropriate framework and
implement there.

The HTML uses a small custom component runtime (`support.js`, `<x-dc>`, `<sc-if>`). Ignore it —
it only powers the interactive prototype and the review document. Everything you need is the
rendered markup, this README, and `BookGate Handoff.dc.html`.

Every screen has a **stable id** used throughout this document (`4b`, `10a`, `11d`, `12c`). Open
`BookGate.dc.html` in a browser and use the id badges to find a screen; each is a 372×806
phone frame (inner screen 346×780, corner radius 44, dynamic island 106×33 at top 24).

## Fidelity

**High-fidelity.** Final colours, typography, spacing, motion and copy. Recreate pixel-accurately
using the codebase's own primitives. Every value in this README is exact and taken from the
design source. Two things are deliberately placeholder and are called out in "Open items":
**prices** and **book-cover / app-icon artwork**.

The design target is a 393×852pt iPhone class device; the frames are drawn at 372×806 with a
346×780 content area. Treat the numbers as points, scale proportionally, and keep the
**44pt minimum tap target** that every interactive row in the design already honours.

---

## Design tokens — dark (default theme)

| Token | Value | Notes |
|---|---|---|
| `base` | `#100C09` | Screen floor behind the ambient |
| `ambient` | `radial-gradient(125% 80% at 50% -8%, #3B2A1A, #241A12 42%, #150F0B 78%, #100C09)` | "Lamp in the dark". Centre/size vary per screen, stops never do |
| `glow-warm` | `radial-gradient(circle, rgba(236,182,112,.26), transparent 62%)`, `filter: blur(32px)` | Drifting blob, 300–320px |
| `glow-copper` | `radial-gradient(circle, rgba(198,124,74,.2), transparent 62%)`, `blur(32px)` | Second blob. **Max two per screen** |
| `ink` | `#F7EFE4` | Steps: `.94` hero · `.85` strong · `.62` body · `.5` secondary · `.45` caption · `.3` disabled |
| `brass-label` | `#E9B872` | Uppercase section labels, active tab |
| `brass-value` | `#F2D6AB` | Values, links, chip text |
| `brass-object` | `linear-gradient(180deg, #F0C68F, #D79A56)` | Bookmark shapes, timeline nodes, filled days |
| `action` | `linear-gradient(180deg, #F2CB95, #DA9E58 58%, #C0863F)`, text `#241606` | One primary action per screen |
| `action-shadow` | `0 14px 30px -12px rgba(215,154,86,.7)`, `inset 0 1px 0 rgba(255,250,240,.5)` | |
| `glass-fill` | `rgba(255,240,222,.07)` quiet · `.085` card · `.10` prominent | |
| `glass-border` | `rgba(255,232,204,.14–.17)` | |
| `glass-blur` | `backdrop-filter: blur(20–24px)` | Shield barrier: fill `.13`, `blur(34px)` |
| `glass-inner` | `inset 0 1px 0 rgba(255,240,220,.2)` | Top highlight, always present on glass |
| `hairline` | `rgba(255,232,204,.12)` | Dividers, timeline spines |
| `shadow-card` | `0 18px 40px -20px rgba(0,0,0,.7)` | Covers go `0 16px 32px -12px rgba(0,0,0,.8)` |
| `shadow-frame` | `0 40px 80px -26px rgba(0,0,0,.55)` | |

**Radii:** screen 44 · sheet 28 · card 22–24 · button 17–20 · chip 13–15 · heatmap cell 9 ·
book cover `3px 7px 7px 3px` (real spine).

**Spacing rhythm:** screen padding `0 20px 16px` (26px on session/alarm). Vertical gaps
8 / 11–12 / 16 / 18 / 22–26. Section label → content = 11–12px. Divider margins 20–30px.

**Motion** (all CSS keyframes, ambient only — nothing animates on tap except the lamp):

| Name | Duration | What |
|---|---|---|
| `drift` / `drift2` | 18–23s ease-in-out infinite | Ambient blobs translate ±6% and scale 1→1.15 |
| `breathe` | 2.4s (dots) / 6s (alarm glow) / 12s (session lamp) | opacity .5→.95, scale 1→1.05 |
| `float` | 6s | Alarm's floating book, translateY -8px, rotate -1.5deg |
| `pop` | .34s ease-out | Cover-found confirmation |
| `sweep` | 2.6s | Camera scan line |
| `ticks` | 2.2s | Camera frame corners pulse |

Honour reduced-motion by **freezing** ambient animation, not removing the elements.

## Design tokens — light theme

Light is a **surface remap only**: no screen changes layout, spacing or copy between themes.
Reference screens `11a`–`11m`. Map whole rows; don't invent intermediate values.

| Token | Dark | Light |
|---|---|---|
| base | `#100C09` | `#F1E8DA` |
| ambient | `#3B2A1A → #150F0B` | `#FDF6E9, #F2E8D8 46%, #E4D8C4` (same geometry per screen) |
| glow | `rgba(236,182,112,.26)` | `rgba(226,168,98,.3)` |
| ink | `#F7EFE4` | `#231A12` — **every de-emphasised step ~0.08 heavier** than its dark twin; paper does not carry low alpha |
| brass text | `#E9B872 / #F2D6AB` | `#8A5A22` |
| brass object | `#F0C68F → #D79A56` | `#E9B872 → #C98F4A` (objects stay brass; only text darkens) |
| action | `#F2CB95 → #C0863F` on `#241606` | `#EFC08C → #D2954F 58% → #B87A2E` on `#2A1A08` |
| glass | 7–10% white fill | **68–78%** `rgba(255,252,246,·)`, border `rgba(255,255,255,.92)`, `inset 0 1px 0 #FFF` |
| hairline | warm white 12% | `rgba(35,26,18,.1)` — flips to ink, never stays white |
| recess / stripe | white 3–5% | `rgba(35,26,18,.035–.06)` — empty heatmap cells and placeholder stripes are ink-tinted |
| shadow | `rgba(0,0,0,·)` | `rgba(90,60,30,·)` at ~half the alpha |
| heatmap fill | brass `.35/.5/.7/.9` | `rgba(201,143,74,·)` at `.38/.55/.74/.92`; numerals flip to ink on the two darkest steps |

**Theme-independent both ways:** book covers (objects, not UI), the dynamic island, the camera
viewfinder (a live feed), and **badge pills** — a dark pill keeps light text, or becomes a brass
pill with `#2A1A08` text (see `11l` SAVE badge, `11m` RECOMMENDED badge).

**The night flow never follows the theme.** Alarm, camera gate, session, shield and complete stay
dark at all times — a white screen at 9pm defeats the product. Light applies everywhere else,
following the system setting, with a manual override in Settings.

## Typography

| Role | Face | Usage |
|---|---|---|
| Display / book | **Newsreader** 300–500 (serif) | Screen titles (31–33px/500), book titles, all large numerals (72px streak, 44px totals, 30px session clock), 13.5–15px italic asides |
| UI | **SF Pro Text / system-ui** 400–650 | Rows 15–16px/600, body 12.5–14.5px/400, buttons 15.5–17px/650, section labels **10px/600 uppercase, 1.4px tracking** |
| Data | ui-monospace | Timecodes only (`0:16 / 0:34`), tabular numerals |

Substitute Newsreader with the codebase's serif only if one already exists; otherwise ship
Newsreader. Japanese falls back to **Noto Serif JP** (titles) and **Noto Sans JP** (UI) at the
same sizes.

## The motif

A **brass bookmark**: a ribbon with a notched foot,
`clip-path: polygon(0 0, 100% 0, 100% 100%, 50% 74%, 0 100%)` (session/complete variants use
`76%`/`78%`). It is the Today tab icon, the streak chip, the takeaway timeline node, and the
filled day in the week row. **It is never decorative** — a drawn bookmark always means a night
that was read. Sizes: 10×14 chip · 14×19 tab · 19×26 week row · 26×36 streak card · 38×52 hero
· 42×56 shield.

---

## Screens

Navigation: a four-tab bar (**Today · Library · Takeaways · Progress**) as a floating glass
panel, `border-radius: 26px`, `padding: 11px 20px 5px`, fill `rgba(255,240,222,.07)`, border
`rgba(255,232,204,.14)`, `blur(20px)`, `box-shadow: 0 -1px 16px rgba(0,0,0,.35)`. Inactive icons
`rgba(247,239,228,.4)`, active `#E9B872`. Home indicator 130×5, radius 3, `rgba(247,239,228,.28)`,
9px below the bar. Settings opens from a three-dot control in the Today header.

### 1. Today — `4b` (light `2a`)
The book is the screen. Cover bleeds off the top (424px tall, `linear-gradient(155deg,#6d5340,#8a6a4e 40%,#5d4635)`
with a spine line at x=14 and a scrim `linear-gradient(180deg,rgba(16,12,9,.55),transparent 24%,rgba(16,12,9,.34) 66%,#100c09)`).
Over it: a wordmark row (`BOOKGATE`, 10.5px/600, 1.6px tracking, ink .75) with the streak chip
(bookmark + count, `rgba(20,14,9,.38)` pill) and the three-dot Settings control; then a bottom
glass sheet (`radius 28`, fill `.10`, `blur(30px) saturate(130%)`) carrying:
- **Tonight row** — bordered, chevron, `TONIGHT` label in brass, `9:00 PM · 15 min` at 22px
  Newsreader, `3 apps shielded · tap to change`. Opens the length sheet. Must look tappable (`6b`).
- **Primary action** — "Begin Reading Now", 56px, action gradient.
- **Last takeaway row** — play circle, one-line quote, duration. Plays inline (`3d`).

Variants: **missed yesterday** `1f` — one calm sentence, streak chip goes quiet, no red, no reset
drama. **Already read today** — action becomes secondary.

### 2. Tonight's length sheet — `5c`
Bottom sheet over a blurred Today. **Length only** — apps and time live in Settings. Seven
durations (5 · 10 · 15 · 20 · 30 · 45 · 1h) as a chip grid; selection is filled brass with dark
ink, others hairline. Changes **tonight only**.

### 3. Alarm — in `1a` (DE/JA `12c`)
Full-bleed, ambient centred at 22%. `READING ALARM` pill with a breathing dot; `9:00` at 74px
Newsreader with `PM` at 20px; the book cover floating (`float` animation) with a soft shadow
ellipse; "It's time to read." / "Your book is waiting."; three stacked full-width actions:
**Show My Book** (58px, action), **Snooze 10 minutes** (52px, glass), **Skip Today** (44px, text).
Never place two of these side by side — see Localisation.

### 4. Camera gate → cover found — in `1a`
Viewfinder plate with a brass-cornered frame (26px corners, 3px, `ticks`), a sweeping scan line,
hint copy, and a **manual fallback always visible**. On detection: brass check circle with `pop`,
cover name, then auto-advance. The viewfinder is a live feed — it is never themed.

### 5. Post-scan settling — `4c` (see `3e`)
No countdown. Cover found, shield up, exactly one decision: read now, or hear last time's
takeaway first. ~6-second beat, then the session begins.

### 6. Session — `4a` (light `2b`, DE/JA `12a`)
The screen's most important rule: **the top is empty on purpose**. A lamp glow
(`radial-gradient(circle, rgba(240,198,143,.42), rgba(215,154,86,.14) 46%, transparent 68%)`,
`blur(26px)`, `breathe 12s`) sits at ~150px; **the glow shrinks as the session burns down — that
is the progress indicator**. Inside the light: book title 27px Newsreader (ink .94),
`CHAPTER 9 · 3 APPS SHIELDED` at 12px/1.4px tracking (ink .5), a 34×1 rule, and an italic line
(15px, ink .62). Lower third: remaining time at 30px Newsreader **ink .52** with tabular numerals,
`LEFT OF 45 MINUTES` at 10.5px (ink .44). Actions are quiet text: **Finish Session** (ink .62),
**End Early** (ink .44). No progress bar, no ring, no edge track.

### 7. Overtime — `3f`
Entered from "Keep Reading" at goal. The goal ring sits full and a brighter arc counts the extra
time; primary action becomes a filled button.

### 8. Shield barrier — `1g` (light `2c`, DE/JA `12b`)
Drawn over the blurred, colourful app the user tried to open. Vellum panel: fill
`rgba(255,240,222,.13)`, border `rgba(255,240,222,.26)`, `blur(34px)`, `radius 30`, inset at
`left/right 18, top 88`. Brass bookmark, "Reading time is active." (24px/1.28 Newsreader),
"Finish your session before opening this app.", **Return to BookGate** (50px action), and
**Emergency access** as a quiet text row — always present, never styled as a punishment.
A "strong" variant exists (fill `.22`, `blur(60px) saturate(170%)`) — pick one and ship it.

### 9. Session complete → takeaway — in `1a` (light `2c` right)
"You read today." + minutes and streak in a glass panel; a brass-tinted prompt panel
(`rgba(233,184,114,.14)`, border `rgba(184,122,46,.22)`) explaining why to record; **Record a
Takeaway** (52px action) and **Not now** (44px text). Recording is optional every single time and
skipping never breaks the streak. The recorder has three states: idle → recording (live waveform)
→ review (scrub, re-record, save).

### 10. Step-up prompt — `5b`
Shown **only** after a clean week at the current length, immediately after a session, never as a
push. Compares `5 NOW → 10 SUGGESTED` at 38px Newsreader, one reassuring italic line, then
**Move to 10 minutes** (56px action) and **Five is working — keep it** (52px glass), with
"Either way, tonight is already read." Declining is a first-class choice and is not asked again
that week.

### 11. Library — `7a` (light `11a`)
`Library` title 33px Newsreader + **Add** chip. `READING NOW` card (radius 24, glass .085) with a
70×104 cover, title/author, takeaway + session counts, chevron → Book details. Then shelves:
**NEXT UP** (84×122 covers in a row, plus a dashed "Add a book" tile), **PAUSED** (60px row),
**FINISHED** (56×76 covers at 72% opacity). Takeaway counts sit where page counts would in a
tracker — that is the point.

### 12. Book details — `7b` (light `11b`)
Cover-derived header (300px, fades to base). Back chevron → Library. 104×154 cover, title 25px,
author, `READING` status chip, "Since 12 July · 9:00 PM nightly". Stats panel: sessions / read /
takeaways (27px Newsreader, brass on the takeaway count). Then **MY TAKEAWAYS** — a timeline on a
hairline with brass bookmark nodes, each entry day + duration + italic quote — and **Play all N**.
Footer: **Pause reading** / **Mark finished**. Schedule is shown, not editable (it is app-wide).

### 13. Takeaways — `7c` (light `11c`)
`Takeaways` + "23 recordings · 11 minutes of you". Per-book header row with **Play all**. The
playing row expands **in place** into a 42px play/pause circle, `day · date`, `0:16 / 0:34`, and a
24px waveform (3px bars, 2.5px gaps; played bars brass, remaining ink .2 / light ink .26).
Newest first, grouped by book.

### 14. Progress — month `10a` (light `11d`)
Three facts only. Compact streak row (bookmark, `17` at 42px, `NIGHTS IN A ROW`, longest at
right). Month grid: header with `‹ August 2026 ›`, weekday letters, then 7-column cells 36px tall,
radius 9, gap 6 —
**fill weight = session length** (`.35/.5/.7/.9` brass), **miss = 1.3px hairline outline**,
**today = brass tint + brass border + breathing dot**, **future = numeral only, no cell**.
Below: "20 of 23 nights · 5h 10m" and a short→long legend. Then `SINCE MAY` totals and a **Year**
chip. Read-only: nothing on this page is tappable except the tab bar, the steppers and the chip.

### 15. Progress — year `10b` (light `11e`)
Back chevron → month. Twelve rows, one per month: label, a strip of one 14px mark per night
(gap 2), night count at right. Same fill weights; months before the user started are blank
(`rgba(255,240,222,.045)` / light `rgba(35,26,18,.06)`), months ahead fainter. "Best month: July,
28 nights" + legend.

### 16. Settings → Reading — `6a` (light `11f`)
Back chevron (currently to Today — **needs the Settings root**). Rows on paper/glass: default
length (current value shown, grid one tap away), alarm time `9:00 PM`, rest day, and the two rules
stated plainly (weekly step-up, rest day). Individual rows are not wired in the prototype.

### 17. Onboarding — 7 steps, order is normative
`8a` welcome → `8b` how it works → `8c` scan your book (skippable) → `5a` length →
`8d` shielded apps → `8e` permissions → `8f` trial.
Light: `11g`, `11h`, `11i`, `11m`, `11j`, `11k`, `11l`.

- **Welcome** — brass bookmark mark, "Make reading happen.", one button, quiet **Restore**.
- **How it works** — four glass cards, verb-first, numbered in brass.
- **Scan your book** — barcode is the fast path and gets the frame; search / photo / manual are
  quiet rows. Skipping is allowed.
- **Length** — seven durations, **5 preselected** and badged RECOMMENDED; 1h present but plainly
  the outlier. App-wide, not per book.
- **Shielded apps** — categories first (one tap covers a habit), then individual apps as striped
  placeholder tiles.
- **Permissions** — camera, notifications, screen time; each says what it is for in the user's
  terms and is granted **one at a time** so a refusal doesn't kill the flow.
- **Trial** — timeline stated before the price (today / day 2 email / day 3 charge), yearly
  preselected, then the plan cards and one CTA.

**Only four steps carry the numbered dots** (scan · length · apps · permissions) so setup never
feels like seven. If a step is added, removed or reordered, **the dots and their captions must
move with it.** The paywall goes **last, after setup**, so the trial starts against a real book,
time and app list.

---

## Interactions & behaviour

**Navigation graph** (as wired in prototype `1a`):

```
Today ──tab──> Library ──card──> Book details ──chevron──> Library
     ──tab──> Takeaways
     ──tab──> Progress ──"Year"──> Year strip ──chevron──> Progress
     ──header dots──> Settings › Reading
     ──Tonight row──> length sheet ──> Today
     ──Begin Reading / alarm──> camera gate ──> post-scan ──> session
session ──goal──> [Keep Reading → overtime] | complete ──> takeaway recorder
        ──> (clean week ? step-up : Today)
onboarding: welcome → how it works → scan → length → apps → permissions → trial → Today
```

**Rules that are product, not styling:**

1. **Session length is one app-wide setting**, not per book. Asked once at first open (5 min
   preselected); permanent home is Settings → Reading. The nightly sheet changes tonight only.
2. **The default earns its way up.** After a clean week at the current length, offer one
   increment, once, right after a session (5 → 10 → 15 → 20 → 30 → 45 → 60).
3. **A miss is stated once.** No red, no reset animation, no catch-up prompt. Missed nights are
   hairline outlines; days that haven't happened are drawn as nothing.
4. **Heatmap fill weight is session length, never a score.** Four steps; a short night still
   counts as a night.
5. **Progress shows three facts** — streak, current month, total time. No averages, no
   projections, no "best day", no percentages, no goal ring.
6. **One primary action per screen.** Everything else is a quiet row or a text button.
7. **Every button is a min-height box with centred wrapping text** (44pt min; 48–58 typical).
   Never a fixed single-line height.
8. **Recording a takeaway is optional every time**; "Not now" carries no penalty.
9. **The word "reminder" never appears**, and nothing shames the user.
10. **The shield always offers emergency access.**

**Transitions:** screen changes are standard push/present for the app shell; the night flow
(alarm → camera → session) is a full-screen sequence with cross-fades. The camera "cover found"
state uses `pop` (.34s) before advancing. The session lamp interpolates its radius continuously
from 100% to ~12% over the session duration.

## State

| State | Type | Notes |
|---|---|---|
| `screen` | enum | today, sheet, alarm, cam, ready, session, overtime, shield, complete, takeaway, stepup, library, book, takeaways, progress, year, settings, onb1…onb7 |
| `defaultLength` | int (min) | App-wide. 5/10/15/20/30/45/60 |
| `tonightLength` | int | Overrides tonight only, resets after the session |
| `alarmTime` | time | Default 9:00 PM |
| `shieldedApps` | list | Categories + individual apps |
| `secondsLeft` / `overtimeSecs` | int | Drives the lamp radius and the readout |
| `streak`, `readToday`, `missedYesterday` | int / bool | Today + Progress states |
| `cleanWeek` | bool | Gates the step-up after the takeaway step |
| `takeaways[]` | records | `{bookId, date, durationSec, audioUrl, transcript?}` |
| `books[]` | records | `{id, title, author, cover, status: reading/next/paused/finished}` |
| `subscription` | enum | trial(dayN) / active / lapsed |
| `theme` | enum | system / light / dark — **ignored by the night flow** |

Data needed: book lookup by barcode/ISBN (title, author, cover), local audio recording +
playback, Screen Time / app-shielding APIs, local notifications for the alarm, StoreKit for the
trial and subscription.

## Localisation

Samples: `12a`–`12d` (session, shield, alarm, paywall) in German and Japanese, with **no layout
changes made to accommodate them**.

- **Buttons wrap, never shrink.** German "10 Minuten später erinnern" fits only because the
  alarm's actions are full-width and stacked. Never place two buttons side by side on a decision
  screen.
- **Japanese type:** Newsreader has no CJK. Titles → Noto Serif JP, UI → Noto Sans JP, same sizes
  and weights. Set `font-style: normal` on CJK — synthetic oblique is not italic.
- **CJK breaks are authored.** No spaces means auto-wrap breaks in the wrong place; titles and
  shield copy ship with manual break hints in the string.
- **Clocks:** 24-hour with "Uhr" in German; Japanese drops the meridiem. Session readouts and
  heatmap numerals stay latin numerals in every locale, in the same font.
- **Prices localise format** (`29,99 €` vs `€29.99`); plan-card numerals never change font.
- **Where German cannot fit, shorten the string** — do not shrink type or grow the screen. The
  paywall needed exactly this twice (`29,99 €/Jahr · 2,50 €/Monat`,
  `Danach 29,99 €/Jahr. Jederzeit kündbar.`).
- **The product name is not translated.** "Zurück zu BookGate" / "BookGate に戻る". Note the
  shield button is the tightest place the name appears — a longer name would force it to wrap.
- **These samples do not prove the copy is good.** The German is translation-quality, not native,
  and the trial timeline is **regulated wording**. Native + legal review is required per market
  before either locale ships.

## Assets

Everything in the design is drawn in CSS — there are **no image assets**. Two categories are
deliberate placeholders and are drop-in replacements that change no layout:

- **Book covers** — typographic placeholders with fictional titles (The Long Field, Winter
  Grammar, The Salt Ledger, Northline, Ordinary Machines, A Borrowed Country) drawn as gradient
  rectangles with a spine line. Replace with real cover art at the same aspect (70×104, 84×122,
  104×154, 118×174, 56×76, 30×44).
- **Shielded app icons** — striped tiles (56×56, radius 16). Replace with real icons from the
  Screen Time picker.

Icons (tab bar, chevrons, play, waveform, camera frame) are CSS shapes; rebuild them with the
codebase's icon set or as vectors — match weight (1.5–1.8px strokes) and size.

There is **no app icon or logotype** designed yet. The wordmark is set in system-ui 600 at
1.6–2.4px tracking, uppercase — it is typography, not a logo, and the rename to BookGate means a
real mark still needs to be commissioned.

## Open items — must be resolved before/while building

1. **Prices are placeholders.** Every number on `8f` / `11l` (`€29.99` yearly, `€5.99` monthly,
   `SAVE 58%`, `€2.50 a month`) is invented for layout. Use real store pricing per market and
   **compute the savings badge**, never hard-code it. Confirm whether an intro offer or lifetime
   tier exists — neither is designed.
2. **Onboarding order and length need product sign-off** (see step dots rule above).
3. **All on-screen labels are design copy.** Titles, row labels, captions, empty states,
   permission explanations and legal footnotes need final product/legal wording. Re-check the four
   tightest screens (session, shield, alarm, paywall) after any copy edit.
4. **Trial-expired / resubscribe is not designed.** Blocked on policy: hard wall (shield off,
   library read-only) or sessions still run unshielded? With no free tier this screen decides
   whether lapsed users return.
5. **Settings root is not designed.** Only the Reading sub-page exists; the header dots open it
   directly and its back chevron has nowhere to go.
6. **Permission-denial paths** are described, not drawn (no camera → manual start only; no
   notifications → no alarm).
7. **Accessibility** unspecified: Dynamic Type behaviour, VoiceOver labels for the bookmark and
   heatmap graphics, reduced-motion (freeze the ambient, don't remove it).
8. **App icon / logotype** does not exist (see Assets).

## Files in this bundle

| File | What it is |
|---|---|
| `BookGate.dc.html` | **The design source.** All screens, every turn of review, id-badged. Screen `1a` is a clickable prototype of the whole app; its side rail jumps to any screen and speeds the session clock. Open in a browser. |
| `BookGate Handoff.dc.html` | The printable design-handoff document (tokens, screen map, behaviour rules, localisation, open items). Same content as this README, formatted for print. |
| `support.js` | Runtime for the two HTML files. Not part of the product. |
| `doc-page.js` | Print shell used by the handoff document. Not part of the product. |

To view: open `BookGate.dc.html` in a browser, scroll to turn 1 (`1a`) for the prototype;
turns are newest-first, so the most recent work is at the top.
