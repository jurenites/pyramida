extends RefCounted
## Numeric arithmetic only: no function calls, objects, indexing or executable code.
var _tokens: Array[String] = []
var _position := 0
var _lookup: Callable
var error := ""

func evaluate(source: String, lookup: Callable, allow_percentage: bool = false) -> Variant:
	if source.contains("%"):
		return _percentage(source, allow_percentage)
	_lookup = lookup
	var token := RegEx.new()
	token.compile("(?:[0-9]+(?:\\.[0-9]*)?|\\.[0-9]+)(?:[eE][+-]?[0-9]+)?|[A-Za-z_][A-Za-z_0-9]*(?:\\.[A-Za-z_][A-Za-z_0-9]*)*|[+*/()\\-]")
	var offset := 0
	while offset < source.length():
		if source[offset] in [" ", "\t", "\r"]:
			offset += 1
			continue
		var found := token.search(source, offset)
		if found == null or found.get_start() != offset:
			error = "unsupported expression syntax"
			return null
		_tokens.append(found.get_string())
		offset = found.get_end()
		if _tokens.size() > 256:
			error = "expression is too long"
			return null
	var value := _sum()
	if _position != _tokens.size() and error.is_empty():
		error = "unexpected token"
	if not is_finite(value) and error.is_empty():
		error = "result must be finite"
	return value if error.is_empty() else null

func _percentage(source: String, allowed: bool) -> Variant:
	# Percentages describe a change from the normal 1x rate, not an absolute rate.
	# Keep them as whole values; references expose the resolved multiplier to math.
	if not allowed:
		error = "percentage bonuses are only supported for multiplier settings"
		return null
	var pattern := RegEx.new()
	pattern.compile("^[+-]?(?:[0-9]+(?:\\.[0-9]+)?|\\.[0-9]+)%$")
	var literal := source.strip_edges()
	if pattern.search(literal) == null:
		error = "expected a percentage bonus such as +50%, 0% or -90%"
		return null
	var value := 1.0 + literal.trim_suffix("%").to_float() / 100.0
	if not is_finite(value):
		error = "result must be finite"
		return null
	return value

func _sum() -> float:
	var value := _product()
	while _peek() in ["+", "-"] and error.is_empty():
		var operation := _take()
		var right := _product()
		value = value + right if operation == "+" else value - right
	return value

func _product() -> float:
	var value := _factor()
	while _peek() in ["*", "/"] and error.is_empty():
		var operation := _take()
		var right := _factor()
		if operation == "/" and right == 0.0:
			error = "division by zero"
			return 0.0
		value = value * right if operation == "*" else value / right
	return value

func _factor() -> float:
	var token := _take()
	if token in ["+", "-"]:
		var value := _factor()
		return -value if token == "-" else value
	if token == "(":
		var value := _sum()
		if _take() != ")": error = "missing closing parenthesis"
		return value
	if token.is_valid_float(): return token.to_float()
	if token.is_empty() or token in [")", "*", "/"]:
		error = "expected a number or setting name"
		return 0.0
	var value: Variant = _lookup.call(token)
	if not (value is int or value is float):
		error = "unknown, invalid or circular reference: " + token
		return 0.0
	return float(value)

func _peek() -> String:
	return _tokens[_position] if _position < _tokens.size() else ""

func _take() -> String:
	var value := _peek()
	if not value.is_empty(): _position += 1
	return value
