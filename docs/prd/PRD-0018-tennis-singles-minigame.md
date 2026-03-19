# PRD-0018 Tennis Singles Minigame

## Vision

把 `godot_citys` 从“城市里已经有一套正式足球 minigame”推进到“城市里再落下一套真正能开打的网球单打 minigame”。`v28` 的目标不是把 `v27` 足球换个贴图，也不是一步到位做成完整职业网球模拟，而是在用户指定地点 `chunk_158_140` 正式 author 一座网球场和一颗网球，让玩家能走进场地、进入开赛圈、按正式单打球场语义发球并与一个 AI 对手来回球，通过 `serve -> rally -> point -> game -> final / reset` 的最小闭环玩完一场短局制单打比赛。由于当前项目是第三人称开放世界原型，`v28` 同时冻结为 **realistic-arcade hybrid**：规则遵循网球，输入与 UI/UX 则必须给到足够的自动跑位、落点预判与合法击球约束，避免“物理是对的，但人根本打不了”的伪真实。

`v28` 的成功标准不是“城市里多了一块像网球场的贴图”，也不是“有一颗黄色小球能弹一弹”。它必须同时满足六件事。第一，仓库必须正式拥有 `venue:v28:tennis_court:chunk_158_140` 与 `prop:v28:tennis_ball:chunk_158_140` 两条 authored 资产入口，并把它们挂进现有 `scene_minigame_venue` / `scene_interactive_prop` 主链，而不是继续把规则散落进临时代码。第二，网球场必须在用户给定 ground probe 锚点附近落成，并明确暴露 singles court、service boxes、net plane、release bounds 等正式 contract，而不是靠肉眼猜边界；同时它必须按第三人称可玩尺度放大，并整体抬高，不能被地形吞掉，[已由 ECN-0026 变更](../ecn/ECN-0026-v28-tennis-playability-replan.md)。第三，玩法必须守住网球最小规则闭环：对角发球、单次 bounce、in/out、不过网/双误丢分，以及正式 point/game progression。第四，玩家不是看 AI 自娱自乐，必须能通过同一颗正式网球参与击球，形成 `player vs AI` 的回合；但玩家与 AI 的击球都必须尽量 obey tennis legality，而不是 generic ball impulse 的裸物理输入。第五，比赛必须有正式 HUD 与世界记分板，能显示当前 point / game 状态，并在比赛结束或玩家出圈时完整 reset；同时必须提供最低限度的接球 UX，例如落点预判、自动跑位辅助与击球窗口/质量反馈；共享 `E` 提示半径必须与合法击球窗口对齐，[已由 ECN-0026 变更](../ecn/ECN-0026-v28-tennis-playability-replan.md)。第六，`v28` 不得为了做网球而把 `v26/v27` 足球主链打坏；这意味着 `CityPrototype.gd` 需要从“只认足球 minigame runtime”提升成“可并存多 sport runtime 的聚合层”。

## Background

- `PRD-0015` 与 `v25` 已冻结 `scene_interactive_prop` 家族，以及足球 `prop:v25:soccer_ball:chunk_129_139` 的正式交互球入口。
- `PRD-0016` 与 `v26` 已冻结 `scene_minigame_venue` 家族、足球场馆 authored 挂载链、大型场边计分板与 `ambient_simulation_freeze` 主链。
- `PRD-0017` 与 `v27` 已证明 `scene_minigame_venue` 不只是静态场馆，而可以承载正式的比赛状态机、开赛圈、HUD 与 reset loop。
- 用户这次明确要求：
  - 在 `Chunk chunk_158_140 (158,140)` 新增一套网球 minigame
  - ground probe 锚点冻结为 `world=(5489.46, 20.62, 1029.73)`
  - 可以参考 `v27` 足球 minigame 的素材与结构
  - 需要先做 deep research，再按塔山循环先落文档，再开始施工
- 官方网球规则与 ITF Appendix VI 已经给出了足够稳定的场地、发球、回合与短局制依据；ITF Play and Stay 也明确支持面向非专业/入门体验的更慢节奏球路 [1][2][3]。

## Scope

本 PRD 只覆盖 `v28 tennis singles minigame`。

包含：

- 新增正式网球场馆 `venue:v28:tennis_court:chunk_158_140`
- 新增正式网球 prop `prop:v28:tennis_ball:chunk_158_140`
- 在用户指定锚点 author 一座 singles tennis court、net、scoreboard、start ring
- `player vs 1 AI opponent` 的单打 minigame
- 正式 serve / rally / point / game / final / reset 状态机
- 正式 court bounds、service boxes、net / in-out / bounce contract
- HUD 与世界空间记分板
- 必要的 map pin / icon 支持
- `CityPrototype` 多 minigame runtime 聚合、ambient freeze 聚合、手动击球事件分发
- 补齐 manifest / prop / geometry / serve / scoring / reset / e2e 测试

不包含：

- 不做双打、球童、裁判、观众、解说、联网或本地多人
- 不做完整职业赛会流程、换边、medical timeout、挑战鹰眼
- 不做复杂球拍骨骼、挥拍 IK、上旋/切削/截击分化动作系统
- 不做完整 let 规则、观众噪声、球拍碰撞精细判定
- 不做把网球场接入任务系统
- 不做把足球 runtime 改名复用成网球 runtime

## Non-Goals

- 不追求在 `v28` 首版里做成完整职业网球模拟
- 不追求把网球 ball 藏进 venue runtime 里绕开 `scene_interactive_prop`
- 不追求让 `CityPrototype.gd` 再继续膨胀成更多 sport 特判的巨石
- 不追求通过“看起来像网球场”而缺失正式 geometry / scoring contract
- 不追求为了图省事把足球 `5v5` AI 强行改造成网球 AI

## Requirements

### REQ-0018-001 系统必须在用户给定锚点落成正式的网球场馆与网球 interactive prop authored 入口

**动机**：用户要的是城市里又一套正式 sports minigame，而不是一段临时代码或只在编辑器里摆着看的场景。

**范围**：

- 正式新增 `venue:v28:tennis_court:chunk_158_140`
- 正式新增 `prop:v28:tennis_ball:chunk_158_140`
- 网球场馆与网球球都必须走现有 `scene_minigame_venue` / `scene_interactive_prop` registry -> manifest -> near chunk mount 主链
- 场馆锚点冻结为：
  - `anchor_chunk_id = chunk_158_140`
  - `anchor_chunk_key = (158, 140)`
  - `world_position = (5489.46, 20.62, 1029.73)`
- 场馆 manifest 最小字段必须至少包含：
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
- ball manifest 最小字段必须至少包含：
  - `prop_id`
  - `display_name`
  - `feature_kind`
  - `anchor_chunk_id`
  - `anchor_chunk_key`
  - `world_position`
  - `surface_normal`
  - `scene_root_offset`
  - `scene_path`
  - `interaction_kind`
  - `prompt_text`
  - `target_diameter_m`
  - `physics_mass_kg`
  - `kick_impulse`
  - `kick_lift_impulse`

**非目标**：

- 不要求 `v28` 首版支持多座网球场同时开赛
- 不要求 `v28` 首版引入新的 world feature family

**验收口径**：

- 自动化测试至少断言：网球场馆与网球 ball 都被正式写入 registry / manifest。
- 自动化测试至少断言：`chunk_158_140` near mount 后可以找到正式 `venue_id` 与 `prop_id` 对应节点。
- 自动化测试至少断言：`primary_ball_prop_id` 正式绑定到 `prop:v28:tennis_ball:chunk_158_140`。
- 反作弊条款：不得把网球 ball 藏在 runtime 内部；不得只在代码里硬编码一个不存在 manifest 的球场。

### REQ-0018-002 网球场馆必须暴露正式单打球场 geometry、net 与 service contract，并以第三人称可玩的 arcade-scale 落地

**动机**：没有正式 court / net / service box contract，网球的合法发球、合法落点和出界判定都无法稳定成立。

**范围**：

- 场馆必须 author 一块稳定的 singles tennis court
- 几何比例以正式网球尺寸为 base，但首版 effective geometry 冻结为 `official proportions * 7.5`
- 平台总抬高量相对原始 authored 基线累计冻结为 `+2.0m`，[已由 ECN-0026 变更](../ecn/ECN-0026-v28-tennis-playability-replan.md)
- 场馆至少显式暴露：
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
  - `service_box_deuce_home`
  - `service_box_ad_home`
  - `service_box_deuce_away`
  - `service_box_ad_away`
  - `release_buffer_m`
- 场馆必须提供可见球网与正式 net collision / net plane contract
- 场馆必须提供 start ring、server anchor、receiver anchor 与 AI baseline anchor
- start ring 必须位于 home/player side serve setup zone 附近，不能落到远离可玩区的 sideline / apron，[已由 ECN-0026 变更](../ecn/ECN-0026-v28-tennis-playability-replan.md)
- 场馆必须提供正式 `in_play` 边界与 `release bounds`
- 场馆最小外观冻结为 hard court / tennis court 语义，不要求观众席

**非目标**：

- 不要求 `v28` 首版实现双打边线
- 不要求 `v28` 首版做高级材质或外部高模资产

**验收口径**：

- 自动化测试至少断言：场馆暴露的 court / net / service box contract 与 singles 网球语义一致，且 effective geometry 足够支撑第三人称可玩性。
- 自动化测试至少断言：网球穿过网高以下区域会被 net / collision 捕获，而不是像没有球网一样直接飞过去。
- 自动化测试至少断言：service boxes 与全场 bounds 是可判定的 geometry，不靠肉眼。
- 自动化测试至少断言：场地整体离地高度足够，不会被地形吞没。
- 自动化测试至少断言：start ring 位于 player-side serve setup zone 附近，而不是远离球场的偏移角落。
- 反作弊条款：不得只画线不暴露 contract；不得只做装饰性网面却没有任何 net 判定。

### REQ-0018-003 `v28` 必须提供正式的单打发球、回合与 point resolution 状态机，以及规则约束下的合法击球输入

**动机**：没有发球、bounce、in/out、不过网与 point winner 规则，网球就只剩下一颗会弹的小球。

**范围**：

- 比赛最小状态冻结为：
  - `idle`
  - `pre_serve`
  - `serve_in_flight`
  - `rally`
  - `point_result`
  - `game_break`
  - `final`
- 发球最小 contract 冻结为：
  - `server_side`
  - `serve_attempt_index`
  - `expected_service_box_id`
  - `serve_legal`
  - `fault_kind`
- 回合最小判分 contract 冻结为：
  - `last_hitter_side`
  - `ball_bounce_count_home`
  - `ball_bounce_count_away`
  - `last_legal_bounce_side`
  - `point_winner_side`
  - `point_end_reason`
- 玩家与 AI 必须围绕同一颗正式网球进行发球和回球
- 玩家必须能通过正式 `E` 键近距离击球入口参与 point
- 玩家 `E` 发球与回球必须先进入 tennis runtime 的合法 shot planner，再转成 ball velocity / impulse
- 默认发球必须打向合法对角 service box；默认回球必须打向对方半场安全区
- AI 必须能完成最小回球闭环：预判落点、移动、回球，并尽量 obey 同一套合法落点约束
- 双误、出界、不过网、二次落地都必须进入 point resolution

**非目标**：

- 不要求 `v28` 首版实现 let、球拍碰网、身体碰网、脚误等全部细则
- 不要求 `v28` 首版做复杂击球种类、旋转与挥拍动画细分

**验收口径**：

- 自动化测试至少断言：合法发球会进入正式 `rally`，而不是直接记分。
- 自动化测试至少断言：默认玩家发球不会向本方半场或明显非法方向裸飞。
- 自动化测试至少断言：fault / double fault 会把 point 判给接发方。
- 自动化测试至少断言：任一侧二次落地会结束 point，并把 point 判给对手。
- 自动化测试至少断言：击球入网或首次落点出界会结束 point，并把 point 判给对手。
- 自动化测试至少断言：玩家能通过同一颗正式网球参与 point，而且玩家与 AI 都不会退回成 generic forward impulse 的乱飞球。
- 反作弊条款：不得通过 debug 直改 point winner；不得生成第二颗隐藏比赛球；不得把 AI 回球做成无视球网和落点的传送。

### REQ-0018-003A `v28` 必须提供足够的接球 UI/UX，使玩家能读懂并接住 AI 回球

**动机**：如果玩家只能看见球飞来，却没有落点预判、跑位辅助与击球窗口反馈，那么玩法在体验上仍是“不可玩”。

**范围**：

- AI 回球后，玩家半场必须出现可读的落点预判
- 玩家需要获得轻度 auto-footwork assist，帮助收拢到理想击球槽位
- shared `E` prompt 的可触达半径必须与 tennis strike window 对齐，不能出现“窗口 ready 但提示不亮”的断链，[已由 ECN-0026 变更](../ecn/ECN-0026-v28-tennis-playability-replan.md)
- 玩家看到的蓝色 receive ring 必须是“可进入并触发接球”的操作圈，而不是与真实击球位分叉的假提示圈，[已由 ECN-0026 变更](../ecn/ECN-0026-v28-tennis-playability-replan.md)
- 来球第一次落地/进入正式击球阶段后，receive ring 应及时消失，只保留 `E` 提示与击球窗口反馈，[已由 ECN-0026 变更](../ecn/ECN-0026-v28-tennis-playability-replan.md)
- tennis ball 必须按 third-person 可读性做 oversize，visual mesh 也必须真实匹配 `target_diameter_m`，[已由 ECN-0026 变更](../ecn/ECN-0026-v28-tennis-playability-replan.md)
- tennis ball 还必须提供最小 third-person 可读性事件 cue：
  - 高对比度球体辅助视觉（例如 emissive shell / outline）
  - 高速来球 motion trail
  - 弹地 / 碰撞时的离散 impact audio cue
- 这些 cue 必须事件驱动或由球体速度驱动，不能退化成每帧重复播音或每帧重建视觉节点
- HUD 必须暴露最小击球辅助状态：
  - `landing_marker_visible`
  - `strike_window_state`
  - `strike_quality_feedback`
- 辅助目标是“让玩家接得住球”，不是替玩家完成整回合

**验收口径**：

- 自动化测试至少断言：AI 回球后，玩家侧存在可见/可读的接球辅助状态。
- 自动化测试至少断言：玩家进入 receive ring 后，共享 `E` 提示会在正式击球窗口内接上同一颗球的 return planner。
- 自动化测试至少断言：receive ring 不会在球已经进入正式击球阶段后继续无意义驻留。
- 自动化测试至少断言：当 `strike_window_state = ready` 时，共享 `E` 提示能够稳定亮起并进入正式 return planner。
- 自动化测试至少断言：玩家在合法窗口内按 `E`，会生成面向对方半场的可控回球，而不是随机乱飞。
- 自动化测试至少断言：oversized tennis ball 的 visual 尺寸与 `target_diameter_m` 一致，而不是只放大碰撞体。
- 自动化测试至少断言：正式 tennis ball scene 暴露可读性视觉 cue 与 impact audio cue，而且球体与地面发生真实碰撞时会触发离散 impact audio，而不是整条链路无声。
- 反作弊条款：不得把所谓 UX 修复降格为“把 AI 球速降到几乎停住”；不得改成完全脚本化过场。

### REQ-0018-004 `v28` 必须提供正式可读的 point / game / final 计分闭环

**动机**：没有正式 score progression，point resolution 就无法积累成“打完一场网球 minigame”的体验。

**范围**：

- HUD 与 world scoreboard 必须共享同一套正式 score state
- score state 最小 contract 冻结为：
  - `home_games`
  - `away_games`
  - `home_point_label`
  - `away_point_label`
  - `server_side`
  - `match_state`
  - `winner_side`
- `v28` 首版赛制冻结为：
  - 单打
  - `player vs AI`
  - `no-ad` game
  - 单盘短局制
- server 必须按 game 轮换
- 比赛结束后，HUD 与 world scoreboard 都必须显示 winner / final

**非目标**：

- 不要求 `v28` 首版做完整多盘赛
- 不要求 `v28` 首版做职业赛事级统计面板

**验收口径**：

- 自动化测试至少断言：point winner 会把 point score 正式推进，而不是只显示 toast。
- 自动化测试至少断言：game 结束后 server side 会正式轮换。
- 自动化测试至少断言：match final 后 HUD 与 world scoreboard 的 winner side 一致。
- 反作弊条款：不得只更新 HUD 不更新世界计分板；不得只改 game 数字但不保留 point/game 层级。

### REQ-0018-005 玩家离开网球场 release bounds 后，整场比赛必须完整 reset

**动机**：城市里的 minigame 需要可重复进入；如果只清一半状态，下次回来就会得到脏比赛。

**范围**：

- 玩家进入网球场有效玩法态时，允许启用 `ambient_simulation_freeze`
- 玩家离开 release bounds 后，整场比赛必须 reset：
  - 球回到当前 server anchor
  - 速度归零
  - `point / game / final` 状态清空
  - AI 回到 baseline anchor
  - HUD 隐藏
  - world scoreboard 清到开局值
- reset 不得依赖重载整个 world

**非目标**：

- 不要求 `v28` 首版保留跨 session 战绩
- 不要求 `v28` 首版在 reset 后保留上一场回放

**验收口径**：

- 自动化测试至少断言：出圈后球会回位并停下。
- 自动化测试至少断言：HUD 会隐藏，world scoreboard 会回到初始值。
- 自动化测试至少断言：AI 会回到初始站位。
- 反作弊条款：不得只清 HUD 文案；不得只清比分不清球与 AI 状态；不得通过 reload world 冒充 reset。

### REQ-0018-006 `v28` 不得破坏现有足球主链，且必须把 minigame runtime 入口提升为多 sport 聚合

**动机**：网球是第二个正式 sports minigame；如果入口仍然只认足球，仓库会立刻分叉成一堆硬编码特判。

**范围**：

- `CityPrototype.gd` 必须支持至少两套 venue runtime 并存：
  - soccer
  - tennis
- `ambient_simulation_frozen` 输出必须能够聚合多个 runtime
- 手动球交互事件必须按 `prop_id` 分发给正确 sport runtime
- HUD 必须支持至少两种 sport 的比赛面板，不允许网球借用足球 HUD 字段名冒充
- 受影响的足球 tests 必须继续通过
- full map pin 若展示网球场，`icon_id -> glyph` 必须正式支持 `tennis`

**非目标**：

- 不要求 `v28` 首版抽出一个复杂的通用体育抽象框架
- 不要求 `v28` 首版把所有旧 debug API 一次性重命名成完全通用形式

**验收口径**：

- 自动化测试至少断言：网球 runtime 可独立获取 state / HUD state。
- 自动化测试至少断言：网球场激活时可以驱动 ambient freeze，而不会因为入口只认足球而失效。
- 自动化测试至少断言：现有足球关键 tests 继续通过。
- 自动化测试至少断言：full map pin 若包含网球场，图标能被正式渲染。
- 反作弊条款：不得通过关闭足球功能来给网球让路；不得在 `CityPrototype.gd` 里堆一批互相打架的 sport 特判而没有正式聚合出口。

## Open Questions

- 首版单盘短局制是否精确冻结为某一档 Appendix VI 变体。当前答案：`v28` 先冻结为 `no-ad` 的紧凑单盘制，并在设计/计划中写明具体实现口径。
- 玩家是否需要可见球拍。当前答案：`v28` 首版不把球拍可视资产当 DoD。
- AI 是否需要多样化击球风格。当前答案：首版不做，先守住回合可读性。

## Future Direction

- `v29+` 可以把 `v28` 的基础单打扩成双打、可见球拍、更多击球类型与更复杂的 tie-break presentation。
- 如果后续要让体育场馆都走统一入口，可以在 `v28` 落地后再考虑抽取更正式的 sport runtime base，而不是在首版前过度设计。

## Sources

- [1] ITF 2026 Rules of Tennis: https://www.itftennis.com/media/7221/2026-rules-of-tennis-english.pdf
- [2] ITF Play and Stay: https://www.itftennis.com/en/growing-the-game/itf-tennis-play-and-stay/
- [3] ITF 2026 Technical Booklet: https://www.itftennis.com/media/15648/2026-technical-booklet.pdf
- [4] USTA Tennis Scoring Rules: https://www.usta.com/en/home/improve/tips-and-instruction/national/tennis-scoring-rules.html
