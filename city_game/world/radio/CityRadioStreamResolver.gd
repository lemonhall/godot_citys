extends RefCounted
class_name CityRadioStreamResolver

func resolve_direct_stream(source_url: String) -> Dictionary:
	var final_url := source_url.strip_edges()
	var candidates: Array = []
	if final_url != "":
		candidates.append(final_url)
	return _build_result("direct", final_url, candidates, [
		{
			"step": "direct",
			"source_url": final_url,
		}
	])

func resolve_document(source_url: String, body_text: String, content_type: String = "") -> Dictionary:
	var resolved_source_url := source_url.strip_edges()
	var normalized_body := body_text.replace("\r\n", "\n").replace("\r", "\n")
	var classification := _detect_classification(resolved_source_url, normalized_body, content_type)
	var trace: Array = [{
		"step": "classify",
		"classification": classification,
		"source_url": resolved_source_url,
		"content_type": content_type.strip_edges().to_lower(),
	}]
	match classification:
		"pls":
			var pls_candidates := _parse_pls_candidates(resolved_source_url, normalized_body)
			trace.append({
				"step": "parse_pls",
				"candidate_count": pls_candidates.size(),
			})
			return _build_result("pls", _first_candidate(pls_candidates), pls_candidates, trace)
		"m3u":
			var m3u_candidates := _parse_m3u_candidates(resolved_source_url, normalized_body)
			trace.append({
				"step": "parse_m3u",
				"candidate_count": m3u_candidates.size(),
			})
			return _build_result("m3u", _first_candidate(m3u_candidates), m3u_candidates, trace)
		"hls":
			var hls_candidates := [resolved_source_url]
			for candidate in _parse_m3u_candidates(resolved_source_url, normalized_body):
				if not hls_candidates.has(candidate):
					hls_candidates.append(candidate)
			trace.append({
				"step": "parse_hls_manifest",
				"candidate_count": hls_candidates.size(),
			})
			return _build_result("hls", resolved_source_url, hls_candidates, trace)
		"asx":
			var asx_candidates := _parse_regex_candidates(resolved_source_url, normalized_body, "href\\s*=\\s*\"([^\"]+)\"")
			trace.append({
				"step": "parse_asx",
				"candidate_count": asx_candidates.size(),
			})
			return _build_result("asx", _first_candidate(asx_candidates), asx_candidates, trace)
		"xspf":
			var xspf_candidates := _parse_regex_candidates(resolved_source_url, normalized_body, "<location>([^<]+)</location>")
			trace.append({
				"step": "parse_xspf",
				"candidate_count": xspf_candidates.size(),
			})
			return _build_result("xspf", _first_candidate(xspf_candidates), xspf_candidates, trace)
		_:
			return resolve_direct_stream(resolved_source_url)

func _detect_classification(source_url: String, body_text: String, content_type: String) -> String:
	var normalized_url := source_url.strip_edges().to_lower()
	var normalized_type := content_type.strip_edges().to_lower()
	var normalized_body := body_text.strip_edges().to_lower()
	if normalized_url.ends_with(".pls") or normalized_type.contains("scpls") or normalized_body.begins_with("[playlist]"):
		return "pls"
	if normalized_url.ends_with(".m3u8") or normalized_type.contains("apple.mpegurl") or normalized_body.contains("#ext-x-stream-inf") or normalized_body.contains("#ext-x-targetduration"):
		return "hls"
	if normalized_url.ends_with(".m3u") or normalized_body.begins_with("#extm3u"):
		return "m3u"
	if normalized_url.ends_with(".asx") or normalized_type.contains("asf") or normalized_body.contains("<asx"):
		return "asx"
	if normalized_url.ends_with(".xspf") or normalized_type.contains("xspf") or normalized_body.contains("<playlist"):
		return "xspf"
	return "direct"

func _parse_pls_candidates(source_url: String, body_text: String) -> Array:
	var candidates: Array = []
	for raw_line in body_text.split("\n", false):
		var line := raw_line.strip_edges()
		if line == "":
			continue
		var separator_index := line.find("=")
		if separator_index < 0:
			continue
		var key := line.substr(0, separator_index).strip_edges().to_lower()
		if not key.begins_with("file"):
			continue
		var candidate := _resolve_candidate_url(source_url, line.substr(separator_index + 1).strip_edges())
		if candidate != "" and not candidates.has(candidate):
			candidates.append(candidate)
	return candidates

func _parse_m3u_candidates(source_url: String, body_text: String) -> Array:
	var candidates: Array = []
	for raw_line in body_text.split("\n", false):
		var line := raw_line.strip_edges()
		if line == "" or line.begins_with("#"):
			continue
		var candidate := _resolve_candidate_url(source_url, line)
		if candidate != "" and not candidates.has(candidate):
			candidates.append(candidate)
	return candidates

func _parse_regex_candidates(source_url: String, body_text: String, pattern: String) -> Array:
	var regex := RegEx.new()
	if regex.compile(pattern) != OK:
		return []
	var candidates: Array = []
	for result in regex.search_all(body_text):
		if result == null:
			continue
		var raw_candidate := result.get_string(1).strip_edges()
		var candidate := _resolve_candidate_url(source_url, raw_candidate)
		if candidate != "" and not candidates.has(candidate):
			candidates.append(candidate)
	return candidates

func _resolve_candidate_url(source_url: String, candidate_url: String) -> String:
	var raw_candidate := candidate_url.strip_edges()
	if raw_candidate == "":
		return ""
	if raw_candidate.contains("://"):
		return raw_candidate
	if raw_candidate.begins_with("//"):
		return "%s:%s" % [_extract_url_scheme(source_url), raw_candidate]
	var source_parts := _split_url_parts(source_url)
	var scheme := str(source_parts.get("scheme", ""))
	var authority := str(source_parts.get("authority", ""))
	if scheme == "" or authority == "":
		return raw_candidate
	if raw_candidate.begins_with("/"):
		return "%s://%s%s" % [scheme, authority, _normalize_url_path(raw_candidate)]
	var base_path := str(source_parts.get("path", "/"))
	var directory_path := base_path
	var last_slash := directory_path.rfind("/")
	if last_slash >= 0:
		directory_path = directory_path.substr(0, last_slash + 1)
	else:
		directory_path = "/"
	return "%s://%s%s" % [scheme, authority, _normalize_url_path(directory_path + raw_candidate)]

func _split_url_parts(source_url: String) -> Dictionary:
	var separator_index := source_url.find("://")
	if separator_index < 0:
		return {}
	var scheme := source_url.substr(0, separator_index)
	var remainder := source_url.substr(separator_index + 3)
	var slash_index := remainder.find("/")
	if slash_index < 0:
		return {
			"scheme": scheme,
			"authority": remainder,
			"path": "/",
		}
	return {
		"scheme": scheme,
		"authority": remainder.substr(0, slash_index),
		"path": remainder.substr(slash_index),
	}

func _extract_url_scheme(source_url: String) -> String:
	var separator_index := source_url.find("://")
	if separator_index < 0:
		return "https"
	return source_url.substr(0, separator_index)

func _normalize_url_path(raw_path: String) -> String:
	var segments: Array = []
	for segment_variant in raw_path.split("/", false):
		var segment := str(segment_variant)
		if segment == "" or segment == ".":
			continue
		if segment == "..":
			if not segments.is_empty():
				segments.pop_back()
			continue
		segments.append(segment)
	return "/" + "/".join(PackedStringArray(segments))

func _first_candidate(candidates: Array) -> String:
	if candidates.is_empty():
		return ""
	return str(candidates[0])

func _build_result(classification: String, final_url: String, candidates: Array, resolution_trace: Array) -> Dictionary:
	return {
		"classification": classification,
		"final_url": final_url,
		"candidates": candidates.duplicate(true),
		"resolution_trace": resolution_trace.duplicate(true),
		"resolved_at_unix_sec": int(Time.get_unix_time_from_system()),
	}
