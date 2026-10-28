class_name BuildInfo
extends RefCounted

## Bump VERSION and refresh the commit/timestamp for every applied chat batch.
const VERSION := "0.1.6"
const GIT_COMMIT := "1dae083"
const APPLIED_AT_GMT_PLUS_3 := "2026-10-21 15:14 GMT+3"


static func inline_label() -> String:
	return "v%s  ·  %s  ·  %s" % [VERSION, GIT_COMMIT, APPLIED_AT_GMT_PLUS_3]
