# V54 M3 Verification - 2026-03-26

## 范围

验证 `v54` 的三条正式口径：

- active drone 不再把 `Space` 当上升输入；
- `drone active + howitzer 操炮 active` 时，`E` 不再退出操炮；
- 复合模式下 accepted fire 跳过 observer closeout，但 shell / impact 结果仍然成立。

## 通过项

### Docs / 解析检查

```powershell
rg -n "REQ-0027-005|REQ-0029-022|REQ-0029-023|composite|observer closeout|Space" docs/prd/PRD-0027-drone-flight-foundation.md docs/prd/PRD-0029-artillery-howitzer-scene-foundation.md docs/ecn/ECN-0038-drone-assisted-artillery-composite-operation.md docs/plan/v54-index.md docs/plan/v54-drone-assisted-artillery-operation.md docs/plans/2026-03-26-v54-drone-assisted-artillery-operation-design.md
& $godot --headless --rendering-driver dummy --path $project --quit
```

结果：

- 文档追溯命中 `REQ-0027-005`、`REQ-0029-022`、`REQ-0029-023`
- 项目 headless 解析通过

### V54 新增 tests

```powershell
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/world/test_city_player_drone_space_input_contract.gd'
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/world/test_city_world_howitzer_drone_composite_contract.gd'
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/e2e/test_city_drone_assisted_artillery_operation_flow.gd'
```

结果：

- `PASS` `test_city_player_drone_space_input_contract.gd`
- `PASS` `test_city_world_howitzer_drone_composite_contract.gd`
- `PASS` `test_city_drone_assisted_artillery_operation_flow.gd`

### 受影响旧链回归

```powershell
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/world/test_city_player_drone_toggle_contract.gd'
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/e2e/test_city_player_drone_flow.gd'
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/world/test_city_world_howitzer_interaction_contract.gd'
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/e2e/test_city_map_artillery_fire_mission_flow.gd'
```

结果：

- `PASS` `test_city_player_drone_toggle_contract.gd`
- `PASS` `test_city_player_drone_flow.gd`
- `PASS` `test_city_world_howitzer_interaction_contract.gd`
- `PASS` `test_city_map_artillery_fire_mission_flow.gd`

## Observer 回归补充

在用户回归中发现：非复合模式下单炮 observer cutaway 体感被带坏。按用户提供的历史基线 `1cfd8eb10abc8c5f7c79d2a261650af127f622f7` 对照后确认，`CityArtilleryFireMissionRuntime.gd` 的 `observer_height_m` 曾从 `30.0` 漂移到 `80.0`。将其恢复到 `30.0` 后，以下非复合 observer 回归重新通过：

```powershell
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/world/test_city_artillery_fire_mission_observer_closeout_contract.gd'
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/e2e/test_city_map_artillery_fire_mission_flow.gd'
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/e2e/test_city_map_artillery_fire_mission_long_range_observer_flow.gd'
```

结果：

- `PASS` `test_city_artillery_fire_mission_observer_closeout_contract.gd`
- `PASS` `test_city_map_artillery_fire_mission_flow.gd`
- `PASS` `test_city_map_artillery_fire_mission_long_range_observer_flow.gd`

## 结论

- `REQ-0027-005`：通过
- `REQ-0029-022`：通过
- `REQ-0029-023`：通过
- 非复合模式旧链：
  - drone toggle / drone flow / world howitzer interaction / observer closeout / map fire mission flow / long-range observer flow 全部通过
