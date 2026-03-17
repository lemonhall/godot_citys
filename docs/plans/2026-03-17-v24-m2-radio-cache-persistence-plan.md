# V24 M2 Radio Cache Persistence Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 为 `v24` 落下 `catalog cache + user persistence` 的正式底座，让 countries index、per-country station page、resolve cache 与 presets/favorites/recents/session_state 具备稳定的 `user://` contract。

**Architecture:** `CityRadioCatalogStore` 负责 `user://cache/radio/` 下的可重建网络缓存，冻结路径、schema、TTL 与 stale fallback 语义；`CityRadioUserStateStore` 负责 `user://radio/` 下的用户状态文件，冻结 `presets / favorites / recents / session_state` 结构，并保证输出为 pretty JSON、输入为 defensive-copy snapshot。

**Tech Stack:** Godot 4.6、GDScript、`FileAccess`、`DirAccess`、`JSON`、现有 `user://cache/world/*` 模式、`v24` PRD/plan contract。

---

### Task 1: Catalog Cache Contract

**Files:**
- Create: `tests/world/test_city_vehicle_radio_catalog_cache_contract.gd`
- Create: `city_game/world/radio/CityRadioCatalogStore.gd`

**Step 1: Write the failing test**

- 断言路径冻结为：
  - `user://cache/radio/countries.index.json`
  - `user://cache/radio/countries.meta.json`
  - `user://cache/radio/countries/<country_code>/stations.index.json`
  - `user://cache/radio/countries/<country_code>/stations.meta.json`
  - `user://cache/radio/stream_resolve_cache.json`
- 断言 countries index、station page、resolve cache 都可写入并读回
- 断言 JSON 为多行 pretty-print
- 断言过期时返回 `stale=true`，但仍能回退到旧缓存

**Step 2: Run test to verify it fails**

```powershell
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/world/test_city_vehicle_radio_catalog_cache_contract.gd'
```

Expected: FAIL，因为 `CityRadioCatalogStore.gd` 尚不存在。

**Step 3: Write minimal implementation**

- 新建 `CityRadioCatalogStore.gd`
- 提供最小方法：
  - `build_countries_index_path()`
  - `build_countries_meta_path()`
  - `build_country_station_index_path(country_code: String)`
  - `build_country_station_meta_path(country_code: String)`
  - `build_stream_resolve_cache_path()`
  - `save_countries_index(...)` / `load_countries_index(...)`
  - `save_country_station_page(...)` / `load_country_station_page(...)`
  - `save_stream_resolve_cache(...)` / `load_stream_resolve_cache(...)`
- TTL 先冻结：
  - countries / station page：`72h`
  - resolve cache：`6h`

**Step 4: Run test to verify it passes**

Run 同 Step 2。

**Step 5: Commit**

```powershell
git add tests/world/test_city_vehicle_radio_catalog_cache_contract.gd city_game/world/radio/CityRadioCatalogStore.gd
git commit -m "feat: add radio catalog cache store"
```

### Task 2: User State Persistence Contract

**Files:**
- Create: `tests/world/test_city_vehicle_radio_preset_persistence.gd`
- Create: `city_game/world/radio/CityRadioUserStateStore.gd`

**Step 1: Write the failing test**

- 断言路径冻结为：
  - `user://radio/presets.json`
  - `user://radio/favorites.json`
  - `user://radio/recents.json`
  - `user://radio/session_state.json`
- 断言 presets/favorites/recents/session_state 都能写入并读回
- 断言持久化的是 station snapshot 副本，而不是外部可变引用
- 断言 JSON 为多行 pretty-print

**Step 2: Run test to verify it fails**

```powershell
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/world/test_city_vehicle_radio_preset_persistence.gd'
```

Expected: FAIL，因为 `CityRadioUserStateStore.gd` 尚不存在。

**Step 3: Write minimal implementation**

- 新建 `CityRadioUserStateStore.gd`
- 提供最小方法：
  - `build_presets_path()`
  - `build_favorites_path()`
  - `build_recents_path()`
  - `build_session_state_path()`
  - `save_presets(...)` / `load_presets()`
  - `save_favorites(...)` / `load_favorites()`
  - `save_recents(...)` / `load_recents()`
  - `save_session_state(...)` / `load_session_state()`
- 所有写入统一使用 pretty JSON 与 schema_version

**Step 4: Run test to verify it passes**

Run 同 Step 2。

**Step 5: Commit**

```powershell
git add tests/world/test_city_vehicle_radio_preset_persistence.gd city_game/world/radio/CityRadioUserStateStore.gd
git commit -m "feat: add radio user state persistence"
```
