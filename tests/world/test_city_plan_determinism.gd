extends SceneTree

# v63 M1: the city plan must be deterministic and cache round-trip safe.
# REQ-0034-001.

const T := preload("res://tests/_test_util.gd")
const GENERATOR_PATH := "res://city_game/world/generation/plan/CityPlanGenerator.gd"
const CACHE_PATH := "res://city_game/world/generation/plan/CityPlanCache.gd"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var generator_script = load(GENERATOR_PATH)
	if not T.require_true(self, generator_script != null, "CityPlanGenerator must exist"):
		return
	var generator = generator_script.new()
	var first: Dictionary = generator.generate(12345)
	var second: Dictionary = generator.generate(12345)
	if not T.require_true(self, str(first.get("plan_hash", "")) != "", "plan_hash must not be empty"):
		return
	if not T.require_true(self, str(first.get("plan_hash", "")) == str(second.get("plan_hash", "")), "same seed must produce the same plan_hash"):
		return
	var other: Dictionary = generator.generate(54321)
	if not T.require_true(self, str(first.get("plan_hash", "")) != str(other.get("plan_hash", "")), "different seeds must produce different plan_hash"):
		return
	var cache_script = load(CACHE_PATH)
	if not T.require_true(self, cache_script != null, "CityPlanCache must exist"):
		return
	var cache = cache_script.new()
	if not T.require_true(self, cache.store(first), "cache store must succeed"):
		return
	var loaded: Dictionary = cache.load_plan()
	if not T.require_true(self, not loaded.is_empty(), "cache load must return a plan"):
		return
	if not T.require_true(self, str(loaded.get("plan_hash", "")) == str(first.get("plan_hash", "")), "cache round-trip must preserve plan_hash"):
		return
	T.pass_and_quit(self)
