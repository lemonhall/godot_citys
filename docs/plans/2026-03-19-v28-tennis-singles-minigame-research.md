# 2026-03-19 V28 Tennis Singles Minigame Research

## Executive Summary

`v28` 网球 minigame 最适合落成一套 `player vs AI opponent` 的单打短局制玩法，而不是直接复制职业网球的整套赛会编排。官方规则已经给出了足够稳定的场地、发球、回合与判分基础；同时，ITF 也明确提供了适合更紧凑、对新手更友好的替代计分方式与慢速球思路，因此把 `godot_citys` 的首版网球冻结为“正式单打场地 + 单次 bounce / in-out / 对角发球 + no-ad short format”是有依据的 [1][2][3]。

对本仓库来说，关键不是“把一颗球换成黄色”，而是把现有 `scene_minigame_venue` 与 `scene_interactive_prop` 主链从“只服务足球”扩展到“可以同时承载足球和网球两种正式场馆玩法”。基于规则与仓库现实，`v28` 应优先落地：正式单打球场、球网、网球 interactive prop、玩家与 AI 的最小对抗闭环、HUD/世界记分板、出圈 reset、以及 `CityPrototype` 的多 minigame runtime 聚合，而不是先做球拍骨骼、双打、裁判、换边或完整职业赛事包装 [1][4]。

## Key Findings

- **官方单打场地几何足够明确，适合直接冻结为 authored contract**：单打球场长度 `23.77m`、单打宽度 `8.23m`，球网中心高度 `0.914m`、网柱处 `1.07m`；发球线距离球网 `6.40m`，这些数据足以定义 court mesh、net collision、service box 与 in/out 检测边界 [1]。
- **网球回合判定的最小规则链可以直接映射成 runtime 状态机**：发球必须斜线进入对角发球区；球员若未能在第二次落地前把球合法回到网对面、或把球打出界、击球入网、发球双误，则输掉该分 [1]。
- **官方确实允许更紧凑的短局制而不是只能做完整职业盘赛**：ITF Rules Appendix VI 明确允许 `no-ad scoring` 与 `short set` 等替代计分方式，这给 `v28` 冻结成“单盘短局制 minigame”提供了正式依据 [1]。
- **新手友好节奏不是拍脑袋的妥协，而是官方推广方向**：ITF Play and Stay 与 2026 Technical Booklet 都强调使用更慢、更可控的球与分级玩法，让初学者更容易形成稳定回合，因此 `v28` 采用 starter-friendly 的飞行速度、弹跳高度与 AI 节奏，是合理的官方导向，不是缩水偷工 [2][3]。
- **实现建议必须来自规则约束与仓库现有主链，而不是照搬足球行为**：足球 `5v5` runtime 已经证明了 `scene_minigame_venue -> runtime -> HUD / reset / ambient freeze` 这条链能承载正式玩法；但网球不是多 AI 围抢一颗活球，而是单颗球在网两侧合法往返，因此需要新的 serve / rally / point / game 状态机，以及 `CityPrototype` 的多 runtime 聚合，而不是把足球 runtime 改名复用 [1][4]。

## Detailed Analysis

### 1. 官方规则里哪些是 `v28` 必须要守住的硬 contract

ITF Rules of Tennis 已经把 `v28` 最需要的空间与判分锚点说明白了。对场地几何而言，单打 court 的长度、宽度、球网高度、发球线与中线位置都足够稳定，完全可以直接冻进 `minigame_venue_manifest + venue script` 的 contract 里 [1]。这意味着 `v28` 不需要自己“发明一个像网球的场地”，而是应该正式 author：

- 单打边线与底线
- 左右对角发球区
- 明确的 net plane / net collision / net height
- 玩家侧与 AI 侧基线锚点
- 进入比赛态后的 release bounds

对规则最小闭环而言，首版不需要完整实现全部细节，但至少要守住以下四条，否则就不再像网球：

1. 发球必须从本方底线后发起，并进入对角发球区 [1]。
2. 一个回合中，球在任一侧落地超过一次，该侧直接丢分 [1]。
3. 球若击球后不过网、或第一次落点越出当前允许区域，则击球方丢分 [1]。
4. 发球方若两次发球都不合法，则双误丢分 [1]。

这些规则本质上都能变成可测的 runtime state machine，而不是只能靠手感判断。

### 2. 计分方式应该如何为 minigame 做正式简化

如果直接照搬完整职业赛制，`v28` 会被拖进换边、长盘、完整盘赛流程、冗长 deuce 循环与 presentation 细节，和仓库当前“先把正式可玩的基础场馆跑通”的节奏不匹配。官方 Appendix VI 已经提供了替代路径：`no-ad scoring` 与 `short set` 都是正式允许的比赛变体 [1]。

结合这一点，`v28` 最合理的冻结方式是：

- `player vs AI opponent`
- 单打
- 单盘 `short set`
- game 内采用 `no-ad`
- 若需要决胜，进入简化 tie-break

这样做的优点有三点：

- 仍然保留了“发球局、分、局、盘”的正式网球层级，而不是退化成纯打靶积分。
- 单局不会在 `40-40` 后无限拉长，更适合 minigame 的时长控制 [1][4]。
- 可以把实现复杂度收敛在“point resolution + score progression + server alternation”这条主链上。

这里需要明确一点：这是基于官方替代格式做的受控简化，不是“因为做不出来所以把网球乱改”。这是规则允许范围内的 minigame 化。

### 3. starter-friendly 节奏为什么应该进入实现口径

ITF Play and Stay 的核心思想，就是通过更慢、更可控的球和分级场地/玩法，帮助玩家更快形成稳定来回球，而不是被过快球速直接打崩 [2]。2026 Technical Booklet 也继续保留了 stage ball 的正式规格，用于不同年龄和入门阶段 [3]。这对 `v28` 的含义并不是必须复刻某个认证 stage ball 的全部物理参数，而是说明首版 minigame 采取“比真实职业击球更慢、更高容错”的飞行与 AI 节奏，是有官方方向支撑的。

因此，`v28` 的推荐实现不应该追求：

- 过快的平击球速
- 过低容错的擦网/出界窗口
- AI 对玩家的高压制式连贯制胜分

更合理的冻结是：

- 发球与回球速度适中，保证可读的飞行弧线
- 弹跳高度略高于现实职业直播观感，以提升玩家反应窗口
- AI 以“优先回球形成回合”为主，而不是首版就做强杀型对手

这会让 `v28` 更像一个能玩起来的城市彩蛋网球场，而不是一个立刻把玩家虐退出圈的半成品。

### 4. 从规则推导出的实现结构建议

下面这些是从官方规则与仓库现实推导出的实现建议，不是外部文档直接给出的句子：

- **venue 层**：负责 court geometry、net、start ring、release bounds、world scoreboard、player/AI anchors。
- **interactive prop 层**：负责同一颗正式 tennis ball 的物理、玩家近距离 `E` 键击球入口、以及 prop manifest。
- **runtime 层**：负责 serve state、bounce tracking、in/out 判定、point/game/set progression、AI 回球决策、出圈 reset。
- **CityPrototype 聚合层**：负责同时驱动 soccer 与 tennis runtime，把 `ambient_simulation_frozen` 聚合成统一输出，并把手动击球事件分发给正确的 runtime，而不是继续只通知足球。

这条分层方式有两个明显好处。第一，它不需要为了网球重新发明第三条 world feature family，继续复用 `scene_minigame_venue` 与 `scene_interactive_prop` 主链即可。第二，它避免把 `CityPrototype.gd` 再次写成“足球 if/else + 网球 if/else”的失控巨石，而是把场馆规则继续收口在各自 runtime 内。

### 5. 哪些东西应该明确排除在 `v28` 之外

基于规则与工程节奏，以下内容应明确排除出首版范围：

- 双打
- 球拍骨骼、发球抛球 IK、截击/上旋/切削多动作系统
- 裁判、let、挑战鹰眼、换边、观众、解说
- 完整职业赛制、多盘长赛、抢七 presentation 打包
- full task system 集成
- 让网球 runtime 借用足球 `5v5` AI 的行为模型

这些内容不是“不做”，而是不能让它们破坏 `v28` 的首版闭环：`进场 -> 开赛 -> 发球 -> 来回球 -> 判分 -> 计局 -> 结束/出圈重置`。

## Areas of Consensus

- 官方场地几何、球网高度、发球区与单次 bounce / in-out / net 规则是稳定且明确的 [1]。
- 官方允许 `no-ad` 与 `short set` 这类更紧凑的替代赛制，不必强行做完整职业长盘 [1]。
- 面向新手与非专业场景时，较慢、较可控的球与节奏是官方推广方向的一部分 [2][3]。
- 对本仓库来说，继续沿 `scene_minigame_venue + scene_interactive_prop + runtime` 主链扩展，明显比发明一条网球专用 world feature 更合理。

## Areas of Debate

- **短局制具体冻结成哪一种**：Appendix VI 给出了多个可选替代格式；`v28` 需要在“更像正式网球”和“实现复杂度可控”之间取最稳的一档 [1]。
- **玩家击球入口的抽象层级**：是直接复用 `interactive prop` 的 `E` 键击球，还是再做一个更专门的 racket swing layer。规则文档不会回答这个问题，需要结合仓库现状做工程选择。
- **starter-friendly 的程度**：官方认可慢球与入门节奏，但 `v28` 仍需自行决定球速、反应窗口和 AI 压迫度，避免既不像网球又不好玩 [2][3]。

## Sources

[1] International Tennis Federation. *2026 Rules of Tennis*. 官方规则 PDF，权威一手来源。https://www.itftennis.com/media/7221/2026-rules-of-tennis-english.pdf

[2] International Tennis Federation. *ITF Tennis Play and Stay*. 官方推广页面，说明以更慢、更易控的教学/入门路径帮助玩家形成回合。https://www.itftennis.com/en/growing-the-game/itf-tennis-play-and-stay/

[3] International Tennis Federation. *2026 Technical Booklet*. 官方技术手册，包含场地、run-off、球与 stage ball 等技术规格。https://www.itftennis.com/media/15648/2026-technical-booklet.pdf

[4] United States Tennis Association. *Tennis Scoring Rules*. 面向玩家的解释型资料，适合把官方计分规则翻译成更可读的产品语言。https://www.usta.com/en/home/improve/tips-and-instruction/national/tennis-scoring-rules.html

## Gaps and Further Research

- 如果后续要把 `v28` 扩成更像正式比赛的 presentation 版本，还需要额外研究 tie-break 视觉表达、换边与 let 的 UI 告知方式。
- 如果后续要让玩家使用可见球拍或更真实击球动作，需要单独研究当前 player rig 与动画资源是否支持 racket 语义。
- 如果后续要做双打或观众表现，需要额外研究多人站位、碰撞与摄像机可读性，而这些都不应阻塞 `v28` 首版。
