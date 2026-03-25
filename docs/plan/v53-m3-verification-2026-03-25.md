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

### 1A. Observer Camera Framing + Restore Regression

```powershell
$godot='E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe'
$tests=@(
  'res://tests/world/test_city_m777_howitzer_fire_contract.gd',
  'res://tests/world/test_city_artillery_fire_mission_contract.gd',
  'res://tests/world/test_city_artillery_fire_mission_observer_closeout_contract.gd',
  'res://tests/e2e/test_city_map_artillery_fire_mission_flow.gd',
  'res://tests/e2e/test_city_map_artillery_fire_mission_long_range_observer_flow.gd'
)
foreach($test in $tests){
  & $godot --headless --rendering-driver dummy --path E:\development\godot_citys --script $test
  if($LASTEXITCODE -ne 0){ exit $LASTEXITCODE }
}
& $godot --headless --rendering-driver dummy --path E:\development\godot_citys --quit
```

结果：

- exit code `0`
- 5 条 tests 全部输出 `PASS`
- headless 解析检查 `PASS`

本轮额外证明：

- observer impact-stage camera 不再反向朝天，测试已直接验证相机 forward 必须对准 predicted impact
- observer camera 必须位于落点上方并保持 downward-looking pitch，而不是水平看天际线
- observer closeout 暴露的 planned observation duration 已收束到 `3s-5s`
- observer closeout 完成后，玩家仍留在 formal howitzer 操炮状态，而不是打一发后 silently 掉出操作链
- `5km` 级 long-range observer flow 已证明不会再把 streaming 焦点留在玩家身边导致目标区灰屏
- long-range observer runtime 已显式暴露 predicted shell flight time，并把真实长弹道压缩进 `3s-5s` 观察窗口，而不是跟着 `45s max_lifetime` 拖到超时

### 1B. Howitzer Toggle + Dual-Window Observer Render Regression

```powershell
$godot='E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe'
$tests=@(
  'res://tests/world/test_city_world_howitzer_spawn_contract.gd',
  'res://tests/world/test_city_world_howitzer_interaction_contract.gd',
  'res://tests/world/test_city_m777_howitzer_fire_contract.gd',
  'res://tests/world/test_city_artillery_fire_mission_contract.gd',
  'res://tests/world/test_city_artillery_fire_mission_observer_closeout_contract.gd',
  'res://tests/e2e/test_city_world_howitzer_flow.gd',
  'res://tests/e2e/test_city_map_artillery_fire_mission_flow.gd',
  'res://tests/e2e/test_city_map_artillery_fire_mission_long_range_observer_flow.gd'
)
foreach($test in $tests){
  & $godot --headless --rendering-driver dummy --path E:\development\godot_citys --script $test
  if($LASTEXITCODE -ne 0){ exit $LASTEXITCODE }
}
& $godot --headless --rendering-driver dummy --path E:\development\godot_citys --quit
```

结果：

- exit code `0`
- 8 条 tests 全部输出 `PASS`
- headless 解析检查 `PASS`

本轮额外证明：

- `KP_8` 已从“重复召唤/重摆放”改成正式 summon/retract toggle；第二次按下会收回火炮，第三次才重新召唤
- observer closeout 不再通过改写主 streaming focus 去卸载玩家周边窗口，而是把玩家窗口与 target impact ring 合并成 dual-window render set
- long-range observer impact chunk 会以 `near` LOD 挂载，而不是因为“离玩家 5km”被错误渲染成一片远距绿色占位地表
- observer active window 中，player-side chunk 与 impact-side chunk 会同时保活，避免“加载 -> 卸载 -> 再加载”的明显 churn

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
- observer camera framing 已改成按 firing solution 的炮位 -> 落点平面方向回推，并以正式俯视角对准落点；不再使用固定世界 `Vector3.BACK` 偏移。
- observer closeout 不再抢占主 world streaming focus；现在是继续保留玩家 streaming 窗口，同时给 renderer 追加 predicted impact ring 并单独用 target focus 驱动 target chunk 的 LOD。
- long-range shell 即使目标 chunk collider 还没及时参与射线相交，也会按 predicted impact world position 做强制预测落点 closeout，不再拖到 `CityArtilleryShell.max_lifetime_sec = 45` 才超时爆炸。
- 本轮没有把 full map destination selection 打坏：既有 `left-click destination`、pan/zoom 与 map pause contract 仍保持 green。
- planned battery snapshot 的目标不是自动调炮，而是保证“先地图记诸元，后召唤 howitzer”这条用户路径成立；玩家仍然通过原有 howitzer 操炮链手动输入 bearing / pitch。
- observer closeout 现在按 predicted shell flight time 做“压缩而非等待”的 timing 计划，并把总观察窗口限制在约 `3s-5s` 后自动切回操炮态。
- world howitzer debug hotkey 现在保持显式 toggle 语义：有炮时收回，无炮时召唤。
