extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var grammar_script := load("res://city_game/world/model/CityAddressGrammar.gd")
	var config_script := load("res://city_game/world/model/CityWorldConfig.gd")
	var block_layout_script := load("res://city_game/world/model/CityBlockLayout.gd")
	if grammar_script == null or config_script == null or block_layout_script == null:
		T.fail_and_quit(self, "Address grammar test requires CityAddressGrammar, CityWorldConfig, and CityBlockLayout")
		return

	var grammar = grammar_script.new()
	var config = config_script.new()
	var block_layout = block_layout_script.new()
	block_layout.setup(config)

	if not T.require_true(self, grammar.has_method("build_address_record"), "CityAddressGrammar must expose build_address_record()"):
		return
	if not T.require_true(self, block_layout.has_method("get_parcels_for_block"), "CityBlockLayout must expose get_parcels_for_block() for address grammar coverage"):
		return

	var block_data: Dictionary = (block_layout.get_blocks_for_chunk(Vector2i.ZERO) as Array)[0]
	var parcels: Array = block_layout.get_parcels_for_block(block_data)
	if not T.require_true(self, parcels.size() >= 2, "Address grammar test requires at least two parcels in the sample block"):
		return

	var road_name := "Atlas Avenue"
	var even_record: Dictionary = grammar.build_address_record(block_data, parcels[0], 0, road_name, "right")
	var odd_record: Dictionary = grammar.build_address_record(block_data, parcels[1], 0, road_name, "left")
	var repeat_record: Dictionary = grammar.build_address_record(block_data, parcels[0], 0, road_name, "right")

	if not T.require_true(self, int(even_record.get("house_number", 0)) % 2 == 0, "Right-side frontage slots must resolve to even house numbers"):
		return
	if not T.require_true(self, int(odd_record.get("house_number", 0)) % 2 == 1, "Left-side frontage slots must resolve to odd house numbers"):
		return
	if not T.require_true(self, int(odd_record.get("house_number", 0)) != int(even_record.get("house_number", 0)), "Opposite block faces must not collapse onto the same house number"):
		return
	if not T.require_true(self, str(even_record.get("display_name", "")) == "%d %s" % [int(even_record.get("house_number", 0)), road_name], "Address display format must freeze as house_number + canonical_road_name"):
		return
	if not T.require_true(self, repeat_record == even_record, "Address grammar must be deterministic for the same parcel/frontage slot input"):
		return

	T.pass_and_quit(self)
