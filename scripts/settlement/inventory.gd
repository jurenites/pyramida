extends RefCounted
## Reservation is not consumption. A resource leaves stock only at physical pickup.
signal resource_stored(resource: String)
var amounts: Dictionary = {}
var reservations: Dictionary = {}
var capacity := 32

func count(resource: String) -> int:
	return int(amounts.get(resource, 0))

func total() -> int:
	var value := 0
	for amount: int in amounts.values():
		value += amount
	return value

func available(resource: String) -> int:
	var value := count(resource)
	for reservation: String in reservations.values():
		if reservation == resource:
			value -= 1
	return value

func reserve(owner: int, resource: String) -> bool:
	if reservations.has(owner) or available(resource) <= 0:
		return false
	reservations[owner] = resource
	return true

func release(owner: int) -> void:
	reservations.erase(owner)

func pickup(owner: int) -> String:
	var resource := str(reservations.get(owner, ""))
	if resource.is_empty() or count(resource) <= 0:
		return ""
	amounts[resource] = count(resource) - 1
	reservations.erase(owner)
	return resource

func store(resource: String, amount := 1) -> bool:
	if amount < 0 or total() + amount > capacity:
		return false
	amounts[resource] = count(resource) + amount
	if amount > 0:
		resource_stored.emit(resource)
	return true
