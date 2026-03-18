# V26 Soccer Minigame Venue Foundation

## Goal

交付一条正式的 `scene_minigame_venue` 实现计划：把 `v25` 的足球所在位置扩成一个真正可玩的足球场馆。该场馆必须通过 `registry -> manifest -> near chunk mount -> scene` 挂进 `chunk_129_139`，提供局部平整 playable floor、两侧球门、goal detection、比分与 reset loop，并与现有 `prop:v25:soccer_ball:chunk_129_139` 正式协作，而不是复制第二个隐藏球或把所有逻辑塞回足球 prop scene。

## PRD Trace

- Direct consumer: REQ-0016-001
- Direct consumer: REQ-0016-002
- Direct consumer: REQ-0016-003
- Direct consumer: REQ-0016-004
- Guard / Performance: REQ-0016-005

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
- playable floor 必须是场馆自带的局部平整承载层，不依赖 terrain runtime 改造。
- 最小比分 contract 冻结为：
  - `home_score`
  - `away_score`
  - `last_scored_side`
- 最小回合状态冻结为：
  - `idle`
  - `in_play`
  - `goal_scored`
  - `out_of_bounds`
  - `resetting`
- 球门检测首版冻结为 goal volume contract，不做复杂球门线技术。

## Scope

做什么：

- 新增 minigame venue registry/runtime
- 在 chunk renderer / chunk scene 增加 venue mount 入口
- author 足球 minigame venue manifest / scene / script
- 在场馆 scene 内实现 playable floor、边界线、两侧球门与 goal volume
- 新增 venue runtime，负责 ball binding、score state、goal / out-of-bounds detection 与 reset
- 在 HUD 或等价 UI 中暴露最小比分/状态
- 补 registry / manifest / pitch / goal / reset / e2e 测试

不做什么：

- 不做 `11v11`、门将、队友或对手 AI
- 不做完整比赛规则、计时器、裁判系统
- 不做 map pin、任务接入、联网或存档
- 不做 terrain 系统级 flattening
- 不做第二个比赛专用足球

## Acceptance

1. 自动化测试必须证明：`scene_minigame_venue` registry/runtime 能正式读取足球场馆 entry，并按 `chunk_129_139` 索引。
2. 自动化测试必须证明：足球场馆 manifest 保存了 kickoff anchor、chunk 信息与 `primary_ball_prop_id`，且 registry / manifest / scene path 三者口径一致。
3. 自动化测试必须证明：场馆 mounted 后存在稳定 playable floor 与可判定 `in_play` 边界，而不是只画一张草地贴图。
4. 自动化测试必须证明：两侧球门与 goal volume 都存在，足球进入合法 goal volume 时比分只增加一次。
5. 自动化测试必须证明：足球从背后穿入或仅碰门框附近时，不会误判成有效进球。
6. 自动化测试必须证明：venue runtime 绑定的是 `v25` 正式足球 prop，而不是偷偷生成第二个球。
7. 自动化测试必须证明：进球或出界后，球会被重置到 kickoff 点，并清零线速度与角速度。
8. 至少一条 e2e 测试必须证明：玩家可完成“进场 -> 踢球 -> 进球 -> 记分 -> 重置 -> 再开球”完整流程。
9. 受影响的 `v25` 足球交互、`v21` landmark mount 与 streaming 相关测试必须继续通过。
10. 反作弊条款：不得把场馆挂成 landmark；不得把 reset 做成重载整个 world；不得复制隐藏球；不得只靠手测或脚本直改比分宣称完成。

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
- Modify: `city_game/world/rendering/CityChunkRenderer.gd`
- Modify: `city_game/world/rendering/CityChunkScene.gd`
- Modify: `city_game/ui/PrototypeHud.gd` only if比分/状态 contract 无法复用现有 HUD 链
- Create: `tests/world/test_city_scene_minigame_venue_registry_runtime.gd`
- Create: `tests/world/test_city_soccer_minigame_venue_manifest_contract.gd`
- Create: `tests/world/test_city_soccer_pitch_play_surface_contract.gd`
- Create: `tests/world/test_city_soccer_goal_detection_contract.gd`
- Create: `tests/world/test_city_soccer_scoreboard_contract.gd`
- Create: `tests/world/test_city_soccer_ball_reset_contract.gd`
- Create: `tests/e2e/test_city_soccer_minigame_goal_flow.gd`

## Steps

1. Analysis
   - 固定 `venue_id`、registry path、manifest path、scene path、kickoff anchor 与 `primary_ball_prop_id`。
   - 审计 `v25` 足球 prop 的可绑定 contract，确认 reset 所需接口缺什么。
   - 固定场馆首版尺寸、goal volume 语义与 out-of-bounds contract。
2. Design
   - 写 `PRD-0016`
   - 写 `v26-index.md`
   - 写 `v26-soccer-minigame-venue-foundation.md`
   - 写 design doc，明确为什么必须新开 `scene_minigame_venue`
3. TDD Red
   - 先写 venue registry/runtime contract test
   - 再写 manifest / playable floor / goal detection / scoreboard tests
   - 再写 reset contract
   - 最后写 goal flow e2e
4. Run Red
   - 逐条运行新测试，确认失败原因是 venue family / scene / runtime 尚未实现，而不是测试拼写错误
5. TDD Green
   - 实现 venue registry/runtime
   - author soccer venue manifest / scene / script
   - 接入 chunk mount
   - 实现 playable floor / bounds / goals / goal detection
   - 实现 ball binding、score state 与 reset
   - 接入最小 HUD 状态
6. Refactor
   - 收口 venue runtime 与 prop binding 接口，避免 `CityPrototype.gd` 继续堆满比赛状态特判
   - 冷路径保留完整 venue snapshot，热路径只保留当前 active venue summary
7. E2E
   - 跑足球 minigame goal flow
   - 补跑受影响 `v25` 足球交互、landmark 与 streaming tests
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
- 如果比分/重置逻辑直接写进 `CityPrototype.gd`，很快会变成第二个玩法总控巨石。
- 如果 `v26` 首版偷偷膨胀进 AI 球员或完整规则系统，计划会失控，测试与 closeout 也会失真。
