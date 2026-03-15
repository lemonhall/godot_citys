# Vehicle Pedestrian Impact Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 让玩家当前正在驾驶的 hijacked vehicle 能撞死近景 pedestrian、触发轻量创飞与局部事故恐慌、并在撞击后把车速打到个位数，同时保持 ambient traffic 与空车状态完全不参与该逻辑。

**Architecture:** 撞击能力只挂在 `player driving state -> CityPrototype -> CityChunkRenderer -> CityPedestrianTierController` 这条链上，避免把 ambient traffic 或 parked visual 带进事故语义。死亡仍复用 `v6` 的 death visual 主链，只在 death event 上补充 launch / landing 元数据，再由 renderer 做轻量位移表现；事故恐慌则作为新的 special-case crowd event，限定近层与 `60%` deterministic 响应。

**Tech Stack:** Godot 4.6、GDScript、headless world/e2e tests、现有 pedestrian layered runtime、现有 vehicle driving mode。

---

### Task 1: 文档与红测基线

**Files:**
- Create: `docs/prd/PRD-0005-vehicle-pedestrian-impact.md`
- Create: `docs/plan/v11-index.md`
- Create: `docs/plan/v11-vehicle-pedestrian-impact.md`
- Test: `tests/world/test_city_player_vehicle_pedestrian_impact.gd`
- Test: `tests/world/test_city_pedestrian_vehicle_impact_panic.gd`
- Test: `tests/world/test_city_player_vehicle_death_visual_launch.gd`
- Test: `tests/e2e/test_city_vehicle_pedestrian_impact_flow.gd`

**Step 1: Write the failing tests**

- 写 world test 断言：只有 `player.is_driving_vehicle()` 时才会杀死 pedestrian。
- 写 world test 断言：撞击后 `speed_mps < 10.0`，继续正油门又能恢复加速。
- 写 panic test 断言：只有近层候选参与，deterministic 响应比例约 `60%`。
- 写 visual / e2e test 断言：death clip 仍是 `death/dead`，且落点在车前。

**Step 2: Run tests to verify they fail**

Run:

```powershell
$godot='E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe'
& $godot --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script 'res://tests/world/test_city_player_vehicle_pedestrian_impact.gd'
& $godot --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script 'res://tests/world/test_city_pedestrian_vehicle_impact_panic.gd'
& $godot --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script 'res://tests/world/test_city_player_vehicle_death_visual_launch.gd'
```

Expected: FAIL，原因集中在“当前 driving mode 没有 pedestrian impact resolver / accident panic / death launch metadata”。

### Task 2: 撞击致死与创飞主链

**Files:**
- Modify: `city_game/world/rendering/CityChunkRenderer.gd`
- Modify: `city_game/world/pedestrians/simulation/CityPedestrianTierController.gd`
- Modify: `city_game/world/pedestrians/rendering/CityPedestrianCrowdRenderer.gd`
- Modify: `city_game/world/pedestrians/rendering/CityPedestrianVisualInstance.gd`

**Step 1: Write the failing test**

- 让 `test_city_player_vehicle_death_visual_launch.gd` 明确期待 death event 提供 `launch_origin / landing_position / impact_source = vehicle` 之类的元数据。

**Step 2: Run test to verify it fails**

Run:

```powershell
$godot='E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe'
& $godot --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script 'res://tests/world/test_city_player_vehicle_death_visual_launch.gd'
```

Expected: FAIL，death event 还没有 vehicle-specific launch / landing 字段。

**Step 3: Write minimal implementation**

- 在 `CityChunkRenderer` 新增“只面向玩家 driving vehicle”的 impact resolver。
- 在 `CityPedestrianTierController` 新增 vehicle impact death event builder，只扫描近景 `Tier 2 / Tier 3`。
- death visual 仍复用现有 visual instance，只消费新增 metadata 做轻量位移表现，不引入 ragdoll。

**Step 4: Run tests to verify they pass**

Run:

```powershell
$godot='E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe'
& $godot --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script 'res://tests/world/test_city_player_vehicle_pedestrian_impact.gd'
& $godot --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script 'res://tests/world/test_city_player_vehicle_death_visual_launch.gd'
```

Expected: PASS。

### Task 3: 降速与局部事故恐慌

**Files:**
- Modify: `city_game/scripts/PlayerController.gd`
- Modify: `city_game/scripts/CityPrototype.gd`
- Modify: `city_game/world/pedestrians/streaming/CityPedestrianBudget.gd`
- Test: `tests/world/test_city_pedestrian_vehicle_impact_panic.gd`
- Test: `tests/e2e/test_city_vehicle_pedestrian_impact_flow.gd`

**Step 1: Write the failing test**

- 断言撞击后车辆速度掉到个位数。
- 断言继续 `W` 输入可重新加速。
- 断言事故恐慌只影响最近 player 的近层候选，且约 `60%` 响应。
- 断言玩家下车后再让空车触碰 pedestrian，不会产生 casualty。

**Step 2: Run test to verify it fails**

Run:

```powershell
$godot='E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe'
& $godot --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script 'res://tests/world/test_city_pedestrian_vehicle_impact_panic.gd'
& $godot --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script 'res://tests/e2e/test_city_vehicle_pedestrian_impact_flow.gd'
```

Expected: FAIL，当前还没有 vehicle-impact slowdown 和 accident panic gate。

**Step 3: Write minimal implementation**

- 在 `PlayerController` 增加 impact slowdown 入口，只修改当前 driving speed，不退出驾驶。
- 在 `CityPrototype` 只在 `player.is_driving_vehicle()` 时调用 impact resolver；退出驾驶后不再调用。
- 在 `CityPedestrianTierController + CityPedestrianBudget` 上增加 accident-specific nearfield gate，限定近层和 `60%` deterministic response。

**Step 4: Run tests to verify they pass**

Run:

```powershell
$godot='E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe'
& $godot --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script 'res://tests/world/test_city_pedestrian_vehicle_impact_panic.gd'
& $godot --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script 'res://tests/e2e/test_city_vehicle_pedestrian_impact_flow.gd'
```

Expected: PASS。

### Task 4: 红线复验

**Files:**
- Verify: `tests/world/test_city_vehicle_runtime_node_budget.gd`
- Verify: `tests/e2e/test_city_runtime_performance_profile.gd`
- Verify: `tests/e2e/test_city_first_visit_performance_profile.gd`

**Step 1: Run regression and profiling**

Run:

```powershell
$godot='E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe'
& $godot --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script 'res://tests/world/test_city_vehicle_runtime_node_budget.gd'
& $godot --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script 'res://tests/e2e/test_city_runtime_performance_profile.gd'
& $godot --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script 'res://tests/e2e/test_city_first_visit_performance_profile.gd'
```

Expected: PASS，且 `wall_frame_avg_usec <= 16667`。

**Step 2: Commit**

```powershell
git add docs/prd/PRD-0005-vehicle-pedestrian-impact.md docs/plan/v11-index.md docs/plan/v11-vehicle-pedestrian-impact.md docs/plans/2026-03-15-v11-vehicle-pedestrian-impact-plan.md tests/world/test_city_player_vehicle_pedestrian_impact.gd tests/world/test_city_pedestrian_vehicle_impact_panic.gd tests/world/test_city_player_vehicle_death_visual_launch.gd tests/e2e/test_city_vehicle_pedestrian_impact_flow.gd city_game/scripts/CityPrototype.gd city_game/scripts/PlayerController.gd city_game/world/rendering/CityChunkRenderer.gd city_game/world/pedestrians/simulation/CityPedestrianTierController.gd city_game/world/pedestrians/streaming/CityPedestrianBudget.gd city_game/world/pedestrians/rendering/CityPedestrianCrowdRenderer.gd city_game/world/pedestrians/rendering/CityPedestrianVisualInstance.gd
git commit -m "v11: feat: add player vehicle pedestrian impact"
```
