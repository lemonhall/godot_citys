# V24 M6 Native Backend Verification

验证日期：`2026-03-18`（Asia/Shanghai）

## 目标

为 `v24 M6 native backend` 留下 fresh 证据，证明当前 Windows 主线环境下：

- `CityRadioNativeBackend.gd` 默认优先走 `GDExtension + FFmpeg`
- `CityPrototype.gd -> CityVehicleRadioController.gd -> CityRadioNativeBackend.gd -> CityRadioNativeBridge`
  主链已打通
- direct / playlist-wrapped / HLS 三类真实样本能从 native backend 解出 PCM 帧
- browser / quick overlay / session recovery 的现有 UI/runtime 主链没有退回 mock 歧义路径

## 环境

- 仓库：`E:\development\godot_citys`
- Godot：`E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe`
- Native DLL：`res://city_game/native/radio_backend/bin/win64/radio_backend_m6.windows.template_debug.x86_64.dll`
- FFmpeg runtime：
  - `avcodec-62.dll`
  - `avformat-62.dll`
  - `avutil-60.dll`
  - `swresample-6.dll`

## Build Closure

验证点：

- `tests/world/_tmp_native_backend_trace.gd`
- 结果：
  - `available=true`
  - `reason=""`
  - `build=ffmpeg_enabled`

结论：

- `.gdextension` 已切到新的 `radio_backend_m6` 版本化 DLL，规避正在运行的 Godot 编辑器对旧 DLL 的锁占用
- 当前 Godot 实际加载的是 FFmpeg-enabled native backend，而不是旧的 `ffmpeg_not_configured` skeleton

## Contract Regression

执行命令：

```powershell
$godot='E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe'
$tests=@(
  'res://tests/world/test_city_vehicle_radio_backend_interface_contract.gd',
  'res://tests/world/test_city_vehicle_radio_drive_mode_contract.gd',
  'res://tests/world/test_city_vehicle_radio_native_bridge_smoke.gd',
  'res://tests/world/test_city_vehicle_radio_native_bridge_playback_contract.gd',
  'res://tests/world/test_city_vehicle_radio_session_recovery_contract.gd',
  'res://tests/e2e/test_city_vehicle_radio_quick_switch_flow.gd',
  'res://tests/e2e/test_city_vehicle_radio_browser_flow.gd'
)
foreach($test in $tests){
  & $godot --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script $test
  if($LASTEXITCODE -ne 0){ exit $LASTEXITCODE }
}
```

结果：

- `PASS`：`test_city_vehicle_radio_backend_interface_contract.gd`
- `PASS`：`test_city_vehicle_radio_drive_mode_contract.gd`
- `PASS`：`test_city_vehicle_radio_native_bridge_smoke.gd`
- `PASS`：`test_city_vehicle_radio_native_bridge_playback_contract.gd`
- `PASS`：`test_city_vehicle_radio_session_recovery_contract.gd`
- `PASS`：`test_city_vehicle_radio_quick_switch_flow.gd`
- `PASS`：`test_city_vehicle_radio_browser_flow.gd`

补充：

- `test_city_vehicle_radio_drive_mode_contract.gd` 已额外卡住 controller reuse 行为，防止 driving context 每帧重复 `play_resolved_stream()`
- `test_city_vehicle_radio_browser_flow.gd` 已额外卡住 runtime state 的 `resolved_url / metadata / latency_ms / underflow_count`

## Transport Sample Preflight

执行命令：

```powershell
& 'E:\development\godot_citys\tests\tools\verify_radio_transport_samples.ps1'
```

结果摘要：

- direct：
  - URL：`https://ice1.somafm.com/groovesalad-128-mp3`
  - `HTTP/1.1 200 OK`
  - `Content-Type: audio/mpeg`
- playlist：
  - URL：`https://somafm.com/groovesalad.pls`
  - `HTTP/1.1 200 OK`
  - `Content-Type: audio/x-scpls`
  - first candidate：`https://ice6.somafm.com/groovesalad-128-mp3`
- hls：
  - URL：`https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_ts/master.m3u8`
  - `HTTP/1.1 200 OK`
  - `Content-Type: application/x-mpegURL`
  - first variant：`v5/prog_index.m3u8`

说明：

- Apple 那条样本适合作 transport/HLS manifest preflight，但不适合作车载电台音频真播验证
- 真播验证的 HLS 样本改用 `SomaFM HLS FLAC`

## Native Real Sample Verification

执行命令：

```powershell
$godot='E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe'
& $godot --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script 'res://tests/tools/verify_city_radio_native_bridge_real_samples.gd'
```

结果摘要：

| sample_id | classification | URL | first_audio_msec | popped_frame_count | codec | success |
|---|---|---|---:|---:|---|---|
| `direct` | `direct` | `https://ice1.somafm.com/groovesalad-128-mp3` | `1008` | `4096` | `mp3float` | `true` |
| `playlist` | `pls` | `https://ice6.somafm.com/groovesalad-128-mp3` | `932` | `4096` | `mp3float` | `true` |
| `hls` | `hls` | `https://hls.somafm.com/hls/groovesalad/FLAC/program.m3u8` | `4244` | `4096` | `flac` | `true` |

metadata 摘要：

- direct / playlist：
  - `stream_title = "Groove Salad: a nicely chilled plate of ambient beats and grooves. [SomaFM]"`
  - `sample_rate_hz = 44100`
  - `channel_count = 2`
- hls：
  - `codec = flac`
  - `sample_rate_hz = 48000`
  - `channel_count = 2`

结论：

- native bridge 已能在真实网络样本上稳定产出 PCM 帧，而不是只把 runtime state 改成 `playing`
- HLS 音频样本已由 FFmpeg demux/decode 成功，不再只是 manifest 级别 preflight

## UI / Runtime Chain Evidence

自动化链路已经证明：

- `CityPrototype.gd` 会优先选择 native backend，并把 audio sink host 挂到当前 world
- `_process()` 每帧在 world pause gate 之前执行 `update_audio_output()`，因此 `B` 打开/关闭 browser 时播放不会被 UI 停掉
- browser detail 已显示：
  - `backend_id`
  - `playback_state`
  - `buffer_state`
  - `latency_ms`
  - `underflow_count`
  - `stream_title`
  - `resolved_url`
  - `error_message`

## Remaining Gate

本次 evidence 证明了 `M6` 的实现主链已成立，但以下项目仍不应在本文件里被假装 closeout：

- 真实非 headless 的人工听感 smoke（human-ear confirmation）
- `M8` profiling 三件套
- `M7` 的完整 closeout 叙述与体验收口文档
