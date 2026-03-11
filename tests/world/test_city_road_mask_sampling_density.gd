extends SceneTree

const T := preload("res://tests/_test_util.gd")
const CityRoadMaskBuilder := preload("res://city_game/world/rendering/CityRoadMaskBuilder.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var builder = CityRoadMaskBuilder.new()
	if not T.require_true(self, builder.has_method("resolve_sample_spacing_m"), "CityRoadMaskBuilder must expose resolve_sample_spacing_m() for mask density control"):
		return

	var local_road_spacing := float(builder.call("resolve_sample_spacing_m", 11.0, 256.0, false))
	var local_stripe_spacing := float(builder.call("resolve_sample_spacing_m", 11.0, 256.0, true))
	var arterial_road_spacing := float(builder.call("resolve_sample_spacing_m", 22.0, 256.0, false))

	if not T.require_true(self, local_road_spacing >= 4.0, "Road mask sampling must not oversample sub-pixel road discs on 256m chunks"):
		return
	if not T.require_true(self, local_stripe_spacing >= 2.0, "Stripe mask sampling must stay coarser than the old 1m-scale oversampling path"):
		return
	if not T.require_true(self, arterial_road_spacing >= local_road_spacing, "Wider roads must not sample more densely than local roads"):
		return

	T.pass_and_quit(self)
