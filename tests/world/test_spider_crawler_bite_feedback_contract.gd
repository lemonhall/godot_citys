extends SceneTree

const T := preload("res://tests/_test_util.gd")
const SPIDER_SCENE_PATH := "res://city_game/world/creatures/arthropods/CitySpiderCrawler.tscn"


class DummySpiderBiteVictim extends Node3D:
	var bite_feedback_count := 0
	var last_feedback: Dictionary = {}

	func apply_spider_bite_feedback(world_position: Vector3, intensity: float = 1.0, species_id: String = "spider") -> Dictionary:
		bite_feedback_count += 1
		last_feedback = {
			"world_position": world_position,
			"intensity": intensity,
			"species_id": species_id,
		}
		return last_feedback.duplicate(true)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := load(SPIDER_SCENE_PATH) as PackedScene
	if not T.require_true(self, scene != null, "Spider bite feedback contract requires CitySpiderCrawler.tscn"):
		return

	var spider := scene.instantiate() as Node3D
	root.add_child(spider)
	await process_frame
	await process_frame

	if not T.require_true(self, spider.has_method("set_bite_victim"), "Spider bite feedback contract requires set_bite_victim() on the species crawler"):
		return
	if not T.require_true(self, spider.has_method("get_portability_contract"), "Spider bite feedback contract requires get_portability_contract() on the species crawler"):
		return

	var portability_contract: Dictionary = spider.get_portability_contract()
	var contact_attack: Dictionary = portability_contract.get("contact_attack", {}) as Dictionary
	if not T.require_true(self, str(contact_attack.get("kind", "")) == "bite_feedback", "Spider portability contract must freeze bite feedback as a species-level contact attack instead of a lab-only gimmick"):
		return

	var victim := DummySpiderBiteVictim.new()
	root.add_child(victim)
	await process_frame

	if spider.has_method("teleport_body_to_world_position"):
		spider.teleport_body_to_world_position(Vector3.ZERO)
	victim.global_position = Vector3(0.0, 0.0, 0.85)
	spider.set_bite_victim(victim)
	if spider.has_method("set_debug_motion_velocity"):
		spider.set_debug_motion_velocity(Vector3.ZERO)
	if spider.has_method("tick_crawler"):
		spider.tick_crawler(0.16)

	if not T.require_true(self, victim.bite_feedback_count >= 1, "Spider bite feedback contract requires nearby victims to receive bite feedback through the species crawler runtime"):
		return
	var feedback_species_id := str(victim.last_feedback.get("species_id", ""))
	if not T.require_true(self, feedback_species_id == "spider", "Spider bite feedback contract must preserve spider species identity in victim feedback"):
		return
	if not T.require_true(self, float(victim.last_feedback.get("intensity", 0.0)) > 0.0, "Spider bite feedback contract requires a non-zero bite intensity payload"):
		return

	var debug_state: Dictionary = spider.get_debug_state() if spider.has_method("get_debug_state") else {}
	if not T.require_true(self, int(debug_state.get("bite_count", 0)) >= 1, "Spider bite feedback contract requires debug_state bite_count to increment after a successful bite"):
		return

	spider.queue_free()
	victim.queue_free()
	await process_frame
	T.pass_and_quit(self)
