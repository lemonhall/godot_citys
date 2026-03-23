# V42 M4 Verification 2026-03-24

## Scope

本次 verification 覆盖 `v42 drone flight foundation` 的 M1-M4 正式收口：

- `KEY_KP_5` 作为唯一正式 deploy / recover toggle 入口
- `CityDroneGunship.tscn` 从 `helicopter` combat runtime 脱钩，切到 `combat/drone` 正式 runtime
- deploy / active / recover 的 camera ownership / input ownership / player lock 主链
- active 阶段第三人称自稳定 hover flight
- formal portability contract 与主世界 wrapper 接线
- `CityPrototype` 原有 debug hotkey / inspection regression 冒烟

## Fresh Passed Checks

以下命令在 `2026-03-24` fresh 执行并通过：

```powershell
$project='E:\development\godot_citys'
$godot='E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe'
$tests=@(
  'res://tests/world/test_city_drone_gunship_scene_contract.gd',
  'res://tests/world/test_city_player_drone_toggle_contract.gd',
  'res://tests/world/test_city_player_drone_camera_takeover_contract.gd',
  'res://tests/world/test_city_player_drone_flight_input_contract.gd',
  'res://tests/world/test_city_player_drone_portability_contract.gd',
  'res://tests/e2e/test_city_player_drone_flow.gd',
  'res://tests/world/test_city_fps_overlay_toggle.gd',
  'res://tests/e2e/test_city_fast_inspection_mode.gd'
)
foreach($test in $tests){
  & $godot --headless --rendering-driver dummy --path $project --script $test
  if($LASTEXITCODE -ne 0){ exit $LASTEXITCODE }
}

& $godot --headless --rendering-driver dummy --path $project --quit
```

## Result Summary

- `test_city_drone_gunship_scene_contract.gd`
  - 证明 `CityDroneGunship.tscn` 已正式绑定 `CityPlayerDroneRuntime.gd`，并挂载 dedicated drone camera rig。
  - 证明 scene text 已不再直接引用 `CityHelicopterGunship.gd`。
- `test_city_player_drone_toggle_contract.gd`
  - 证明正式入口只认 `KEY_KP_5`，`KEY_5` 不触发。
  - 证明 deploy transition 期间重复 toggle 会被忽略，不会打乱状态机。
- `test_city_player_drone_camera_takeover_contract.gd`
  - 证明 deploy 完成前 camera owner 仍是 `player`，active 后切到 `drone`，recover 完成后再切回 `player`。
  - 证明 deploy / active / recover 三段都会冻结玩家位置与武器链。
- `test_city_player_drone_flight_input_contract.gd`
  - 证明 active 阶段 `W/D` 提供 camera-relative planar move，`E/Space` 上升，`Q` 下降。
  - 证明释放输入后无人机会回到 near-zero hover，而不是继续漂移。
- `test_city_player_drone_portability_contract.gd`
  - 证明正式 drone runtime 暴露 portability contract，且 `CityPrototype` 挂载的是同一份 `combat/drone` runtime。
- `test_city_player_drone_flow.gd`
  - 证明主世界整链 `deploy -> active flight -> recover -> restore player control` 端到端通过。
- `test_city_fps_overlay_toggle.gd`
  - 证明新增 `KP_5` 没打坏原有 numpad debug hotkey 链。
- `test_city_fast_inspection_mode.gd`
  - 证明 `CityPrototype` 的 inspection control mode 主链未被 v42 的 camera ownership 改动污染。
- `--quit`
  - 证明项目解析检查通过，没有因为新增 drone runtime / scene wiring 破坏工程加载。

## Closeout Decision

- `v42 M1-M4`: 完成，可作为本轮 drone flight foundation 的 fresh evidence
- 当前本轮 focused regression 中未观察到新的失败项
