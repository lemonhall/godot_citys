extends SceneTree

const T := preload("res://tests/_test_util.gd")
const LAB_SCENE_PATH := "res://city_game/scenes/labs/SpiderCrawlerLab.tscn"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := load(LAB_SCENE_PATH) as PackedScene
	if not T.require_true(self, scene != null, "Spider crawler lab bite blood overlay contract requires SpiderCrawlerLab.tscn"):
		return

	var lab := scene.instantiate() as Node3D
	root.add_child(lab)
	await process_frame
	await process_frame

	var player := lab.get_node_or_null("Player")
	var hud := lab.get_node_or_null("Hud")
	var spider := lab.get_node_or_null("CrawlerRoot") as Node3D
	if not T.require_true(self, player != null and spider != null and hud != null, "Spider crawler lab bite blood overlay contract requires Player, Hud, and CrawlerRoot"):
		return
	if not T.require_true(self, player.has_method("get_spider_bite_feedback_state"), "Spider crawler lab bite blood overlay contract requires Player.get_spider_bite_feedback_state()"):
		return
	if not T.require_true(self, hud.has_method("get_spider_bite_overlay_state"), "Spider crawler lab bite blood overlay contract requires PrototypeHud.get_spider_bite_overlay_state()"):
		return

	if player.has_method("teleport_to_world_position"):
		player.teleport_to_world_position(spider.global_position + Vector3(0.0, 1.1, 0.95))
	await physics_frame
	await process_frame

	if spider.has_method("set_debug_motion_velocity"):
		spider.set_debug_motion_velocity(Vector3.ZERO)
	if spider.has_method("tick_crawler"):
		spider.tick_crawler(0.16)
	await process_frame
	await process_frame

	var bite_state: Dictionary = player.get_spider_bite_feedback_state()
	if not T.require_true(self, bool(bite_state.get("active", false)), "Spider crawler lab bite blood overlay contract requires spider contact to activate player bite feedback"):
		return
	if not T.require_true(self, int(bite_state.get("bite_count", 0)) >= 1, "Spider crawler lab bite blood overlay contract requires bite_count to advance after contact"):
		return

	var overlay_state: Dictionary = hud.get_spider_bite_overlay_state()
	if not T.require_true(self, bool(overlay_state.get("visible", false)), "Spider crawler lab bite blood overlay contract requires the HUD blood overlay to become visible after a bite"):
		return
	if not T.require_true(self, float(overlay_state.get("intensity", 0.0)) > 0.0, "Spider crawler lab bite blood overlay contract requires a non-zero blood overlay intensity"):
		return
	if not T.require_true(self, str(overlay_state.get("species_id", "")) == "spider", "Spider crawler lab bite blood overlay contract must keep spider as the overlay species source"):
		return

	var overlay_view := hud.get_node_or_null("Root/SpiderBiteBloodOverlay") as ColorRect
	if not T.require_true(self, overlay_view != null, "Spider crawler lab bite blood overlay contract requires a dedicated Root/SpiderBiteBloodOverlay view"):
		return
	if not T.require_true(self, overlay_view.material is ShaderMaterial, "Spider crawler lab bite blood overlay contract requires the visual to be shader-driven"):
		return

	lab.queue_free()
	await process_frame
	T.pass_and_quit(self)
