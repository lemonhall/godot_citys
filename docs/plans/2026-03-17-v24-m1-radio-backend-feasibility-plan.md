# V24 M1 Radio Backend Feasibility Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 为 `v24` 落下首批可执行实现：冻结并验证 vehicle radio 的 resolver contract、backend interface 与最小 driving-bound controller。

**Architecture:** 本阶段只建设 `city_game/world/radio/*` 的基础设施层，不接入 browser/full overlay。`CityRadioStreamResolver` 负责 direct / playlist wrapper 分类与 trace；`CityRadioStreamBackend` 与 `CityRadioMockBackend` 冻结 transport/playback state contract；`CityVehicleRadioController` 负责 `driving + power + selected station snapshot` 的最小生命周期，并通过 compact runtime state 向上游暴露结果。

**Tech Stack:** Godot 4.6、GDScript、现有 `PlayerController.gd` driving contract、现有 world contract 测试模式、`user://` 不参与本阶段。

---

### Task 1: Radio Resolver Contract

**Files:**
- Create: `tests/world/test_city_vehicle_radio_stream_resolution_contract.gd`
- Create: `city_game/world/radio/CityRadioStreamResolver.gd`
- Create: `city_game/world/radio/CityRadioStreamResolver.gd.uid`

**Step 1: Write the failing test**

- 断言 resolver 可稳定识别 `direct / pls / m3u / hls / asx / xspf`
- 断言输出最小字段：
  - `classification`
  - `final_url`
  - `candidates`
  - `resolution_trace`
  - `resolved_at_unix_sec`
- 断言相对 URL 会基于 source URL 转成绝对 URL

**Step 2: Run test to verify it fails**

Run:

```powershell
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/world/test_city_vehicle_radio_stream_resolution_contract.gd'
```

Expected: FAIL，因为 resolver 脚本尚不存在。

**Step 3: Write minimal implementation**

- 新建 `CityRadioStreamResolver.gd`
- 提供最小入口：
  - `resolve_document(source_url: String, body_text: String, content_type: String = "") -> Dictionary`
  - `resolve_direct_stream(source_url: String) -> Dictionary`
- 用轻量字符串解析支持：
  - `.pls`
  - `.m3u`
  - `.m3u8`
  - `.asx`
  - `.xspf`
- 输出 `resolution_trace`，保留每一步分类与候选 URL

**Step 4: Run test to verify it passes**

Run 同 Step 2。

Expected: PASS。

**Step 5: Commit**

```powershell
git add tests/world/test_city_vehicle_radio_stream_resolution_contract.gd city_game/world/radio/CityRadioStreamResolver.gd city_game/world/radio/CityRadioStreamResolver.gd.uid
git commit -m "feat: add radio stream resolver contract"
```

### Task 2: Backend Interface And Transport Config

**Files:**
- Create: `tests/world/test_city_vehicle_radio_backend_interface_contract.gd`
- Create: `city_game/world/radio/backend/CityRadioStreamBackend.gd`
- Create: `city_game/world/radio/backend/CityRadioStreamBackend.gd.uid`
- Create: `city_game/world/radio/backend/CityRadioMockBackend.gd`
- Create: `city_game/world/radio/backend/CityRadioMockBackend.gd.uid`

**Step 1: Write the failing test**

- 断言 backend 最小状态字段存在：
  - `backend_id`
  - `playback_state`
  - `buffer_state`
  - `resolved_url`
  - `metadata`
  - `latency_ms`
  - `underflow_count`
  - `error_code`
  - `error_message`
- 断言 mock backend 的 play/stop 调用会更新播放状态

**Step 2: Run test to verify it fails**

Run:

```powershell
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/world/test_city_vehicle_radio_backend_interface_contract.gd'
```

Expected: FAIL，因为 backend 脚本尚不存在。

**Step 3: Write minimal implementation**

- 新建 backend 基类，冻结 runtime state schema
- 新建 mock backend，记录最后一次播放请求并返回 compact runtime state
- 明确 UI/controller 只调用 backend 接口，不直接触碰 HTTP

**Step 4: Run test to verify it passes**

Run 同 Step 2。

Expected: PASS。

**Step 5: Commit**

```powershell
git add tests/world/test_city_vehicle_radio_backend_interface_contract.gd city_game/world/radio/backend/CityRadioStreamBackend.gd city_game/world/radio/backend/CityRadioStreamBackend.gd.uid city_game/world/radio/backend/CityRadioMockBackend.gd city_game/world/radio/backend/CityRadioMockBackend.gd.uid
git commit -m "feat: add radio backend interface contract"
```

### Task 3: Driving-Bound Controller Contract

**Files:**
- Create: `tests/world/test_city_vehicle_radio_drive_mode_contract.gd`
- Create: `city_game/world/radio/CityVehicleRadioController.gd`
- Create: `city_game/world/radio/CityVehicleRadioController.gd.uid`

**Step 1: Write the failing test**

- 断言未处于 driving mode 时，即使已选站点且 power=on，也不会向 backend 发起播放
- 断言进入 driving mode 后，power=on + selected station snapshot + resolved stream 会触发播放
- 断言退出 driving mode 会停止播放
- 断言 controller 对外暴露 compact runtime state，不 deep-copy 大目录 payload

**Step 2: Run test to verify it fails**

Run:

```powershell
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/world/test_city_vehicle_radio_drive_mode_contract.gd'
```

Expected: FAIL，因为 controller 脚本尚不存在。

**Step 3: Write minimal implementation**

- 新建 `CityVehicleRadioController.gd`
- 只实现本阶段需要的最小 contract：
  - `configure(backend: RefCounted)`
  - `set_driving_context(is_driving: bool, vehicle_state: Dictionary = {})`
  - `set_power_state(power_on: bool)`
  - `select_station(station_snapshot: Dictionary, resolved_stream: Dictionary)`
  - `stop(reason: String = "stopped")`
  - `get_runtime_state() -> Dictionary`
- 保留 `selected_station_snapshot` 副本
- backend stop/play 只在事件边界触发，不在 `_process()` 中轮询

**Step 4: Run test to verify it passes**

Run 同 Step 2。

Expected: PASS。

**Step 5: Commit**

```powershell
git add tests/world/test_city_vehicle_radio_drive_mode_contract.gd city_game/world/radio/CityVehicleRadioController.gd city_game/world/radio/CityVehicleRadioController.gd.uid
git commit -m "feat: add vehicle radio drive mode controller"
```

### Task 4: Verification And Traceability Refresh

**Files:**
- Modify: `docs/plan/v24-index.md`
- Modify: `docs/plan/v24-vehicle-radio-system.md`

**Step 1: Run focused verification**

Run:

```powershell
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/world/test_city_vehicle_radio_stream_resolution_contract.gd'
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/world/test_city_vehicle_radio_backend_interface_contract.gd'
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/world/test_city_vehicle_radio_drive_mode_contract.gd'
```

Expected: All PASS。

**Step 2: Refresh v24 docs**

- 在 `v24-index` 中把 `M1` 更新为进行中或完成态
- 在 `v24-vehicle-radio-system.md` 中回填已落地文件与验证入口
- 若真实 backend sample verification 尚未完成，明确保留为后续 gate，不得宣称直播 backend 已闭环

**Step 3: Commit**

```powershell
git add docs/plan/v24-index.md docs/plan/v24-vehicle-radio-system.md
git commit -m "docs: refresh v24 m1 traceability"
```
