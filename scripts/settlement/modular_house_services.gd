extends RefCounted
## Prototype-only resource account and finite construction charge.
const UPGRADE_METAL := 6
const INITIAL_CHARGE := 35.0
var metal := 0
var supply := 6
var tier := 0
var charge := INITIAL_CHARGE
var connected := false

func collect() -> void:
	var amount := mini(3, supply); metal += amount; supply -= amount

func can_upgrade() -> bool:
	return tier == 0 and metal >= UPGRADE_METAL

func upgrade() -> bool:
	if not can_upgrade(): return false
	metal -= UPGRADE_METAL; tier = 1
	return true

func advance(delta: float) -> void:
	if not connected: charge = maxf(0, charge - maxf(0, delta))

func brightness() -> float:
	if connected: return 1.0
	return smoothstep(0, 5, charge)
