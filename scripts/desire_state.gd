extends RefCounted
## Explicit model inputs. Missing parameters do not invent unmet needs.
const FIELDS := ["hot", "thirsty", "requires_electricity", "electricity_connected"]

static func valid(value: Variant) -> bool:
	if not value is Dictionary: return false
	for key in value:
		if key not in FIELDS or not value[key] is bool: return false
	return true

static func icons(parameters: Dictionary, door_connected := true) -> Array[String]:
	var result: Array[String] = []
	if not door_connected: result.append("door_blocked")
	if parameters.get("thirsty", false): result.append("water")
	if parameters.get("hot", false): result.append("heat")
	if parameters.get("requires_electricity", false) and not parameters.get("electricity_connected", false):
		result.append("electricity")
	return result
