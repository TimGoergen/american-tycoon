# sim/ — headless verification

Each test is a `SceneTree` script run standalone; it runs `_check(name, cond)`-style assertions and quits.
This is the balance simulator + regression harness — it loads the SAME `ConfigLoader` the game does, so the
two can never drift on rules or numbers.

## Running
`D:\Downloads\Godot_v4.5.1-stable_win64\Godot_v4.5.1-stable_win64_console.exe --headless --path game --script res://sim/SomeTest.gd`
(run from the repo root; the Godot binary is NOT on PATH — see the root `CLAUDE.md`).

## Gotchas
- Sims call `ConfigLoader.load_tuning(false)` so they measure the BAKED defaults, never a device's user overrides.
- To test a custom tuning value, set the TUNING field, THEN build the dynasty — do NOT poke a catalog's
  `static var` directly, because `DynastyState` re-pushes tuning config on construction and would overwrite it.
- A NEW `class_name` used by a sim needs a project editor-import first (root `CLAUDE.md`), or `--script` errors
  "Could not resolve external class". A standalone `--check-only` on a single UI script also reports spurious
  "identifier not declared" for `class_name`/preload refs outside project context — the editor-import + a
  `--quit-after 90` boot is the authoritative check.
- The `ObjectDB instances leaked / resources still in use at exit` lines are normal SceneTree-script teardown
  noise, not a failure.
