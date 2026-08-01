class_name UiPalette

# The nine-color palette from the Art Style Guide §1, plus the shared style
# builders for M1's placeholder chrome (§8). The limited palette is the
# consistency engine: no colors outside this table appear anywhere.
# (Colors are art direction with the style guide as their source of truth,
# not game tuning, so they live here rather than in /config.)

const CREAM := Color("#F4ECD8")
const KETCHUP_RED := Color("#B5402A")
const NAVY := Color("#1D2D50")
const MUSTARD_GOLD := Color("#E3B23C")
## A darker, deeper gold (a darkened MUSTARD_GOLD) for gold elements that need more weight than
## the bright mustard — e.g. the Estate tab's "Legacy:" balance (Tim, 2026-06-28).
const DARK_GOLD := Color("#A87C16")
const ATOMIC_TEAL := Color("#9FD8D4")
const MONEY_GREEN := Color("#7DA87B")
## A darker money green for headline dollar figures that want more weight than the soft
## MONEY_GREEN — the cash-on-hand total and the Family Ledger's dynasty total (Tim, 2026-06-28).
const DARK_MONEY_GREEN := Color("#5E7E5C")
const INK_NAVY := Color("#0D1830")
const BRICK := Color("#8E2F1E")
const PALE_GOLD := Color("#F0D49A")
## Warm orange — the middle stop of the minigame spectrum bar's red→orange→yellow climb toward
## the "full" line, so the bar reads as a clear heat gradient as performance rises (Tim,
## 2026-06-25). A small warm extension of the §1 palette for that one gradient.
const ORANGE := Color("#D9702B")

# Grays for the "not yet owned" property state — a deliberately drab, inactive
# look so an unbought rung reads as locked next to the live cream rungs. A small
# extension of the §1 palette for this one UI state, pending style-guide blessing.
const LIGHT_GRAY := Color("#CBCBCB")  # unowned row background
const MID_GRAY := Color("#9A9A9A")    # unowned borders
const DARK_GRAY := Color("#6E6E6E")   # unowned start button + portrait circle

## Cool metallic silver — the background of an owned-but-unstaffed property's portrait
## button, behind its restart icon (the start/rush control, GDD §5 / Tim 2026-06-22).
const SILVER := Color("#C7CBD1")

## Light gray track behind every progress meter's fill (Tim, 2026-06-23): lightened from the
## former semi-dark slate so the empty part of each bar reads as a soft, quiet background
## rather than a heavy band competing with the colored fill.
const PROGRESS_TRACK_GRAY := Color("#B6BAC0")

## Calm muted blue for a property's cycle bar once it is staffed and running itself
## hands-off — rush is no longer an option, so the bar drops its active green and reads
## as a steady, automated meter. Tuned to the same muted value as MONEY_GREEN so the two
## states sit in the same family. (Tim, 2026-06-23.)
const CYCLE_BLUE := Color("#5E86B8")
## Bright electric blue for the economy bar's carbonation — deliberately outside the
## era palette so the bubbles glow against the CYCLE_BLUE fill (Tim, 2026-07-06).
const NEON_BLUE := Color("#4DE8FF")

## The Rush Momentum meter's purples: DARK_PURPLE is the fill with BRIGHT_PURPLE carbonation on
## top (dark-fill / bright-bubble since Tim 2026-07-15; it launched light-fill / dark-bubble).
## PURPLE is the original lighter fill hue, kept in the palette for future use.
const PURPLE := Color("#9B5DE5")
const DARK_PURPLE := Color("#5E3499")
## Bright purple carbonation added to every property bar while Rush Momentum is MAXED — a vivid
## glow against the green/blue cycle fills, distinct from the always-present gold (Tim, 2026-07-13).
const BRIGHT_PURPLE := Color("#C77DFF")
## Neon salmon for the MAX-Rush-Momentum streaks — tiny dots that fly fast in a straight line
## (MomentumStreaks), a deliberate contrast to the swaying gold carbonation (Tim, 2026-07-14).
## Dimmed ~15% from the original #FF7A6B (Tim 2026-07-15: "a little dimmer").
const NEON_SALMON := Color("#D9685B")

# ---------------------------------------------------------------------------
# Type scale — the single source of truth for UI font sizes (Tim's "chunkier UI"
# pass, 2026-06-21). Named semantic tiers replace the ~24 scattered magic numbers.
# The pass RAISES THE FLOOR (nothing below FONT_SMALL) so small text reads clearly
# at arm's length (§1b: Tim's vision), while the big tuned numbers stay put. These
# are referenced both by make_app_theme() (defaults) and by per-element overrides
# where a control needs a specific tier.
# ---------------------------------------------------------------------------
const FONT_PAGE_TITLE := 76   # full-screen page titles (Estate Office, Family Ledger, dev panel)
const FONT_HERO := 67         # the income / cash hero numbers
const FONT_DISPLAY := 60      # big secondary displays & names (wallet, heir name, civ name, wage)
const FONT_HEADLINE := 52     # section headlines, emphasized card lines
const FONT_SUBHEAD := 41      # sub-headers, ancestor names, dev-row labels
const FONT_CARD_BODY := 37    # card body text and detail lines
const FONT_BUTTON := 34       # standard action-button labels (buy / hire / proceed)
const FONT_BODY := 32         # body text and captions
const FONT_LABEL := 28        # secondary labels
const FONT_SMALL := 26        # the smallest text allowed — the readability floor

## The one standard action-button height used across the game's primary buttons (Tim,
## 2026-06-22). Set to 160% of the average of the four buttons it replaces — turbo (56),
## buy-mode (56), Plan the Estate (72), and DEV tuning (64): average 62 × 1.6 ≈ 99.
const STANDARD_BUTTON_HEIGHT := 99

## Corner radius (px, 1080-wide design space) for UI that hugs the phone's rounded screen
## corners — the income panel's top corners and the outer bottom corners of the edge tab
## buttons — so they nest inside the Pixel's screen curve instead of squaring into it.
## Bumped 44 -> 80 (Tim, 2026-06-22): on the Pixel 10 Pro XL the old radius was too tight
## to read — the panel ran into the screen's own curved corner before its rounding showed.
## A larger radius (paired with the bigger top/bottom screen margins in Main) lands the
## visible curve in the flat area inside the bezel.
const SCREEN_CORNER_RADIUS := 80

## Black-frame inset (px, 1080-wide design space) of the cream viewing area from the physical
## screen edges — the width of the black "viewing area" border on the sides and top/bottom.
## Shared by the Main screen and the full-screen overlays so they all frame identically.
const SCREEN_BEZEL_SIDE := 9
const SCREEN_BEZEL_TOP_BOTTOM := 20

## Universal inner margin (px) between screen content and the cream viewing-area border, so no
## element ever crowds the edge. Applied once as the viewing area's content margin.
const UNIVERSAL_CONTENT_MARGIN := 16

## The cream rounded "viewing area" plate: cream fill, thin black outline, rounded corners that
## follow the phone screen, and the universal inner content margin. The framed background for
## the Main screen and the full-screen overlays (e.g. the dev panel) alike.
static func make_screen_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = CREAM
	style.set_corner_radius_all(SCREEN_CORNER_RADIUS)
	style.border_color = Color.BLACK
	style.set_border_width_all(2)
	style.set_content_margin_all(UNIVERSAL_CONTENT_MARGIN)
	return style


## A see-through version of the viewing-area plate: same rounded corners, thin black outline, and
## universal inner margin as make_screen_panel_style, but with NO cream fill — used on the Main
## screen so a full-bleed background image (the prairie) shows through behind the UI while the
## crisp black frame and inner padding still read exactly as before.
static func make_screen_frame_style() -> StyleBoxFlat:
	var style := make_screen_panel_style()
	style.bg_color = Color.TRANSPARENT
	return style


## Inset `control` from its (full-screen) parent by the screen bezel, so the black parent shows
## through as the frame around it. Sets full-rect anchors first, then pulls each edge inward.
static func apply_screen_bezel(control: Control) -> void:
	control.set_anchors_preset(Control.PRESET_FULL_RECT)
	control.offset_left = SCREEN_BEZEL_SIDE
	control.offset_right = -SCREEN_BEZEL_SIDE
	control.offset_top = SCREEN_BEZEL_TOP_BOTTOM
	control.offset_bottom = -SCREEN_BEZEL_TOP_BOTTOM


## The app-wide Theme: the default font sizes only, so any control that does NOT
## override its own size still reads large (the §1b readability bar). Assigned on the
## Main root (see Main._build_ui) so it cascades to every descendant, including the
## overlays. Per-element sizes still win where a control sets a specific tier via the
## FONT_* constants above.
##
## The sizes live in a small Theme RESOURCE (ui/theme/american_tycoon.tres) rather than
## being built here in code, so they can be tuned in Godot's Theme editor and are the
## single source of truth for the size cascade. The resource's three sizes mirror
## FONT_BODY / FONT_BUTTON above — keep them in sync. Styling (button plates, panels,
## colors) is deliberately NOT in the theme: every control styles itself explicitly via
## the helpers below, which keeps each control's look readable at its call site instead
## of hidden in a global cascade. load() returns the shared cached resource; this theme
## is only read (assigned on the root), never mutated, so sharing one instance is safe.
static func make_app_theme() -> Theme:
	return load("res://ui/theme/american_tycoon.tres")


## A faux-bold version of the app's default font, for the few labels that need to read heavier
## without a dedicated bold font file (the project ships no bold face yet). FontVariation's
## `variation_embolden` thickens the built-in font's strokes — Godot's "fake bold." Assign it with
## add_theme_font_override("font", …); pair it with a font_size override for the size.
static func make_bold_font() -> FontVariation:
	var bold := FontVariation.new()
	bold.base_font = ThemeDB.fallback_font  # the same built-in face every un-themed control uses
	bold.variation_embolden = 0.5
	return bold


## Cream plate with a navy border — the standard card/panel (§8).
static func make_panel_style() -> StyleBoxFlat:
	return _make_plate(CREAM, NAVY)


# --- Flagship plates -------------------------------------------------------------------------
# The FLAGSHIP of an epoch's cohort is the property the era actually turns on: owning 35 units of
# it advances the epoch (Epoch Advance Rework), and auto-purchase deliberately never buys it. Until
# now nothing on screen said which row that was. These plates mark it (Tim, 2026-07-31): "a more
# bold outline, a family ledger icon in the top right corner, and the background slightly glowing."
# The icon half lives in PropertyRow; the outline + glow are here.

## Twice the standard plate's 3px border. Same NAVY as every other frame — this is the SAME frame
## language, just carrying more weight, rather than a new color that would read as a new kind of
## thing.
const FLAGSHIP_BORDER_WIDTH := 6
## How far the gold halo bleeds out past the plate's edge. This shadow IS the "glow" — a warmer
## background alone is too quiet to find while scrolling a ladder.
const FLAGSHIP_GLOW_SIZE := 10
## Alpha of that halo. Low on purpose: Tim asked for "slightly glowing", so it should read as warm
## lighting spilling off the panel, not as a highlight marker painted on top of it.
const FLAGSHIP_GLOW_ALPHA := 0.35
## How far the plate's background is pulled toward MUSTARD_GOLD. Enough to be obvious beside a
## plain cream row, not so far that the navy text loses contrast.
const FLAGSHIP_WARM_BLEND := 0.18
## The gray (unowned) flagship warms a little harder than the cream one: it starts from a drab
## LIGHT_GRAY, so it needs more gold to travel the same visual distance.
const FLAGSHIP_UNOWNED_WARM_BLEND := 0.22


## Warm cream plate with a heavy navy border and a gold halo — the OWNED flagship rung.
static func make_flagship_panel_style() -> StyleBoxFlat:
	var style := _make_plate(CREAM.lerp(MUSTARD_GOLD, FLAGSHIP_WARM_BLEND), NAVY)
	_apply_flagship_frame(style)
	return style


## The flagship rung the player has not bought yet. It keeps the gray family's drabness (it is
## still locked) but takes the same heavy border, gold warmth and halo, because an UNBOUGHT
## flagship is exactly the row the player is saving toward — it has to stay findable. Its border
## goes DARK_GOLD rather than the unowned plate's MID_GRAY: navy would read as "owned" beside the
## gray rows, while mid-gray at 6px just looks like a thicker gray line.
static func make_unowned_flagship_panel_style() -> StyleBoxFlat:
	var style := _make_plate(LIGHT_GRAY.lerp(MUSTARD_GOLD, FLAGSHIP_UNOWNED_WARM_BLEND), DARK_GOLD)
	_apply_flagship_frame(style)
	return style


## Turn a plate built by _make_plate into a flagship plate: heavier border + gold outer halo.
##
## LAYOUT NOTE — this is what keeps the no-moving-UI rule. The content margin is deliberately left
## at _make_plate's 12. In Godot, StyleBox.get_margin() returns the CONTENT margin whenever one is
## set (>= 0) and only falls back to the border width when it is not: the two are ALTERNATIVES,
## not a sum. So the content box is inset 12px from the panel's outer edge whether the border is
## 3px or 6px, and a PanelContainer's minimum size — which is built from those same margins — is
## identical either way. The thicker border simply eats 3px of the padding it was already sitting
## inside; nothing on the row moves, resizes, or reflows. (Dropping the margin to 9 to "compensate"
## for the border would in fact shift every control 3px OUTWARD and shrink the panel — the exact
## thing to avoid.)
##
## The halo is a StyleBoxFlat SHADOW, drawn outside the box. Unlike expand_margin, a shadow
## contributes nothing to minimum size or layout — it is pure paint.
static func _apply_flagship_frame(style: StyleBoxFlat) -> void:
	style.set_border_width_all(FLAGSHIP_BORDER_WIDTH)
	style.shadow_color = Color(MUSTARD_GOLD, FLAGSHIP_GLOW_ALPHA)
	style.shadow_size = FLAGSHIP_GLOW_SIZE


## Vertical gap that floats each tab's content panel between the hero stat above and the
## tab bar below. TOP/BOTTOM only since 2026-07-06 (Tim): the panel's left/right edges
## now sit flush with the hero stat panel and the tab buttons, full column width.
const TAB_PANEL_EDGE_MARGIN := 40


## The standard per-tab content panel: a translucent cream plate with the same navy frame as
## the income header and the tab buttons (12px border, 4px corners — Tim 2026-07-15; was the
## settings tab's thin gray outline) and an inner content margin so nothing crowds the frame.
## 65% alpha so the epoch backdrop reads faintly through it (Tim, 2026-06-28).
static func make_tab_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(CREAM, 0.65)
	style.border_color = NAVY
	style.set_border_width_all(12)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(24)
	return style


## Wrap a tab's content Control in the standard edge margin + outlined translucent-cream panel,
## so every tab shares one framed look (the settings-tab outline). Returns the outer
## MarginContainer; the caller drops THAT into the tab-content slot in place of the bare content.
static func wrap_in_tab_panel(content: Control) -> MarginContainer:
	var margin := MarginContainer.new()
	for side in ["margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, TAB_PANEL_EDGE_MARGIN)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", make_tab_panel_style())
	panel.add_child(content)
	margin.add_child(panel)
	return margin


## Style a Button in place. Standard buttons are navy-on-mustard; action
## buttons (spend/act: buy, pop, tuition) are pale-gold-on-red — red is
## reserved for "spend/act", never decoration (§8).
static func style_button(button: Button, is_action: bool) -> void:
	var plate := KETCHUP_RED if is_action else MUSTARD_GOLD
	var pressed_plate := BRICK if is_action else PALE_GOLD
	var label_color := PALE_GOLD if is_action else NAVY
	_style_button_plates(button, plate, pressed_plate, label_color)


## Style a Button with a blue plate (CYCLE_BLUE) and cream label. Used for the minigame tuning
## screen's mode toggles so they read as a distinct kind of control, clearly apart from the gold
## game buttons below them (Tim, 2026-07-01). Blue is not a §8 action color, so it stays reserved
## for this "pick a mode" role rather than spend/act.
static func style_blue_button(button: Button) -> void:
	_style_button_plates(button, CYCLE_BLUE, CYCLE_BLUE.darkened(0.2), CREAM)


## Shared plate/label wiring for the styled buttons above: the normal/hover plate, a darker
## pressed plate, a cream disabled plate, and one label color that holds across every interactive
## state so the text never flips color on click/hover/focus — only the disabled state dims it
## (Tim, 2026-06-28).
static func _style_button_plates(
		button: Button, plate: Color, pressed_plate: Color, label_color: Color
) -> void:
	button.add_theme_stylebox_override("normal", _make_plate(plate, NAVY))
	button.add_theme_stylebox_override("hover", _make_plate(plate, NAVY))
	button.add_theme_stylebox_override("pressed", _make_plate(pressed_plate, NAVY))
	button.add_theme_stylebox_override("disabled", _make_plate(CREAM, NAVY))

	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color",
			"font_hover_pressed_color"]:
		button.add_theme_color_override(state, label_color)
	button.add_theme_color_override("font_disabled_color", Color(NAVY, 0.45))


## Light-gray plate with a mid-gray border — the background for a property rung
## the player does not own any units of yet (reads as locked/inactive).
static func make_unowned_panel_style() -> StyleBoxFlat:
	return _make_plate(LIGHT_GRAY, MID_GRAY)


## Style a button as the drab dark-gray "unowned" control (the START button on a
## rung the player doesn't own yet). All states share the one gray plate so the
## disabled button still reads as gray rather than the default cream.
static func style_unowned_button(button: Button) -> void:
	var plate := _make_plate(DARK_GRAY, MID_GRAY)
	button.add_theme_stylebox_override("normal", plate)
	button.add_theme_stylebox_override("hover", plate)
	button.add_theme_stylebox_override("pressed", plate)
	button.add_theme_stylebox_override("disabled", plate)
	# Constant cream label across every state (incl. focus/hover/pressed) so a click never
	# recolors it (Tim, 2026-06-28).
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color",
			"font_hover_pressed_color", "font_disabled_color"]:
		button.add_theme_color_override(state, CREAM)


## A tab's title label in the standard tab-title format (Tim, 2026-06-28): the settings-tab
## heading style — large (FONT_HEADLINE ×1.4), faux-bold, navy, horizontally centered. Used by
## every tab (Settings, Estate Planning, Family Ledger) so the titles all match.
static func make_tab_title(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL  # fill the width so "centered" is the whole tab
	label.add_theme_color_override("font_color", NAVY)
	label.add_theme_font_size_override("font_size", int(FONT_HEADLINE * 1.4))
	label.add_theme_font_override("font", make_bold_font())
	return label


## Reserved width of a styled vertical scrollbar — also the width of its (wider) handle.
const SCROLLBAR_WIDTH := 24
## How far the track is inset on EACH side, so the handle reads as wider than the track:
## against a ~20px base the handle is ~20% wider (24) and the track ~20% narrower (16).
const SCROLLBAR_TRACK_INSET := 4


## Style a ScrollContainer's vertical scrollbar (Tim, 2026-06-28): a wide navy handle riding
## over a narrower gray track, both with rounded ends. Pass ScrollContainer.get_v_scroll_bar().
static func style_vscrollbar(bar: VScrollBar) -> void:
	bar.custom_minimum_size.x = SCROLLBAR_WIDTH

	# The handle fills the bar's full reserved width (the wider element).
	var handle := StyleBoxFlat.new()
	handle.bg_color = NAVY
	handle.set_corner_radius_all(SCROLLBAR_WIDTH / 2)

	# The track is drawn narrower than the bar: negative expand margins inset its draw rect by
	# SCROLLBAR_TRACK_INSET on each side (the same shrink trick style_framed_progress uses).
	var track := StyleBoxFlat.new()
	track.bg_color = PROGRESS_TRACK_GRAY
	track.set_corner_radius_all((SCROLLBAR_WIDTH - 2 * SCROLLBAR_TRACK_INSET) / 2)
	track.set_expand_margin(SIDE_LEFT, -float(SCROLLBAR_TRACK_INSET))
	track.set_expand_margin(SIDE_RIGHT, -float(SCROLLBAR_TRACK_INSET))

	bar.add_theme_stylebox_override("scroll", track)
	for state in ["grabber", "grabber_highlight", "grabber_pressed"]:
		bar.add_theme_stylebox_override(state, handle)


## Teal track with a fill in the given color (§8: sliders and meters).
static func style_progress_bar(bar: ProgressBar, fill_color: Color) -> void:
	var track := StyleBoxFlat.new()
	track.bg_color = PROGRESS_TRACK_GRAY
	track.set_corner_radius_all(3)

	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_color
	fill.set_corner_radius_all(3)

	bar.add_theme_stylebox_override("background", track)
	bar.add_theme_stylebox_override("fill", fill)


## A progress meter framed as a button surface: a colored track inside a navy
## frame, with the fill inset so it grows INSIDE the frame instead of painting over
## it. Used wherever a meter doubles as a button background — the wage "clock in"
## meter (§2) and the frenzy TURBO button. `border_width` defaults to the standard
## 3px plate frame so a meter-button lines up with the ordinary buttons beside it;
## the wage meter overrides it heavier.
static func style_framed_progress(
		bar: ProgressBar, fill_color: Color, track_color: Color, border_width: int = 3
) -> void:
	var track := StyleBoxFlat.new()
	track.bg_color = track_color
	track.border_color = NAVY
	track.set_border_width_all(border_width)
	track.set_corner_radius_all(4)

	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_color
	fill.set_corner_radius_all(4)
	# Negative expand margins shrink the fill's draw rect inward by the frame
	# thickness, so the fill stays INSIDE the navy outline as it grows rather than
	# painting over the frame.
	fill.set_expand_margin_all(-float(border_width))

	bar.add_theme_stylebox_override("background", track)
	bar.add_theme_stylebox_override("fill", fill)


## Dark-gold plate with a bright-gold fill — the "clock in" wage button doubles
## as a promotion-progress meter (UI notes §2: dark gold background, bright gold
## bar), with the heavier navy frame Tim called for. The dark gold is a darkened
## MUSTARD_GOLD; a deliberate extension of the §1 palette for this meter.
static func style_gold_progress(bar: ProgressBar) -> void:
	style_framed_progress(bar, MUSTARD_GOLD, MUSTARD_GOLD.darkened(0.45), 8)


## Faint-green plate for a staffed property's hire button — signals "this one is
## automated" (a soft money-green wash over the cream card, navy border).
static func make_staffed_style() -> StyleBoxFlat:
	return _make_plate(CREAM.lerp(MONEY_GREEN, 0.45), NAVY)


## Let a swipe that begins on `root` — or on any of its non-button children —
## fall through to an enclosing ScrollContainer, so the list scrolls when grabbed
## on a panel surface, not only on the bare background. Buttons are left at their
## default STOP filter so a tap on a button stays a tap, never a scroll.
##
## Godot detail: every Control defaults to MOUSE_FILTER_STOP, which swallows the
## press so the ScrollContainer never sees the drag begin (this is why a swipe
## that started on a row used to do nothing). Switching the non-interactive
## surfaces to PASS lets the unhandled press keep bubbling up the tree to the
## scroller, which then drives the scroll once the finger passes the deadzone.
static func allow_scroll_drag_through(root: Control) -> void:
	if root is BaseButton:
		return  # leave buttons (and their internals) alone — taps must stay taps
	root.mouse_filter = Control.MOUSE_FILTER_PASS
	for child in root.get_children():
		if child is Control:
			allow_scroll_drag_through(child as Control)


static func _make_plate(bg_color: Color, border_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.set_border_width_all(3)
	style.set_corner_radius_all(4)
	# Content padding bumped 10 -> 12 (Tim's "panels a bit larger" pass, 2026-06-21).
	# _make_plate backs both panels and buttons, so this roomies up both at once.
	style.set_content_margin_all(12)
	return style
