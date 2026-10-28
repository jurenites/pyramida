class_name PixelUI
extends RefCounted

const VisualTokens = preload("res://scripts/ui_visual_tokens.gd")

## Reuses Godot's existing vector fallback font while rasterizing glyphs as if
## they were displayed on a low-density monitor: no antialiasing, no subpixel
## positioning, four-times-density glyph rasters, nearest texture sampling, and
## normal whole-pixel hinting.

static var _pixel_font: Font
static var _tooltip_theme: Theme


static func font() -> Font:
	if _pixel_font != null:
		return _pixel_font
	var duplicated_font := ThemeDB.fallback_font.duplicate(true)
	if duplicated_font is FontFile:
		var font_file := duplicated_font as FontFile
		font_file.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		font_file.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
		font_file.hinting = TextServer.HINTING_NORMAL
		font_file.multichannel_signed_distance_field = false
		# Render four source pixels along each glyph axis before the shared retro
		# screen pass. Nearest sampling keeps hard edges, while the denser glyph
		# raster prevents text from becoming coarser than the 3D presentation.
		font_file.oversampling = 4.0
	_pixel_font = duplicated_font as Font
	return _pixel_font


static func apply(control: Control) -> void:
	control.add_theme_font_override("font", font())
	control.add_theme_font_size_override("font_size", VisualTokens.UI_FONT_SIZE)
	control.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


static func tooltip_theme() -> Theme:
	if _tooltip_theme != null:
		return _tooltip_theme
	_tooltip_theme = Theme.new()
	_tooltip_theme.default_font = font()
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color.BLACK
	panel_style.border_color = Color.WHITE
	panel_style.set_border_width_all(int(VisualTokens.LINE_WIDTH))
	panel_style.set_corner_radius_all(0)
	panel_style.content_margin_left = 5.0
	panel_style.content_margin_right = 5.0
	panel_style.content_margin_top = 3.0
	panel_style.content_margin_bottom = 3.0
	_tooltip_theme.set_stylebox("panel", "TooltipPanel", panel_style)
	_tooltip_theme.set_color("font_color", "TooltipLabel", Color.WHITE)
	_tooltip_theme.set_font("font", "TooltipLabel", font())
	_tooltip_theme.set_font_size("font_size", "TooltipLabel", VisualTokens.TOOLTIP_FONT_SIZE)
	return _tooltip_theme
