# V24 M3 Verification Artifact

## Scope

本文件记录 `v24` 在 `2026-03-17` 的 fresh verification，当前收口范围是：

- `quick-select overlay + input contract` 已经从 world contract 进入到真实 e2e：上车后可以打开 quick overlay、切到第 3 个 quick slot、开机、确认选台，并把结果写入 radio runtime。
- `CityPrototype.gd` 已把 `quick overlay -> radio controller -> mock backend` 串成正式链路；`vehicle_radio_confirm` 不再只是 UI 占位，而会落到 `selected_station_id / playback_state`。
- `M1/M2` 既有 resolver、backend interface、catalog cache、preset persistence contract 在本轮回归里继续保持通过。

本轮没有 fresh 重跑 radio browser，也没有重跑 profiling 三件套，所以这里**只 closeout `M3`**，不宣称 `M4/M6` 已完成；`M5` 的 driving enter/exit / session recovery 也仍未整体收口。

## Environment

- Date: `2026-03-17`
- Workspace: `E:\development\godot_citys`
- Branch: `main`
- Engine: `E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe`
- Mode: `--headless --rendering-driver dummy`

## Commands

```powershell
$project='E:\development\godot_citys'
$godot='E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe'
$tests=@(
  'res://tests/world/test_city_vehicle_radio_stream_resolution_contract.gd',
  'res://tests/world/test_city_vehicle_radio_backend_interface_contract.gd',
  'res://tests/world/test_city_vehicle_radio_drive_mode_contract.gd',
  'res://tests/world/test_city_vehicle_radio_catalog_cache_contract.gd',
  'res://tests/world/test_city_vehicle_radio_preset_persistence.gd',
  'res://tests/world/test_city_vehicle_radio_quick_overlay_contract.gd',
  'res://tests/e2e/test_city_vehicle_radio_quick_switch_flow.gd',
  'res://tests/world/test_city_hud_mouse_passthrough_contract.gd',
  'res://tests/world/test_city_prototype_ui.gd',
  'res://tests/world/test_city_fps_overlay_toggle.gd',
  'res://tests/world/test_city_autodrive_shortcut_contract.gd'
)
foreach($test in $tests){
  & $godot --headless --rendering-driver dummy --path $project --script $test
  if($LASTEXITCODE -ne 0){ exit $LASTEXITCODE }
}
```

## Results

| Test | Result | Note |
|---|---|---|
| `test_city_vehicle_radio_stream_resolution_contract.gd` | PASS | `direct / playlist / hls` resolver schema 继续保持 formal contract |
| `test_city_vehicle_radio_backend_interface_contract.gd` | PASS | mock backend 继续暴露统一 playback state / buffer state / error state |
| `test_city_vehicle_radio_drive_mode_contract.gd` | PASS | radio runtime 仍然只在 driving lifecycle 下进入正式工作态 |
| `test_city_vehicle_radio_catalog_cache_contract.gd` | PASS | countries/stations cache 路径、TTL 与 stale fallback 未回退 |
| `test_city_vehicle_radio_preset_persistence.gd` | PASS | presets/favorites/recents/session state 持久化 contract 继续成立 |
| `test_city_vehicle_radio_quick_overlay_contract.gd` | PASS | quick bank 仍固定 8 槽、pause semantics 继续共享 world pause 主链 |
| `test_city_vehicle_radio_quick_switch_flow.gd` | PASS | 上车 -> quick overlay -> next/next -> power on -> confirm 后，runtime 进入 `selected_station_id=station:quick:2` 且 `playback_state=playing` |
| `test_city_hud_mouse_passthrough_contract.gd` | PASS | HUD 继续保持 mouse passthrough，不拦截驾驶/视角输入 |
| `test_city_prototype_ui.gd` | PASS | `PrototypeHud` 主 UI 主链未因 radio overlay 回退 |
| `test_city_fps_overlay_toggle.gd` | PASS | 既有 FPS overlay 开关未被新 action family 破坏 |
| `test_city_autodrive_shortcut_contract.gd` | PASS | `G` 键 autodrive 快捷链继续保持原 contract |

## Functional Notes

- 本轮真正修掉的不是 radio runtime，而是新 e2e 自己的接口误用：`set_vehicle_radio_selection_sources()` 需要 `presets / favorites / recents` 三段输入，测试一开始只传了一个数组，导致 GDScript 在运行时中断当前测试协程而没有 `quit()`，表现成“Godot 进程一直挂着”。
- 修正测试调用后，现有 `CityPrototype.gd` 集成已经足以证明：
  - `vehicle_radio_power_toggle` 会把 quick overlay 的 power state 同步到 `CityVehicleRadioController`
  - `vehicle_radio_confirm` 会把当前 quick slot 绑定到 runtime `selected_station_id`
  - driving 中且 power on 时，mock backend 会进入 `playing`
- 当前 `resolved_stream` 仍是 quick overlay confirm 的最小 direct snapshot，真正的 live stream backend sample verification 仍属于 `M1` 未完成项。

## Performance Guard

| Test | Result | Note |
|---|---|---|
| `test_city_chunk_setup_profile_breakdown.gd` | not rerun | 本轮只收 `M3` 功能链，不宣称 profiling guard 已 fresh 通过 |
| `test_city_runtime_performance_profile.gd` | not rerun | `M6` 仍未 closeout |
| `test_city_first_visit_performance_profile.gd` | not rerun | 后续做 browser/lifecycle 收口时再统一 fresh 重跑 |

## Residual Risks

- `M1` 还缺 Windows direct / playlist / HLS 真样本 backend verification；当前 `playing` 只代表 mock backend contract，不代表真实互联网电台已播通。
- `M5` 仍缺完整的上车/下车恢复、session recovery、power/session 持久化回放口径；本轮只是把 quick flow 真正接进 runtime。
- `M4` browser surface 尚未开始 fresh verification，国家目录、收藏/预设编辑流与大列表虚拟化还没有 closeout 证据。
