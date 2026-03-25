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

### 1C. Fine Adjust Precision + KP_8 Safety Retract + Lower Observer Framing

```powershell
$godot='E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe'
$tests=@(
  'res://tests/world/test_city_world_howitzer_interaction_contract.gd',
  'res://tests/world/test_city_world_howitzer_spawn_contract.gd',
  'res://tests/world/test_city_artillery_solution_hud_contract.gd',
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
- 7 条 tests 全部输出 `PASS`
- headless 解析检查 `PASS`

本轮额外证明：

- `Shift+J/L/I/K` fine adjust 已从 `0.5°` 收紧到 `0.1°`，并且跨多帧按住时仍只会触发一个精调 step，不会漏出 coarse traverse/elevation
- world howitzer 操作提示文案已同步改成 `精调 0.1°`，确保 HUD 内教学文字与真实控制步长一致
- `KP_8` 在 howitzer 仍处于 `E` 操炮态时，会先清掉 formal operator-lanyard binding 再执行 retract，不再直接把仍在操炮绑定中的火炮节点 queue_free 掉
- artillery solution HUD 的 yaw strip 已改成 `0.1°` bearing_text，而不是继续把 bearing round 回整数度数
- observer impact-stage camera framing 已进一步压低到接近“约 30m 高度、较近俯视”的口径；contract 现在同时卡住 overhead height 上界与 planar backoff 上界，避免镜头重新飘远

### 1D. Live Howitzer Accuracy Closeout + Tennis-Court Hit Verification

```powershell
$godot='E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe'
& $godot --headless --rendering-driver dummy --path E:\development\godot_citys --script 'res://tests/e2e/test_city_artillery_tennis_court_hit_flow.gd'
```

结果：

- exit code `0`
- `test_city_artillery_tennis_court_hit_flow.gd` 输出 `PASS`

为避免只得到“通过/失败”的二元口径，本轮还额外跑了一次一次性量化脚本，对同一条“出生地附近布炮 -> 网球场为 target -> 真炮 live solve -> 发射 -> 着弹”链路直接测量数值偏差。

量化结果：

- `solver_target_delta_m = 0.001`
- `field_target_delta_m = 0.0`
- `live_target_delta_m = 0.0`
- `impact_target_delta_m = 0.279`
- `impact_vs_live_prediction_delta_m = 0.280`
- 当次 firing data：`bearing = 100.643°`，`pitch = 7.338°`

本轮直接证明：

- “地图先标点、操炮后解算”新语义下，mission solver 已可在 live howitzer 上收敛到近似 `0m`
- live howitzer HUD bearing/pitch 字段与 live shell snapshot 已重新统一，不再出现 `~70m` 或 `~5.3km` 级别的自相矛盾
- 真正 shell impact 与 live predictor 的剩余误差已收敛到约 `0.28m`，在当前“仅重力、无风偏、无空气阻力”的理想环境中，可视为接近 `0m`
- 当前 residual 更像数值积分 / ray impact / frame-step 级别误差，而不是 solver / yaw / pitch / origin 主链错误

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
- `KP_8` 在操炮态下的收炮语义已补成防呆路径：先退出操炮绑定，再收回火炮。
- main-world howitzer 的精调步长与教学文案现在统一为 `0.1°`；artillery solution HUD 的 yaw bearing 文本也同步显示到 `0.1°`。
- observer impact-stage framing 已进一步贴近目标区，当前口径约为 `30m` overhead + 更短 backoff；headless 合同已覆盖，但真实渲染下仍建议继续做一次人工观察确认视觉主观感受。
- artillery fire mission 现在正式分成两段：地图右键只留下 target marker；只有 `8` 召唤真炮并 `E` 进入操炮后，才会基于 live howitzer 解算诸元；退出操炮后再次回到 `待操炮解算`。
- 本轮精度修复的根因有两层：
  - 不能再把 `platform -> muzzle` 的位置差向量当成 `muzzle_direction_world`；那会把炮口位置偏移误当成弹道方向
  - 也不能盲信视觉节点 basis 作为物理发射方向；当前资源里它与真实 ballistic pitch 不一致
- 当前正式口径是：
  - firing solution 里的物理发射方向，必须以 live `world_bearing_deg + pitch_deg` 为真源
  - live fire mission solve 必须对真实 spawned howitzer 做短迭代取样，读取候选角度下的真实 muzzle origin，再回修 solver；只靠 reference howitzer 几何近似会残留几十米系统性偏差
