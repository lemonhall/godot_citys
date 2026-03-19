# 2026-03-19 V28 Tennis Singles Minigame Design

## 方案选择

围绕“在 `chunk_158_140` 再 author 一个网球 minigame”，这里其实有三条路。方案 A 是把足球 `v27` 的 `5v5` runtime 改名，然后删到只剩两个人和一张更窄的场地；这会复用一些代码，但本质上是在拿“多人围抢活球”的行为模型去冒充网球，发球、对角服务区、bounce tracking 和 point/game/set progression 都不对。方案 B 是继续沿 `scene_minigame_venue + scene_interactive_prop` 主链新增一套网球场馆、网球 ball prop 和网球 runtime，让足球与网球共享世界接入管线，但各自维持独立规则状态机。方案 C 是另开一条新的 world feature family 专门做体育游戏。综合范围、复用和风险，`v28` 推荐方案 B。它能最大限度复用 `v26/v27` 已经打通的 manifest、chunk mount、HUD、ambient freeze、interactive prop 主链，同时避免把网球实现绑死在足球行为模型上，也不必再发明第三条 authored feature family。

## 为什么 `CityPrototype` 必须从“足球单 runtime”提升成“minigame runtime 聚合层”

当前 `CityPrototype.gd` 对 minigame venue 的认知仍然是“registry 读完以后再喂给 `_soccer_venue_runtime`，每帧只更新足球一个 runtime，手动踢球后也只通知足球”。这在只有 `v27` 时还能工作，但一旦 `v28` 落地，同一条 `scene_minigame_venue` family 下就会同时出现 `soccer_pitch` 和 `tennis_court`。如果仍然把 `ambient_simulation_frozen`、HUD、手动击球事件只接到足球一条线上，网球运行时要么根本收不到事件，要么只能继续往 `CityPrototype.gd` 里堆特判。

`v28` 推荐做法是保持“每个 sport 各有独立 runtime”，但把 `CityPrototype` 升为一个很薄的聚合层：

- 读取同一份 `scene_minigame_venue` 运行时快照；
- 分别配置 `CitySoccerVenueRuntime` 与 `CityTennisVenueRuntime`；
- 每帧收集各 sport runtime 的状态；
- 把 `ambient_simulation_frozen` 聚合成单个输出；
- 把 HUD 分别同步到 soccer / tennis 面板；
- 把手动击球事件按 `prop_id` 分发给正确的 runtime。

这样足球不会被网球回归破坏，网球也不用假装自己是足球的一个特殊状态。

## 网球场与互动球的 authored 结构

`v28` 应该继续沿 `v26` 的 authored scene 思路做一个程序化场馆，而不是强依赖外部大模型或复杂 DCC 资产。推荐新增：

- `venue:v28:tennis_court:chunk_158_140`
- `prop:v28:tennis_ball:chunk_158_140`

场馆 scene 负责 build：

- raised hard-court play surface
- singles sideline / baseline / service boxes / center mark
- net mesh + net collision
- 场边记分板
- start ring
- AI opponent anchor / player service anchor / return anchor

interactive prop scene 则继续使用 `RigidBody3D`，但把足球的“按 E 踢球”语义改成球类可配置 contract：网球 ball 采用更小直径、更轻质量、更高弹跳系数、更适合越网的 lift impulse，以及 `prompt_text = 按 E 击球`。这里不建议把网球 ball 直接做成 runtime 内部隐藏对象，因为那会打断已经成熟的 `scene_interactive_prop` mount / prompt / debug locate 主链。

## 规则状态机：从 serve 到 point，再到 game/set

网球不需要足球式的常时活球对抗，而需要一条明确的状态机。`v28` 推荐冻结以下 match state：

- `idle`
- `pre_serve`
- `serve_in_flight`
- `rally`
- `point_result`
- `game_break`
- `final`

point 级别再冻结以下观测量：

- `server_side`
- `receiver_side`
- `serve_attempt_index`
- `last_hitter_side`
- `last_legal_bounce_side`
- `ball_bounce_count_home`
- `ball_bounce_count_away`
- `ball_in_play_bounds`
- `point_winner_side`

score 级别采用 `no-ad short set`：game 内分值显示 `0 / 15 / 30 / 40 / game`；若来到 `40-40`，下一分直接决胜；games 进入单盘短局制，优先冻结为“先到 4 局获胜，若打到 3:3，则进入 tie-break-like 决胜局”。这里的设计取舍是：保留网球“分 -> 局 -> 盘”的正式层级，同时把实现复杂度控制在可测试的范围内，不把首版拖进完整职业赛事包装。

## 玩家与 AI 的击球语义

首版不值得先做球拍骨骼和复杂挥拍动画，建议先把可玩性收在“可控击球窗口 + 合法落点判分”上。玩家侧继续沿现有 `interactive prop` 主链：当网球 ball 进入玩家击球半径且当前 point 允许玩家击球时，HUD/提示显示 `按 E 击球`；玩家触发后，球按照玩家朝向与适度 lift 被打向 AI 半场。AI 侧不走 prompt，而是在对方半场内通过单个 opponent agent 做最小决策：

- 预判落点
- 向落点移动
- 合法击球窗口内回球
- 优先把球回到玩家半场内

这里的关键不是做出“特别聪明的 AI”，而是保证它能稳定把点打起来，并对发球、双误、出界、二次落地这些正式规则负责。也正因为如此，`v28` 的 AI 应该优先追求“形成可读回合”，而不是首版就追求强压制。

## HUD、世界记分板与 reset

`v28` 需要同时提供 HUD 与 world scoreboard，但两者口径必须完全共享同一套 runtime state。HUD 负责：

- 当前 games
- 当前 point score
- 发球方
- 当前状态（serve / rally / point / final）

world scoreboard 则负责在场馆旁提供稳定可见的比分 surface。用户离开网球场释放圈后，整场比赛必须 reset：球回到当前 server 锚点、分与局回到开局值、AI 回到 baseline、HUD 隐藏、winner/highlight 清空。这个 reset 不能只清 HUD 文案，也不能只重置球而保留旧 game score；必须是整条比赛状态一起归位。

## 测试策略

`v28` 的测试必须优先卡住规则闭环，而不是只看场景能 mount。推荐顺序：

1. registry / manifest / prop contract：确认 tennis court 与 tennis ball 都走正式 authored 主链。
2. court geometry / net / service box contract：确认场地几何是可判定的，不靠肉眼。
3. match start / HUD contract：确认 start ring、HUD、server state。
4. serve / point contract：确认合法发球、fault / double fault、bounce / out / net 对 point 的影响。
5. reset on exit / final scoreboard：确认出圈归位与胜负显示。
6. e2e：跑“进场 -> 开赛 -> 发球 -> 至少 1 个 point 结束 -> score 更新 -> 出圈 reset”的整链路。

实现过程中，足球相关回归本身也是 `v28` 的重要 guard，因为这次真正高风险的地方是 `CityPrototype` 的入口泛化，而不是网球 court geometry 本身。
