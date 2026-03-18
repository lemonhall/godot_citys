extends SceneTree

const T := preload("res://tests/_test_util.gd")
const RESOLVER_PATH := "res://city_game/world/radio/CityRadioStreamResolver.gd"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	T.install_vehicle_radio_test_scope("vehicle_radio_stream_resolution_contract")
	var resolver_script := load(RESOLVER_PATH)
	if not T.require_true(self, resolver_script != null, "Vehicle radio stream resolution contract requires CityRadioStreamResolver.gd"):
		return

	var resolver = resolver_script.new()
	if not T.require_true(self, resolver != null and resolver.has_method("resolve_direct_stream"), "Vehicle radio stream resolution contract requires resolve_direct_stream()"):
		return
	if not T.require_true(self, resolver.has_method("resolve_document"), "Vehicle radio stream resolution contract requires resolve_document()"):
		return

	var direct_result: Dictionary = resolver.resolve_direct_stream("https://radio.example/live.mp3")
	if not _require_resolution_fields(direct_result, "direct"):
		return
	if not T.require_true(self, str(direct_result.get("final_url", "")) == "https://radio.example/live.mp3", "Direct stream resolution must preserve the original stream URL as final_url"):
		return

	var pls_result: Dictionary = resolver.resolve_document(
		"https://radio.example/catalog/listen.pls",
		"[playlist]\nNumberOfEntries=2\nFile1=stream/live.ogg\nTitle1=Example\nFile2=https://cdn.example/live.mp3\nTitle2=Fallback\n",
		"audio/x-scpls"
	)
	if not _require_resolution_fields(pls_result, "pls"):
		return
	if not T.require_true(self, str(pls_result.get("final_url", "")) == "https://radio.example/catalog/stream/live.ogg", "PLS resolution must resolve relative entries against the source URL"):
		return

	var m3u_result: Dictionary = resolver.resolve_document(
		"https://radio.example/dir/playlist.m3u",
		"#EXTM3U\n#EXTINF:-1,Main\nstream/main.mp3\nhttps://cdn.example/alt.aac\n",
		"audio/x-mpegurl"
	)
	if not _require_resolution_fields(m3u_result, "m3u"):
		return
	if not T.require_true(self, str(m3u_result.get("final_url", "")) == "https://radio.example/dir/stream/main.mp3", "M3U resolution must resolve the first playable candidate to an absolute URL"):
		return

	var hls_result: Dictionary = resolver.resolve_document(
		"https://radio.example/live/master.m3u8",
		"#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=64000\nvariant-low.m3u8\n#EXT-X-STREAM-INF:BANDWIDTH=128000\nvariant-high.m3u8\n",
		"application/vnd.apple.mpegurl"
	)
	if not _require_resolution_fields(hls_result, "hls"):
		return
	if not T.require_true(self, str(hls_result.get("final_url", "")) == "https://radio.example/live/master.m3u8", "HLS resolution must preserve the manifest URL as final_url for backend playback"):
		return

	var asx_result: Dictionary = resolver.resolve_document(
		"https://radio.example/radio/listen.asx",
		"<asx version=\"3.0\"><entry><ref href=\"../streams/live.asf\" /></entry></asx>",
		"video/x-ms-asf"
	)
	if not _require_resolution_fields(asx_result, "asx"):
		return
	if not T.require_true(self, str(asx_result.get("final_url", "")) == "https://radio.example/streams/live.asf", "ASX resolution must extract the first ref href as final_url"):
		return

	var xspf_result: Dictionary = resolver.resolve_document(
		"https://radio.example/radio/listen.xspf",
		"<?xml version=\"1.0\"?><playlist version=\"1\" xmlns=\"http://xspf.org/ns/0/\"><trackList><track><location>https://cdn.example/live.opus</location></track></trackList></playlist>",
		"application/xspf+xml"
	)
	if not _require_resolution_fields(xspf_result, "xspf"):
		return
	if not T.require_true(self, str(xspf_result.get("final_url", "")) == "https://cdn.example/live.opus", "XSPF resolution must extract the first track location as final_url"):
		return

	T.pass_and_quit(self)

func _require_resolution_fields(result: Dictionary, expected_classification: String) -> bool:
	if not T.require_true(self, str(result.get("classification", "")) == expected_classification, "Resolver classification must match %s" % expected_classification):
		return false
	if not T.require_true(self, not str(result.get("final_url", "")).is_empty(), "Resolver must expose final_url for %s" % expected_classification):
		return false
	var candidates := result.get("candidates", []) as Array
	if not T.require_true(self, not candidates.is_empty(), "Resolver must expose at least one candidate for %s" % expected_classification):
		return false
	var trace := result.get("resolution_trace", []) as Array
	if not T.require_true(self, not trace.is_empty(), "Resolver must expose a non-empty resolution_trace for %s" % expected_classification):
		return false
	if not T.require_true(self, int(result.get("resolved_at_unix_sec", 0)) > 0, "Resolver must stamp resolved_at_unix_sec for %s" % expected_classification):
		return false
	return true
