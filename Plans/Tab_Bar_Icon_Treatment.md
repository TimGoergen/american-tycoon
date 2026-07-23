# Tab Bar Icon Treatment — Design Spec

**Status:** Planned (rides with the M3 art pass — needs the AI art pipeline for the colored
active-state icons). **Author:** Tim (reasoned out in a separate Claude chat), captured here
2026-07-23. **Scope:** Main interface bottom tab bar (Properties, Estate, Family History,
Settings) and related in-content icon usage.

---

## Current State

- Four tabs across the bottom of the main interface: **Properties**, **Estate**, **Family
  History**, **Settings**.
- The **Estate** tab button uses a full-color icon (purple gem). The other three tabs use
  black-and-white silhouette icons.
- Tab icons do not currently change treatment based on active/inactive state.
- A separate **red dot** badge system already exists on tab buttons to indicate new/noteworthy
  content.
- The property icon is reused inside content (e.g., purchase buttons showing `<icon> +5`) as an
  object/count label.
- The gem icon is reused inside the Estate tab as a currency indicator for legacy point amounts,
  displayed in full color.

### Problem

One colorful icon among three silhouettes is inconsistent and sends a false signal — permanent
color on a single tab reads as "something important here" even when nothing is new, competing
with the red dot system.

---

## Desired Future State

### Tab bar: hybrid active/inactive treatment

- **All four tabs** use the same visual language:
  - **Inactive:** black-and-white silhouette.
  - **Active:** full-color version of the same icon.
- The existing purple gem becomes the *active-state* icon for the Estate tab; a new silhouette
  version is created for its inactive state.
- New full-color active-state versions are created for Properties, Family History, and Settings.

### Signal separation (protect this going forward)

Each visual signal has exactly one job:

| Signal | Meaning |
|---|---|
| Icon color | "You are here" (active tab) |
| Red dot badge | "Something new over there" |

Color must **never** be used as a notification mechanism on tabs, and the red dot must never
indicate active state.

### Icon treatment rules (codified)

1. **Navigation icons (tab bar):** silhouette when inactive, colored when active. Uniform
   treatment across all tabs.
2. **Currency/resource icons (in content):** always full color wherever they represent an amount
   (e.g., legacy point displays in the Estate tab). Grayscale is reserved exclusively for a
   deliberate "can't afford" state, if ever implemented.
3. **Object/label icons (in content):** icons used as labels or counts (e.g., property icon in
   `+5` purchase buttons) match the visual weight of the surrounding UI. Silhouette is acceptable
   and preferred where the surrounding UI is flat/clean.
4. **Within-category consistency:** icons doing the same job must receive the same treatment.
   Different jobs may receive different treatments — that is intentional, not inconsistency.

---

## Implementation Notes

- **Structural parity:** silhouette and colored versions of each icon must share the same
  outline, dimensions, and anchor point. Only the fill treatment changes — the swap should feel
  like the same icon "lighting up," not a replacement.
- **Transition:** apply a short crossfade (~100–150 ms) between inactive and active states rather
  than an instant swap.
- **Red dot contrast:** badge stays at top-right of the icon, slightly overlapping the edge.
  Verify visibility against both silhouette and colored states; add a thin stroke (white or
  background-colored) around the dot if it vibrates against the purple gem or other colored icons.
- **Distinguishability check:** squint-test all four silhouettes at actual device size (~24–32 dp)
  to confirm outlines remain distinct.

---

## Asset Requirements

| Icon | Silhouette (inactive) | Full color (active) |
|---|---|---|
| Properties | ✅ Exists | 🔨 Create |
| Estate (gem) | 🔨 Create | ✅ Exists |
| Family History | ✅ Exists | 🔨 Create |
| Settings | ✅ Exists | 🔨 Create |

Colored active-state icons are a candidate for the AI art pipeline, using the existing
silhouettes as structural reference.

---

## Explicitly Out of Scope / Non-Goals

- No changes to in-content icon usage (property count labels, legacy point currency displays) —
  current treatments are correct per the rules above.
- No changes to the red dot badge system.
- Differentiating tab glyphs from in-content glyphs (e.g., separate "deed" icon for purchase
  buttons) was considered and deferred as a nice-to-have, not a fix.
