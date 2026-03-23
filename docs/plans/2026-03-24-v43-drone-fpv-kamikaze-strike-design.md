# V43 Drone FPV Kamikaze Strike Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 在 `v42` 无人机基础上，新增正式的 `右键 FPV/ADS -> 左键锁定 -> 第一视角红外滤镜自杀冲击 -> 爆炸后切回玩家` 玩法链。

**Architecture:** 保持 `v42` 的 `drone-only runtime` 不变，在 `CityPlayerDroneRuntime.gd` 内新增 `view_mode + strike_state` 子状态机，避免把自杀冲击做成独立投射物旁路。无人机准星目标、FPV 相机、滤镜 overlay、爆炸 closeout 都继续沿 `CityPrototype` / 现有战斗解析主链扩展，不另起一套 lab-only 逻辑。

**Tech Stack:** Godot 4.6、GDScript、CanvasLayer/ColorRect + CanvasItem shader、现有 `CityPrototype` HUD/crosshair 主链、headless world/e2e tests。

---

### Task 1: 冻结 FPV/ADS 合同测试

**Files:**
- Create: `tests/world/test_city_player_drone_fpv_ads_contract.gd`
- Modify: `tests/world/test_city_player_drone_flight_input_contract.gd`
- Modify: `tests/world/test_city_player_drone_speed_and_attitude_contract.gd`
- Test: `res://tests/world/test_city_player_drone_fpv_ads_contract.gd`

**Step 1: Write the failing test**

- 断言 `active` drone 右键后进入 `FPV/ADS`。
- 断言 debug state 暴露：
  - `view_mode`
  - `strike_state`
  - `fpv_filter_enabled`
  - `fpv_crosshair_visible`
  - `fpv_fov_deg`
- 断言第三人称下该合同默认关闭。

**Step 2: Run test to verify it fails**

Run:

```powershell
$project='E:\development\godot_citys'
$godot='E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe'
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/world/test_city_player_drone_fpv_ads_contract.gd'
```

Expected: FAIL，因为当前无人机 runtime 尚无 `FPV/ADS` debug contract。

**Step 3: Write minimal implementation**

- 在 `CityPlayerDroneRuntime.gd` 中加入 `view_mode` 子状态。
- 定义 `third_person` / `fpv_ads`。
- 初步接入右键切换、debug state 字段、相机模式与滤镜开关。

**Step 4: Run test to verify it passes**

Run 同上。

Expected: PASS。

### Task 2: 搭建 FPV Camera + Infrared Overlay

**Files:**
- Modify: `city_game/combat/drone/CityDroneGunship.tscn`
- Modify: `city_game/combat/drone/CityPlayerDroneCameraRig.tscn`
- Create: `city_game/combat/drone/shaders/CityDroneFpvInfraredOverlay.gdshader`
- Test: `res://tests/world/test_city_drone_gunship_scene_contract.gd`

**Step 1: Write the failing test**

- 扩展 `test_city_drone_gunship_scene_contract.gd`：
  - 要求正式 `FPV` camera anchor / camera node 存在。
  - 要求正式红外滤镜 shader 资源存在并通过场景挂载。

**Step 2: Run test to verify it fails**

Run:

```powershell
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/world/test_city_drone_gunship_scene_contract.gd'
```

Expected: FAIL，因为当前无人机场景没有 `FPV` camera/overlay 资源。

**Step 3: Write minimal implementation**

- 在 camera rig 中加入 `FPV` camera 位姿或正式 `Marker3D` anchor。
- 在无人机场景中加入 `CanvasLayer + ColorRect`，挂 `CityDroneFpvInfraredOverlay.gdshader`。
- 先只做到场景可切换、资源引用稳定。

**Step 4: Run test to verify it passes**

Run 同上。

Expected: PASS。

### Task 3: 锁定目标与自杀冲击状态机

**Files:**
- Create: `tests/world/test_city_player_drone_suicide_strike_contract.gd`
- Modify: `city_game/combat/drone/CityPlayerDroneRuntime.gd`
- Modify: `city_game/combat/drone/CityPlayerDroneFlightController.gd`
- Test: `res://tests/world/test_city_player_drone_suicide_strike_contract.gd`

**Step 1: Write the failing test**

- 断言仅在 `fpv_ads` 下左键才会触发锁定。
- 断言锁定后进入 `striking`。
- 断言锁定后手动飞行输入失效。
- 断言若射线无命中，仍会生成 fallback 目标点。

**Step 2: Run test to verify it fails**

Run:

```powershell
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/world/test_city_player_drone_suicide_strike_contract.gd'
```

Expected: FAIL，因为当前无人机没有锁定/冲刺状态。

**Step 3: Write minimal implementation**

- 在 runtime 中增加：
  - `strike_state = idle/locked/striking/exploding`
  - 当前准星射线求交
  - fallback 目标点
  - committed 后禁用人工输入
- 在 flight controller 中增加一条 `committed strike` 的高速追目标路径。

**Step 4: Run test to verify it passes**

Run 同上。

Expected: PASS。

### Task 4: 爆炸 closeout 与主世界恢复

**Files:**
- Modify: `city_game/combat/drone/CityPlayerDroneRuntime.gd`
- Modify: `city_game/scripts/CityPrototype.gd`
- Modify: `tests/e2e/test_city_player_drone_flow.gd`
- Create: `tests/e2e/test_city_player_drone_kamikaze_flow.gd`
- Test: `res://tests/e2e/test_city_player_drone_kamikaze_flow.gd`

**Step 1: Write the failing test**

- 断言 `FPV/ADS -> LMB lock -> strike -> explode -> player restored` 端到端成立。
- 断言爆炸后：
  - `camera_owner == player`
  - `input_owner == player`
  - `system_state == stowed`
- 断言 `CityPrototype` 的爆炸解析主链被调用。

**Step 2: Run test to verify it fails**

Run:

```powershell
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/e2e/test_city_player_drone_kamikaze_flow.gd'
```

Expected: FAIL，因为当前没有自杀冲击 closeout。

**Step 3: Write minimal implementation**

- 在 runtime 中复用 `DeathFxRoot` 做爆炸表现。
- 把爆炸伤害接到：
  - `city_enemy`
  - `resolve_pedestrian_explosion()`
  - `resolve_vehicle_explosion()`
  - 建筑爆炸链
- 爆炸结束后正式 restore player camera/input，并把无人机收回 `stowed`。

**Step 4: Run test to verify it passes**

Run 同上。

Expected: PASS。

### Task 5: HUD 准星与回归收口

**Files:**
- Modify: `city_game/scripts/CityPrototype.gd`
- Modify: `tests/world/test_city_player_drone_portability_contract.gd`
- Modify: `docs/plan/v43-index.md`
- Modify: `docs/plan/v43-drone-fpv-kamikaze-strike.md`
- Create: `docs/plan/v43-m3-verification-2026-03-24.md`

**Step 1: Write the failing test**

- 断言 `CityPrototype._build_crosshair_state()` 在 `fpv_ads` 时改取无人机准星世界点。
- 断言第三人称 active drone 不会错误泄漏玩家枪械准星合同。

**Step 2: Run test to verify it fails**

Run:

```powershell
$tests=@(
  'res://tests/world/test_city_player_drone_fpv_ads_contract.gd',
  'res://tests/world/test_city_player_drone_suicide_strike_contract.gd',
  'res://tests/e2e/test_city_player_drone_kamikaze_flow.gd'
)
foreach($test in $tests){
  & $godot --headless --rendering-driver dummy --path $project --script $test
  if($LASTEXITCODE -ne 0){ exit $LASTEXITCODE }
}
```

Expected: 其中至少一项 FAIL，直到 HUD/准星主链完成切换。

**Step 3: Write minimal implementation**

- 在 `CityPrototype` 中接入 drone aim target / crosshair state。
- 更新 `v43` 追溯矩阵与 verification 文档。

**Step 4: Run test to verify it passes**

Run:

```powershell
$tests=@(
  'res://tests/world/test_city_drone_gunship_scene_contract.gd',
  'res://tests/world/test_city_player_drone_toggle_contract.gd',
  'res://tests/world/test_city_player_drone_camera_takeover_contract.gd',
  'res://tests/world/test_city_player_drone_flight_input_contract.gd',
  'res://tests/world/test_city_player_drone_fpv_ads_contract.gd',
  'res://tests/world/test_city_player_drone_suicide_strike_contract.gd',
  'res://tests/world/test_city_player_drone_portability_contract.gd',
  'res://tests/world/test_city_player_drone_streaming_anchor_contract.gd',
  'res://tests/e2e/test_city_player_drone_flow.gd',
  'res://tests/e2e/test_city_player_drone_kamikaze_flow.gd'
)
foreach($test in $tests){
  & $godot --headless --rendering-driver dummy --path $project --script $test
  if($LASTEXITCODE -ne 0){ exit $LASTEXITCODE }
}
& $godot --headless --rendering-driver dummy --path $project --quit
```

Expected: 全绿，并生成 `v43` fresh verification 证据。

