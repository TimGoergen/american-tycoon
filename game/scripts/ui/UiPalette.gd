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


## The app-wide Theme: a chunky default font size plus per-control-type defaults, so
## any control that does NOT override its own size still reads large (the §1b
## readability bar). Assigned on the Main root (see Main._build_ui) so it cascades to
## every descendant, including the overlays. Per-element sizes still win where a
## control sets a specific tier via the FONT_* constants above.
static func make_app_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = FONT_BODY            # backstop for anything un-themed
	theme.set_font_size("font_size", "Button", FONT_BUTTON)
	theme.set_font_size("font_size", "Label", FONT_BODY)
	return theme


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


## Edge gap that floats each tab's content panel clear of the screen — the same inset the
## settings tab established, now shared by every tab.
const TAB_PANEL_EDGE_MARGIN := 40


## The standard per-tab content panel: a translucent cream plate with the gray outline the
## settings tab established (3px border, 8px corners) and an inner content margin so nothing
## crowds the outline. 65% alpha so the epoch backdrop reads faintly through it (Tim, 2026-06-28).
static func make_tab_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(CREAM, 0.65)
	style.border_color = MID_GRAY
	style.set_border_width_all(3)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(24)
	return style


## Wrap a tab's content Control in the standard edge margin + outlined translucent-cream panel,
## so every tab shares one framed look (the settings-tab outline). Returns the outer
## MarginContainer; the caller drops THAT into the tab-content slot in place of the bare content.
static func wrap_in_tab_panel(content: Control) -> MarginContainer:
	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
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

	button.add_theme_stylebox_override("normal", _make_plate(plate, NAVY))
	button.add_theme_stylebox_override("hover", _make_plate(plate, NAVY))
	button.add_theme_stylebox_override("pressed", _make_plate(pressed_plate, NAVY))
	button.add_theme_stylebox_override("disabled", _make_plate(CREAM, NAVY))

	button.add_theme_color_override("font_color", label_color)
	button.add_theme_color_override("font_hover_color", label_color)
	button.add_theme_color_override("font_pressed_color", NAVY)
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
	button.add_theme_color_override("font_color", CREAM)
	button.add_theme_color_override("font_disabled_color", CREAM)


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
