# American Tycoon — Art Style Guide

**Version:** v0.1
**Date:** June 12, 2026
**Companion to:** GDD v0.2 §12 (direction), Mechanics Spec v0.1 (what needs depicting)
**Source of truth:** the approved ATM hero draft (this guide codifies its choices)
**Pipeline:** Claude-generated SVG (vector pieces) · Copilot/Gemini raster (backdrops) · manual pass in Inkscape/Photoshop (palette grading, halftone unification)

---

## 1. The Palette (exact, exhaustive)

Core four (GDD §12) plus the accents the ATM draft established. **No colors outside this table** — the limited palette is the consistency engine across vector, raster, and UI.

| Role | Name | Hex |
|---|---|---|
| Field / paper | Cream | `#F4ECD8` |
| Primary accent / urgency | Ketchup Red | `#B5402A` |
| Structure / ink / chrome | Navy | `#1D2D50` |
| Warmth / glow / sunbursts | Mustard Gold | `#E3B23C` |
| Screens, chrome trim | Atomic Teal | `#9FD8D4` |
| Currency, bills, success | Money Green | `#7DA87B` |
| Deep shadow on navy | Ink Navy | `#0D1830` |
| Deep shadow on red | Brick | `#8E2F1E` |
| Highlight on red/navy | Pale Gold | `#F0D49A` |

Rules: shadows are **darker palette members, never black**; highlights are cream or pale gold, never white. Raster backdrops get graded to this table in the manual pass (Photoshop: gradient map or selective color toward the nine values).

## 2. Typography

The ATM draft used Georgia as a stand-in; production picks era-true free fonts (Google Fonts, all embeddable in Godot):

| Use | Style | Candidates |
|---|---|---|
| Slogans, display | Heavy slab serif | Alfa Slab One, Rozha One |
| Script exclamations | Brush/sign-painter script | Yellowtail, Pacifico |
| Small print, taglines, documents | Bookish serif, italic for taglines | Libre Baskerville |
| UI numbers/stats | Condensed gothic | Oswald, Archivo Narrow |

Rules: letterspaced ALL-CAPS for institutional lines ("THE AUTOMATED TELLER"); italic serif for taglines in quotes; exclamation points are load-bearing; the narrator never uses a sans-serif (sans is reserved for UI stat readouts only).

## 3. Composition Grammar — The Property Hero ("Full Advertisement" format, approved)

Every hero is a complete little poster. Standard anatomy, top to bottom:

1. **Rotated slogan banner** (ketchup red, ±3–5°, forked ribbon ends in brick, halftone overlay) — the pitch, with a letterspaced sub-line in pale gold.
2. **Sunburst** behind the subject (mustard, 12 rays, ~50% opacity over cream).
3. **The subject** — the scheme rendered as a gleaming consumer product (see §5), navy-dominant, cream linework, teal screen/glass.
4. **Flying money garnish** (green bills, navy outline, scattered rotations) or scheme-appropriate equivalent.
5. **Grounding shadow** (navy ellipse, ~18% opacity).
6. **Footer plate** (navy band): product name in caps + italic tagline in mustard — the deadpan kicker.
7. **Double frame:** navy outer stroke, thin red inner stroke at 50%.

Texture: halftone dot pattern over field and large fills (navy dots on cream ~10% opacity; red dots on red ~16%). Halftone is the signature unifier — it goes on everything, vector and raster alike.

## 4. The Rule of Sincerity (binding, from GDD §1.2)

The art never winks. Every scheme is advertised the way a 1955 agency would sell a refrigerator: proud, gleaming, family-friendly. Crime gets the same sunny treatment as appliances. The *only* editorial channel is deadpan accuracy — the tagline states a true thing in a proud voice ("It pays to own the machine"). No skulls, no shadows-of-menace, no visual irony.

## 5. The Twelve Heroes — Subject & Slogan Concepts (draft copy, content-pass to finalize)

| # | Property | Subject treatment | Slogan (draft) | Tagline (draft) |
|---|---|---|---|---|
| 1 | ATM | Gleaming navy machine, teal screen, bills | "Cash, Instantly!" | "It pays to own the machine." |
| 2 | Money Tree | Potted sapling, bills as leaves, picket fence | "It Does Grow on Trees!" | "Plant once. Pick forever." |
| 3 | NFTs | Ornate frame around pixelated nothing, certificate seal | "Tomorrow's Heirlooms, Today!" | "Certificate of authenticity included." |
| 4 | Tax Increment Financing | Ribbon-cutting before empty lot, blueprints | "The Neighborhood Pays for Itself!" | "Public money. Private vision." |
| 5 | Cross Border Distribution | Cheerful cargo truck at sunset border | "Import. Export. Prosper." | "No questions. Just answers." |
| 6 | Money Laundering | Maytag-style washer, bills in the drum | "Freshness You Can Bank On!" | "Whites, colors, and greens." |
| 7 | Day Trading | Man at ticker, rocket chart, coffee | "Buy Low. Sell High. Before Lunch!" | "The market rewards the bold." |
| 8 | Flipping Houses | Identical house ×2, second with bow + bigger price | "Every Home Has a Price!" | "Buy it. Paint it. Double it." |
| 9 | Multi Level Marketing | Tupperware-party tableau, pyramid of smiling guests | "Success Is a Party!" | "Be your own boss — and theirs." |
| 10 | Hedge Fund | Marble lobby, golden hedge topiary | "Other People's Money, Working for You." | "Two and twenty, guaranteed.*" |
| 11 | Legislative Assets | Handshake under bunting, capitol dome | "Good Government Is a Sound Investment." | "Your voice, amplified. Theirs, retained." |
| 12 | Executive Assets | Oval desk, pen poised over document | "Leadership, Acquired." | "The handshake that signs itself." |

## 6. Staffer Cards (M3)

Format: portrait bust in a circular cream medallion on navy card; name plate (slab serif) + role. Faces: simplified flat-vector 50s-ad people — dot eyes, confident smiles, period hair; skin tones from a warm limited ramp added to §1 when first needed. Same halftone, same double frame.

**Epoch reskins (updated 2026-06-16):** staffing is now an epoch-keyed *tier track* (GDD §6.1), so each property's staffer is **reskinned per epoch** — Earth's ATM Technician becomes the Luminari *Photon Teller*, the Geth *Autonomous Teller Unit*, the Mycelium *Spore-Cash Node*, etc. Plan the asset bill accordingly: ~12 Earth staffers × the shipped epochs (Earth + 5 aliens = ~72 cards), each carrying its civilization's visual flavor over the same medallion frame. The **quiet ratio** stat pair (hire cost vs. lifetime revenue) is now a *deferred* satirical addition (GDD §6.4), not a required element of the card.

**Alien property types (added 2026-06-28, GDD §5.5 site 2):** the ladder now has **17** properties — the 12 Earth rows plus 5 alien property types, one opened at each alien First Contact: **Photon Exchange** (epoch 2), **Data Foundry** (3), **Spore Bank** (4), **Prism Vault** (5), **Time Bank** (6). Each needs its own §5 hero card plus a staffer reskin for the epochs in which it's staffable (Photon Exchange epochs 2–6, Data Foundry 3–6, … Time Bank 6 only — ~15 alien-property staffer cards on top of the 72 above). Until that art lands, each ships a placeholder accent color (a per-property hue, the documented §1 exception — see `PropertyConfig.accent_color`) and the lettered-medallion fallback. Prompt themes: light/energy (Photon Exchange), machine/data (Data Foundry), fungal/spreading (Spore Bank), crystal/faceted (Prism Vault), time/clockwork (Time Bank).

## 7. Backdrops (raster pipeline, M3)

6–8 per planet, crossfading at net-worth thresholds (GDD §12). Generation guidance for Copilot/Gemini prompts: *"1950s American advertisement illustration, flat color lithograph print style, limited palette (cream, brick red, navy, mustard), halftone texture, [SCENE], no text, wide portrait composition, muted matte finish"* — then manual grade to §1 palette and halftone overlay. Scene ladder: Main Street diner → suburban boomtown → downtown skyline → penthouse terrace → marble lobby → Capitol dome at golden hour.

**Live play-field background (added 2026-06-25).** The Main screen now renders a full-bleed image behind the UI, clipped to the phone-screen rounded corners and shared by all four tabs (it is intentionally hidden under the full-screen overlays — will ceremony, dev panel, minigames, first contact). The shipped image is a green prairie (Earth) — a placeholder ahead of the graded 1950s-ad backdrops above. **Planned: the background swaps per epoch after each first contact** — Earth's prairie gives way to a Luminari / Geth / Mycelium / etc. scene, the play-field's visual echo of the per-epoch staffer reskins in §6. So this backdrop set is **epoch-keyed, not just net-worth-keyed**: one (eventually a small crossfading set) per shipped civilization, swapped on `EpochState` advancement.

## 8. UI Chrome

- Cream field everywhere; navy ink for structure; red reserved for **actionable** (buy buttons, frenzy pop) — red = "spend/act," never decoration.
- Buttons: navy slab-serif label on mustard plate, navy border, hard offset shadow (no blur — print, not web).
- The income/sec hero stat: condensed gothic numerals, navy, on a cream ticket plate with red frame.
- Frenzy bar: mustard fill, sunburst cap at full; burns down in red.
- Progress sliders (milestone bands): teal track, navy fill, mustard milestone tick.
- Documents (will, ledger, mail, certificates): cream paper, Baskerville, navy rules, red wax-seal accents. The (Hon.) titles get a too-ornate gold border.

## 9. Motion Language (M1-relevant — the acceleration is the message)

- **Cycle spin** is the core animation: property dial/drum rotation locked to cycle progress. Speed reads literally — milestone halvings double the visible RPM until the blur threshold (motion-streak swap above ~3 rev/sec).
- **Purchase delta**: income/sec stat does a single hard "stamp" scale-pop (1.0→1.12→1.0, ~120ms) + flashed `+38%` in red. Print-press energy: things *stamp*, they don't bounce or ease elastically.
- **Frenzy pop**: full-screen mustard sunburst flash, one frame of halftone invert.
- **Money collect**: 2–3 bills arc from property to the stat ticket.
- Rule: animations are **mechanical, not bouncy** — pistons and presses, not jelly. Mid-century machines, not mobile-game squash.

## 10. Production Workflow

1. Claude generates SVG against this guide (prompt template: *"American Tycoon hero card, §3 anatomy, palette table §1, subject: [row from §5], sincere 50s ad voice"*).
2. Manual pass in Inkscape: kerning, curve cleanup, palette audit.
3. Export PNG @2× target resolution for Godot import (or import SVG directly; rasterize at import — test both in M1).
4. Raster backdrops: generate → grade → halftone → crop to portrait safe area.
5. Every approved asset's source SVG lives in the repo under `/art/src/` — assets are code.

## 11. Open Art Items

1. Final font selections (license-check, render-test in Godot).
2. Skin-tone ramp for staffer cards (first needed M3).
3. Slogan/tagline copy lock (content pass, with narrator copy — GDD §14.9).
4. App icon (the ATM? the dollar-sign sunburst? decide M3).
5. Final Dollar ceremony set pieces (parade, certificate, the Letter) — bespoke, M4.
6. Planet Two visual modifier (palette shift? new backdrop set?) — M4 pipeline proof.
