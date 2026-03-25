# V55 M3 Verification - 2026-03-26

## 范围

验证 `v55` 的四条正式口径：

- `player drone active + FPV ADS active` 时，按 `T` 会直接创建或更新正式 artillery fire mission；
- 重复按 `T` 只更新单个黄色黄叉，不累积第二个 marker；
- live howitzer 操炮 active 时，新的 drone target 会立即刷新 solved bearing / pitch；
- 非无人机 FPV 场景下，`T` 的既有 fast-travel shortcut 不回退。

## 通过项

### Docs / 解析检查

```powershell
rg -n "REQ-0029-019|REQ-0029-020|REQ-0029-024|drone active|FPV ADS|single active|T" docs/prd/PRD-0029-artillery-howitzer-scene-foundation.md docs/ecn/ECN-0039-drone-crosshair-artillery-fire-mission.md docs/plan/v55-index.md docs/plan/v55-drone-crosshair-artillery-fire-mission.md docs/plans/2026-03-26-v55-drone-crosshair-artillery-fire-mission-design.md
& $godot --headless --rendering-driver dummy --path $project --quit
```

结果：

- 文档追溯命中 `REQ-0029-019`、`REQ-0029-020`、`REQ-0029-024`
- 项目 headless 解析通过

### V55 新增 tests

```powershell
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/world/test_city_drone_artillery_target_marking_contract.gd'
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/e2e/test_city_drone_artillery_recalibration_flow.gd'
```

结果：

- `PASS` `test_city_drone_artillery_target_marking_contract.gd`
- `PASS` `test_city_drone_artillery_recalibration_flow.gd`

### 受影响旧链回归

```powershell
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/world/test_city_artillery_fire_mission_contract.gd'
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/world/test_city_fast_travel_shortcut_contract.gd'
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/world/test_city_world_howitzer_drone_composite_contract.gd'
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/e2e/test_city_map_artillery_fire_mission_flow.gd'
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/e2e/test_city_player_drone_flow.gd'
```

结果：

- `PASS` `test_city_artillery_fire_mission_contract.gd`
- `PASS` `test_city_fast_travel_shortcut_contract.gd`
- `PASS` `test_city_world_howitzer_drone_composite_contract.gd`
- `PASS` `test_city_map_artillery_fire_mission_flow.gd`
- `PASS` `test_city_player_drone_flow.gd`

## 备注

- 所有相关测试都打印了同一条既有 warning：
  - `CityM777Howitzer.tscn:8 - ext_resource, invalid UID ... CityArtilleryLanyardLine.gd`
- 该 warning 在本轮前已存在，且不影响 `v55` 新增与回归测试通过；本轮未触碰该资源引用，不将其包装成 `v55` 的修复项。

## 结论

- `REQ-0029-019`：通过
- `REQ-0029-020`：通过
- `REQ-0029-024`：通过
- 既有 map fire mission / fast travel / drone composite / player drone flow：全部通过
