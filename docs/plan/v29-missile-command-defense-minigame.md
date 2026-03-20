# V29 Missile Command Defense Minigame

## Goal

交付一条正式的 `v29` 实现计划：在 `chunk_183_152` 用户指定锚点 author 一座 3D `Missile Command` 防空电池场馆。该玩法必须沿现有 `scene_minigame_venue` 主链挂载，进入开赛圈后自动切到 battery mode，并提供 `left click fire / right click zoom / Q cycle silo / Esc exit` 的正式输入链；运行时必须具备敌弹波次、拦截弹、爆炸圈链式击毁、城市/发射井毁伤、HUD、世界记分牌与 reset。

## PRD Trace

- Direct consumer: REQ-0019-001
- Direct consumer: REQ-0019-002
- Direct consumer: REQ-0019-003
- Direct consumer: REQ-0019-004
- Direct consumer: REQ-0019-005
- Guard / Runtime: REQ-0019-006

## Dependencies

- 依赖 `v26` 已冻结 `scene_minigame_venue` family、registry/runtime、ambient freeze 主链。
- 依赖 `v28` 已冻结多 minigame runtime 聚合、HUD 扩展与 scene-first sports venue 的成熟思路。
- 依赖 `CityPrototype._unhandled_input()` 现有世界层热键入口，便于为 `battery mode` 劫持鼠标/键盘事件。
- 依赖 `CityMapScreen.gd` 现有 `icon_id -> glyph` 映射，便于新增 `missile_command` pin glyph。

## Contract Freeze

- 正式 `venue_id = venue:v29:missile_command_battery:chunk_183_152`
- `game_kind = missile_command_battery`
- 锚点冻结为：
  - `anchor_chunk_id = chunk_183_152`
  - `anchor_chunk_key = (183, 152)`
  - `world_position = (11925.63, -4.74, 4126.84)`
  - `surface_normal = (-0.01, 1.00, -0.00)`
- 首版固定为：
  - `3 silos`
  - `3 cities`
  - `3 waves`
- 正式输入冻结为：
  - `left click = fire interceptor`
  - `right click hold = zoom`
  - `Q = cycle launch silo`
  - `Esc = exit battery mode`
- 玩家进入 start ring 后自动进入 battery mode，不再把主动作绑定为 `E`
- gameplay plane contract 至少包含：
  - `gameplay_plane_origin`
  - `gameplay_plane_half_width_m`
  - `gameplay_plane_height_m`
  - `camera_world_position`
  - `camera_look_target`
  - `silo_ids`
  - `city_ids`
  - `release_buffer_m`
- 最小 runtime state 冻结为：
  - `battery_mode_active`
  - `wave_index`
  - `wave_state`
  - `selected_silo_id`
  - `selected_silo_index`
  - `enemy_remaining_count`
  - `cities_alive_count`
  - `silo_states`
  - `city_states`
  - `enemy_tracks`
  - `interceptor_tracks`
  - `explosion_tracks`
  - `reticle_world_position`
  - `zoom_active`
- HUD 最小 contract 冻结为：
  - `visible`
  - `battery_mode_active`
  - `wave_index`
  - `wave_state`
  - `selected_silo_id`
  - `cities_alive_count`
  - `enemy_remaining_count`
  - `zoom_active`
  - `feedback_event_token`
  - `feedback_event_kind`
  - `feedback_event_text`

## Scope

做什么：

- 新增 `Missile Command` 场馆 manifest / scene / script
- 新增 `CityMissileCommandVenueRuntime.gd`
- 在 `CityPrototype` 聚合第三套 minigame runtime
- 新增 battery mode 输入分发与 formal request API
- 新增 missile HUD block
- 新增 `missile_command` full-map pin glyph
- author 三座 silo、三座 city、开赛圈、camera pivot / camera、gameplay plane、scoreboard
- 补齐 manifest / battery contract / mode / wave / damage / HUD / e2e tests

不做什么：

- 不做新的 interactive prop
- 不做自由 TPS 火箭筒版
- 不做任务系统集成
- 不做排行榜、剧情、结算大屏
- 不做特殊弹型与复杂音频系统

## Acceptance

1. 自动化测试必须证明：`v29` 场馆被正式写入 `scene_minigame_venue` registry / manifest，并在 `chunk_183_152` near mount 后可找到。
2. 自动化测试必须证明：场馆暴露正式 battery contract，而不是只在 runtime 常量里硬编码 gameplay plane / camera / silo / city 坐标。
3. 自动化测试必须证明：进入开赛圈会自动进入正式 battery mode，切换到场馆 camera，并禁用玩家移动控制。
4. 自动化测试必须证明：左键 formal request 会从当前所选 silo 发射拦截弹；`Q` 可正式切井；右键会切 zoom；`Esc` 会退出玩法态。
5. 自动化测试必须证明：敌弹按波次落向 city/silo，拦截弹到点生成爆炸圈，爆炸圈可以摧毁进入半径的敌弹。
6. 自动化测试必须证明：enemy hit city/silo 会正式改变毁伤状态，不是只改 HUD 数字。
7. 自动化测试必须证明：城市全灭会进入 `game_over`；最终波清空且至少保住一座 city 会进入 `final`。
8. 自动化测试必须证明：HUD 与世界记分牌共享同一份 runtime summary。
9. 自动化测试必须证明：退出玩法态后会 reset session、隐藏 HUD、恢复玩家控制和玩家 camera。
10. 自动化测试必须证明：full map pin `icon_id = missile_command` 能正式渲染。
11. 受影响的 soccer / tennis 主链 tests 必须继续通过。
12. 如改动触及 HUD / mount / tick，fresh closeout 必须串行跑 profiling 三件套。
13. 反作弊条款：不得点击即消敌；不得从虚空发弹；不得只做 HUD 没有真实敌我轨迹；不得继续靠 `E` 作为主动作；不得关闭足球/网球功能换 `v29` 通过。

## Files

- Create: `docs/plans/2026-03-20-v29-missile-command-research.md`
- Create: `docs/plans/2026-03-20-v29-missile-command-design.md`
- Create: `docs/prd/PRD-0019-missile-command-defense-minigame.md`
- Create: `docs/plan/v29-index.md`
- Create: `docs/plan/v29-missile-command-defense-minigame.md`
- Create: `city_game/world/minigames/CityMissileCommandVenueRuntime.gd`
- Create: `city_game/serviceability/minigame_venues/generated/venue_v29_missile_command_battery_chunk_183_152/minigame_venue_manifest.json`
- Create: `city_game/serviceability/minigame_venues/generated/venue_v29_missile_command_battery_chunk_183_152/missile_command_minigame_venue.tscn`
- Create: `city_game/serviceability/minigame_venues/generated/venue_v29_missile_command_battery_chunk_183_152/MissileCommandMinigameVenue.gd`
- Modify: `city_game/serviceability/minigame_venues/generated/minigame_venue_registry.json`
- Modify: `city_game/scripts/CityPrototype.gd`
- Modify: `city_game/ui/PrototypeHud.gd`
- Modify: `city_game/ui/CityMapScreen.gd`
- Create: `tests/world/test_city_missile_command_minigame_venue_manifest_contract.gd`
- Create: `tests/world/test_city_missile_command_battery_contract.gd`
- Create: `tests/world/test_city_missile_command_mode_contract.gd`
- Create: `tests/world/test_city_missile_command_wave_contract.gd`
- Create: `tests/world/test_city_missile_command_damage_contract.gd`
- Create: `tests/world/test_city_missile_command_hud_contract.gd`
- Create: `tests/world/test_city_missile_command_full_map_pin_contract.gd`
- Create: `tests/e2e/test_city_missile_command_wave_flow.gd`

## Steps

1. Analysis
   - 固定 `venue_id`、manifest 路径、锚点与 pin 语义。
   - 固定 battery mode 输入合同与玩法态边界。
   - 决定 gameplay plane / camera / silo / city 最小 contract。
2. Design
   - 写 research / design / PRD / `v29-index` / `v29` plan。
   - 明确采用“scene_minigame_venue + gameplay plane + battery mode”方案，而不是自由射击或独立 UI app。
3. TDD Red
   - 先写 venue manifest / registry / pin tests。
   - 再写 battery contract / mode contract / HUD contract。
   - 再写 wave / damage / e2e flow。
4. Run Red
   - 逐条运行新测试，确认失败原因是 `v29` 尚未实现，而不是路径或 contract 拼写错误。
5. TDD Green
   - author battery venue scene / manifest / registry。
   - 实现 `CityMissileCommandVenueRuntime.gd`。
   - 扩展 `CityPrototype.gd` 做第三套 minigame runtime 聚合、输入分发与 crosshair/HUD 接线。
   - 扩展 `PrototypeHud.gd` 与 `CityMapScreen.gd`。
6. Refactor
   - 收口 battery mode 输入和 runtime state，避免 `CityPrototype.gd` 再膨胀成玩法逻辑容器。
   - 冷路径保留完整 runtime snapshot，热路径只暴露紧凑 HUD summary。
7. E2E
   - 跑 `Missile Command` wave flow。
   - 补跑受影响 soccer / tennis tests。
   - 如触及 HUD / tick / mount，串行跑 profiling 三件套。
8. Review
   - 更新 `v29-index` traceability 与验证证据。
   - 若后续要改控制口径、波次数量或胜负条件，先写 ECN 再改代码。
9. Ship
   - `v29: doc: freeze missile command minigame scope`
   - 后续红绿 slices 分别 `test / feat / refactor`

## Risks

- 如果继续沿 `E` 交互主链做这轮玩法，左键/右键/准星/zoom 合同会直接断裂。
- 如果不用正式 gameplay plane，三维拦截点、爆炸链和测试锚点会迅速失控。
- 如果 runtime 从虚空发射导弹而不绑定当前 silo，就会直接破坏 `Missile Command` 的核心语义。
- 如果 camera 不是场馆 authored，而是硬塞玩家 camera，很容易出现调不准的视角和未来不可维护的 magic transform。
- 如果 HUD 与世界记分牌不共享同一份 summary，状态很快就会漂移。
