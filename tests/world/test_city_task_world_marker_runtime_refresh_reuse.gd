extends SceneTree

const T := preload("res://tests/_test_util.gd")

class FakeTaskRuntime:
	extends RefCounted

	var slot := {
		"slot_id": "slot:start:test",
		"task_id": "task:test",
		"slot_kind": "start",
		"world_anchor": Vector3(64.0, 0.0, 96.0),
		"trigger_radius_m": 8.0,
	}

	func get_slots_for_rect(_rect: Rect2, _statuses: Array = [], _slot_kinds: Array = []) -> Array[Dictionary]:
		return [slot.duplicate(true)]

	func get_current_objective_slot() -> Dictionary:
		return {}

class ResolverProbe:
	extends RefCounted

	var call_count := 0

	func resolve(anchor: Vector3) -> Vector3:
		call_count += 1
		return anchor + Vector3(0.0, 1.0, 0.0)

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var runtime_script := load("res://city_game/world/tasks/runtime/CityTaskWorldMarkerRuntime.gd")
	if runtime_script == null:
		T.fail_and_quit(self, "Task world marker runtime refresh reuse test requires CityTaskWorldMarkerRuntime.gd")
		return

	var probe := ResolverProbe.new()
	var runtime: Node3D = runtime_script.new()
	root.add_child(runtime)
	runtime.setup(FakeTaskRuntime.new(), Callable(probe, "resolve"))
	await process_frame

	runtime.refresh(Vector3(64.0, 0.0, 96.0), 256.0)
	runtime.refresh(Vector3(64.0, 0.0, 96.0), 256.0)
	runtime.refresh(Vector3(64.0, 0.0, 96.0), 256.0)

	var state: Dictionary = runtime.get_state()
	if not T.require_true(self, int(state.get("marker_count", 0)) == 1, "Repeated refresh with the same slot set must keep exactly one world marker instance"):
		return
	if not T.require_true(self, probe.call_count == 1, "Repeated refresh with an unchanged slot contract must reuse cached marker placement instead of re-running ground resolution every frame"):
		return

	T.pass_and_quit(self)
