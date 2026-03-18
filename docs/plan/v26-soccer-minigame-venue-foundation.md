# V26 Soccer Minigame Venue Foundation

## Goal

交付一条正式的 `scene_minigame_venue` 实现计划：把 `v25` 的足球所在位置扩成一个真正可玩的足球场馆。该场馆必须通过 `registry -> manifest -> near chunk mount -> scene` 挂进 `chunk_129_139`，提供 raised playable floor、walkable apron ring、标准中圈/禁区/小禁区标线、两侧球门、goal detection、大型场边计分板、比分与 reset loop，并与现有 `prop:v25:soccer_ball:chunk_129_139` 正式协作。同时，场馆激活时必须支持只冻结全城 crowd / ambient traffic 的 `ambient_simulation_freeze`，而不是粗暴走全局 pause，更不能把现有收音机链路一起停掉。

## PRD Trace

- Direct consumer: REQ-0016-001
- Direct consumer: REQ-0016-002
- Direct consumer: REQ-0016-003
- Direct consumer: REQ-0016-004
- Guard / Performance: REQ-0016-005
- Guard / Performance: REQ-0016-006

## Dependencies

- 依赖 `v21` 已冻结 `scene_landmark` 的 authored 世界接入思路，但本版不复用其语义。
- 依赖 `v25` 已冻结 `scene_interactive_prop` 与足球 `prop_id`、kick interaction、mount chain。
- 依赖 `CityChunkRenderer / CityChunkScene` 的 chunk near mount 事件链。
- 依赖当前 `CityPrototype.gd` 已具备 primary interaction 与 scene interactive prop runtime 合流能力。

## Contract Freeze

- 新增正式 family：`scene_minigame_venue`。
- registry entry 最小字段冻结为：
  - `venue_id`
  - `feature_kind`
  - `manifest_path`
  - `scene_path`
- `feature_kind` 在 `v26` 冻结为 `scene_minigame_venue`。
- manifest 最小字段冻结为：
  - `venue_id`
  - `display_name`
  - `feature_kind`
  - `game_kind`
  - `anchor_chunk_id`
  - `anchor_chunk_key`
  - `world_position`
  - `surface_normal`
  - `scene_root_offset`
  - `scene_path`
  - `manifest_path`
  - `primary_ball_prop_id`
- 首个场馆正式 `venue_id` 冻结为 `venue:v26:soccer_pitch:chunk_129_139`。
- `primary_ball_prop_id` 冻结为 `prop:v25:soccer_ball:chunk_129_139`。
- `world_position = (-1877.94, 2.52, 618.57)` 的语义在 `v26` 冻结为 kickoff / 场馆中心锚点。
- playable floor 必须是场馆自带的 raised 局部平整承载层，不依赖 terrain runtime 改造。
- pitch 外圈 apron ring 必须和比赛面同标高可步行，不能只做视觉条带然后让玩家从边缘走入时掉回 terrain。
- podium 外侧那一圈有厚度的侧壁必须也是正式碰撞体，玩家不得从侧面钻进 raised pitch 下方空腔。
- 当前冻结口径下，球场顶面高度不得再上调；如需继续消除 terrain 缝隙，只允许把 podium/foundation 向下加厚嵌入地面。
- 首版足球场标线至少包含 halfway line、center circle、center spot、两侧 penalty area、两侧 goal box 与 penalty spot。
- 最小比分 contract 冻结为：
  - `home_score`
  - `away_score`
  - `last_scored_side`
- [已由 ECN-0025 变更](../ecn/ECN-0025-v26-scoreboard-and-ambient-freeze.md) 大型场边计分板是首版主比分 surface，最小显示 contract 额外冻结为：
  - `game_state_label`
- 最小回合状态冻结为：
  - `idle`
  - `in_play`
  - `goal_scored`
  - `out_of_bounds`
  - `resetting`
- 球门检测首版冻结为 goal volume contract，不做复杂球门线技术。
- [已由 ECN-0025 变更](../ecn/ECN-0025-v26-scoreboard-and-ambient-freeze.md) `ambient_simulation_freeze` 冻结为专用玩法性能模式：
  - 冻结对象仅限 `pedestrians + ambient vehicles`
  - 不得复用 `world_simulation_pause`
  - 必须保留 `player + soccer prop + venue runtime + HUD + radio`
  - 进入比赛场地有效范围立即激活
  - 只有离开赛场边界后再退出额外 `24.0m` 的 release buffer 才允许解冻

## Scope

做什么：

- 新增 minigame venue registry/runtime
- 在 chunk renderer / chunk scene 增加 venue mount 入口
- author 足球 minigame venue manifest / scene / script
- 在场馆 scene 内实现 raised playable floor、walkable apron ring、blocking podium side faces、标准标线、两侧球门、goal volume 与大型场边计分板
- 如用户继续反馈 terrain seam，可通过增加 foundation 向下埋深处理，但不得再改动已冻结的场地顶面高度
- 新增 venue runtime，负责 ball binding、score state、goal / out-of-bounds detection、scoreboard sync 与 reset
- 新增场馆激活时的 `ambient_simulation_freeze`
- 在 HUD 或等价 UI 中暴露最小比分/状态
- 补 registry / manifest / pitch / goal / scoreboard / ambient freeze / reset / e2e 测试

不做什么：

- 不做 `11v11`、门将、队友或对手 AI
- 不做完整比赛规则、计时器、裁判系统
- 不做 map pin、任务接入、联网或存档
- 不做 terrain 系统级 flattening
- 不做第二个比赛专用足球
- 不做全局 `SceneTree.paused` / `Engine.time_scale = 0` 式粗暴停机

## Acceptance

1. 自动化测试必须证明：`scene_minigame_venue` registry/runtime 能正式读取足球场馆 entry，并按 `chunk_129_139` 索引。
2. 自动化测试必须证明：足球场馆 manifest 保存了 kickoff anchor、chunk 信息与 `primary_ball_prop_id`，且 registry / manifest / scene path 三者口径一致。
3. 自动化测试必须证明：场馆 mounted 后存在稳定 raised playable floor、walkable apron ring、blocking podium side faces 与可判定 `in_play` 边界，而不是只画一张草地贴图。
4. 自动化测试必须证明：两侧球门与 goal volume 都存在，足球进入合法 goal volume 时比分只增加一次。
5. 自动化测试必须证明：大型场边计分板存在，且会跟随 `home_score / away_score / game_state_label` 正式更新。
6. 自动化测试必须证明：激活足球场馆后，`ambient_simulation_freeze` 会冻结 crowd / ambient traffic，但不会把 `is_world_simulation_paused()` 置为 `true`。
7. 自动化测试必须证明：ambient freeze 期间，venue runtime 绑定的是 `v25` 正式足球 prop，而不是偷偷生成第二个球。
8. 自动化测试必须证明：ambient freeze 期间，收音机若原本处于播放态，则仍保持播放。
9. 自动化测试必须证明：玩家刚离开赛场边界但仍处于 `24.0m release buffer` 内时，ambient freeze 仍保持激活，不会立刻解冻。
10. 自动化测试必须证明：玩家在边界附近反复进出时，freeze state 不会每几帧来回翻转。
11. 自动化测试必须证明：进球或出界后，球会被重置到 kickoff 点，并清零线速度与角速度。
12. 至少一条 e2e 测试必须证明：玩家可完成“进场 -> 踢球 -> 进球 -> 记分 -> 重置 -> 再开球”完整流程。
13. 受影响的 `v25` 足球交互、`v21` landmark mount、`v24` radio 与 streaming 相关测试必须继续通过。
14. 自动化测试必须证明：足球从背后穿入或仅碰门框附近时，不会误判成有效进球。
15. 反作弊条款：不得把场馆挂成 landmark；不得把 reset 做成重载整个 world；不得复制隐藏球；不得只靠手测或脚本直改比分宣称完成；不得用 `_apply_world_simulation_pause(true)` 或停掉 audio backend 冒充 ambient freeze。

## Files

- Create: `docs/prd/PRD-0016-soccer-minigame-venue-foundation.md`
- Create: `docs/plan/v26-index.md`
- Create: `docs/plan/v26-soccer-minigame-venue-foundation.md`
- Create: `docs/plans/2026-03-18-v26-soccer-minigame-venue-design.md`
- Create: `city_game/world/features/CitySceneMinigameVenueRegistry.gd`
- Create: `city_game/world/features/CitySceneMinigameVenueRuntime.gd`
- Create: `city_game/world/minigames/CitySoccerVenueRuntime.gd`
- Create: `city_game/serviceability/minigame_venues/generated/minigame_venue_registry.json`
- Create: `city_game/serviceability/minigame_venues/generated/venue_v26_soccer_pitch_chunk_129_139/minigame_venue_manifest.json`
- Create: `city_game/serviceability/minigame_venues/generated/venue_v26_soccer_pitch_chunk_129_139/soccer_minigame_venue.tscn`
- Create: `city_game/serviceability/minigame_venues/generated/venue_v26_soccer_pitch_chunk_129_139/SoccerMinigameVenue.gd`
- Modify: `city_game/scripts/CityPrototype.gd`
- Modify: `city_game/world/pedestrians/simulation/CityPedestrianTierController.gd`
- Modify: `city_game/world/vehicles/simulation/CityVehicleTierController.gd`
- Modify: `city_game/world/radio/CityVehicleRadioController.gd` only if ambient freeze continuity contract requires explicit guard
- Modify: `city_game/world/rendering/CityChunkRenderer.gd`
- Modify: `city_game/world/rendering/CityChunkScene.gd`
- Modify: `city_game/ui/PrototypeHud.gd` only if比分/状态 contract 无法复用现有 HUD 链
- Create: `tests/world/test_city_scene_minigame_venue_registry_runtime.gd`
- Create: `tests/world/test_city_soccer_minigame_venue_manifest_contract.gd`
- Create: `tests/world/test_city_soccer_pitch_play_surface_contract.gd`
- Create: `tests/world/test_city_soccer_pitch_markings_contract.gd`
- Create: `tests/world/test_city_soccer_player_surface_grounding_contract.gd`
- Create: `tests/world/test_city_soccer_goal_detection_contract.gd`
- Create: `tests/world/test_city_soccer_scoreboard_contract.gd`
- Create: `tests/world/test_city_soccer_scoreboard_visual_contract.gd`
- Create: `tests/world/test_city_soccer_venue_ambient_freeze_contract.gd`
- Create: `tests/world/test_city_soccer_venue_ambient_freeze_hysteresis_contract.gd`
- Create: `tests/world/test_city_soccer_venue_radio_survives_ambient_freeze.gd`
- Create: `tests/world/test_city_soccer_ball_reset_contract.gd`
- Create: `tests/e2e/test_city_soccer_minigame_goal_flow.gd`

## Steps

1. Analysis
   - 固定 `venue_id`、registry path、manifest path、scene path、kickoff anchor 与 `primary_ball_prop_id`。
   - 审计 `v25` 足球 prop 的可绑定 contract，确认 reset 所需接口缺什么。
   - 固定场馆首版尺寸、goal volume 语义、scoreboard 可读尺寸与 out-of-bounds contract。
   - 固定 `ambient_simulation_freeze` 的触发/恢复语义，并明确不走 `world_simulation_pause`。
   - 冻结 release hysteresis：进入场地立即冻结，退出则必须离开赛场边界后再额外退出 `24.0m`。
2. Design
   - 写 `PRD-0016`
   - 写 `v26-index.md`
   - 写 `v26-soccer-minigame-venue-foundation.md`
   - 写 design doc，明确为什么必须新开 `scene_minigame_venue`
3. TDD Red
   - 先写 venue registry/runtime contract test
   - 再写 manifest / playable floor / goal detection / scoreboard tests
   - 再写 ambient freeze / hysteresis / radio continuity tests
   - 再写 reset contract
   - 最后写 goal flow e2e
4. Run Red
   - 逐条运行新测试，确认失败原因是 venue family / scene / runtime 尚未实现，而不是测试拼写错误
5. TDD Green
   - 实现 venue registry/runtime
   - author soccer venue manifest / scene / script
   - 接入 chunk mount
   - 实现 playable floor / bounds / goals / goal detection
   - 实现 scoreboard sync
   - 实现 crowd / ambient traffic 的 `ambient_simulation_freeze`
   - 实现 ball binding、score state 与 reset
   - 接入最小 HUD 状态
6. Refactor
   - 收口 venue runtime 与 prop binding / ambient freeze 接口，避免 `CityPrototype.gd` 继续堆满比赛状态特判
   - 冷路径保留完整 venue snapshot，热路径只保留当前 active venue summary
7. E2E
   - 跑足球 minigame goal flow
   - 补跑受影响 `v25` 足球交互、`v24` radio、landmark 与 streaming tests
   - 如触及 mount/tick/HUD，串行跑 profiling 三件套
8. Review
   - 更新 `v26-index` traceability
   - 写差异列表与 verification evidence
   - 如实现中改变 DoD 或 contract，先写 ECN 再改代码
9. Ship
   - `v26: doc: freeze soccer minigame venue scope`
   - 后续红绿 slices 分别 `test / feat / refactor`

## Risks

- 如果继续把球场塞进 `scene_interactive_prop`，后面所有场馆玩法都会退化成“一个越来越胖的球”。
- 如果试图让足球玩法直接贴自然 terrain，goal detection 与 reset 会持续被地形起伏污染。
- 如果场馆偷偷复制第二个球，`v25` 的 prop contract 会被破坏，后续排查也会非常混乱。
- 如果 ambient freeze 误走了 `world_simulation_pause`，很可能会把场馆 runtime 或收音机一起停掉，直接违反用户口径。
- 如果 freeze / unfreeze 没有迟滞，玩家只要在场边附近活动就会频繁抖动切换，体验会非常差。
- 如果比分/重置逻辑直接写进 `CityPrototype.gd`，很快会变成第二个玩法总控巨石。
- 如果大计分板只做成装饰节点、不接正式 runtime state，最后又会退化回“只有 HUD 才知道比分”。
- 如果 `v26` 首版偷偷膨胀进 AI 球员或完整规则系统，计划会失控，测试与 closeout 也会失真。
