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

当前状态：`M0 docs freeze` 已完成；`M1 backend feasibility` 仍在进行中；`M2 catalog cache + persistence` 已完成；`M3 quick-select overlay + input contract` 已在 [v24-m3-verification-2026-03-17.md](./v24-m3-verification-2026-03-17.md) 中完成 fresh functional verification；`M5 vehicle lifecycle integration` 已启动但尚未 closeout；`M4/M6` 仍待后续推进。

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
- `v24` 先冻结 backend interface，不在 docs 阶段提前假装 Godot 现成就有完整 internet radio player。
- 现有 profiling 三件套与 driving/HUD 主链必须继续保留。

## 里程碑

| 里程碑 | 范围 | DoD | 验证命令/测试 | 状态 |
|---|---|---|---|---|
| M0 docs freeze | PRD、design、v24 plan、traceability | `PRD-0014`、`v24-index`、`v24-vehicle-radio-system`、design doc 全部落地且 Req ID 可追溯 | `rg -n "REQ-0014" docs/prd/PRD-0014-vehicle-radio-system.md docs/plan/v24-index.md docs/plan/v24-vehicle-radio-system.md` | done |
| M1 backend feasibility + transport contract | live stream backend interface、resolver contract、Windows 样本可播性基线 | direct / playlist / HLS 三类样本都有正式验证路径；backend interface 冻结；UI 不直接触网 | `tests/world/test_city_vehicle_radio_stream_resolution_contract.gd`、`tests/world/test_city_vehicle_radio_backend_interface_contract.gd`、手动/自动 backend sample verification | in_progress |
| M2 catalog cache + persistence | countries index、station pages、favorites、recents、presets、session_state、resolve cache | `user://cache/radio/` 与 `user://radio/` 正式写入；TTL 与 stale fallback 成立 | `tests/world/test_city_vehicle_radio_catalog_cache_contract.gd`、`tests/world/test_city_vehicle_radio_preset_persistence.gd` | done |
| M3 quick-select overlay + input contract | 8-slot quick bank、pause semantics、keyboard/controller action family | driving 中可快速切台、开关电台、next/prev，不实例化大列表 | `tests/world/test_city_vehicle_radio_quick_overlay_contract.gd`、`tests/e2e/test_city_vehicle_radio_quick_switch_flow.gd` | done |
| M4 radio browser UX | `当前播放 / Presets / Favorites / Recents / Browse`、国家目录、局部过滤、虚拟化/分页 | 海量目录浏览成立，不污染 quick overlay，不一次性构造几千 rows | `tests/world/test_city_vehicle_radio_browser_state_contract.gd`、`tests/e2e/test_city_vehicle_radio_browser_flow.gd` | todo |
| M5 vehicle lifecycle integration | driving enter/exit、power/session recovery、selected station snapshot、HUD/state sync | 上车/下车/关机/恢复链成立，radio lifecycle 正式绑定 driving mode | `tests/world/test_city_vehicle_radio_drive_mode_contract.gd`、`tests/e2e/test_city_vehicle_radio_quick_switch_flow.gd` | in_progress |
| M6 verification | driving/HUD/runtime 回归与 profiling 三件套 | 受影响主链不回退，profiling 三件套 fresh 通过 | `tests/world/test_city_chunk_setup_profile_breakdown.gd`、`tests/e2e/test_city_runtime_performance_profile.gd`、`tests/e2e/test_city_first_visit_performance_profile.gd` | todo |

## 计划索引

- [v24-vehicle-radio-system.md](./v24-vehicle-radio-system.md)
- [v24-m3-verification-2026-03-17.md](./v24-m3-verification-2026-03-17.md)

## 追溯矩阵

| Req ID | v24 Plan | 单元/集成测试 | E2E / 验证命令 | 证据 | 状态 |
|---|---|---|---|---|---|
| REQ-0014-001 | `v24-vehicle-radio-system.md` | `tests/world/test_city_vehicle_radio_drive_mode_contract.gd` | `--script res://tests/e2e/test_city_vehicle_radio_quick_switch_flow.gd` | [2026-03-17-v24-vehicle-radio-design.md](../plans/2026-03-17-v24-vehicle-radio-design.md)、[v24-m3-verification-2026-03-17.md](./v24-m3-verification-2026-03-17.md) | in_progress |
| REQ-0014-002 | `v24-vehicle-radio-system.md` | `tests/world/test_city_vehicle_radio_quick_overlay_contract.gd` | `--script res://tests/e2e/test_city_vehicle_radio_quick_switch_flow.gd` | [2026-03-17-v24-vehicle-radio-design.md](../plans/2026-03-17-v24-vehicle-radio-design.md)、[v24-m3-verification-2026-03-17.md](./v24-m3-verification-2026-03-17.md) | done |
| REQ-0014-003 | `v24-vehicle-radio-system.md` | `tests/world/test_city_vehicle_radio_browser_state_contract.gd` | `--script res://tests/e2e/test_city_vehicle_radio_browser_flow.gd` | [2026-03-17-v24-vehicle-radio-design.md](../plans/2026-03-17-v24-vehicle-radio-design.md) | todo |
| REQ-0014-004 | `v24-vehicle-radio-system.md` | `tests/world/test_city_vehicle_radio_catalog_cache_contract.gd`、`tests/world/test_city_vehicle_radio_preset_persistence.gd` | `--script res://tests/e2e/test_city_vehicle_radio_browser_flow.gd` | [2026-03-17-v24-vehicle-radio-design.md](../plans/2026-03-17-v24-vehicle-radio-design.md) | done |
| REQ-0014-005 | `v24-vehicle-radio-system.md` | `tests/world/test_city_vehicle_radio_stream_resolution_contract.gd`、`tests/world/test_city_vehicle_radio_backend_interface_contract.gd` | Windows direct / playlist / HLS sample verification | [2026-03-17-v24-vehicle-radio-design.md](../plans/2026-03-17-v24-vehicle-radio-design.md) | in_progress |
| REQ-0014-006 | `v24-vehicle-radio-system.md` | `tests/world/test_city_vehicle_radio_hud_idle_contract.gd` | `--script res://tests/world/test_city_chunk_setup_profile_breakdown.gd`、`--script res://tests/e2e/test_city_runtime_performance_profile.gd`、`--script res://tests/e2e/test_city_first_visit_performance_profile.gd` | [2026-03-17-v24-vehicle-radio-design.md](../plans/2026-03-17-v24-vehicle-radio-design.md) | todo |

## ECN 索引

- 当前无

## 差异列表

- `M1` 已进入实现中：resolver contract、backend interface contract、最小 drive-mode controller contract 已有首批 world tests 与实现骨架，但真实直播 backend sample verification 仍未完成。
- `M2` 已完成首批 cache/persistence contract：`CityRadioCatalogStore` 与 `CityRadioUserStateStore` 已冻结路径、schema、pretty JSON 与 TTL/stale fallback 的最小实现。
- `M3` 已完成 fresh functional verification：`project.godot` radio action 家族、`CityRadioQuickBank`、HUD quick overlay、shared pause contract 与 quick-switch e2e 已串起来，证据见 [v24-m3-verification-2026-03-17.md](./v24-m3-verification-2026-03-17.md)。
- `M5` 已启动首批 vehicle lifecycle integration：`CityPrototype.gd` 已把 quick overlay confirm / power toggle 与 `CityVehicleRadioController`、mock backend 接通，但 enter/exit / recovery 仍未整体 closeout。
- `v24` 当前不包含虚构 DJ 电台、广告、录音、转录、翻译、同传、站点推荐或跨设备同步。
- backend 库选型尚未冻结；`M1` 之前只冻结 interface、resolver contract 与验证样本。
- 默认物理按键映射尚未冻结；当前只冻结 `InputMap action` 家族，避免过早把 raw keycode 写进主链。
