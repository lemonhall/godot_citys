# V53 M3 Verification - 2026-03-25

## Scope

针对 `v53` 的 full-map artillery fire mission 与 observer closeout 做 fresh verification：

- full map right-click context menu 与 `炮击标记` action
- 单个 active fire mission marker / solver / planned battery snapshot
- accepted fire 后的 observer closeout / impact chunk prewarm / camera restore
- 对既有 full map 与 world howitzer 主链的回归影响

## Commands

### 1. V53 Focused + Related Regression Suite

```powershell
$godot='E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe'
$tests=@(
  'res://tests/world/test_city_map_artillery_context_menu_contract.gd',
  'res://tests/world/test_city_artillery_fire_mission_contract.gd',
  'res://tests/world/test_city_artillery_fire_mission_observer_closeout_contract.gd',
  'res://tests/e2e/test_city_map_artillery_fire_mission_flow.gd',
  'res://tests/world/test_city_full_map_pan_zoom_contract.gd',
  'res://tests/world/test_city_map_destination_contract.gd',
  'res://tests/e2e/test_city_map_destination_selection_flow.gd',
  'res://tests/world/test_city_world_howitzer_spawn_contract.gd',
  'res://tests/world/test_city_world_howitzer_ballistics_contract.gd',
  'res://tests/e2e/test_city_world_howitzer_flow.gd'
)
foreach($test in $tests){
  & $godot --headless --rendering-driver dummy --path E:\development\godot_citys --script $test
  if($LASTEXITCODE -ne 0){ exit $LASTEXITCODE }
}
```

结果：

- exit code `0`
- 10 条 tests 全部输出 `PASS`

本轮直接证明：

- full map right-click context menu 已正式存在，且 `炮击标记` action 可被测试读到
- `CityPrototype.request_artillery_fire_mission_from_world_point()` 与 `get_artillery_fire_mission_state()` 已建立 formal fire mission contract
- fire mission 会留下 single active marker、solver 结果与 planned battery snapshot
- `KP_8` 在 active mission 下会复用 planned battery snapshot，而不是跳到玩家的新位置
- accepted fire 会启动 observer closeout，并暴露 predicted impact / prewarm chunk / camera owner state
- free fire、旧 full-map pan/zoom、旧 map destination、旧 world howitzer spawn/ballistics/e2e 主链都未回退

### 2. 项目解析检查

```powershell
$godot='E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe'
& $godot --headless --rendering-driver dummy --path E:\development\godot_citys --quit
```

结果：

- exit code `0`
- headless 成功启动并退出，无解析错误、脚本错误或资源缺失报错

## Traceability Closeout

| Req ID | 验证方式 | 结果 |
|---|---|---|
| REQ-0029-018 | `test_city_map_artillery_context_menu_contract.gd`; 本文档 | done |
| REQ-0029-019 | `test_city_artillery_fire_mission_contract.gd`; `test_city_map_artillery_fire_mission_flow.gd`; 本文档 | done |
| REQ-0029-020 | `test_city_artillery_fire_mission_contract.gd`; `test_city_map_artillery_fire_mission_flow.gd`; 本文档 | done |
| REQ-0029-021 | `test_city_artillery_fire_mission_contract.gd`; `test_city_world_howitzer_spawn_contract.gd`; 本文档 | done |
| REQ-0029-022 | `test_city_artillery_fire_mission_observer_closeout_contract.gd`; `test_city_map_artillery_fire_mission_flow.gd`; `test_city_world_howitzer_ballistics_contract.gd`; 本文档 | done |
| REQ-0029-023 | `test_city_artillery_fire_mission_observer_closeout_contract.gd`; `test_city_world_howitzer_ballistics_contract.gd`; 本文档 | done |

## Closeout Notes

- `v53` 的 observer closeout 没有另起一套假爆炸链，而是直接复用了 accepted fire 的 actual firing solution 与 live shell runtime。
- 本轮没有把 full map destination selection 打坏：既有 `left-click destination`、pan/zoom 与 map pause contract 仍保持 green。
- planned battery snapshot 的目标不是自动调炮，而是保证“先地图记诸元，后召唤 howitzer”这条用户路径成立；玩家仍然通过原有 howitzer 操炮链手动输入 bearing / pitch。
