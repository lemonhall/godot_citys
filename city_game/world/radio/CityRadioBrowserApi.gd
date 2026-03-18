extends RefCounted
class_name CityRadioBrowserApi

const DEFAULT_BASE_URL := "https://de1.api.radio-browser.info"
const DEFAULT_CONNECT_TIMEOUT_MSEC := 15000
const DEFAULT_CALL_TIMEOUT_MSEC := 20000
const DEFAULT_MAX_BODY_BYTES := 8 * 1024 * 1024
const PROXY_MODE_DIRECT := "direct"
const PROXY_MODE_SYSTEM := "system_proxy"
const PROXY_MODE_LOCAL := "local_proxy"
const DEFAULT_LOCAL_PROXY_HOST := "127.0.0.1"
const DEFAULT_LOCAL_PROXY_PORT := 7897

var _base_url := DEFAULT_BASE_URL

static var _proxy_settings := {
	"proxy_mode": PROXY_MODE_DIRECT,
	"local_proxy_host": DEFAULT_LOCAL_PROXY_HOST,
	"local_proxy_port": DEFAULT_LOCAL_PROXY_PORT,
}

static func configure_proxy_settings(settings: Dictionary) -> Dictionary:
	_proxy_settings = _normalize_proxy_settings(settings)
	return _proxy_settings.duplicate(true)

static func get_proxy_settings() -> Dictionary:
	return resolve_proxy_settings(_proxy_settings)

static func resolve_proxy_settings(settings: Dictionary = {}) -> Dictionary:
	var normalized_settings := _normalize_proxy_settings(settings if not settings.is_empty() else _proxy_settings)
	var proxy_mode := str(normalized_settings.get("proxy_mode", PROXY_MODE_DIRECT))
	var local_proxy_host := str(normalized_settings.get("local_proxy_host", DEFAULT_LOCAL_PROXY_HOST)).strip_edges()
	var local_proxy_port := int(normalized_settings.get("local_proxy_port", DEFAULT_LOCAL_PROXY_PORT))
	var env_http_proxy := OS.get_environment("HTTP_PROXY").strip_edges()
	var env_https_proxy := OS.get_environment("HTTPS_PROXY").strip_edges()
	var env_all_proxy := OS.get_environment("ALL_PROXY").strip_edges()
	var effective_enabled := false
	var effective_host := ""
	var effective_port := 0
	var effective_label := "直连"
	var effective_error := ""
	match proxy_mode:
		PROXY_MODE_LOCAL:
			effective_enabled = local_proxy_host != "" and local_proxy_port > 0
			effective_host = local_proxy_host
			effective_port = local_proxy_port
			effective_label = "本机代理 %s:%d" % [effective_host, effective_port]
			if not effective_enabled:
				effective_error = "invalid_local_proxy"
		PROXY_MODE_SYSTEM:
			var parsed_system_proxy := _parse_proxy_url(
				env_https_proxy if env_https_proxy != "" else (env_http_proxy if env_http_proxy != "" else env_all_proxy)
			)
			effective_enabled = bool(parsed_system_proxy.get("enabled", false))
			effective_host = str(parsed_system_proxy.get("host", ""))
			effective_port = int(parsed_system_proxy.get("port", 0))
			effective_label = "系统代理"
			effective_error = str(parsed_system_proxy.get("error", ""))
		_:
			proxy_mode = PROXY_MODE_DIRECT
	return {
		"proxy_mode": proxy_mode,
		"local_proxy_host": local_proxy_host,
		"local_proxy_port": local_proxy_port,
		"enabled": effective_enabled,
		"host": effective_host,
		"port": effective_port,
		"effective_label": effective_label,
		"effective_error": effective_error,
		"env_http_proxy": env_http_proxy,
		"env_https_proxy": env_https_proxy,
		"env_all_proxy": env_all_proxy,
	}

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
	_apply_proxy_settings(client)
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

func _apply_proxy_settings(client: HTTPClient) -> void:
	if client == null:
		return
	var proxy_settings := get_proxy_settings()
	if not bool(proxy_settings.get("enabled", false)):
		return
	var proxy_host := str(proxy_settings.get("host", "")).strip_edges()
	var proxy_port := int(proxy_settings.get("port", 0))
	if proxy_host == "" or proxy_port <= 0:
		return
	client.set_http_proxy(proxy_host, proxy_port)
	client.set_https_proxy(proxy_host, proxy_port)

static func _normalize_proxy_settings(settings: Dictionary) -> Dictionary:
	var proxy_mode := str(settings.get("proxy_mode", PROXY_MODE_DIRECT)).strip_edges()
	if proxy_mode not in [PROXY_MODE_DIRECT, PROXY_MODE_SYSTEM, PROXY_MODE_LOCAL]:
		proxy_mode = PROXY_MODE_DIRECT
	var local_proxy_host := str(settings.get("local_proxy_host", DEFAULT_LOCAL_PROXY_HOST)).strip_edges()
	if local_proxy_host == "":
		local_proxy_host = DEFAULT_LOCAL_PROXY_HOST
	var local_proxy_port := int(settings.get("local_proxy_port", DEFAULT_LOCAL_PROXY_PORT))
	if local_proxy_port <= 0:
		local_proxy_port = DEFAULT_LOCAL_PROXY_PORT
	return {
		"proxy_mode": proxy_mode,
		"local_proxy_host": local_proxy_host,
		"local_proxy_port": local_proxy_port,
	}

static func _parse_proxy_url(proxy_url: String) -> Dictionary:
	var raw_proxy_url := proxy_url.strip_edges()
	if raw_proxy_url == "":
		return {
			"enabled": false,
			"host": "",
			"port": 0,
			"error": "missing_system_proxy",
		}
	if raw_proxy_url.begins_with("https://"):
		raw_proxy_url = raw_proxy_url.trim_prefix("https://")
	elif raw_proxy_url.begins_with("http://"):
		raw_proxy_url = raw_proxy_url.trim_prefix("http://")
	var slash_index := raw_proxy_url.find("/")
	if slash_index >= 0:
		raw_proxy_url = raw_proxy_url.substr(0, slash_index)
	var at_index := raw_proxy_url.rfind("@")
	if at_index >= 0 and at_index < raw_proxy_url.length() - 1:
		raw_proxy_url = raw_proxy_url.substr(at_index + 1)
	var host := raw_proxy_url
	var port := 0
	var colon_index := raw_proxy_url.rfind(":")
	if colon_index > 0 and colon_index < raw_proxy_url.length() - 1:
		host = raw_proxy_url.substr(0, colon_index)
		port = raw_proxy_url.substr(colon_index + 1).to_int()
	host = host.strip_edges()
	if host == "" or port <= 0:
		return {
			"enabled": false,
			"host": "",
			"port": 0,
			"error": "invalid_system_proxy",
		}
	return {
		"enabled": true,
		"host": host,
		"port": port,
		"error": "",
	}
