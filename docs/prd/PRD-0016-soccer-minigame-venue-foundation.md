# PRD-0016 Soccer Minigame Venue Foundation

## Vision

把 `godot_citys` 从“世界里只有一个能踢动的足球道具”推进到“世界里出现第一套正式可玩的足球 minigame 场馆”。`v26` 的目标不是一步到位做出完整 `11v11` 足球竞技模拟，而是先把足球玩法真正需要的场馆级要素立住：一块不受自然地形起伏破坏的平整比赛地面、两侧球门、正式进球检测、比分与回合重置，以及一条能把现有 `v25` 足球 prop 纳入场馆规则的 runtime 主链。

`v26` 的成功标准不是“足球旁边多了两个门”，也不是“做一个看起来像球场的装饰 scene”。它必须同时满足六件事。第一，仓库要正式拥有 `scene_minigame_venue` 这条 sibling family，用来承载“有边界、有规则、有重置、有比分”的 authored 玩法场馆，而不是滥用 `scene_landmark` 或继续把所有逻辑塞进 `scene_interactive_prop`。第二，足球场必须在用户指定的足球位置附近落成，并自带局部平整比赛承载层，不能要求 terrain 系统先变平。第三，[已由 ECN-0025 变更](../ecn/ECN-0025-v26-scoreboard-and-ambient-freeze.md) 场馆必须提供两侧球门、正式 goal detection、大型场边计分板，球进门后能更新世界空间计分显示并把球重置回开球点。第四，玩家必须能沿现有 `v25` 的踢球交互把球踢进门，形成最小但完整的“进场 -> 踢球 -> 进球/出界 -> 重置 -> 再开球”闭环。第五，[已由 ECN-0025 变更](../ecn/ECN-0025-v26-scoreboard-and-ambient-freeze.md) 进入足球 minigame 的有效玩法态后，系统必须允许把全城行人与 ambient 车辆冻结为静止状态，以守住玩法期性能，但这个冻结不得演变成全局 world pause，更不能把收音机停掉。第六，`v26` 首版必须明确拒绝把范围膨胀成 `22` 名球员、越位、犯规、裁判、门将 AI 的全套足球竞技模拟；这些属于后续版本，不允许在本版口径里偷渡。

## Background

- `PRD-0012` 与 `v21` 已冻结 `scene_landmark` authored 世界接入链，但也明确区分了“离散场景内容”和“需要改 terrain/water 的区域特征”不应混成一条 runtime。
- `PRD-0015` 与 `v25` 已冻结 `scene_interactive_prop` sibling family，并把足球作为首个真实 consumer 跑通。当前正式 `prop_id` 为 `prop:v25:soccer_ball:chunk_129_139`。
- 用户当前的新目标已经超出“一个能踢的球”：
  - 需要足球场边界
  - 需要两个球门
  - 需要进球检测
  - 需要更完整的足球玩法
- 用户还明确指出现实约束：当前大世界 terrain 不是平的，因此不能指望“直接在原地形上画两条线”就获得可玩的足球体验。
- [已由 ECN-0025 变更](../ecn/ECN-0025-v26-scoreboard-and-ambient-freeze.md) 用户还补充了两条性能与表现约束：
  - 场馆旁边应有一个大型计分板，而不是只有 HUD
  - 进入足球 minigame 后，可以把全城行人与 ambient 车辆冻结掉，但不能把收音机停掉
- 当前 `CityPrototype.gd` 与现有世界接入链能解决“点位挂载 authored scene”和“互动 prop 踢球”，但还没有一条正式的“场馆级 minigame runtime”主链。
- `CityPrototype.gd` 当前已有 `world_simulation_pause` 主链，服务 full map、controls help、vehicle radio quick overlay / browser 等 UI pause contract；这条链不能被直接拿来实现足球场的 ambient freeze，否则会把不该停的玩法与音频链一起停掉。

## Scope

本 PRD 只覆盖 `v26 soccer minigame venue foundation`。

包含：

- 新增正式 `scene_minigame_venue` family
- 新增独立于 `scene_landmark` 与 `scene_interactive_prop` 的 venue registry / manifest / runtime 主链
- 在足球当前位置附近 author 一个正式足球场馆 scene
- 场馆自带局部平整比赛地面，不依赖 terrain page 改造
- 两侧球门与正式进球检测
- [已由 ECN-0025 变更](../ecn/ECN-0025-v26-scoreboard-and-ambient-freeze.md) 大型场边计分板、最小比分状态、开球点与进球/出界后的球重置
- 场馆 runtime 与 `v25` 足球 prop 的正式协作 contract
- [已由 ECN-0025 变更](../ecn/ECN-0025-v26-scoreboard-and-ambient-freeze.md) 场馆激活时冻结全城行人与 ambient 车辆模拟，但保留收音机、玩家和场馆玩法 runtime
- 最少一条完整“踢球进门”自动化 e2e 流程

不包含：

- 不做 `11v11`、`7v7` 或 `5v5` 的完整球队系统
- 不做门将 AI、队友 AI、对手 AI、战术、传球配合或控球决策
- 不做越位、犯规、裁判、角球、界外球、红黄牌等完整规则系统
- 不做联网对战、本地双人、观众、解说或音频播报系统
- 不做 terrain 系统级的全局找平、地表重建或 nav 全面改写
- 不做 full map / minimap pin，除非后续版本另行立项

## Non-Goals

- 不追求把足球场继续包装成 `scene_landmark`
- 不追求把场馆逻辑继续塞进足球 prop scene
- 不追求把场馆性能模式偷换成现有 `world_simulation_pause`
- 不追求让球场“贴合自然起伏地形”来冒充可玩场地
- 不追求用两个装饰性球门和一块贴图草地就宣称完成 minigame
- 不追求在 `v26` 首版里偷渡完整多人足球竞技内容

## Requirements

### REQ-0016-001 系统必须支持独立于 landmark 和 prop 的 `scene_minigame_venue` 主链

**动机**：足球场馆不是单个可互动道具，也不是可发现地标。它是一个带规则和状态的 authored 玩法场景。

**范围**：

- 新增正式 registry：`scene_minigame_venue`
- registry entry 最小字段冻结为：
  - `venue_id`
  - `feature_kind`
  - `manifest_path`
  - `scene_path`
- `feature_kind` 在 `v26` 冻结为 `scene_minigame_venue`
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
- chunk near mount 时，若当前 chunk 命中相关 venue entry，则实例化 venue scene
- venue mount 必须是事件驱动的 chunk mount，不允许 per-frame 全量扫描 registry

**非目标**：

- 不要求 `v26` 首版支持多个场馆同时活跃比赛
- 不要求 `v26` 首版支持跨很多 chunk 的超大体育园区

**验收口径**：

- 自动化测试至少断言：venue registry 能正式加载并按 chunk 索引 entry。
- 自动化测试至少断言：目标 chunk near mount 时，venue scene 会被实例化并带有稳定 `venue_id` 元数据。
- 自动化测试至少断言：没有 registry entry 的 chunk 不会凭空多挂 venue scene。
- 自动化测试至少断言：venue mount 只发生在 chunk mount / remount 链路，不需要每帧扫全量 registry。
- 反作弊条款：不得把足球场偷偷挂成 `scene_landmark`；不得把场馆逻辑藏进 `_process()` 的全局扫描；不得把所有规则继续塞进足球 prop 节点。

### REQ-0016-002 足球场馆必须在足球位置附近提供正式可玩的平整比赛地面与边界

**动机**：自然 terrain 起伏会直接破坏带球、射门、进球判断和重置位置的稳定性。

**范围**：

- `v26` 的首个场馆正式 `venue_id` 冻结为 `venue:v26:soccer_pitch:chunk_129_139`
- 场馆 anchored 在当前足球所在 `chunk_129_139`
- 场馆必须引用并保留当前足球 authored anchor：
  - `primary_ball_prop_id = prop:v25:soccer_ball:chunk_129_139`
  - `world_position = (-1877.94, 2.52, 618.57)` 作为 kickoff / 场馆中心锚点
- 场馆 scene 必须自带局部平整比赛承载层
- 比赛承载层必须为球与玩家提供稳定碰撞平面
- 场馆必须提供清晰可见的边界线或 boundary cue
- 场馆必须提供正式 `in_play` 边界 contract，用于判定球是否出界

**非目标**：

- 不要求 `v26` 首版改变底层 terrain page 数据
- 不要求 `v26` 首版做真实尺寸十一人制标准场地

**验收口径**：

- 自动化测试至少断言：场馆 manifest 保存了 anchor chunk、kickoff anchor 与 `primary_ball_prop_id`。
- 自动化测试至少断言：venue mounted 后存在稳定的平整 playable floor，球与玩家不会因为地形起伏在中圈附近持续抖动、下沉或悬空。
- 自动化测试至少断言：场馆显式暴露 `in_play` 边界或等价 contract，而不是靠“肉眼看那块草地”判断。
- 自动化测试至少断言：球离开 `in_play` 边界时，venue runtime 能检测到 out-of-bounds。
- 反作弊条款：不得直接把 terrain 采样结果当作比赛平面；不得只画贴图线条而没有可判定边界；不得在文档里宣称“地形基本够平所以算完成”。

### REQ-0016-003 [已由 ECN-0025 变更] 场馆必须提供两侧球门、正式进球检测、比分更新以及大型场边计分板

**动机**：没有正式 goal detection，就没有足球玩法闭环，只有一个能滚动的球。

**范围**：

- 场馆必须提供 `goal_a` 与 `goal_b`
- 每个球门至少包含：
  - 可见球门几何
  - 球网/门框范围内的进球检测体积或等价 contract
  - 明确所属 side
- 当绑定足球进入球门有效检测区域时，venue runtime 必须更新比分
- 比分最小 contract 冻结为：
  - `home_score`
  - `away_score`
  - `last_scored_side`
- 场馆必须提供一个大型世界空间计分板，位于球场旁的稳定可读位置
- 计分板最小显示 contract 冻结为：
  - `home_score`
  - `away_score`
  - `game_state_label`
- HUD 可以继续显示比分，但首版的主可视比分 surface 必须是场边计分板，而不是只有 HUD
- 首版不要求复杂球门线技术，只要求稳定可靠的 goal volume 级判定

**非目标**：

- 不要求 `v26` 首版支持争议判罚回放
- 不要求 `v26` 首版支持射门速度、角度等高级统计

**验收口径**：

- 自动化测试至少断言：场馆 mounted 后，两侧球门节点与检测节点都存在。
- 自动化测试至少断言：足球进入 `goal_a` / `goal_b` 时，比分会更新到正确 side。
- 自动化测试至少断言：足球仅碰到门框附近或从球门背后穿入时，不会被误判为合法进球。
- 自动化测试至少断言：一次进球只记一次分，不允许在球停留在 goal volume 时连加多次。
- 自动化测试至少断言：场边计分板节点存在，且比分与 `game_state_label` 会跟随 venue runtime 正式更新。
- 自动化测试至少断言：玩家在球场主要可玩区域内能稳定看见并读懂计分板，而不是一个过小或被遮挡的装饰面片。
- 反作弊条款：不得把进球实现成按键加分；不得只靠“球坐标大概靠近门”就算进球；不得用手工脚本在测试里直接改比分绕过检测体积；不得只在 HUD 更新比分却把世界空间计分板留成静态装饰。

### REQ-0016-004 场馆 runtime 必须把现有足球 prop 纳入完整的回合重置闭环

**动机**：比分与球门只有在“进球后重置、出界后重置、重新开球”成立时才真正可玩。

**范围**：

- venue runtime 必须能找到 `primary_ball_prop_id` 对应的已挂载足球 prop
- 最小回合状态冻结为：
  - `idle`
  - `in_play`
  - `goal_scored`
  - `out_of_bounds`
  - `resetting`
- 进球后必须把球重置到 kickoff 点
- 出界后必须把球重置到 kickoff 点或冻结的 restart 点
- 重置时必须清零球的线速度与角速度
- 首版允许玩家自由进出场馆，但场馆 UI 与回合状态只在场馆有效范围内激活

**非目标**：

- 不要求 `v26` 首版重置玩家到严格站位
- 不要求 `v26` 首版实现完整开球规则或裁判吹哨流程

**验收口径**：

- 自动化测试至少断言：venue runtime 能通过 `primary_ball_prop_id` 绑定到现有足球 prop，而不是偷偷生成第二个球。
- 自动化测试至少断言：进球后球会回到 kickoff 点，且速度被正确归零。
- 自动化测试至少断言：出界后球会进入重置流程，而不是永远滚下山或留在场外。
- 自动化测试至少断言：重置完成后，玩家仍可继续使用现有 `E` 键踢球。
- 反作弊条款：不得复制一个隐藏球来代替重置原球；不得把“重置”实现成重新载入整个 world；不得让比分更新后球仍保持旧速度乱飞。

### REQ-0016-005 `v26` 必须提供至少一条完整可玩的足球 minigame 流程，并守住现有 v21/v25 主链

**动机**：用户要的是“比较完整的足球游戏起点”，不是一堆孤立组件。

**范围**：

- 最小可玩流程冻结为：
  - 玩家进入场馆范围
  - 场馆 HUD 或等价提示显示比分/状态
  - 玩家踢球
  - 球进门或出界
  - 系统更新比分或判定出界
  - 球回到 kickoff 点
  - 玩家可再次开球
- `v25` 足球交互链必须继续成立
- `v21` / `v25` 的 landmark / interactive prop / streaming 主链不得回退

**非目标**：

- 不要求 `v26` 首版做完整教程、任务接入或地图导航入口
- 不要求 `v26` 首版做球队阵容、换边、中场休息或比赛倒计时

**验收口径**：

- 至少一条 e2e 测试必须自动跑通“进场 -> 踢球 -> 进球 -> 记分 -> 重置 -> 再次可踢”的完整流程。
- 受影响的 `v25` 足球 interaction tests 必须继续通过。
- 受影响的 landmark / streaming / mount 相关 tests 必须继续通过。
- 若改动触及 chunk mount / runtime tick / HUD，每次 fresh closeout 仍需串行跑 profiling 三件套。
- 反作弊条款：不得用仅手测视频或聊天描述宣称完成；不得通过关闭旧交互链、关闭场馆逻辑或绕过 physics 来让测试表面变绿。

### REQ-0016-006 [已由 ECN-0025 新增] 场馆激活时必须支持 `ambient_simulation_freeze`，冻结全城行人与 ambient 车辆，但不得把收音机停掉

**动机**：足球 minigame 首版追求的是稳定、可读、低干扰的场馆玩法；全城 crowd/traffic 同时运行会额外消耗性能与注意力，但不能为了冻结它们而把玩家、足球、场馆 runtime 或收音机也一并停掉。

**范围**：

- 当玩家进入足球场馆有效玩法态时，系统必须允许切入正式 `ambient_simulation_freeze`
- `ambient_simulation_freeze` 的冻结对象只包括：
  - 行人模拟 runtime
  - ambient 车辆模拟 runtime
- `ambient_simulation_freeze` 的触发/释放语义冻结为：
  - 玩家进入比赛场地有效范围时，立即进入冻结态
  - 解冻条件不是“刚出赛场边界”，而是玩家离开赛场边界后，再走出一圈额外的 `24.0m release buffer`
  - 进入圈与释放圈必须形成迟滞，不允许玩家在边缘来回走动时频繁抖动切换
- `ambient_simulation_freeze` 必须保留：
  - 玩家控制
  - 足球 prop 物理
  - 足球场 venue runtime
  - 场馆 HUD / 计分板更新
  - 收音机 runtime 与 audio backend
- `ambient_simulation_freeze` 不得复用当前 `world_simulation_pause` 主链
- 冻结时允许保留 crowd / traffic 当前可见快照，使其以静止状态继续存在于世界中；首版不要求强制卸载这些节点

**非目标**：

- 不要求 `v26` 首版让冻结中的行人与车辆继续执行低频动画
- 不要求 `v26` 首版支持多个不同 minigame 同时争夺 ambient freeze 所有权

**验收口径**：

- 自动化测试至少断言：激活足球场馆后，行人与 ambient 车辆的 simulation step / assignment rebuild / runtime state 会进入冻结态。
- 自动化测试至少断言：ambient freeze 不会把 `is_world_simulation_paused()` 置为 `true`，以免误走 full map / radio browser 的 pause contract。
- 自动化测试至少断言：ambient freeze 期间，足球、venue runtime 与比分/计分板更新仍可继续运行。
- 自动化测试至少断言：ambient freeze 期间，收音机若原本处于播放态，则仍保持播放，不会因为足球场馆激活而自动停止。
- 自动化测试至少断言：玩家刚离开赛场边界但仍处于 `24.0m release buffer` 内时，ambient freeze 仍保持激活，不会立刻解冻。
- 自动化测试至少断言：离开足球场馆有效玩法态后，crowd / traffic simulation 能恢复。
- 自动化测试至少断言：玩家在边界附近反复进出时，freeze state 不会每几帧来回翻转。
- 反作弊条款：不得通过全局 `Engine.time_scale = 0`、`SceneTree.paused = true`、`_apply_world_simulation_pause(true)` 或粗暴停掉 audio backend 来冒充 ambient freeze。

## Open Questions

- 后续是否要把足球 minigame 接到任务系统。当前答案：`v26` 不做，先把自由玩法闭环立住。
- 后续是否要给场馆加 minimap / full-map pin。当前答案：`v26` 不做，除非玩法需要主动导航。
- 球门后方是否需要 invisible catch wall。当前答案：可作为实现细节，但不应替代正式 out-of-bounds / reset contract。
- `ambient_simulation_freeze` 是否默认在玩家靠近球场就触发。当前答案：先冻结为“进入比赛场地有效范围时触发”，不在 chunk mount 或远距离路过时误触发；解冻则必须等玩家离开赛场边界后再额外退出 `24.0m`。

## Future Direction

- `v27` 可考虑在 `scene_minigame_venue` 基础上新增简单门将、1v1 或 1vN 训练玩法。
- 如果未来需要把足球场做成更“活”的比赛场景，可在后续版本把 `ambient_simulation_freeze` 放宽成更细粒度的 `venue bubble crowd/traffic suppression`，但 `v26` 首版优先守住稳定和性能。
- `v28+` 再考虑小队足球、计时赛、任务接入、观众反馈或更复杂规则。
- `11v11`、完整球队 AI 与正式比赛规则应单独立项，不应在 `v26` 首版偷偷膨胀。
