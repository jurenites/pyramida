class_name GamePalette
extends RefCounted

## Authoritative environmental and construction palette.
## Derived darker/lighter states should be calculated from these colours rather
## than introducing unrelated hard-coded colours in individual render scripts.

const WOODEN_ROOF := Color("#A85C5C")
const ROOF_LOG := Color("#E08160")
const HOME_DOORWAY := Color("#7F4645")
# Page 1 / Colours, Figma node 110:122 (30 October 2026).
const SAND_SURFACE := Color("#FEF1CF")
const PEACH_SHADOW := Color("#EABEA4")
const TIMBER_SIDE := Color("#AF644B")
# Shared shoreline/freshwater/resource swatch; retain the existing public name.
const WATER_BLUE := Color(0.15, 0.69, 0.65)
const BUSHES := Color("#799369")
## Closely related exact colours used per living Tree or Bush. These variants
## distinguish dense greenery while preserving the flat-colour visual rule.
const GREENERY_VARIANTS: Array[Color] = [
	Color("#718B65"),
	Color("#75906A"),
	BUSHES,
	Color("#7D976C"),
	Color("#829A70"),
]
const GRASS := Color("#E3B563")
const HAY_FIELD := Color("#FFC471")
const CACTUS := Color("#B1C070")
const PALM_TRUNK := Color("#8F523E")
const PALM_LEAF_LIGHT := Color("#4F713B")
const PALM_LEAF_DARK := Color("#284735")
const LIMESTONE := SAND_SURFACE
const LIMESTONE_SIDE := Color("#EEBF8A")
const MARBLE := Color("#F3EEE5")
const CONCRETE := Color("#8A8D8F")
const PINE_WOOD := Color("#8B5E45")
const CLOUD := Color("#FFFFFF")
const FOG_AND_SHADOW := PEACH_SHADOW
const CITIZEN_SKIN := Color("#3A1F1F")
const WOMAN_CLOTHING := Color("#E18074")
const TOOL_METAL := Color("#4B7781")
const HAIR := Color("#000000")
const SUN := Color("#FFD166")
const MORNING_LIGHT := Color("#A9D5EA")
const EVENING_LIGHT := Color("#D96C5F")
const NIGHT_LIGHT := Color("#55729B")
const MORNING_SKY := Color("#A8D3E4")
const EVENING_SKY := Color("#C97968")
const MORNING_SURFACE := Color("#BCD7E3")
const EVENING_SURFACE := Color("#D98267")
const MORNING_SHADOW := Color("#7896A6")
const EVENING_SHADOW := Color("#8C5D59")
const NIGHT_SKY := Color("#182638")
const NIGHT_SURFACE := Color("#6A758D")
const NIGHT_FOG_AND_SHADOW := Color("#4C5A77")
const PLACEMENT_ALLOWED := Color("#808080")
const PLACEMENT_BLOCKED := Color("#D85C5C")
const DECONSTRUCTION_PREVIEW := Color("#8A5A3A")
