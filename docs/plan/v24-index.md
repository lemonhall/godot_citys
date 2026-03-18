# V24 Index

## 愿景

PRD 入口：[PRD-0014 Vehicle Radio System](../prd/PRD-0014-vehicle-radio-system.md)

设计入口：[2026-03-17-v24-vehicle-radio-design.md](../plans/2026-03-17-v24-vehicle-radio-design.md)

依赖入口：

- [PRD-0004 Vehicle Hijack Driving](../prd/PRD-0004-vehicle-hijack-driving.md)
- [PRD-0011 Custom Building Full-Map Icons](../prd/PRD-0011-custom-building-full-map-icons.md)
- [PRD-0013 Music Road Landmark And Song Trigger](../prd/PRD-0013-music-road-landmark-and-song-trigger.md)
- [v9-index.md](./v9-index.md)
- [v18-index.md](./v18-index.md)
- [v23-index.md](./v23-index.md)

`v24` 的目标是把“玩家开车时想听电台”从一句设想推进成正式系统：驾驶态拥有 GTA 风格的低摩擦快速切台 surface，但深度浏览、收藏、预设、最近收听和全球目录缓存必须与 quick surface 分层；车内体验不能因为“全球台很多”而退化成一个不可操作的大列表，也不能因为“先把声音放出来”就跳过真实 `http/https + playlist wrapper + live playback backend` 的工程硬度。当前推荐路线是“双界面模型 + 冷热分层数据 + backend 抽象接口”：quick overlay 专门负责车内切台，browser 专门负责海量目录，catalog 与 resolve cache 走 `user://cache/radio/`，用户状态走 `user://radio/`，而直播 backend 先冻结正式接口与验证样本，再通过 `M1` feasibility gate 决定最终实现形态。

当前状态：`M0 docs freeze` 已完成；`M1 backend feasibility` 已进入 native true-playback 证据阶段；`M2 catalog cache + persistence` 已完成；`M3 quick-select overlay + input contract` 已在 [v24-m3-verification-2026-03-17.md](./v24-m3-verification-2026-03-17.md) 中完成 fresh functional verification；`M4 radio browser UX` 已经补到 repository 驱动的 countries/stations lazy sync，并修掉 runtime 读取 headless fixture 假目录的问题；`M5 vehicle lifecycle integration` 已补到 `B`/`O`/`Esc` 新交互、browser fixture 清洗与 session hygiene；当前 Windows 主线默认会优先走 `CityRadioNativeBackend.gd + GDExtension + FFmpeg`，mock 只保留为 fallback；direct / playlist / HLS 三类真实样本的 native decode 证据已落在 [v24-m6-native-backend-verification-2026-03-18.md](./v24-m6-native-backend-verification-2026-03-18.md)，`M7` 继续预留给全链 closeout，原 `M6 verification` 后移为 `M8`。

## 决策冻结

- `v24` 采用“双界面模型”：
  - driving 中的 quick-select overlay
  - 全屏 radio browser
- quick-select 只承载 `8-slot quick bank`，不承担全球目录浏览。
- `radio power off` 走独立 action，不占 quick bank 站位。
- quick-select 打开时允许进入单机可测的 `radio selection pause`，不强求 GTA 式慢动作。
- 输入 contract 先冻结 `InputMap action` 名称，不先写死物理按键。
- browser 最小分区冻结为：`当前播放 / Presets / Favorites / Recents / Browse`。
- `Browse` 首层正式入口冻结为 `国家/地区目录`；目录内默认展示按热度排序的 `top 200` station page。
- catalog cache 与 user state 必须分层：
  - `user://cache/radio/`：countries index、station pages、resolve cache
  - `user://radio/`：presets、favorites、recents、session_state
- cache TTL 当前冻结为：
  - countries / station pages：`72h`
  - stream resolve cache：`6h`
- 播放链必须正式面对 `direct / pls / m3u / hls / asx / xspf`，不得用本地假音频替代 live stream。
- backend 选型现已冻结为：`GDExtension + C++ + FFmpeg(libavformat/libavcodec/libswresample/libavutil)`，并坚持 `LGPL-only build`；不允许外部 helper、`ffplay/mpv` 桥接、`libVLC/GStreamer` 大依赖或任何 `127.0.0.1` 本地代理假设。
- native backend 输出口径冻结为：后台线程拉流/解码 + Godot 音频出口消费 PCM；browser/quick overlay 只能当 control surface，不能当播放器本体。
- 现有 profiling 三件套与 driving/HUD 主链必须继续保留。

## 里程碑

| 里程碑 | 范围 | DoD | 验证命令/测试 | 状态 |
|---|---|---|---|---|
| M0 docs freeze | PRD、design、v24 plan、traceability | `PRD-0014`、`v24-index`、`v24-vehicle-radio-system`、design doc 全部落地且 Req ID 可追溯 | `rg -n "REQ-0014" docs/prd/PRD-0014-vehicle-radio-system.md docs/plan/v24-index.md docs/plan/v24-vehicle-radio-system.md` | done |
| M1 backend feasibility + transport contract | live stream backend interface、resolver contract、Windows 样本可播性基线 | direct / playlist / HLS 三类样本都有正式验证路径；backend interface 冻结；UI 不直接触网 | `tests/world/test_city_vehicle_radio_stream_resolution_contract.gd`、`tests/world/test_city_vehicle_radio_backend_interface_contract.gd`、手动/自动 backend sample verification | in_progress |
| M2 catalog cache + persistence | countries index、station pages、favorites、recents、presets、session_state、resolve cache | `user://cache/radio/` 与 `user://radio/` 正式写入；TTL 与 stale fallback 成立 | `tests/world/test_city_vehicle_radio_catalog_cache_contract.gd`、`tests/world/test_city_vehicle_radio_preset_persistence.gd` | done |
| M3 quick-select overlay + input contract | 8-slot quick bank、pause semantics、keyboard/controller action family | driving 中可快速切台、开关电台、next/prev，不实例化大列表 | `tests/world/test_city_vehicle_radio_quick_overlay_contract.gd`、`tests/e2e/test_city_vehicle_radio_quick_switch_flow.gd` | done |
| M4 radio browser UX | `当前播放 / Presets / Favorites / Recents / Browse`、国家目录、局部过滤、虚拟化/分页 | 海量目录浏览成立，不污染 quick overlay，不一次性构造几千 rows | `tests/world/test_city_vehicle_radio_browser_state_contract.gd`、`tests/e2e/test_city_vehicle_radio_browser_flow.gd` | in_progress |
| M5 vehicle lifecycle integration | driving enter/exit、power/session recovery、selected station snapshot、HUD/state sync | 上车/下车/关机/恢复链成立，radio lifecycle 正式绑定 driving mode | `tests/world/test_city_vehicle_radio_drive_mode_contract.gd`、`tests/e2e/test_city_vehicle_radio_quick_switch_flow.gd` | in_progress |
| M6 native backend | `GDExtension` 工程、FFmpeg 选型、真播 backend、后台线程解码、Godot 音频出口、错误/重连/metadata | direct / playlist / HLS 真播链路在游戏内成立；`B` 关闭后继续播放；不依赖外部 helper；主线程不做阻塞拉流/解码 | [2026-03-18-v24-m6-native-backend-plan.md](../plans/2026-03-18-v24-m6-native-backend-plan.md)、[v24-m6-native-backend-verification-2026-03-18.md](./v24-m6-native-backend-verification-2026-03-18.md)、`tests/world/test_city_vehicle_radio_backend_interface_contract.gd`、Windows sample verification | in_progress |
| M7 native playback closeout | browser -> detail -> playback 真链路、session recovery、favorites/recents/presets/native backend 收口、真实错误面 | catalog/browser/lifecycle/native backend 不再分叉；mock path 不再伪装完成态；真播状态进入 HUD/browser | `tests/e2e/test_city_vehicle_radio_browser_flow.gd`、`tests/e2e/test_city_vehicle_radio_quick_switch_flow.gd`、Windows manual/end-to-end verification | todo |
| M8 verification | driving/HUD/runtime 回归与 profiling 三件套 | 受影响主链不回退，profiling 三件套 fresh 通过 | `tests/world/test_city_chunk_setup_profile_breakdown.gd`、`tests/e2e/test_city_runtime_performance_profile.gd`、`tests/e2e/test_city_first_visit_performance_profile.gd` | todo |

## 计划索引

- [v24-vehicle-radio-system.md](./v24-vehicle-radio-system.md)
- [v24-m3-verification-2026-03-17.md](./v24-m3-verification-2026-03-17.md)
- [2026-03-18-v24-m6-native-backend-plan.md](../plans/2026-03-18-v24-m6-native-backend-plan.md)
- [v24-m6-native-backend-verification-2026-03-18.md](./v24-m6-native-backend-verification-2026-03-18.md)

## 追溯矩阵

| Req ID | v24 Plan | 单元/集成测试 | E2E / 验证命令 | 证据 | 状态 |
|---|---|---|---|---|---|
| REQ-0014-001 | `v24-vehicle-radio-system.md` | `tests/world/test_city_vehicle_radio_drive_mode_contract.gd` | `--script res://tests/e2e/test_city_vehicle_radio_quick_switch_flow.gd` | [2026-03-17-v24-vehicle-radio-design.md](../plans/2026-03-17-v24-vehicle-radio-design.md)、[v24-m3-verification-2026-03-17.md](./v24-m3-verification-2026-03-17.md) | in_progress |
| REQ-0014-002 | `v24-vehicle-radio-system.md` | `tests/world/test_city_vehicle_radio_quick_overlay_contract.gd` | `--script res://tests/e2e/test_city_vehicle_radio_quick_switch_flow.gd` | [2026-03-17-v24-vehicle-radio-design.md](../plans/2026-03-17-v24-vehicle-radio-design.md)、[v24-m3-verification-2026-03-17.md](./v24-m3-verification-2026-03-17.md) | done |
| REQ-0014-003 | `v24-vehicle-radio-system.md` | `tests/world/test_city_vehicle_radio_browser_state_contract.gd` | `--script res://tests/e2e/test_city_vehicle_radio_browser_flow.gd` | [2026-03-17-v24-vehicle-radio-design.md](../plans/2026-03-17-v24-vehicle-radio-design.md)、[2026-03-17-v24-m4-radio-browser-plan.md](../plans/2026-03-17-v24-m4-radio-browser-plan.md) | in_progress |
| REQ-0014-004 | `v24-vehicle-radio-system.md` | `tests/world/test_city_vehicle_radio_catalog_cache_contract.gd`、`tests/world/test_city_vehicle_radio_preset_persistence.gd` | `--script res://tests/e2e/test_city_vehicle_radio_browser_flow.gd` | [2026-03-17-v24-vehicle-radio-design.md](../plans/2026-03-17-v24-vehicle-radio-design.md) | done |
| REQ-0014-005 | `v24-vehicle-radio-system.md`、[2026-03-18-v24-m6-native-backend-plan.md](../plans/2026-03-18-v24-m6-native-backend-plan.md) | `tests/world/test_city_vehicle_radio_stream_resolution_contract.gd`、`tests/world/test_city_vehicle_radio_backend_interface_contract.gd`、`tests/world/test_city_vehicle_radio_native_bridge_playback_contract.gd` | Windows direct / playlist / HLS sample verification | [2026-03-17-v24-vehicle-radio-design.md](../plans/2026-03-17-v24-vehicle-radio-design.md)、[2026-03-18-v24-m6-native-backend-plan.md](../plans/2026-03-18-v24-m6-native-backend-plan.md)、[v24-m6-native-backend-verification-2026-03-18.md](./v24-m6-native-backend-verification-2026-03-18.md) | in_progress |
| REQ-0014-006 | `v24-vehicle-radio-system.md`、[2026-03-18-v24-m6-native-backend-plan.md](../plans/2026-03-18-v24-m6-native-backend-plan.md) | `tests/world/test_city_vehicle_radio_hud_idle_contract.gd` | `--script res://tests/world/test_city_chunk_setup_profile_breakdown.gd`、`--script res://tests/e2e/test_city_runtime_performance_profile.gd`、`--script res://tests/e2e/test_city_first_visit_performance_profile.gd` | [2026-03-17-v24-vehicle-radio-design.md](../plans/2026-03-17-v24-vehicle-radio-design.md)、[2026-03-18-v24-m6-native-backend-plan.md](../plans/2026-03-18-v24-m6-native-backend-plan.md) | todo |

## ECN 索引

- 当前无

## 差异列表

- `M1` 已进入实现中：resolver contract、backend interface contract 与 native bridge playback contract 已补齐，真实直播 backend sample verification 已有首批 Windows evidence，但仍未正式 closeout。
- `M2` 已完成首批 cache/persistence contract：`CityRadioCatalogStore` 与 `CityRadioUserStateStore` 已冻结路径、schema、pretty JSON 与 TTL/stale fallback 的最小实现。
- `M3` 已完成 fresh functional verification：`project.godot` radio action 家族、`CityRadioQuickBank`、HUD quick overlay、shared pause contract 与 quick-switch e2e 已串起来，证据见 [v24-m3-verification-2026-03-17.md](./v24-m3-verification-2026-03-17.md)。
- `M4` 已不再只是 browser 壳：`CityPrototype.gd`、`CityVehicleRadioBrowser.gd`、`CityRadioCatalogRepository.gd` 已接上 repository 驱动的 countries/stations lazy sync，并显式清洗非 headless 运行时误读到的 fixture 国家目录/电台页；但 browser 仍未 closeout。
- `M5` 已补到 `B` 全局开关 browser、`O` quick overlay、`Esc`/再次按 `B` 可关闭，以及 `session_state / presets / favorites / recents` 的 fixture hygiene；当前主线已默认优先走 native backend，mock 只保留为 capability fallback。
- `M6` 现已落下 `GDExtension + FFmpeg` 真播主链：后台线程解码、Godot 音频出口、runtime metadata/error/buffer contract、direct / playlist / HLS 样本验证都已有 fresh 证据，详见 [v24-m6-native-backend-verification-2026-03-18.md](./v24-m6-native-backend-verification-2026-03-18.md)。
- `v24` 当前不包含虚构 DJ 电台、广告、录音、转录、翻译、同传、站点推荐或跨设备同步。
- 默认物理按键映射已局部收口：当前实际主链为 `B=browser`、`O=quick overlay`、`Esc=cancel`；如后续再改，必须以不占用既有核心动作按键为前提。
