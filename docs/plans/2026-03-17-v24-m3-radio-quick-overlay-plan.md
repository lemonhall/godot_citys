# V24 M3 Radio Quick Overlay Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 为 `v24` 交付 driving 中可用的 radio quick-select overlay，冻结 8-slot quick bank、InputMap action 家族与 radio selection pause contract。

**Architecture:** 复用 `CityPrototype.gd` 现有 `_apply_world_simulation_pause()` 主链，不新造第三套暂停系统。`CityRadioQuickBank` 负责把 presets/favorites/recents 收敛成最多 8 个 quick slots；`PrototypeHud.gd` 负责挂载 `CityVehicleRadioQuickOverlay` 并渲染 compact overlay state；`CityPrototype.gd` 负责 driving gate、InputMap action 分发和 overlay open/close lifecycle。

**Tech Stack:** Godot 4.6、GDScript、`project.godot` InputMap、现有 `Hud/Root` 控件树、`PlayerController.gd` driving contract。

---

### Task 1: Quick Overlay Contract Test

**Files:**
- Create: `tests/world/test_city_vehicle_radio_quick_overlay_contract.gd`

**Step 1: Write the failing test**

- 断言 `project.godot` 暴露 action：
  - `vehicle_radio_quick_open`
  - `vehicle_radio_next`
  - `vehicle_radio_prev`
  - `vehicle_radio_power_toggle`
  - `vehicle_radio_browser_open`
  - `vehicle_radio_confirm`
  - `vehicle_radio_cancel`
- 断言 world 非 driving 时无法打开 quick overlay
- 断言 driving 时打开 overlay 会进入 world pause
- 断言 overlay 最多 8 slots，且 `power/browser` 不占 slot
- 断言 `vehicle_radio_cancel` 关闭 overlay 并恢复 world pause

**Step 2: Run test to verify it fails**

```powershell
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/world/test_city_vehicle_radio_quick_overlay_contract.gd'
```

Expected: FAIL，因为 quick overlay contract 尚不存在。

### Task 2: InputMap And Quick Bank Model

**Files:**
- Modify: `project.godot`
- Create: `city_game/world/radio/CityRadioQuickBank.gd`

**Step 1: Write minimal implementation**

- 在 `project.godot` 增加 radio action 家族
- 新建 `CityRadioQuickBank.gd`
- 提供最小方法：
  - `build_slots(presets: Array, favorites: Array, recents: Array) -> Array`
- 冻结输出最多 8 项，优先 presets，缺位时用 favorites/recents 回填

**Step 2: Re-run test**

Expected: 仍然 FAIL，但失败点推进到 overlay / lifecycle 缺失。

### Task 3: HUD Overlay And World Lifecycle

**Files:**
- Create: `city_game/ui/CityVehicleRadioQuickOverlay.gd`
- Modify: `city_game/ui/PrototypeHud.gd`
- Modify: `city_game/scripts/CityPrototype.gd`

**Step 1: Write minimal implementation**

- 在 `PrototypeHud.gd` 动态挂载 quick overlay 控件
- 暴露：
  - `set_vehicle_radio_quick_overlay_state(state: Dictionary)`
  - `get_vehicle_radio_quick_overlay_state() -> Dictionary`
- 在 `CityPrototype.gd` 增加：
  - `open_vehicle_radio_quick_overlay()`
  - `close_vehicle_radio_quick_overlay()`
  - `get_vehicle_radio_quick_overlay_state()`
  - radio action 分发
- 打开 quick overlay 时复用 `_apply_world_simulation_pause(true)`；关闭时恢复

**Step 2: Run focused test**

Run 同 Task 1。

Expected: PASS。

### Task 4: Verification And Traceability

**Files:**
- Modify: `docs/plan/v24-index.md`

**Step 1: Run focused verification**

```powershell
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/world/test_city_vehicle_radio_quick_overlay_contract.gd'
```

Expected: PASS。

**Step 2: Refresh plan state**

- `M2` 若已满足 DoD，更新为 `done`
- `M3` 更新为 `in_progress`
- 在追溯矩阵中把 REQ-0014-002 标记为 `in_progress`

**Step 3: Commit**

```powershell
git add project.godot city_game/world/radio/CityRadioQuickBank.gd city_game/ui/CityVehicleRadioQuickOverlay.gd city_game/ui/PrototypeHud.gd city_game/scripts/CityPrototype.gd tests/world/test_city_vehicle_radio_quick_overlay_contract.gd docs/plan/v24-index.md
git commit -m "feat: start v24 radio quick overlay"
```
