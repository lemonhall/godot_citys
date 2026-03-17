extends RefCounted
class_name CityRadioBrowserApi

const DEFAULT_BASE_URL := "https://de1.api.radio-browser.info"
const DEFAULT_CONNECT_TIMEOUT_MSEC := 15000
const DEFAULT_CALL_TIMEOUT_MSEC := 20000
const DEFAULT_MAX_BODY_BYTES := 8 * 1024 * 1024

var _base_url := DEFAULT_BASE_URL

func _init(base_url: String = DEFAULT_BASE_URL) -> void:
	_base_url = base_url.strip_edges()
	if _base_url == "":
		_base_url = DEFAULT_BASE_URL

func list_countries() -> Dictionary:
	var request_result := _request_json_array("/json/countries")
	if not bool(request_result.get("success", false)):
		return {
			"success": false,
			"countries": [],
			"error": str(request_result.get("error", "request_failed")),
		}
	return {
		"success": true,
		"countries": (request_result.get("items", []) as Array).duplicate(true),
		"error": "",
	}

func list_stations_by_country(country_name: String, limit: int = 200) -> Dictionary:
	var normalized_country_name := country_name.strip_edges()
	if normalized_country_name == "":
		return {
			"success": false,
			"stations": [],
			"error": "invalid_country_name",
		}
	var request_path := "/json/stations/bycountry/%s?hidebroken=true&order=votes&reverse=true&limit=%d" % [
		normalized_country_name.uri_encode(),
		clampi(limit, 1, 500),
	]
	var request_result := _request_json_array(request_path)
	if not bool(request_result.get("success", false)):
		return {
			"success": false,
			"stations": [],
			"error": str(request_result.get("error", "request_failed")),
		}
	return {
		"success": true,
		"stations": (request_result.get("items", []) as Array).duplicate(true),
		"error": "",
	}

func _request_json_array(request_path: String) -> Dictionary:
	var endpoint := _parse_base_endpoint()
	if endpoint.is_empty():
		return {
			"success": false,
			"items": [],
			"error": "invalid_base_url",
		}
	var request_target := _combine_request_target(str(endpoint.get("base_path", "")), request_path)
	var client := HTTPClient.new()
	var tls_options: TLSOptions = TLSOptions.client() if bool(endpoint.get("use_tls", true)) else null
	var connect_error := client.connect_to_host(
		str(endpoint.get("host", "")),
		int(endpoint.get("port", 443)),
		tls_options
	)
	if connect_error != OK:
		client.close()
		return {
			"success": false,
			"items": [],
			"error": "connect_failed",
		}
	var connect_result := _wait_until_connected(client, DEFAULT_CONNECT_TIMEOUT_MSEC)
	if not bool(connect_result.get("success", false)):
		client.close()
		return {
			"success": false,
			"items": [],
			"error": str(connect_result.get("error", "connect_timeout")),
		}
	var request_error := client.request(HTTPClient.METHOD_GET, request_target, PackedStringArray([
		"Accept: application/json",
		"User-Agent: godot-citys-v24-radio/1",
	]))
	if request_error != OK:
		client.close()
		return {
			"success": false,
			"items": [],
			"error": "request_failed",
		}
	var response_result := _read_response(client, DEFAULT_CALL_TIMEOUT_MSEC)
	client.close()
	if not bool(response_result.get("success", false)):
		return {
			"success": false,
			"items": [],
			"error": str(response_result.get("error", "response_failed")),
		}
	var status_code := int(response_result.get("status_code", 0))
	if status_code < 200 or status_code >= 300:
		return {
			"success": false,
			"items": [],
			"error": "http_%d" % status_code,
		}
	var parsed: Variant = JSON.parse_string(str(response_result.get("body_text", "")))
	if not (parsed is Array):
		return {
			"success": false,
			"items": [],
			"error": "invalid_json",
		}
	return {
		"success": true,
		"items": (parsed as Array).duplicate(true),
		"error": "",
	}

func _wait_until_connected(client: HTTPClient, timeout_msec: int) -> Dictionary:
	var started_msec := Time.get_ticks_msec()
	while true:
		var poll_error := client.poll()
		if poll_error != OK:
			return {
				"success": false,
				"error": "poll_failed",
			}
		var status := client.get_status()
		if status == HTTPClient.STATUS_CONNECTED or status == HTTPClient.STATUS_REQUESTING or status == HTTPClient.STATUS_BODY:
			return {
				"success": true,
				"error": "",
			}
		if status == HTTPClient.STATUS_DISCONNECTED:
			return {
				"success": false,
				"error": "disconnected",
			}
		if Time.get_ticks_msec() - started_msec > timeout_msec:
			return {
				"success": false,
				"error": "connect_timeout",
			}
		OS.delay_msec(10)
	return {
		"success": false,
		"error": "connect_timeout",
	}

func _read_response(client: HTTPClient, timeout_msec: int) -> Dictionary:
	var started_msec := Time.get_ticks_msec()
	var response_started := false
	var body := PackedByteArray()
	while true:
		var poll_error := client.poll()
		if poll_error != OK:
			return {
				"success": false,
				"status_code": 0,
				"body_text": "",
				"error": "poll_failed",
			}
		if client.has_response():
			response_started = true
		var status := client.get_status()
		if status == HTTPClient.STATUS_BODY:
			var chunk := client.read_response_body_chunk()
			if not chunk.is_empty():
				body.append_array(chunk)
				if body.size() > DEFAULT_MAX_BODY_BYTES:
					return {
						"success": false,
						"status_code": int(client.get_response_code()),
						"body_text": "",
						"error": "response_too_large",
					}
		elif response_started and (status == HTTPClient.STATUS_CONNECTED or status == HTTPClient.STATUS_DISCONNECTED):
			return {
				"success": true,
				"status_code": int(client.get_response_code()),
				"body_text": body.get_string_from_utf8(),
				"error": "",
			}
		if Time.get_ticks_msec() - started_msec > timeout_msec:
			return {
				"success": false,
				"status_code": int(client.get_response_code()),
				"body_text": body.get_string_from_utf8(),
				"error": "response_timeout",
			}
		OS.delay_msec(10)
	return {
		"success": false,
		"status_code": int(client.get_response_code()),
		"body_text": body.get_string_from_utf8(),
		"error": "response_timeout",
	}

func _parse_base_endpoint() -> Dictionary:
	var raw := _base_url.strip_edges()
	if raw == "":
		raw = DEFAULT_BASE_URL
	var use_tls := true
	if raw.begins_with("https://"):
		raw = raw.trim_prefix("https://")
	elif raw.begins_with("http://"):
		raw = raw.trim_prefix("http://")
		use_tls = false
	raw = raw.trim_suffix("/")
	var host_port := raw
	var base_path := ""
	var slash_index := raw.find("/")
	if slash_index >= 0:
		host_port = raw.substr(0, slash_index)
		base_path = raw.substr(slash_index)
	var host := host_port
	var port := 443 if use_tls else 80
	var colon_index := host_port.rfind(":")
	if colon_index > 0 and colon_index < host_port.length() - 1:
		var parsed_port := host_port.substr(colon_index + 1).to_int()
		if parsed_port > 0:
			host = host_port.substr(0, colon_index)
			port = parsed_port
	host = host.strip_edges()
	if host == "":
		return {}
	return {
		"host": host,
		"port": port,
		"use_tls": use_tls,
		"base_path": base_path,
	}

func _combine_request_target(base_path: String, request_path: String) -> String:
	var normalized_base := base_path.strip_edges()
	var normalized_request := request_path.strip_edges()
	if normalized_request == "":
		return normalized_base if normalized_base != "" else "/"
	if not normalized_request.begins_with("/"):
		normalized_request = "/" + normalized_request
	if normalized_base == "" or normalized_base == "/":
		return normalized_request
	if normalized_base.ends_with("/"):
		normalized_base = normalized_base.trim_suffix("/")
	return normalized_base + normalized_request
