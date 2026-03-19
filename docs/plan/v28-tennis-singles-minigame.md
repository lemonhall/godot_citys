# V28 Tennis Singles Minigame

## Goal

交付一条正式的 `v28` 实现计划：在 `chunk_158_140` 用户指定锚点 author 一座网球场和一颗正式网球，提供 `player vs AI opponent` 的单打 minigame。该玩法必须沿现有 `scene_minigame_venue + scene_interactive_prop` 主链挂载，具备 singles court / net / service boxes、开赛圈、发球与回合状态机、point / game 计分、HUD / 世界计分板、出圈 reset，以及 `CityPrototype` 对 soccer + tennis 双 minigame runtime 的聚合能力。

## PRD Trace

- Direct consumer: REQ-0018-001
- Direct consumer: REQ-0018-002
- Direct consumer: REQ-0018-003
- Direct consumer: REQ-0018-003A
- Direct consumer: REQ-0018-004
- Guard / Runtime: REQ-0018-005
- Guard / Runtime: REQ-0018-006

## Dependencies

- 依赖 `v25` 已冻结 `scene_interactive_prop` 与正式球类 prop mount / prompt / interaction 链。
- 依赖 `v26` 已冻结 `scene_minigame_venue` family、registry/runtime、ambient freeze 主链。
- 依赖 `v27` 已冻结开赛圈、HUD、world scoreboard、match reset 的成熟思路，但不复用足球行为模型。
- 依赖 `CityChunkRenderer / CityChunkScene` 已支持同 chunk 同时挂载 authored venue 与 interactive prop。

## Contract Freeze

- 正式 `venue_id = venue:v28:tennis_court:chunk_158_140`
- 正式 `prop_id = prop:v28:tennis_ball:chunk_158_140`
- 锚点冻结为：
  - `anchor_chunk_id = chunk_158_140`
  - `anchor_chunk_key = (158, 140)`
  - `world_position = (5489.46, 20.62, 1029.73)`
  - `surface_normal = (-0.02, 1.00, -0.02)`
- 场馆 `game_kind` 冻结为 `tennis_court`
- 球 prop `interaction_kind` 冻结为 `swing`
- `court_scale_factor = 7.5`
- `platform_lift_total_m = +2.0`（[ECN-0026](../ecn/ECN-0026-v28-tennis-playability-replan.md)）
- `start_ring_location = near_home_serve_setup_zone`（[ECN-0026](../ecn/ECN-0026-v28-tennis-playability-replan.md)）
- `tennis_ball_target_diameter_m` 冻结到 third-person readable oversize 区间，visual mesh 必须同步跟随 contract（[ECN-0026](../ecn/ECN-0026-v28-tennis-playability-replan.md)）
- `tennis_ball_feedback_cues = glow + trail + impact_audio`，且必须事件驱动/速度驱动，禁止每帧重复播音
- `interaction_radius_m >= player_strike_radius_m`，共享提示窗口必须与 tennis 合法击球窗口对齐（[ECN-0026](../ecn/ECN-0026-v28-tennis-playability-replan.md)）
- receive ring 冻结为玩家可进入的接球操作圈；球进入正式击球阶段后应及时消失（[ECN-0026](../ecn/ECN-0026-v28-tennis-playability-replan.md)）
- 首版 court geometry contract 至少冻结为：
  - `base_court_length_m`
  - `base_singles_width_m`
  - `base_service_line_distance_m`
  - `court_scale_factor`
  - `court_length_m`
  - `singles_width_m`
  - `service_line_distance_m`
  - `net_center_height_m`
  - `net_post_height_m`
  - `court_bounds`
  - `service_box_ids`
  - `release_buffer_m`
- 比赛状态冻结为：
  - `idle`
  - `pre_serve`
  - `serve_in_flight`
  - `rally`
  - `point_result`
  - `game_break`
  - `final`
- 最小 point resolution contract 冻结为：
  - `server_side`
  - `serve_attempt_index`
  - `expected_service_box_id`
  - `last_hitter_side`
  - `ball_bounce_count_home`
  - `ball_bounce_count_away`
  - `point_winner_side`
  - `point_end_reason`
- 最小 score contract 冻结为：
  - `home_games`
  - `away_games`
  - `home_point_label`
  - `away_point_label`
  - `server_side`
  - `winner_side`
- HUD 与世界计分板必须共享同一份 runtime score state。
- `CityPrototype` 必须聚合 soccer + tennis 的 `ambient_simulation_frozen` 输出。
- 手动球交互事件必须带 `prop_id` 分发，不能再只通知足球。
- 玩家 `E` 输入必须先进入 tennis runtime 的合法 shot planner，再落到 ball velocity / impulse；禁止继续沿用通用球 prop 的裸前向冲量。
- 接球 UX 至少冻结为：
  - `landing_marker_visible`
  - `landing_marker_world_position`
  - `auto_footwork_assist_state`
  - `strike_window_state`
  - `strike_quality_feedback`

## Scope

做什么：

- 新增 tennis venue manifest / scene / script
- 新增 tennis ball prop manifest / scene / script
- 若需要，抽出共享 `ball interactive prop` 基类，统一 soccer / tennis 球类交互配置
- author singles court、net、scoreboard、start ring、AI opponent visual / anchor
- 新增 `CityTennisVenueRuntime.gd`
- 扩展 `CityPrototype.gd` 聚合 soccer + tennis runtime
- 扩展 `PrototypeHud.gd` 增加 tennis HUD block
- 扩展 `CityMapScreen.gd` 支持 `icon_id = tennis`
- 补 registry / geometry / scoring / reset / e2e / soccer regression tests

不做什么：

- 不做双打
- 不做可见球拍、复杂挥拍动画、裁判、观众
- 不做完整职业长盘
- 不做 task system 集成
- 不做把足球 runtime 改名冒充网球 runtime

## Acceptance

1. 自动化测试必须证明：网球场馆与网球 ball 都被正式写入 registry / manifest，并在 `chunk_158_140` near mount 后能找到对应节点。
2. 自动化测试必须证明：网球场暴露正式 singles court / service box / net contract，而不是只画地面纹理。
3. 自动化测试必须证明：start ring 可正式启动比赛，HUD 会显示当前 score / state，且 start ring 位于 player-side serve setup zone 附近。
4. 自动化测试必须证明：合法发球会进入 rally，fault / double fault 会正确判分，而且默认发球不会朝本方半场或非法方向裸飞。
5. 自动化测试必须证明：二次落地、不过网、首次落点出界都会结束 point，并把分判给正确 side。
6. 自动化测试必须证明：玩家可以通过正式网球 prop 参与击球，而且玩家与 AI 的击球都尽量 obey tennis legality，而不是 generic ball impulse 乱飞。
7. 自动化测试必须证明：AI opponent 至少能完成最小回球闭环，不会永远站桩；AI 回球后玩家侧具备足够的接球 UX 提示，而且 `strike_window_state = ready` 时共享 `E` 提示必须能稳定接上。
8. 自动化测试必须证明：`ready / point result / final` 至少具备事件驱动的 focus cue 或音效 cue，且不会在热路径里每帧重复触发。
9. 自动化测试必须证明：AI 在长回合下存在轻量、确定性的失误风险，避免表现成永不出错的必胜对手。
10. 自动化测试必须证明：正式 tennis ball scene 具备 third-person 可读性的视觉/音频反馈组件，而且真实弹地时会触发离散 impact audio。
11. 自动化测试必须证明：point winner 会正式推进 game score，HUD 与 world scoreboard 始终一致。
12. 自动化测试必须证明：出圈 reset 会同时重置球、AI、HUD、scoreboard 与比赛状态。
13. 自动化测试必须证明：`CityPrototype` 在网球激活时能正确聚合 `ambient_simulation_frozen`，且不会因此打坏足球主链。
14. 自动化测试必须证明：网球 full map pin 若存在，`icon_id = tennis` 能正式渲染。
15. 受影响的足球关键 tests 必须继续通过。
16. 如改动触及 mount / tick / HUD / renderer sync，fresh closeout 必须串行跑 profiling 三件套。
17. 反作弊条款：不得复制隐藏球；不得只改 HUD 不改 scoreboard；不得只改 point label 不保留 point/game 层级；不得关闭足球功能来换网球通过；不得只放大碰撞体却让视觉球仍停留在初始小尺寸；不得用每帧重复播音来冒充事件反馈；不得只给球加 HUD 文案而不提供真实球体 feedback cue。

## Files

- Create: `docs/plans/2026-03-19-v28-tennis-singles-minigame-research.md`
- Create: `docs/plans/2026-03-19-v28-tennis-singles-minigame-design.md`
- Create: `docs/plans/2026-03-19-v28-tennis-input-ui-ux-research.md`
- Create: `docs/plans/2026-03-19-v28-tennis-feedback-audio-research.md`
- Create: `docs/prd/PRD-0018-tennis-singles-minigame.md`
- Create: `docs/plan/v28-index.md`
- Create: `docs/plan/v28-tennis-singles-minigame.md`
- Create: `city_game/world/minigames/CityTennisVenueRuntime.gd`
- Create: `city_game/serviceability/minigame_venues/generated/venue_v28_tennis_court_chunk_158_140/minigame_venue_manifest.json`
- Create: `city_game/serviceability/minigame_venues/generated/venue_v28_tennis_court_chunk_158_140/tennis_minigame_venue.tscn`
- Create: `city_game/serviceability/minigame_venues/generated/venue_v28_tennis_court_chunk_158_140/TennisMinigameVenue.gd`
- Create: `city_game/serviceability/minigame_venues/generated/venue_v28_tennis_court_chunk_158_140/TennisOpponent.gd`
- Create: `city_game/serviceability/interactive_props/generated/prop_v28_tennis_ball_chunk_158_140/interactive_prop_manifest.json`
- Create: `city_game/serviceability/interactive_props/generated/prop_v28_tennis_ball_chunk_158_140/tennis_ball_prop.tscn`
- Create: `city_game/serviceability/interactive_props/generated/prop_v28_tennis_ball_chunk_158_140/TennisBallProp.gd`
- Modify: `city_game/serviceability/minigame_venues/generated/minigame_venue_registry.json`
- Modify: `city_game/serviceability/interactive_props/generated/interactive_prop_registry.json`
- Modify: `city_game/scripts/CityPrototype.gd`
- Modify: `city_game/ui/PrototypeHud.gd`
- Modify: `city_game/ui/CityMapScreen.gd`
- Optional Create/Modify: `city_game/world/minigames/CityBallInteractiveProp.gd`
- Create: `tests/world/test_city_tennis_minigame_venue_manifest_contract.gd`
- Create: `tests/world/test_city_tennis_ball_prop_manifest_contract.gd`
- Create: `tests/world/test_city_tennis_court_geometry_contract.gd`
- Create: `tests/world/test_city_tennis_match_start_contract.gd`
- Create: `tests/world/test_city_tennis_match_hud_contract.gd`
- Create: `tests/world/test_city_tennis_point_resolution_contract.gd`
- Create: `tests/world/test_city_tennis_scoring_contract.gd`
- Create: `tests/world/test_city_tennis_ai_return_contract.gd`
- Create: `tests/world/test_city_tennis_ai_pressure_error_contract.gd`
- Create: `tests/world/test_city_tennis_ball_feedback_contract.gd`
- Create: `tests/world/test_city_tennis_reset_on_exit_contract.gd`
- Create: `tests/world/test_city_tennis_runtime_aggregate_contract.gd`
- Create: `tests/e2e/test_city_tennis_singles_match_flow.gd`

## Steps

1. Analysis
   - 固定 tennis venue / ball 的正式 ID、manifest 路径、锚点与 map pin 语义。
   - 固定首版赛制、serve / rally / point / game 状态机与 AI 最小职责。
   - 审计现有足球入口，确认 `CityPrototype` 需要被泛化的点：runtime 更新、ambient freeze、HUD、手动击球通知。
2. Design
   - 写 research / design / PRD / `v28-index` / `v28` plan。
   - 明确选择“共享 authored 主链、各 sport 独立 runtime、入口层聚合”的方案。
3. TDD Red
   - 先写 tennis venue / ball manifest contract tests。
   - 再写 court geometry / start ring / HUD tests。
   - 再写 serve / point / scoring / reset / aggregate tests。
   - 最后写 tennis singles e2e flow。
4. Run Red
   - 逐条运行新测试，确认失败原因是 `v28` 尚未实现，而不是测试拼写或场景路径错误。
5. TDD Green
   - author tennis venue / ball 资产与 registries。
   - 实现 `CityTennisVenueRuntime.gd`。
   - 扩展 `CityPrototype.gd` 做双 runtime 聚合。
   - 扩展 HUD / map pin。
   - 实现 serve planner / return planner / landing marker / auto-footwork assist。
   - 接入必要 debug hooks，支持 deterministic point / score 验证。
6. Refactor
   - 收口共享球类交互逻辑，避免 soccer / tennis ball script 无控制分叉。
   - 保持每个 sport 规则状态在各自 runtime 内，避免 `CityPrototype.gd` 再次膨胀。
7. E2E
   - 跑 tennis singles flow。
   - 补跑受影响 soccer tests。
   - 如触及 HUD / mount / tick，串行跑 profiling 三件套。
8. Review
   - 更新 `v28-index` 追溯矩阵与证据。
   - 本轮 playability replan 已由 `ECN-0026` 冻结；如再改变赛制或 DoD，先写 ECN 再改代码。
9. Ship
   - `v28: doc: freeze tennis singles minigame scope`
   - 后续红绿 slices 分别 `test / feat / refactor`

## Risks

- 如果继续让 `CityPrototype.gd` 只认足球 runtime，网球即使 scene 挂上来也无法形成正式玩法链。
- 如果把 tennis ball 做成 runtime 内隐藏对象，interactive prop 主链与玩家击球入口会立刻分叉。
- 如果 court geometry 没有正式 contract，发球区、出界与不过网判分都会变成脆弱的魔法数字。
- 如果玩家与 AI 继续共用 generic ball impulse，而不是合法 shot planner，很容易出现“规则写对了，但人根本打不出合法网球”的伪实现。
- 如果没有接球 UX 提示，玩家会频繁出现“看见来球但根本接不住”的挫败感，等价于玩法不可玩。
- 如果 reset 只清 HUD 不清 point/game/ball/AI 状态，下次进场会得到脏比赛。
- 如果为了图快关闭足球或绕开 ambient freeze 聚合，`v28` 会以破坏 `v26/v27` 为代价通过，不能接受。
