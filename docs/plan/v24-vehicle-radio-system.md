# V24 Vehicle Radio System

## Goal

在现有 `v9 driving mode` 之上交付一套正式 `vehicle radio` 设计与实施计划：玩家在 driving 中拥有低摩擦 quick-select 电台切换体验，同时通过独立 browser surface 管理 `Presets / Favorites / Recents / Browse`，并以正式 catalog cache、stream resolver 与 live playback backend 把全球互联网电台接入游戏主链。

## PRD Trace

- Direct consumer: REQ-0014-001
- Direct consumer: REQ-0014-002
- Direct consumer: REQ-0014-003
- Direct consumer: REQ-0014-004
- Direct consumer: REQ-0014-005
- Guard / Performance discipline: REQ-0014-006

## Dependencies

- 依赖 `v9` 已冻结 `player driving state / hijack / exit vehicle` 主链。
- 依赖 `PrototypeHud.gd` 与 `CityMapScreen.gd` 现有 overlay/HUD 基础，但不应把 radio browser 硬塞成 map 子功能。
- 依赖 `v23` 已证明 driving state 可驱动正式音频相关 runtime，但当前仍无通用 live stream backend。
- 依赖外部参考 `E:\development\kotlinagentapp` 的 `RadioRepository`、`RadioStationFileV1`、`StreamUrlResolver` 设计经验；只借鉴协议、缓存和 UX 分层，不直接搬 Android 实现。

## Contract Freeze

- `vehicle radio` 生命周期从属于 `player.is_driving_vehicle()`，不是全局独立音乐播放器。
- quick-select surface 冻结为 `8-slot quick bank`。
- `radio power off` 走独立 action，不占 quick bank 站位。
- 输入先冻结 action 名称：
  - `vehicle_radio_quick_open`
  - `vehicle_radio_next`
  - `vehicle_radio_prev`
  - `vehicle_radio_power_toggle`
  - `vehicle_radio_browser_open`
  - `vehicle_radio_confirm`
  - `vehicle_radio_cancel`
- quick-select 打开时允许进入 `radio selection pause`，以保证 keyboard/controller 都能稳定选台。
- browser 最小分区冻结为：`当前播放 / Presets / Favorites / Recents / Browse`。
- `Browse` 首层入口冻结为 `国家/地区目录`，国家目录内默认使用按热度排序的 `top 200` station page。
- cache / state 路径分层冻结为：
  - `user://cache/radio/`：可重建网络缓存
  - `user://radio/`：用户状态与会话
- TTL 冻结为：
  - countries / station pages：`72h`
  - stream resolve cache：`6h`
- resolver 必须覆盖 `direct / pls / m3u / hls / asx / xspf`。
- backend 只冻结接口与验证样本；库选型留给 `M1`。

## Scope

做什么：

- 新增 `vehicle radio controller`、catalog store、resolver、user-state store
- 新增 quick-select overlay
- 新增 radio browser full-screen surface
- 新增 `presets / favorites / recents / session_state` 正式持久化
- 新增 countries index 与 per-country station page cache
- 新增 stream resolve cache 与 backend interface
- 为 driving lifecycle、quick-select、browser、resolver、profiling 补齐 tests

不做什么：

- 不做虚构电台内容制作
- 不做录音 / 转录 / 翻译 / 同传
- 不做所有 NPC 车辆的 3D 电台声源
- 不做跨设备同步
- 不做地图页直接浏览全球电台

## Acceptance

1. 自动化测试必须证明：vehicle radio runtime 只在 driving mode 中进入正式工作态。
2. 自动化测试必须证明：quick-select overlay 只承载 8 个 quick bank 站位，并通过 `InputMap action` 接受 keyboard/controller 输入。
3. 自动化测试必须证明：browser 正式区分 `当前播放 / Presets / Favorites / Recents / Browse`，而不是单一长列表。
4. 自动化测试必须证明：`Browse` 首层是国家/地区目录，station list 不会一次性平铺全球所有电台。
5. 自动化测试必须证明：countries index、station page、presets、favorites、recents、session_state、resolve cache 都有正式 schema 与 pretty JSON 输出。
6. 自动化测试必须证明：catalog cache 未过期时会复用，过期时会尝试刷新，失败时可回退到旧缓存。
7. 自动化测试必须证明：resolver 能稳定产出 `classification / final_url / candidates / resolution_trace`。
8. 自动化验证必须证明：Windows 主线环境至少有一条 direct stream、一条 playlist-wrapped stream、一条 HLS stream 能走通正式 backend。
9. 自动化测试必须证明：quick-select idle 与 browser hidden 时，不会触发 catalog 全量扫描或大列表重建。
10. 自动化测试必须证明：radio lifecycle 与 `v9` 的 enter/exit vehicle 主链一致，不会下车后继续误播。
11. profiling 三件套必须继续串行给出 fresh 结果。
12. 反作弊条款：不得通过本地 MP3 假播、8 条静态演示台、全局内存临时字典、或测试时关闭 radio runtime 来宣称完成。

## Files

- Modify: `project.godot`
- Modify: `city_game/scripts/CityPrototype.gd`
- Modify: `city_game/scripts/PlayerController.gd`
- Modify: `city_game/ui/PrototypeHud.gd`
- Create: `city_game/ui/CityVehicleRadioQuickOverlay.gd`
- Create: `city_game/ui/CityVehicleRadioQuickOverlay.gd.uid`
- Create: `city_game/ui/CityVehicleRadioQuickOverlay.tscn`
- Create: `city_game/ui/CityVehicleRadioBrowser.gd`
- Create: `city_game/ui/CityVehicleRadioBrowser.gd.uid`
- Create: `city_game/ui/CityVehicleRadioBrowser.tscn`
- Create: `city_game/world/radio/CityVehicleRadioController.gd`
- Create: `city_game/world/radio/CityVehicleRadioController.gd.uid`
- Create: `city_game/world/radio/CityRadioCatalogStore.gd`
- Create: `city_game/world/radio/CityRadioCatalogStore.gd.uid`
- Create: `city_game/world/radio/CityRadioUserStateStore.gd`
- Create: `city_game/world/radio/CityRadioUserStateStore.gd.uid`
- Create: `city_game/world/radio/CityRadioStreamResolver.gd`
- Create: `city_game/world/radio/CityRadioStreamResolver.gd.uid`
- Create: `city_game/world/radio/CityRadioQuickBank.gd`
- Create: `city_game/world/radio/CityRadioQuickBank.gd.uid`
- Create: `city_game/world/radio/backend/CityRadioStreamBackend.gd`
- Create: `city_game/world/radio/backend/CityRadioStreamBackend.gd.uid`
- Create: `city_game/world/radio/backend/CityRadioMockBackend.gd`
- Create: `city_game/world/radio/backend/CityRadioMockBackend.gd.uid`
- Future Create: `city_game/native/radio_backend/*`
- Create: `tests/world/test_city_vehicle_radio_drive_mode_contract.gd`
- Create: `tests/world/test_city_vehicle_radio_quick_overlay_contract.gd`
- Create: `tests/world/test_city_vehicle_radio_browser_state_contract.gd`
- Create: `tests/world/test_city_vehicle_radio_catalog_cache_contract.gd`
- Create: `tests/world/test_city_vehicle_radio_preset_persistence.gd`
- Create: `tests/world/test_city_vehicle_radio_stream_resolution_contract.gd`
- Create: `tests/world/test_city_vehicle_radio_hud_idle_contract.gd`
- Create: `tests/e2e/test_city_vehicle_radio_quick_switch_flow.gd`
- Create: `tests/e2e/test_city_vehicle_radio_browser_flow.gd`
- Modify: `docs/plan/v24-index.md`

## Steps

1. Analysis
   - 审计 `CityPrototype.gd`、`PrototypeHud.gd`、`PlayerController.gd`、`project.godot` 的当前输入与 HUD 接口，确认 radio action 可安全接入而不踩现有 `M/T/E/F/G` 主链。
   - 审计 Godot 4.6 当前可用的 HTTP、proxy、PCM playback 能力，形成 backend feasibility checklist。
   - 从 `kotlinagentapp` 提取正式参考点：countries/stations TTL、`RadioStationFileV1` schema、`StreamUrlResolver` 分类策略、playlist wrapper 支持范围。
2. Design
   - 冻结“双界面模型”：quick-select 只负责 8-slot 切台，browser 负责海量目录。
   - 冻结 `user://cache/radio/` 与 `user://radio/` 的文件 contract。
   - 冻结 backend interface、resolver output schema 与验证样本。
3. TDD Red
   - 先写 drive-mode contract、quick overlay contract、catalog cache contract、preset persistence contract、browser state contract、stream resolution contract。
   - 先跑到红，确认当前仓库确实缺少 radio runtime、browser、resolver 与 persistence。
4. TDD Green
   - 先落 `CityRadioUserStateStore` 与 `CityRadioCatalogStore`。
   - 再落 `CityRadioQuickBank`、`CityVehicleRadioController`、mock backend。
   - 再落 quick overlay 与 browser UI。
   - 再落 resolver 与真实 backend adapter。
   - 最后把 driving enter/exit、HUD、session recovery 接入 `CityPrototype.gd`。
5. Refactor
   - 把 quick overlay state、browser state、catalog/cache IO、backend playback、drive lifecycle 分层，避免 `CityPrototype.gd` 变成 radio 巨石。
   - 热路径只保留 compact runtime snapshot；Favorites / Recents / station pages 的完整 payload 留在冷路径。
6. E2E
   - 跑 `test_city_vehicle_radio_quick_switch_flow.gd`：上车 -> 打开 quick-select -> 切台 -> 关机 -> 下车。
   - 跑 `test_city_vehicle_radio_browser_flow.gd`：上车 -> 打开 browser -> 浏览国家目录 -> 加收藏 -> 设为 preset -> quick-select 生效。
   - 在 Windows 主线环境补 direct / playlist / HLS 三类样本验证。
7. Review
   - 回填 `v24-index` 追溯矩阵。
   - fresh 重跑 profiling 三件套。
   - 对照 `PRD-0014` 检查是否出现“quick overlay 被大目录污染”“catalog state 写进 cache 目录”“本地 MP3 冒充直播”等 scope drift。

## Risks

- 最大技术风险不在 UI，而在 Godot 侧 live stream backend；若 `M1` 不先打掉 feasibility，后续 UI 再漂亮也会被空后端拖死。
- 如果不把 quick-select 与 browser 分离，几千个站点一定会污染车内切台体验。
- 如果 favorites / recents / presets 只存 `station_id` 不存 snapshot，一旦 catalog refresh 失败，整个车载电台会出现“看得见按钮但无内容”的假恢复。
- 如果热路径每帧去 deep-copy country pages 或 favorites 列表，性能问题会比 UI 更早爆。
- 如果把代理配置、backend 选型、resolve cache 这些脏活都推迟到 UI 完成后再说，返工会非常大。
