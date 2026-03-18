# 2026-03-18 V26 Soccer Minigame Venue Design

## 方案选择

围绕“把现在这个足球扩成比较完整的足球游戏”，其实有三条路。

方案 A 是一步到位做完整比赛：两边各 `11` 人、球门、边线、裁判、规则、完整 AI。这条路最接近用户脑海里的“足球游戏”，但它在当前仓库里风险最大。因为它同时要求新 family、平整场地、进球检测、回合状态、队友/对手 AI、门将、碰撞与导航约束，还会立刻碰到 performance 和行为稳定性问题。它不是不能做，而是绝对不该作为 `v26` 首版 DoD。

方案 B 是先做“可玩的场馆基础版”。也就是新开 `scene_minigame_venue`，把球场、球门、进球检测、比分、大型场边计分板、出界、重置、基础 HUD 和现有足球 prop 的联动先打通。这样用户一进场，就已经有一个完整玩法闭环：球能踢、门能进、分能记、球会重置，而且比分不只存在于 HUD，还会通过一个明确的世界空间计分板被看见。这不是完整职业足球，但已经不是“只有一个球”的玩具状态。

方案 C 是只做射门训练场：一个门、一个球、一个重置点。这条路实现最轻，但太容易把未来收窄成“射门靶场”，而不是足球 minigame。综合范围、可玩性和后续扩展性，`v26` 推荐冻结方案 B。它既不冒进到 `11v11`，也不后退成纯训练假人系统。

## 为什么需要新 family，而不是继续扩足球 prop

`v25` 的足球是 `scene_interactive_prop`，它的职责很清楚：一个世界里的可互动道具，靠近后出现 prompt，按 `E` 后产生真实物理 kick。这个抽象对“球本身”是对的，但对“球场”不对。球场不是单个道具，它有边界、球门、比分、回合状态、重置逻辑，以及一个明显更大的 authored 空间语义。如果继续把这些东西塞进足球 prop scene，最终会得到一个荒唐的对象：它既是球，又要当记分牌、裁判、场地管理器和规则引擎。

所以 `v26` 应该新开 sibling family：`scene_minigame_venue`。它和 `scene_landmark`、`scene_interactive_prop` 一样，继续复用 `registry -> manifest -> near chunk mount -> scene` 这套已经成熟的 authored 接入纪律；但它的语义明确是“可玩场馆”。在这个 family 里，场馆 scene 负责场地、球门、比分、重置与回合状态；足球则继续保留为独立的 `scene_interactive_prop`，通过 `primary_ball_prop_id` 被 venue runtime 绑定和管理。这样分层之后，后面要加别的小游戏场馆，比如篮球半场、停车训练区、射击靶场，也都有了正确归宿。

## 大型计分板怎么放

既然用户明确希望计分板是一个树立在球场旁的大型装置，那它就不该被当成一个附属 HUD 图标。`v26` 推荐把它作为场馆 scene 的正式组成部分：一个独立的 world-space scoreboard root，固定立在边线外、朝向主要玩法区，默认用足够大的数字与简洁的 `HOME / AWAY / 状态` 三区域布局。这样做有两个好处。第一，比分变成了场馆空间叙事的一部分，玩家抬头就能看，不会像只有 HUD 时那样容易被忽略。第二，后续如果要做进球闪烁、状态条、比赛倒计时、赞助牌外观，也都有了稳定挂点。

这块计分板不应该做成特别花的屏幕系统。`v26` 首版的重点是“可读”和“稳定更新”，而不是高保真体育转播 UI。也就是说，先把节点结构、数字显示 contract 和 runtime 更新链路冻住，再考虑更复杂的材质或动画。HUD 仍然保留，但定位应该退到辅助视图，而不是唯一比分来源。

## 地形不平怎么解决

当前 terrain 系统不是平的，这不是小问题，而是决定方案成败的边界条件。如果强行让足球玩法贴自然地形，就会立刻出现三个连锁问题。第一，球的滚动和停靠变得不可预测，稍微有坡就会偏航或自己滑走。第二，球门高度、门线检测和边界判断会受地表起伏干扰。第三，任何“为什么这次没进球”的排查都会变成 terrain、physics、goal volume 三者互相甩锅。

`v26` 的推荐解法不是改 terrain pipeline，而是让场馆自带一块 authored 的平整比赛承载层。可以把它理解成一个局部抬起、局部找平的球场地台或铺装层：视觉上它仍然坐在城市世界里，但玩法上它提供一个稳定、平整、可预测的 collision floor。这样做的好处是边界清晰。球场的平整性、边线、球门和重置点都由场馆 scene 自己保证，不用去碰整个城市地形系统。代价是球场边缘需要做一点过渡，比如低矮包边、台阶、草地裙边或者缓坡装饰，避免场馆像一块突兀贴图浮在地面上。但这笔成本远小于为 `v26` 单独发明“局部 terrain flattening runtime”。

## 玩法闭环与状态机

`v26` 首版的玩法闭环应该极简但完整：玩家进入场馆范围，HUD 显示当前比分和回合状态；玩家继续用 `E` 踢 `v25` 足球；球在场内滚动；如果进入任一球门的合法 goal volume，则记分；如果滚出边界，则判定出界；随后 venue runtime 把球重置回 kickoff 点，并清空球的线速度与角速度；玩家可以再次开球。这条链已经满足“可玩 minigame”的最低标准。

因此 runtime 最小状态机建议冻结为：`idle -> in_play -> goal_scored/out_of_bounds -> resetting -> idle`。`idle` 表示球在 kickoff 点等待开球；第一次有效踢球后进入 `in_play`；进球或出界后进入对应结果态；随后系统执行 reset，并返回 `idle`。这里最关键的设计点是：venue runtime 不应该偷偷生成第二个球，也不应该把“重置”实现成重开整个场景。它必须显式绑定现有 `prop:v25:soccer_ball:chunk_129_139`，并直接控制这一个球的 reset。这能保证 `v25` 的交互语义在 `v26` 中继续成立，而不是被新系统替换掉。

这条状态机还应该顺便驱动计分板。也就是一旦进入 `goal_scored`，计分板上的比分和状态文案必须一起更新；进入 `resetting` 时，计分板可以显示简短状态，例如“RESET”或“READY”。这样比分不是一个孤立数字，而是场馆 runtime 的正式输出。

## 性能策略：`ambient_simulation_freeze`，不是 global pause

用户补充的“进入游戏后把整个世界的行人和车辆都静止掉”是合理的，但实现方式必须非常克制。当前仓库里已经有现成的 `world_simulation_pause` 主链，它服务 full map、controls help、radio quick overlay 和 browser 这些 UI surface。那条链的语义是“暂停 3D 世界”，不是“只停 ambient crowd/traffic”。如果直接拿它来做足球场，很容易把 venue runtime、球物理、交互，甚至 radio 行为一起打停，这和用户要求“别把收音机停了”正面冲突。

`v26` 正确的做法应该是新增一个更窄的模式：`ambient_simulation_freeze`。它只冻结 `CityPedestrianTierController` 和 `CityVehicleTierController` 这类 ambient simulation controller 的 step / assignment rebuild / reaction update，让它们维持最后一帧可见快照；玩家、足球、场馆 runtime、HUD、计分板和 radio controller 全部继续运行。换句话说，这不是 pause 整个 world，而是把“与足球场玩法无关、但会消耗预算的全城 crowd/traffic 模拟”静音处理。这样既能把性能让给 minigame，又不破坏 `v24` 已冻结的收音机生命周期。

这条 freeze 还必须带迟滞，不然边缘体验会非常糟。用户已经明确说了：进入比赛场地就可以冻结，但退出时不能刚出赛场边界就立刻解冻，否则会误触发。推荐冻结方案是双圈层。内圈是比赛场地有效范围，玩家一进入就激活 ambient freeze；外圈是释放圈，用比赛场地边界向外扩 `24m` 形成 release buffer。只有玩家离开这个外圈，系统才真正解冻。这能保证人贴着边线跑动、捡球、或者刚走到场边看计分板时，不会让 crowd/traffic 在背后反复开开关关。

## 版本切分

真正的“比较完整足球游戏”一定还要往后走，但 `v26` 只做 foundation。后续版本可以这样展开。

下一版优先级最高的是“有对抗但仍可控”的内容，比如一个简单门将、一个防守 dummy、或者 `1v1 / 1vN` 的训练玩法。这样用户会明显感觉“更像足球了”，但系统复杂度仍然可控。再下一层才是小队比赛、倒计时、换边、任务接入、记录统计。完整 `11v11` 则应该是更后面的专门版本，它需要独立解决球员 AI、站位、碰撞密度、导航、裁判规则、性能红线等问题。

换句话说，`v26` 不是“完整足球游戏的终点”，而是“正式足球玩法系统的第一块地基”。地基必须稳，但不能假装自己已经是整栋楼。

## 测试与验收策略

`v26` 的测试要围着“场馆是否真的形成玩法闭环”来写，而不是围着节点是否存在。第一类是 registry/runtime contract，证明 `scene_minigame_venue` 是正式 family，不是临时场景硬插。第二类是场地 contract，证明 playable floor、边界与球门检测都能稳定被 runtime 消费。第三类是 score/reset contract，证明球进门记一次分、出界能重置、重置后仍能继续踢。这里现在还要额外加一层：scoreboard contract，证明世界空间大计分板确实跟 runtime 绑定，不是装饰。第四类是 ambient freeze contract，证明冻结 crowd/traffic 后，球场玩法和收音机还活着，而且带 `24m` release buffer 的迟滞不会在边界处抖动。第五类才是 e2e flow，证明玩家从进场到再次开球的整条流程跑得通。

同时要保住已有资产。`v25` 的足球 interaction tests 不能回退，`v21`/`v25` 的世界挂载主链不能被 `scene_minigame_venue` 污染，`v24` 的 radio contract 也不能被足球场误伤。如果 `v26` 的实现触及 chunk mount、runtime tick 或 HUD，就必须继续接受 profiling 三件套约束。也就是说，`v26` 不是“先把球场做出来再看性能”，而是从第一天起就按正式世界功能的纪律推进。
