# Radio Backend Agent Notes

本文件只作用于 `city_game/native/radio_backend/` 及其子目录；若与仓库根 `AGENTS.md` 冲突，以本文件为准。

## Overview

- 本目录承载车载电台的 Windows GDExtension，不是随手堆第三方二进制的缓存目录。
- 正式入口是 `radio_backend.gdextension`；GDScript 消费侧在 `res://city_game/world/radio/backend/CityRadioNativeBackend.gd`。
- 当前 DLL basename 冻结为 `radio_backend_m6`；`radio_backend.gdextension` 的 library mapping 与 `SConstruct` 输出名必须保持一致。

## Quick Commands

```powershell
$project='E:\development\godot_citys'
$godot='E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe'
```

- 恢复缺失的 `avfilter-11.dll`：

```powershell
pwsh -File "$project\scripts\restore-radio-ffmpeg-avfilter.ps1"
```

- 构建 debug DLL：

```powershell
Push-Location "$project\city_game\native\radio_backend"
scons platform=windows target=template_debug
Pop-Location
```

- 构建 release DLL：

```powershell
Push-Location "$project\city_game\native\radio_backend"
scons platform=windows target=template_release
Pop-Location
```

- focused 验证：

```powershell
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/world/test_city_vehicle_radio_native_bridge_smoke.gd'
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/world/test_city_vehicle_radio_native_bridge_playback_contract.gd'
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/world/test_city_vehicle_radio_backend_interface_contract.gd'
```

## Architecture

- `SConstruct`
  - 构建入口；会加载 `thirdparty/godot-cpp/SConstruct`，并在可用时自动接入 FFmpeg include/lib/bin。
- `radio_backend.gdextension`
  - Godot 侧入口；指向 `bin/win64/radio_backend_m6.*.dll`。
- `src/`
  - `CityRadioNativeBackend.*`：播放 / 传输核心
  - `CityRadioNativeBridge.*`：Godot 暴露桥
  - `register_types.*`：类型注册
- `bin/win64/`
  - 放构建产物和复制进来的运行时 DLL；这里的正式输出必须与 `.gdextension` 对齐。
- `thirdparty/godot-cpp/`
  - vendored 依赖，默认只读参考区。
- `thirdparty/ffmpeg/`
  - 共享 FFmpeg 运行时与 split archive 所在地；`avfilter-11.dll` 通过 `scripts/restore-radio-ffmpeg-avfilter.ps1` 恢复。

## Safety & Contracts

- 不要手改 `thirdparty/godot-cpp`
  - 为什么：这是 vendored upstream，改动会让后续升级和 review 失真
  - 替代：只改 `src/*`、`SConstruct`、`radio_backend.gdextension`
  - 验证：`git diff -- city_game/native/radio_backend/thirdparty`

- 不要提交本地构建垃圾和解压产物
  - 为什么：`src/build/`、`.sconsign.dblite`、恢复出来的 `avfilter-11.dll`、`_extract_avfilter_tmp/` 都是本地产物
  - 替代：依赖 `.gitignore`，必要时重新运行恢复脚本或重建
  - 验证：`git status --short`

- 不要无声改动 DLL basename 或 `.gdextension` 映射
  - 为什么：Godot 会直接加载失败，GDScript 侧会退化成桥接不可用
  - 替代：如果确实要改，`SConstruct`、`radio_backend.gdextension`、相关测试一起改
  - 验证：native bridge smoke 与 playback contract 同时通过

- 不要假装 FFmpeg 已配置
  - 为什么：`SConstruct` 只有在 include/lib/bin 可用时才会定义 `CITY_RADIO_USE_FFMPEG`
  - 替代：优先跑恢复脚本；如需外部路径，显式设置 `CITY_RADIO_FFMPEG_ROOT`
  - 验证：构建日志正常，`test_city_vehicle_radio_native_bridge_playback_contract.gd` 通过

## Testing Rules

- 改 `src/*` 或桥接 API 时，至少跑：
  - `test_city_vehicle_radio_backend_interface_contract.gd`
  - `test_city_vehicle_radio_native_bridge_smoke.gd`
  - `test_city_vehicle_radio_native_bridge_playback_contract.gd`

- 改 catalog / browser / transport 相关行为时，再补：
  - `test_city_vehicle_radio_catalog_repository_sync_contract.gd`
  - `test_city_vehicle_radio_stream_resolution_contract.gd`
  - `tests/e2e/test_city_vehicle_radio_quick_switch_flow.gd`
  - `tests/e2e/test_city_vehicle_radio_browser_flow.gd`

- 改 FFmpeg 打包或真实样本链时，再补：
  - `tests/tools/verify_city_radio_native_bridge_real_samples.gd`
  - `tests/tools/verify_radio_transport_samples.ps1`
