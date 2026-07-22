# ui/ — screens, HUD, overlays, minigames

Godot `Control` scenes built in code. `scripts/Main.gd` is the root screen; it owns the tabs, the HUD, and
the full-screen modal overlays instantiated here.

## Conventions
- **`UiPalette.gd` is the design system.** Use its named colors (`NAVY`, `CREAM`, `MUSTARD_GOLD`, `DARK_GOLD`,
  `MONEY_GREEN`, `ATOMIC_TEAL`, `KETCHUP_RED`, …) and `FONT_*` size constants — do NOT hardcode colors or sizes.
  Helpers: `apply_screen_bezel`, `make_screen_panel_style`, `make_tab_title`, `style_button`, `make_bold_font`.
- **Full-screen modal pattern** (`AboutScreen` / `StatsScreen` / `MinigameReviewScreen`): `extends ColorRect`,
  black bg + bezel + panel, a top-left "◀ BACK" button, a `signal closed`, and an `open()` method. `Main.gd`
  instantiates + `add_child`'s it and opens it from a Settings button; add it to Main's `modal_up` set if it
  should freeze the economy while up.
- **Standing UI rules (Tim):** LARGE text + LARGE tappable targets (he's low-vision); NEVER hide/show controls —
  keep them visible with a gray disabled state.

## Minigame library
- **`Minigame.gd`** — the base type: `display_name()`, `begin(tuning)`, `get_performance() -> [0,1]` (the reward
  metric the host maps to a multiplier), `get_score() -> int` (raw cumulative), `is_busy()`, a `challenge_mode`
  flag, and a `completed` signal.
- **`MinigameScreen.gd`** — the reward-agnostic host: it maps a game's performance to a multiplier and shows a
  configurable reward noun. Six types: Match Three, Timing Bar, Catch the Money, Memory, Micro Basketball, Balance.
- **Reward-agnostic contract:** a minigame only reports performance/score — it must never know the reward.

## Gotcha
A `RichTextLabel` inside a CanvasLayer needs `custom_minimum_size` + `AUTOWRAP_OFF` or it renders as stray pixels.
