# V56 M3 Verification - 2026-03-26

## 范围

验证 `v56` 的五条正式口径：

- `KP_5` 已升级为机群热键：`short press -> +1 drone`，`long press -> recall all`；
- 第 1 架仍是 formal leader，继续拥有 camera / input / FPV owner；
- 僚机会以默认分散 slot 出现，不与 leader 长期重叠；
- 普通无人机态下长按全收后，玩家上下文能恢复；
- `howitzer 操炮 + drone` 复合态下长按全收后，howitzer 操炮与 artillery HUD 不回退。

## 通过项

### Docs / 解析检查

```powershell
rg -n "REQ-0027-007|REQ-0027-008|REQ-0027-009|short press|long press|10|howitzer 操炮" docs/prd/PRD-0027-drone-flight-foundation.md docs/ecn/ECN-0040-drone-squadron-summon-control.md docs/plan/v56-index.md docs/plan/v56-drone-squadron-summon-control.md docs/plans/2026-03-26-v56-drone-squadron-summon-control-design.md
& $godot --headless --rendering-driver dummy --path $project --quit
```

结果：

- 文档追溯命中 `REQ-0027-007`、`REQ-0027-008`、`REQ-0027-009`
- 项目 headless 解析通过

### V56 新增 / 更新 tests

```powershell
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/world/test_city_player_drone_toggle_contract.gd'
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/world/test_city_player_drone_squadron_summon_contract.gd'
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/world/test_city_player_drone_camera_takeover_contract.gd'
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/e2e/test_city_player_drone_flow.gd'
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/e2e/test_city_drone_assisted_artillery_operation_flow.gd'
```

结果：

- `PASS` `test_city_player_drone_toggle_contract.gd`
- `PASS` `test_city_player_drone_squadron_summon_contract.gd`
- `PASS` `test_city_player_drone_camera_takeover_contract.gd`
- `PASS` `test_city_player_drone_flow.gd`
- `PASS` `test_city_drone_assisted_artillery_operation_flow.gd`

### 受影响旧链回归

```powershell
$tests=@(
  'res://tests/world/test_city_player_drone_toggle_contract.gd',
  'res://tests/world/test_city_player_drone_camera_takeover_contract.gd',
  'res://tests/world/test_city_player_drone_flight_input_contract.gd',
  'res://tests/world/test_city_player_drone_fpv_ads_contract.gd',
  'res://tests/world/test_city_player_drone_presentation_contract.gd',
  'res://tests/world/test_city_player_drone_portability_contract.gd',
  'res://tests/world/test_city_player_drone_space_input_contract.gd',
  'res://tests/world/test_city_player_drone_speed_and_attitude_contract.gd',
  'res://tests/world/test_city_player_drone_streaming_anchor_contract.gd',
  'res://tests/world/test_city_player_drone_suicide_strike_contract.gd',
  'res://tests/world/test_city_player_drone_squadron_summon_contract.gd',
  'res://tests/world/test_city_world_howitzer_drone_composite_contract.gd',
  'res://tests/e2e/test_city_player_drone_flow.gd',
  'res://tests/e2e/test_city_drone_assisted_artillery_operation_flow.gd'
)
foreach($test in $tests){
  & $godot --headless --rendering-driver dummy --path $project --script $test
  if($LASTEXITCODE -ne 0){ exit $LASTEXITCODE }
}
& $godot --headless --rendering-driver dummy --path $project --quit
```

结果：

- `PASS` `test_city_player_drone_toggle_contract.gd`
- `PASS` `test_city_player_drone_camera_takeover_contract.gd`
- `PASS` `test_city_player_drone_flight_input_contract.gd`
- `PASS` `test_city_player_drone_fpv_ads_contract.gd`
- `PASS` `test_city_player_drone_presentation_contract.gd`
- `PASS` `test_city_player_drone_portability_contract.gd`
- `PASS` `test_city_player_drone_space_input_contract.gd`
- `PASS` `test_city_player_drone_speed_and_attitude_contract.gd`
- `PASS` `test_city_player_drone_streaming_anchor_contract.gd`
- `PASS` `test_city_player_drone_suicide_strike_contract.gd`
- `PASS` `test_city_player_drone_squadron_summon_contract.gd`
- `PASS` `test_city_world_howitzer_drone_composite_contract.gd`
- `PASS` `test_city_player_drone_flow.gd`
- `PASS` `test_city_drone_assisted_artillery_operation_flow.gd`
- `PASS` headless project parse

## 回归口径修正

- `test_city_player_drone_flight_input_contract.gd`
  - 移除了对 `Space` 抬升的旧要求，避免与 `v54` 已冻结的 `Space` 退场合同冲突。
- `test_city_player_drone_suicide_strike_contract.gd`
  - 将 FPV 对齐断言限制在 `locked/striking` 阶段，避免把已经进入 `exploding` 的帧误判为“撞击前朝向错误”。

## 备注

- 所有相关测试都打印了同一条既有 warning：
  - `CityM777Howitzer.tscn:8 - ext_resource, invalid UID ... CityArtilleryLanyardLine.gd`
- 该 warning 在本轮前已存在，且不影响 `v56` 文档追溯、focused tests、回归套件与 headless 解析通过；本轮未触碰该资源引用，不将其包装成 `v56` 修复项。

## 结论

- `REQ-0027-002`：通过
- `REQ-0027-004`：通过
- `REQ-0027-007`：通过
- `REQ-0027-008`：通过
- `REQ-0027-009`：通过
- 既有 player drone / suicide strike / howitzer composite 旧链回归：通过
