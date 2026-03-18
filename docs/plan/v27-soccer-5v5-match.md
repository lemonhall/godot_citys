# V27 Soccer 5v5 Match

## Goal

交付一条正式的 `v27` 实现计划：在现有 `v26` 足球场馆上，增加记分牌旁开赛圈、HUD `5:00` 倒计时、红蓝两队各 `5` 名球员、简单追球/踢球/守门 AI、终场胜负与记分牌红圈高亮，以及玩家离开冻结/释放圈后的整场清零复位。同时，用户提供的 `Animated Human.glb` 必须被归置到足球专用资产域，不得进入 ambient pedestrian 资产池。

## PRD Trace

- Direct consumer: REQ-0017-001
- Direct consumer: REQ-0017-002
- Direct consumer: REQ-0017-003
- Direct consumer: REQ-0017-004
- Direct consumer: REQ-0017-005
- Guard / Performance: REQ-0017-006

## Dependencies

- 依赖 `v25` 已冻结同一颗正式足球 `prop:v25:soccer_ball:chunk_129_139` 的 kick interaction 与物理 contract。
- 依赖 `v26` 已冻结同一座足球场馆 `venue:v26:soccer_pitch:chunk_129_139` 的球门、scoreboard、goal detection、reset loop 与 ambient freeze。
- 依赖 `CityWorldRingMarker.gd` 已冻结 shared world ring 视觉 family，可复用为开赛圈。
- 依赖 `PrototypeHud.gd` 与 `CityPrototype.gd` 已具备正式 HUD 状态刷新链，可扩展足球比赛 HUD state。

## Contract Freeze

- 用户提供的素体模型正式入口不得位于 `city_game/assets/pedestrians/civilians/`。
- `v27` 正式比赛资源路径冻结为足球专用资产域，不进入 `pedestrian_model_manifest.json`。
- 比赛最小状态冻结为：
  - `idle`
  - `countdown_ready`
  - `in_progress`
  - `final`
  - `resetting`
- 比赛赛制冻结为：
  - `match_duration_sec = 300.0`
  - `match_clock_display = mm:ss`
  - `winner_side in {home, away, draw, ""}`
- 两队阵容冻结为：
  - `home/red = 5`
  - `away/blue = 5`
  - each team: `1 goalkeeper + 4 field_players`
- 球员最小 runtime contract 冻结为：
  - `player_id`
  - `team_id`
  - `role_id`
  - `home_anchor`
  - `world_position`
  - `move_target`
  - `intent_kind`
  - `animation_state`
  - `kick_requested`
- 开赛圈最小 contract 冻结为：
  - `ring_id`
  - `theme_id = task_available_start`
  - `world_anchor`
  - `trigger_radius_m`
  - `active`
- 终场 scoreboard 增量 contract 冻结为：
  - `winner_side`
  - `winner_highlight_visible`
  - `winner_highlight_side`
  - `match_clock_text`
- 玩家离开足球场冻结/释放圈时，必须触发整场 reset，而不是只解冻 ambient crowd/traffic。

## Scope

做什么：

- 归置 `Animated Human.glb` 到足球专用资产目录
- 新增 soccer player wrapper / runtime 节点与 team color 覆盖
- 在足球场馆内 author 红蓝两队 10 名球员与记分牌旁开赛圈
- 扩展 `CitySoccerVenueRuntime.gd` 以承载比赛状态、开赛触发、倒计时、AI、终场与复位
- 扩展 `PrototypeHud.gd` / `CityPrototype.gd` 暴露足球比赛 HUD 状态
- 复用同一颗正式足球完成 AI 与玩家共用的比赛链路
- 补资产、开赛、倒计时、阵容、AI、终场高亮、出圈归零与 e2e 测试

不做什么：

- 不做第二颗比赛专用足球
- 不做完整规则、裁判、替补、阵型编辑或联网
- 不做素体进入街道行人池
- 不做复杂身体对抗、抢断物理、专门踢球动作或 IK
- 不做 task system 集成，只复用开赛圈的 shared world ring 视觉 family

## Acceptance

1. 自动化测试必须证明：`Animated Human.glb` 已迁移到足球专用资产路径，且没有进入 `city_game/assets/pedestrians/civilians/` 或 `pedestrian_model_manifest.json`。
2. 自动化测试必须证明：足球场馆 mounted 后，场上存在红蓝两队各 `5` 名球员，且每队恰好 `1` 名守门员。
3. 自动化测试必须证明：未开赛时全部球员处于 Idle，且记分牌旁存在正式 start ring contract。
4. 自动化测试必须证明：Player 进入 start ring 后，比赛状态切到 `in_progress`，HUD 显示 `05:00`。
5. 自动化测试必须证明：倒计时会正式递减，并在归零时进入 `final`。
6. 自动化测试必须证明：比赛中至少有 AI 球员会切到 locomotion 状态并对同一颗正式足球施加有效 kick impulse。
7. 自动化测试必须证明：守门员 home zone 靠近本方球门，且与普通场上球员的 role contract 不同。
8. 自动化测试必须证明：终场时胜方正确结算，world scoreboard 暴露胜方红圈高亮；平局时不高亮。
9. 自动化测试必须证明：玩家离开足球场冻结/释放圈后，比分归 `0`、倒计时恢复 `05:00`、球与 `10` 名球员全部回初始站位并转回 Idle。
10. 受影响的 `v25` 足球 interaction 与 `v26` 场馆 tests 必须继续通过。
11. 如改动触及 mount / tick / HUD / renderer sync，fresh closeout 仍需串行跑 profiling 三件套。
12. 反作弊条款：不得把模型塞进 `civilians`；不得生成第二颗隐藏球；不得直接改比分绕过进球检测；不得只做跑步动画却不影响足球；不得只清 HUD 数字而不重置球与球员。
13. `M4` 金标准 1：正式 `5:00` 自主比赛里，红蓝 AI 必须围绕同一颗正式足球和正式 goal detection 自己打进至少 `1` 个球；不得靠 debug 注球、直接写分或其他旁路作弊来满足该条。
14. `M4` 金标准 2：同一实现做 `10` 场采样时，最终比分结果不得 `10/10` 完全一致；如果 `10` 场比分全同，则视为球员参数、环境或策略仍然过于镜像，`M4` 不通过。
15. 为满足金标准 2，允许引入真实物理链路内的球员差异化参数，例如体力条、冲刺能力、触球半径、射门偏好或其他可复核的能力扰动；但这些扰动必须进入正式 runtime contract，不能以 hidden score buff / goal assist / 暗改球轨迹 的形式作弊。
16. `M4` 金标准 3：完整 `5:00` 比赛与 `10` 场采样里，任一队单场得分不得达到两位数（`>= 10`），且任一场分差不得超过 `6` 球；一旦出现超高比分或过于悬殊比分，视为节奏、环境或物理参数已失真，`M4` 不通过。

## Files

- Create: `docs/prd/PRD-0017-soccer-5v5-match.md`
- Create: `docs/plan/v27-index.md`
- Create: `docs/plan/v27-soccer-5v5-match.md`
- Create: `docs/plans/2026-03-18-v27-soccer-5v5-match-design.md`
- Move/Create: `city_game/assets/minigames/soccer/players/animated_human.glb`
- Create: `city_game/world/minigames/CitySoccerMatchPlayerAgent.gd`
- Create: `city_game/world/minigames/CitySoccerMatchRoster.gd`
- Create: `city_game/serviceability/minigame_venues/generated/venue_v26_soccer_pitch_chunk_129_139/SoccerMatchPlayer.gd`
- Modify: `city_game/serviceability/minigame_venues/generated/venue_v26_soccer_pitch_chunk_129_139/SoccerMinigameVenue.gd`
- Modify: `city_game/serviceability/minigame_venues/generated/venue_v26_soccer_pitch_chunk_129_139/soccer_minigame_venue.tscn`
- Modify: `city_game/world/minigames/CitySoccerVenueRuntime.gd`
- Modify: `city_game/scripts/CityPrototype.gd`
- Modify: `city_game/ui/PrototypeHud.gd`
- Create: `tests/world/test_city_soccer_match_asset_contract.gd`
- Create: `tests/world/test_city_soccer_match_roster_contract.gd`
- Create: `tests/world/test_city_soccer_match_start_contract.gd`
- Create: `tests/world/test_city_soccer_match_countdown_contract.gd`
- Create: `tests/world/test_city_soccer_match_ai_kick_contract.gd`
- Create: `tests/world/test_city_soccer_match_final_scoreboard_contract.gd`
- Create: `tests/world/test_city_soccer_match_reset_on_exit_contract.gd`
- Create: `tests/e2e/test_city_soccer_5v5_match_flow.gd`

## Steps

1. Analysis
   - 固定素体资产路径，确保不进入 `civilians` 与 pedestrian manifest。
   - 固定 start ring 位置、trigger radius、HUD 倒计时 display contract。
   - 固定每队 `5` 人的 role 布局、home anchor 与守门员职责。
   - 固定终场 winner/highlight 与出圈 reset 语义。
2. Design
   - 写 `PRD-0017`
   - 写 `v27-index.md`
   - 写 `v27-soccer-5v5-match.md`
   - 写 design doc，明确为何继续扩展 `v26` 场馆 runtime，而不是引入第二套比赛系统
3. TDD Red
   - 先写 asset isolation / roster contract tests
   - 再写 start ring / countdown tests
   - 再写 AI kick / final scoreboard / reset-on-exit tests
   - 最后写完整 `5v5` match flow e2e
4. Run Red
   - 逐条运行新测试，确认失败原因是 `v27` 资产/比赛态尚未实现，而不是测试拼写错误
5. TDD Green
   - 归置素体资产
   - author soccer player wrapper / roster nodes
   - 扩展场馆 scene 与 runtime，接入 start ring / HUD timer / AI / final / reset
   - 接入 world introspection / debug hooks，支持可重复测试
6. Refactor
   - 把球员意图计算与场馆状态同步从 `CityPrototype.gd` 收口到 `CitySoccerVenueRuntime.gd` 及其 helper
   - 冷路径保留完整比赛 snapshot，热路径只保留 compact HUD / scoreboard / roster state
7. E2E
   - 跑 `test_city_soccer_5v5_match_flow.gd`
   - 补“完整 `5:00` 自主比赛至少有真实进球”的慢验证
   - 补“10 场采样比分不全同”的慢验证
   - 补“单队不得 `>= 10` 球且单场分差不得 `> 6`”的现实比分护栏验证
   - 补跑受影响 `v25/v26` 足球与场馆 tests
   - 如触及 mount/tick/HUD，串行跑 profiling 三件套
8. Review
   - 更新 `v27-index` traceability
   - 写 verification evidence 与差异列表
   - 如实现中改变 contract，先写 ECN 再改代码
9. Ship
   - `v27: doc: freeze soccer 5v5 match scope`
   - 后续红绿 slices 分别 `test / feat / refactor`

## Risks

- 如果把素体放进 `civilians`，它会被 ambient pedestrian manifest 误消费，直接违反用户口径。
- 如果把比赛态塞成第二套隐藏球或第二套场馆逻辑，`v25/v26` 主链会立刻分叉。
- 如果倒计时只做在 HUD 文案而不进入正式 runtime state，测试、记分牌和终场逻辑会失去统一口径。
- 如果 AI 没有正式 kick contract，只是围着球跑，用户会立刻感知为“假比赛”。
- 如果 `10` 名球员完全镜像、能力参数完全相同，比赛极易退化成中场拉扯与固定比分，无法通过 `M4` 的采样金标准。
- 如果为了通过短窗 smoke 而把射门速度、触球节奏或控球优势调得过猛，就会出现 `0:十几`、`0:几十` 这类失真比分，同样不能通过 `M4`。
- 如果出圈 reset 只清数字不清场上状态，球与球员会很快积累脏状态。
