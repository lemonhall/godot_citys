# V55 M4 Verification - 2026-03-26

## 范围

验证 `v55` 后续回归修复：

- `player drone active + howitzer 操炮 active` 的复合击发链依旧跳过 observer camera closeout；
- 但复合态 shell payload 不再丢失 `forced impact / flight time / ballistic time scale`；
- map-side fire mission 与 drone-assisted howitzer operation 旧链不回退；
- 单独操炮下的 observer closeout 仍保持原行为。

## 根因

- 之前 `CityPrototype._handle_world_howitzer_fire_input()` 只有在“非复合态”时才调用 `start_observation_from_firing_solution()`。
- `observer_force_predicted_impact`、`observer_forced_impact_world_position`、`observer_forced_impact_flight_time_sec`、`observation_ballistic_time_scale` 这些 shell 必需字段，全都绑在这条 observer path 上。
- 结果是：复合态虽然按设计跳过了 observer camera，但也一并跳过了 shell impact contract，导致 shell 回退到任意 physics collision / max lifetime 路径，玩家飞到标点附近时经常看不到目标区爆炸。

## 修复口径

- 把 shell impact contract 预备逻辑从 observer camera lifecycle 中拆出来，沉到 `CityArtilleryFireMissionRuntime.prepare_shell_impact_contract_from_firing_solution()`。
- 非复合态：
  - 继续走 `start_observation_from_firing_solution()`；
  - 观察镜头、player lock、impact hold 行为保持不变。
- 复合态：
  - 不启动 observer camera；
  - 但仍复用同一份 predicted impact / surface snap / chunk prewarm / shell time-scale / forced-impact payload。

## 通过项

### Focused 回归

```powershell
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/world/test_city_world_howitzer_drone_composite_contract.gd'
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/e2e/test_city_drone_assisted_artillery_operation_flow.gd'
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/e2e/test_city_map_artillery_fire_mission_flow.gd'
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/world/test_city_artillery_fire_mission_observer_closeout_contract.gd'
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/world/test_city_world_howitzer_ballistics_contract.gd'
```

结果：

- `PASS` `test_city_world_howitzer_drone_composite_contract.gd`
- `PASS` `test_city_drone_assisted_artillery_operation_flow.gd`
- `PASS` `test_city_map_artillery_fire_mission_flow.gd`
- `PASS` `test_city_artillery_fire_mission_observer_closeout_contract.gd`
- `PASS` `test_city_world_howitzer_ballistics_contract.gd`

### 新增保护点

- `test_city_world_howitzer_drone_composite_contract.gd` 现在额外卡住：
  - 复合态 shell payload 必须带 `observer_force_predicted_impact`
  - 必须带 `observer_forced_impact_world_position`
  - 必须带 `observer_forced_impact_flight_time_sec`
  - 必须带 `observation_ballistic_time_scale`
  - 最终 `trigger_kind` 必须是 `forced_predicted_impact`

## 备注

- 所有相关测试仍打印同一条既有 warning：
  - `CityM777Howitzer.tscn:8 - ext_resource, invalid UID ... CityArtilleryLanyardLine.gd`
- 这是本轮前已存在的资源引用 warning；本轮未触碰该 UID，不把它包装成这次修复的一部分。

## 结论

- 复合态“跳过 observer”与“保留 shell impact contract”已经解耦；
- 无人机观察链可以继续保持 camera ownership，同时 shell 仍按已解算 target 区域收敛；
- 单独操炮 observer closeout 未回退。
