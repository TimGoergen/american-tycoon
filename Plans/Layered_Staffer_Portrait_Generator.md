# Layered Staffer Portrait Generator

**Status:** PROPOSED — design only, no code. **M3-milestone territory** (the art pass, §13);
this is "plan now, build later," not something to land on the current UI branch. Raised by Tim
2026-07-01.

**GDD reference:** §6.5 (Staffer portraits — the layered generator), §12 (asset bill).
**Related plans:** `Epoch_Staffing_System.md` (the tier system these portraits reskin),
`First_Contact_Property_Reward.md` (the alien property rungs that also need portraits).
**Decided by:** open — the three decisions in §7 are Tim's to make before any build.

---

## 1. The design goal

Give every staffer a distinct, recognizable **face** instead of the single gray silhouette
placeholder every automated property shows today — and do it **procedurally** so we don't have to
hand-author ~100 portraits. A "layered portrait generator" composites each face at runtime from a
stack of art layers (base, hair, eyes, clothing, accessory…), picking one variant per layer from a
seed, so a handful of parts yields thousands of combinations.

The payoff is thematic: a Luminari *Photon Teller* should not look like a Geth *Autonomous Teller
Unit*. Distinct faces per role reinforce the epoch fantasy (§6.1's "re-skinned per epoch") at a
glance, and make the property ladder feel populated rather than placeholder.

## 2. Where portraits stand today (as-built)

- `PropertyConfig.manager_portrait: Texture2D` — one static portrait per property, **all currently
  null**. Explicitly deferred to M3.
- `ManagerCircle._draw()` draws that texture into the accent-colored disc when present, else falls
  back to the generic dark-gray `headshot.svg` silhouette.
- Art convention already in use: icons are authored **white** and tinted at draw time
  (`draw_texture_rect(tex, box, false, color)`). One silhouette serves any palette — the generator
  leans hard on this.
- The circle calls `queue_redraw()` every frame, so portraits **must be pre-baked**, never
  recomposited per frame.

## 3. The scope wrinkle — this is not a stock avatar generator

A "staffer" is not one identity. It is a **role slot** = (property rung × epoch tier):

- **17 property rungs** (12 Earth + 5 alien property types, §5.5 / First Contact reward)
- **× 6 epoch tiers** (Earth + Luminari, Geth, Mycelium, Quartzite, Chronophage)
- **≈ 102 role slots**, and the six tiers are wildly different visual themes: humans, then
  light-beings, machines, fungal hive-mind, crystalloids, time-eaters (`EpochCatalog.gd`).

A human hair-and-glasses part library covers exactly **1 of 6** epochs. The generator therefore
needs a **per-tier part set**, and that art multiplication — not the code — is the whole cost.

## 4. The three components

### 4.1 `PortraitGenerator` (the small part — ~1–2 days of code)

A static helper / autoload:

```
PortraitGenerator.get_portrait(property_index: int, tier: int, size: int) -> Texture2D
```

- **Seed deterministically** from the role — e.g. `hash(property_index, tier)` (optionally folded
  with the generation number; see §7). A `RandomNumberGenerator` with that seed picks one variant
  per layer. Determinism is non-negotiable: the face must be stable across the constant `_draw`
  redraws, across the row / Will screen / obituary, and for the run's lifetime.
- **Pick** one variant per layer from the tier's layer set, plus palette colors (skin/hair/accent).
- **Bake once** into an `ImageTexture` and **cache** it, keyed by `(property_index, tier, size)`.
  Callers only ever look up a cached texture.
- `PropertyConfig.manager_portrait`, when set, **overrides** the generator — an escape hatch for a
  hand-authored hero face if any role earns one.

### 4.2 Compositing technique — the SubViewport "paper-doll" bake

The clean Godot way to stack tinted layers:

1. Create a `SubViewport` at the target size, transparent background.
2. Add ordered `TextureRect`s (or `Sprite2D`s), one per layer, each with its `modulate` tint.
3. Render **one** frame; grab `viewport.get_texture().get_image()` → wrap in `ImageTexture`.
4. Free the viewport.

Tinting is free on the GPU this way. The GDScript alternative — walking pixels to tint an `Image` —
is far slower and should be avoided. Bake **lazily on demand** (only the ~dozen visible rungs ever
bake) and cache; memory for ~100 small circular textures is trivial.

Circular framing is already handled by `ManagerCircle` (the accent disc + navy ring); layers just
need transparent corners and to draw within the radius.

### 4.3 The art — ~90% of the real effort

**Earth (tier 1) human taxonomy** (standard paper-doll layers, bottom to top):

| Layer | Role | Notes |
|---|---|---|
| base / skin | head + shoulders shape | white-authored, tinted by a **skin palette** |
| hair | hairstyle | tinted by a **hair palette**; include a "none" variant |
| brows / eyes | facial features | small set; carries most of the "personality" |
| facial hair | optional | include "none" |
| collar / clothing | 50s-ad attire | ties, lab coats, suits — matches §12 vocabulary |
| accessory | glasses / hat / headset | optional; include "none" |

Even **5 variants × 6 layers**, tint-varied, yields thousands of recognizable Earth faces.

**The alien tiers (2–6)** are where a full human-style library ×5 would balloon the art bill for
little marginal charm. Recommended alternative: a **cheaper, more abstract per-epoch treatment** —
a tier silhouette shape (light-being aura, machine visor, fungal cap, crystal facet cluster,
hourglass form) + procedural accent patterns in that epoch's palette (`PropertyConfig.accent_color`
already gives each property a hue). Aliens are abstract by nature — a hive-mind doesn't need
eyebrows — so we get strong thematic variety for a fraction of the human-taxonomy art.

## 5. Where it plugs in

- `ManagerCircle.set_state()` / `_draw()` — swap the "authored `manager_portrait` or fallback icon"
  branch for "override texture if set, else `PortraitGenerator.get_portrait(index, tier, size)`."
- `PropertyRow._refresh()` already knows `prop_index` and `_prop.staff_tier` — pass both to the
  circle so it can request the right role's face.
- Reuse anywhere else a staffer appears (Will/retention screen, obituary, any future staffer card).

## 6. Recommended phasing

1. **Prove the pipeline on Earth humans (tier 1).** Build `PortraitGenerator`, the SubViewport
   bake, the cache, and one Earth part set (even 3–4 variants/layer). Wire it into `ManagerCircle`.
   This is the vertical slice — and it's what players stare at for a long stretch **before** first
   contact, so it's the highest-value slice.
2. **Add the abstract alien treatment** for tiers 2–6, one epoch at a time, sharing the same
   generator + bake with per-tier part sets / procedural rules.
3. **Polish:** more variants, hand-authored hero overrides for flagship roles (Chief of Staff,
   Exchange Directors), optional per-generation reseed for dynasty freshness.

Rationale: full layered generation across all six human-style epochs is where scope explodes; the
abstract alien path keeps epochs 2–6 affordable while still distinct.

## 7. Open decisions (Tim's to make before any build)

1. **Seed basis.** Per **role** (property+tier) — stable, recognizable, recommended — vs. per
   **hire** (re-rolls each hire; throws away recognizability) vs. per **role + generation** (each
   dynasty's staff look fresh, a given manager stable within a run). Recommendation: role, with an
   optional generation fold.
2. **Alien treatment.** Full layered part-sets per epoch (expensive, most uniform with Earth) vs.
   abstract procedural per epoch (cheaper, my recommendation). This is the single biggest cost lever.
3. **Scope commitment.** Earth-only vertical slice first (recommended) vs. commit to all six epochs
   up front.

## 8. Non-goals / notes

- **Not the dynasty heir.** §8.2 keeps the *player character* portrait-less in v1 ("the names are
  the characters"). This plan is about **staffers** (the manager circle), which M3 already scopes.
- **Not on the current UI branch.** This is M3 work; the current `feature/ui-tap-targets` line is
  small on-device UI fixes.
- **Palette discipline.** Part tints should draw from the §1 nine-color palette + the sanctioned
  per-property accent extension, so generated faces stay on-style rather than introducing new hues.
