extends RefCounted

const CACHE_SCHEMA_VERSION := 1
const CACHE_DIRECTORY := "user://cache/world/road_surface"
const DEFAULT_MASK_RESOLUTION := 256

func build_cache_signature(profile: Dictionary, chunk_size_m: float, detail_mode: String = "full", mask_resolution: int = DEFAULT_MASK_RESOLUTION) -> String:
	var road_signature := str(profile.get("road_signature", profile.get("signature", "")))
	return "v%d_res%d_chunk%d_mode%s_road%s" % [
		CACHE_SCHEMA_VERSION,
		mask_resolution,
		int(round(chunk_size_m)),
		detail_mode,
		road_signature,
	]

func build_cache_path(profile: Dictionary, chunk_size_m: float, detail_mode: String = "full", mask_resolution: int = DEFAULT_MASK_RESOLUTION) -> String:
	var signature := build_cache_signature(profile, chunk_size_m, detail_mode, mask_resolution)
	return "%s/road_surface_%s.bin" % [CACHE_DIRECTORY, signature.md5_text()]

func clear_cache_for_profile(profile: Dictionary, chunk_size_m: float, detail_mode: String = "full", mask_resolution: int = DEFAULT_MASK_RESOLUTION) -> void:
	var cache_path := build_cache_path(profile, chunk_size_m, detail_mode, mask_resolution)
	if FileAccess.file_exists(cache_path):
		DirAccess.remove_absolute(cache_path)

func load_surface_masks(profile: Dictionary, chunk_size_m: float, detail_mode: String = "full", mask_resolution: int = DEFAULT_MASK_RESOLUTION) -> Dictionary:
	var cache_path := build_cache_path(profile, chunk_size_m, detail_mode, mask_resolution)
	var signature := build_cache_signature(profile, chunk_size_m, detail_mode, mask_resolution)
	if not FileAccess.file_exists(cache_path):
		return {
			"hit": false,
			"path": cache_path,
			"signature": signature,
			"size_bytes": 0,
			"error": "missing",
			"road_bytes": PackedByteArray(),
			"stripe_bytes": PackedByteArray(),
		}

	var file := FileAccess.open(cache_path, FileAccess.READ)
	if file == null:
		return {
			"hit": false,
			"path": cache_path,
			"signature": signature,
			"size_bytes": 0,
			"error": "open_failed",
			"road_bytes": PackedByteArray(),
			"stripe_bytes": PackedByteArray(),
		}

	var payload_variant: Variant = file.get_var(false)
	var size_bytes := int(file.get_length())
	if not (payload_variant is Dictionary):
		return {
			"hit": false,
			"path": cache_path,
			"signature": signature,
			"size_bytes": size_bytes,
			"error": "invalid_payload",
			"road_bytes": PackedByteArray(),
			"stripe_bytes": PackedByteArray(),
		}

	var payload: Dictionary = payload_variant
	if int(payload.get("schema_version", -1)) != CACHE_SCHEMA_VERSION:
		return {
			"hit": false,
			"path": cache_path,
			"signature": signature,
			"size_bytes": size_bytes,
			"error": "schema_mismatch",
			"road_bytes": PackedByteArray(),
			"stripe_bytes": PackedByteArray(),
		}
	if str(payload.get("signature", "")) != signature:
		return {
			"hit": false,
			"path": cache_path,
			"signature": signature,
			"size_bytes": size_bytes,
			"error": "signature_mismatch",
			"road_bytes": PackedByteArray(),
			"stripe_bytes": PackedByteArray(),
		}

	var road_bytes: PackedByteArray = payload.get("road_bytes", PackedByteArray())
	var stripe_bytes: PackedByteArray = payload.get("stripe_bytes", PackedByteArray())
	return {
		"hit": true,
		"path": cache_path,
		"signature": signature,
		"size_bytes": size_bytes,
		"error": "",
		"road_bytes": road_bytes,
		"stripe_bytes": stripe_bytes,
	}

func save_surface_masks(profile: Dictionary, chunk_size_m: float, road_bytes: PackedByteArray, stripe_bytes: PackedByteArray, detail_mode: String = "full", mask_resolution: int = DEFAULT_MASK_RESOLUTION) -> Dictionary:
	var cache_path := build_cache_path(profile, chunk_size_m, detail_mode, mask_resolution)
	var signature := build_cache_signature(profile, chunk_size_m, detail_mode, mask_resolution)
	var make_dir_error := DirAccess.make_dir_recursive_absolute(CACHE_DIRECTORY)
	if make_dir_error != OK:
		return {
			"success": false,
			"path": cache_path,
			"signature": signature,
			"size_bytes": 0,
			"error": "mkdir_failed",
		}

	var file := FileAccess.open(cache_path, FileAccess.WRITE)
	if file == null:
		return {
			"success": false,
			"path": cache_path,
			"signature": signature,
			"size_bytes": 0,
			"error": "open_failed",
		}

	file.store_var({
		"schema_version": CACHE_SCHEMA_VERSION,
		"signature": signature,
		"road_bytes": road_bytes,
		"stripe_bytes": stripe_bytes,
	}, false)
	return {
		"success": true,
		"path": cache_path,
		"signature": signature,
		"size_bytes": int(file.get_position()),
		"error": "",
	}
